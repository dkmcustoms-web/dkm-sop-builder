"""
Database layer voor DKM SOP Builder — SQLAlchemy-engine naar Neon (Postgres).

Ontwerp:
- Eén gecachte SQLAlchemy-engine (@st.cache_resource) over alle reruns/sessies.
- pool_pre_ping=True vangt verbroken Neon-verbindingen op na auto-suspend/idle.
- Gebruik de POOLED Neon-string (host bevat '-pooler') zodat Neons eigen pooler
  de vele korte Streamlit-verbindingen afhandelt.

Connectie:
- DATABASE_URL eerst uit environment (Railway), met st.secrets als fallback (lokaal).
- 'postgres://' wordt herschreven naar 'postgresql://' (SQLAlchemy-schema).
- sslmode=require hoort in de string (Neon vereist TLS).

Security:
- Wachtwoorden ALTIJD met bcrypt; nooit plaintext.
- Alle queries gebruiken named params (:naam) -> parameterized, injection-veilig.
- DATABASE_URL als env-var / secret, nooit in code.
"""

import os
import re
import streamlit as st
from sqlalchemy import create_engine, text
import sqlparse
import bcrypt


# ---------- Connectie ----------
def _database_url() -> str:
    url = os.environ.get("DATABASE_URL")
    if not url:
        try:
            url = st.secrets["DATABASE_URL"]
        except Exception:
            url = None
    if not url:
        raise RuntimeError(
            "DATABASE_URL ontbreekt. Railway: Settings > Variables > DATABASE_URL. "
            "Lokaal: .streamlit/secrets.toml of een env-var. "
            "Gebruik de POOLED Neon-string met ?sslmode=require."
        )
    # SQLAlchemy verwacht het 'postgresql://' schema, niet 'postgres://'.
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql://", 1)
    # Forceer de psycopg v3-driver (we installeren psycopg[binary], niet psycopg2).
    # Zonder dit zoekt SQLAlchemy standaard naar psycopg2 en crasht op Railway.
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+psycopg://", 1)
    return url


@st.cache_resource
def get_engine():
    """Eén engine voor de hele app. Gecachet, dus niet bij elke rerun opnieuw."""
    return create_engine(
        _database_url(),
        pool_pre_ping=True,   # test connectie voor gebruik (Neon idle/suspend)
        pool_recycle=300,     # vervang connecties ouder dan 5 min
    )


# ---------- bcrypt ----------
def hash_pw(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def check_pw(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode(), hashed.encode())
    except Exception:
        return False


# ---------- Schema (idempotent) ----------
def _is_template_seed(stmt: str) -> bool:
    """True als dit statement de blokken-bibliotheek seedt (na commentaar negeren)."""
    no_comments = re.sub(r"--[^\n]*", "", stmt)
    return no_comments.strip().upper().startswith("INSERT INTO BLOCK_TEMPLATES")


def init_db():
    """Draait schema.sql bij elke start. CREATE TABLE IF NOT EXISTS -> veilig.
    De seed-INSERTs (blokken-bibliotheek) draaien ALLEEN als block_templates leeg is,
    zodat een herstart geen dubbele blokken aanmaakt.
    Statements worden gesplitst met sqlparse (correct met ';' in tekst/strings)."""
    here = os.path.dirname(__file__)
    with open(os.path.join(here, "schema.sql"), encoding="utf-8") as f:
        schema_sql = f.read()
    statements = [s.strip() for s in sqlparse.split(schema_sql) if s.strip()]
    eng = get_engine()
    with eng.begin() as conn:
        for stmt in statements:
            if _is_template_seed(stmt):
                n = conn.execute(text("SELECT COUNT(*) FROM block_templates")).scalar()
                if n and n > 0:
                    continue
            conn.exec_driver_sql(stmt)


def seed_users():
    """Maakt demo-users + klanten als users leeg is."""
    eng = get_engine()
    with eng.begin() as conn:
        n = conn.execute(text("SELECT COUNT(*) FROM users")).scalar()
        if n and n > 0:
            return
        acme = conn.execute(
            text("INSERT INTO customers (name, eori) VALUES (:n,:e) RETURNING id"),
            {"n": "Import4You", "e": "NL000000000000"},
        ).scalar()
        conn.execute(text("INSERT INTO customers (name, eori) VALUES (:n,:e)"),
                     {"n": "Marken", "e": "NL111111111111"})
        conn.execute(
            text("INSERT INTO users (login, password_hash, role) "
                 "VALUES (:l,:p,:r)"),
            {"l": "admin", "p": hash_pw("admin123"), "r": "admin"},
        )
        conn.execute(
            text("INSERT INTO users (login, password_hash, role) "
                 "VALUES (:l,:p,:r)"),
            {"l": "editor", "p": hash_pw("editor123"), "r": "editor"},
        )
        conn.execute(
            text("INSERT INTO users (login, password_hash, role, customer_id) "
                 "VALUES (:l,:p,:r,:c)"),
            {"l": "import4you", "p": hash_pw("klant123"), "r": "customer", "c": acme},
        )


# ---------- Helpers ----------
def _rows(result):
    """SQLAlchemy Result -> lijst van dicts (zoals psycopg dict_row gaf)."""
    return [dict(r._mapping) for r in result]


def _one(result):
    r = result.fetchone()
    return dict(r._mapping) if r else None


# ---------- Queries ----------
def get_user(login):
    eng = get_engine()
    with eng.connect() as conn:
        return _one(conn.execute(
            text("SELECT * FROM users WHERE login = :l"), {"l": login}))


def list_customers():
    eng = get_engine()
    with eng.connect() as conn:
        return _rows(conn.execute(text("SELECT * FROM customers ORDER BY name")))


def create_customer(name, eori):
    """Maakt een klant. Naam en EORI zijn verplicht (afgedwongen in de UI én DB)."""
    eng = get_engine()
    with eng.begin() as conn:
        return conn.execute(text(
            "INSERT INTO customers (name, eori) VALUES (:n,:e) RETURNING id"),
            {"n": name.strip(), "e": eori.strip()}).scalar()


def list_templates(only_active=True, lang="nl"):
    if lang not in ("nl", "en"):
        lang = "nl"
    q = (f"SELECT id, category, title_{lang} AS title, content_{lang} AS content, "
         "sort_order, active FROM block_templates")
    if only_active:
        q += " WHERE active = TRUE"
    q += " ORDER BY sort_order, category"
    eng = get_engine()
    with eng.connect() as conn:
        return _rows(conn.execute(text(q)))


def list_all_templates():
    eng = get_engine()
    with eng.connect() as conn:
        return _rows(conn.execute(
            text("SELECT * FROM block_templates ORDER BY sort_order")))


def update_template(tpl_id, category, title_nl, title_en, content_nl, content_en, active):
    eng = get_engine()
    with eng.begin() as conn:
        conn.execute(text(
            "UPDATE block_templates SET category=:cat, title_nl=:tnl, title_en=:ten, "
            "content_nl=:cnl, content_en=:cen, active=:act WHERE id=:id"),
            {"cat": category, "tnl": title_nl, "ten": title_en,
             "cnl": content_nl, "cen": content_en, "act": active, "id": tpl_id})


def add_template(category, title_nl, title_en, content_nl, content_en):
    eng = get_engine()
    with eng.begin() as conn:
        n = conn.execute(text(
            "SELECT COALESCE(MAX(sort_order),0)+1 FROM block_templates")).scalar()
        conn.execute(text(
            "INSERT INTO block_templates (category,title_nl,title_en,content_nl,"
            "content_en,sort_order) VALUES (:cat,:tnl,:ten,:cnl,:cen,:so)"),
            {"cat": category, "tnl": title_nl, "ten": title_en,
             "cnl": content_nl, "cen": content_en, "so": n})


def list_sops(customer_id=None, only_published=False):
    q = ("SELECT s.*, c.name AS customer_name FROM sops s "
         "JOIN customers c ON c.id = s.customer_id")
    cond, params = [], {}
    if customer_id:
        cond.append("s.customer_id = :cid"); params["cid"] = customer_id
    if only_published:
        cond.append("s.status = 'published'")
    if cond:
        q += " WHERE " + " AND ".join(cond)
    q += " ORDER BY s.updated_at DESC"
    eng = get_engine()
    with eng.connect() as conn:
        return _rows(conn.execute(text(q), params))


def create_sop(customer_id, title, lang, updated_by):
    eng = get_engine()
    with eng.begin() as conn:
        return conn.execute(text(
            "INSERT INTO sops (customer_id,title,lang,updated_by) "
            "VALUES (:c,:t,:l,:u) RETURNING id"),
            {"c": customer_id, "t": title, "l": lang, "u": updated_by}).scalar()


def get_sop(sop_id):
    eng = get_engine()
    with eng.connect() as conn:
        s = _one(conn.execute(text(
            "SELECT s.*, c.name AS customer_name, c.eori AS eori FROM sops s "
            "JOIN customers c ON c.id = s.customer_id WHERE s.id = :id"),
            {"id": sop_id}))
        blocks = _rows(conn.execute(text(
            "SELECT * FROM sop_blocks WHERE sop_id = :id ORDER BY sort_order"),
            {"id": sop_id}))
    return s, blocks


def _fill_placeholders(text_value, customer_name, eori):
    """Vervangt klant-plaatshouders in een blok (snapshot bij toevoegen).
    [KLANT] en [CUSTOMER] -> klantnaam ; [EORI] -> EORI-nummer."""
    if not text_value:
        return text_value
    return (text_value
            .replace("[KLANT]", customer_name)
            .replace("[CUSTOMER]", customer_name)
            .replace("[EORI]", eori))


def add_sop_block(sop_id, template_id, title, content):
    eng = get_engine()
    with eng.begin() as conn:
        # Klantgegevens ophalen om plaatshouders in te vullen (snapshot, Optie A).
        cust = conn.execute(text(
            "SELECT c.name, c.eori FROM sops s "
            "JOIN customers c ON c.id = s.customer_id WHERE s.id = :id"),
            {"id": sop_id}).fetchone()
        if cust:
            name, eori = cust[0], cust[1]
            title = _fill_placeholders(title, name, eori)
            content = _fill_placeholders(content, name, eori)
        n = conn.execute(text(
            "SELECT COALESCE(MAX(sort_order),-1)+1 FROM sop_blocks WHERE sop_id=:s"),
            {"s": sop_id}).scalar()
        conn.execute(text(
            "INSERT INTO sop_blocks (sop_id,template_id,title,content,sort_order) "
            "VALUES (:s,:t,:ti,:co,:so)"),
            {"s": sop_id, "t": template_id, "ti": title, "co": content, "so": n})


def update_sop_block(block_id, title, content):
    eng = get_engine()
    with eng.begin() as conn:
        conn.execute(text(
            "UPDATE sop_blocks SET title=:t, content=:c WHERE id=:id"),
            {"t": title, "c": content, "id": block_id})


def delete_sop_block(block_id):
    eng = get_engine()
    with eng.begin() as conn:
        conn.execute(text("DELETE FROM sop_blocks WHERE id=:id"), {"id": block_id})


def swap_block_order(a, b):
    eng = get_engine()
    with eng.begin() as conn:
        conn.execute(text("UPDATE sop_blocks SET sort_order=:o WHERE id=:id"),
                     {"o": b["sort_order"], "id": a["id"]})
        conn.execute(text("UPDATE sop_blocks SET sort_order=:o WHERE id=:id"),
                     {"o": a["sort_order"], "id": b["id"]})


def set_prepared_on(sop_id, prepared_on):
    """Zet de handmatige 'opgemaakt op'-datum (date of ISO-string)."""
    eng = get_engine()
    with eng.begin() as conn:
        conn.execute(text("UPDATE sops SET prepared_on=:d WHERE id=:id"),
                     {"d": prepared_on, "id": sop_id})


def publish_sop(sop_id, updated_by):
    eng = get_engine()
    with eng.begin() as conn:
        conn.execute(text(
            "UPDATE sops SET status='published', updated_by=:u, updated_at=now() "
            "WHERE id=:id"), {"u": updated_by, "id": sop_id})
