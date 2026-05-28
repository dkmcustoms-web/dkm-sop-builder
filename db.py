"""
Database layer voor DKM SOP Builder — Postgres / Neon.

Connectie via env-var DATABASE_URL (Neon connection string):
  postgresql://user:pass@ep-xxx.eu-central-1.aws.neon.tech/sopbuilder?sslmode=require

Security:
- sslmode=require staat in de connection string (Neon vereist TLS).
- Wachtwoorden ALTIJD met bcrypt; nooit plaintext.
- Zet DATABASE_URL als Azure App Service env-var, niet in code.
- Gebruik een aparte read/write rol i.p.v. de owner-rol.
"""

import os
from contextlib import contextmanager
import psycopg
from psycopg.rows import dict_row
import bcrypt

DATABASE_URL = os.environ["DATABASE_URL"]  # faalt expliciet als niet gezet


@contextmanager
def get_conn():
    conn = psycopg.connect(DATABASE_URL, row_factory=dict_row)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def hash_pw(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def check_pw(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode(), hashed.encode())
    except Exception:
        return False


# ---------- Schema (idempotent) ----------
def init_schema():
    """Draait schema.sql als de tabellen nog niet bestaan.
    In productie kun je schema.sql ook één keer via de Neon SQL Editor draaien."""
    here = os.path.dirname(__file__)
    with open(os.path.join(here, "schema.sql"), encoding="utf-8") as f:
        sql = f.read()
    with get_conn() as c:
        exists = c.execute(
            "SELECT to_regclass('public.block_templates') IS NOT NULL AS ok"
        ).fetchone()["ok"]
        if not exists:
            c.execute(sql)


def seed_users():
    """Maakt demo-users + klanten aan als users leeg is.
    De blokken-bibliotheek komt uit schema.sql."""
    with get_conn() as c:
        if c.execute("SELECT COUNT(*) AS n FROM users").fetchone()["n"] > 0:
            return
        acme = c.execute(
            "INSERT INTO customers (name) VALUES (%s) RETURNING id", ("Import4You",)
        ).fetchone()["id"]
        c.execute("INSERT INTO customers (name) VALUES (%s)", ("Marken",))
        c.execute(
            "INSERT INTO users (login, password_hash, role) VALUES (%s,%s,%s)",
            ("admin", hash_pw("admin123"), "admin"),
        )
        c.execute(
            "INSERT INTO users (login, password_hash, role) VALUES (%s,%s,%s)",
            ("editor", hash_pw("editor123"), "editor"),
        )
        c.execute(
            "INSERT INTO users (login, password_hash, role, customer_id) "
            "VALUES (%s,%s,%s,%s)",
            ("import4you", hash_pw("klant123"), "customer", acme),
        )


# ---------- Queries ----------
def list_customers():
    with get_conn() as c:
        return c.execute("SELECT * FROM customers ORDER BY name").fetchall()


def list_templates(only_active=True, lang="nl"):
    """Geeft templates met titel/inhoud al gemapt naar de gekozen taal."""
    q = ("SELECT id, category, title_%s AS title, content_%s AS content, "
         "sort_order, active FROM block_templates" % (lang, lang))
    if only_active:
        q += " WHERE active = TRUE"
    q += " ORDER BY sort_order, category"
    with get_conn() as c:
        return c.execute(q).fetchall()


def list_sops(customer_id=None, only_published=False):
    q = ("SELECT s.*, c.name AS customer_name FROM sops s "
         "JOIN customers c ON c.id = s.customer_id")
    cond, params = [], []
    if customer_id:
        cond.append("s.customer_id = %s"); params.append(customer_id)
    if only_published:
        cond.append("s.status = 'published'")
    if cond:
        q += " WHERE " + " AND ".join(cond)
    q += " ORDER BY s.updated_at DESC"
    with get_conn() as c:
        return c.execute(q, params).fetchall()


def get_sop(sop_id):
    with get_conn() as c:
        s = c.execute(
            "SELECT s.*, c.name AS customer_name FROM sops s "
            "JOIN customers c ON c.id = s.customer_id WHERE s.id = %s", (sop_id,)
        ).fetchone()
        blocks = c.execute(
            "SELECT * FROM sop_blocks WHERE sop_id = %s ORDER BY sort_order", (sop_id,)
        ).fetchall()
    return s, blocks
