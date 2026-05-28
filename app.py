"""
DKM SOP Builder — Streamlit app (SQLAlchemy + Neon).

Rollen:
  admin    : beheert blok-templates (NL+EN) + SOP's
  editor   : maakt & vult SOP's (geen templatebeheer)
  customer : read-only eigen gepubliceerde SOP's + PDF-download

Vereist DATABASE_URL (Railway env-var of st.secrets).
Demo-logins (seed): admin/admin123 · editor/editor123 · import4you/klant123
"""

import streamlit as st
import db
import pdf_export

st.set_page_config(page_title="DKM SOP Builder", page_icon="📋", layout="wide")

DKM_BLUE, DKM_ORANGE = "#3cceff", "#f35e40"
st.markdown(f"""
<style>
  .stApp h1, .stApp h2, .stApp h3 {{ color: {DKM_ORANGE}; }}
  div.stButton > button[kind="primary"] {{
      background: {DKM_BLUE}; border: none; color: #0a2a33; font-weight: 600; }}
</style>""", unsafe_allow_html=True)

# Schema + demo-users 1x klaarzetten (idempotent)
db.init_db()
db.seed_users()

LANGS = {"Nederlands": "nl", "English": "en"}


# ---------- Auth ----------
def login_view():
    st.title("📋 DKM SOP Builder")
    st.caption("Standard Operating Procedures — maken, beheren, delen")
    with st.form("login"):
        login = st.text_input("Login")
        pw = st.text_input("Wachtwoord", type="password")
        if st.form_submit_button("Inloggen", type="primary"):
            row = db.get_user(login)
            if row and db.check_pw(pw, row["password_hash"]):
                st.session_state.user = row
                st.rerun()
            else:
                st.error("Ongeldige login.")
    st.info("Demo: admin/admin123 · editor/editor123 · import4you/klant123")


def logout():
    st.session_state.pop("user", None)
    st.rerun()


# ---------- Admin: tweetalig template-beheer ----------
def templates_page():
    st.header("Blok-bibliotheek (NL + EN)")
    st.caption("Standaardblokken met default tekst in beide talen. De tekst wordt "
               "gekopieerd in een SOP bij toevoegen — wijzigingen hier raken "
               "bestaande SOP's niet.")
    for t in db.list_all_templates():
        label = f"[{t['category']}] {t['title_nl']} / {t['title_en']}"
        with st.expander(label + ("" if t["active"] else "  (inactief)")):
            with st.form(f"tpl_{t['id']}"):
                cat = st.text_input("Categorie", t["category"])
                c1, c2 = st.columns(2)
                tnl = c1.text_input("Titel (NL)", t["title_nl"])
                ten = c2.text_input("Title (EN)", t["title_en"])
                cnl = c1.text_area("Tekst (NL)", t["content_nl"], height=200)
                cen = c2.text_area("Content (EN)", t["content_en"], height=200)
                active = st.checkbox("Actief", t["active"])
                if st.form_submit_button("Opslaan", type="primary"):
                    db.update_template(t["id"], cat, tnl, ten, cnl, cen, active)
                    st.success("Opgeslagen."); st.rerun()

    st.divider()
    st.subheader("Nieuw blok")
    with st.form("new_tpl"):
        cat = st.text_input("Categorie")
        c1, c2 = st.columns(2)
        tnl = c1.text_input("Titel (NL)"); ten = c2.text_input("Title (EN)")
        cnl = c1.text_area("Tekst (NL)", height=160)
        cen = c2.text_area("Content (EN)", height=160)
        if st.form_submit_button("Toevoegen", type="primary") and tnl and ten:
            db.add_template(cat or "Algemeen", tnl, ten, cnl, cen)
            st.success("Blok toegevoegd."); st.rerun()


# ---------- Editor/Admin: SOP-bouwer ----------
def builder_page(user):
    st.header("SOP's")

    # Nieuwe klant aanmaken (naam + EORI verplicht)
    with st.expander("👤 Nieuwe klant aanmaken"):
        with st.form("new_customer"):
            cn = st.text_input("Klantnaam *")
            ce = st.text_input("EORI-nummer *", placeholder="bv. BE0123456789")
            submitted = st.form_submit_button("Klant aanmaken", type="primary")
            if submitted:
                if not cn.strip() or not ce.strip():
                    st.error("Klantnaam én EORI zijn verplicht.")
                else:
                    db.create_customer(cn, ce)
                    st.success(f"Klant '{cn.strip()}' aangemaakt.")
                    st.rerun()

    customers = db.list_customers()
    cmap = {c["name"]: c["id"] for c in customers}

    if not customers:
        st.info("Maak eerst een klant aan voordat je een SOP kunt maken.")
        return

    with st.expander("➕ Nieuwe SOP aanmaken"):
        with st.form("new_sop"):
            cust = st.selectbox("Klant", list(cmap.keys()))
            title = st.text_input("Titel", "SOP Douaneafhandeling")
            lang_label = st.selectbox("Taal van deze SOP", list(LANGS.keys()))
            if st.form_submit_button("Aanmaken", type="primary") and title:
                sid = db.create_sop(cmap[cust], title, LANGS[lang_label], user["login"])
                st.session_state.edit_sop = sid
                st.rerun()

    for s in db.list_sops():
        badge = "🟢 gepubliceerd" if s["status"] == "published" else "🟡 draft"
        cols = st.columns([5, 2, 1, 2])
        cols[0].write(f"**{s['title']}** · {s['customer_name']}")
        cols[1].write(badge)
        cols[2].write(s["lang"].upper())
        if cols[3].button("Bewerken", key=f"edit_{s['id']}"):
            st.session_state.edit_sop = s["id"]; st.rerun()

    if "edit_sop" in st.session_state:
        st.divider()
        edit_sop_view(st.session_state.edit_sop, user)


def edit_sop_view(sop_id, user):
    sop, blocks = db.get_sop(sop_id)
    st.subheader(f"✏️ {sop['title']}  ·  {sop['customer_name']}  ·  {sop['lang'].upper()}")

    # 'Opgemaakt op'-datum (handmatig instelbaar); aanmaakdatum staat los in updated_at.
    from datetime import date as _date
    cur = sop.get("prepared_on")
    if isinstance(cur, str):
        try:
            cur = _date.fromisoformat(cur)
        except ValueError:
            cur = _date.today()
    dc1, dc2 = st.columns([1, 3])
    new_date = dc1.date_input("Opgemaakt op", value=cur or _date.today(),
                              key=f"prep_{sop_id}", format="DD/MM/YYYY")
    if new_date != cur:
        db.set_prepared_on(sop_id, new_date)

    templates = db.list_templates(lang=sop["lang"])
    tmap = {f"[{t['category']}] {t['title']}": t for t in templates}
    c1, c2 = st.columns([4, 1])
    pick = c1.selectbox("Blok toevoegen uit bibliotheek", list(tmap.keys()))
    if c2.button("Toevoegen", type="primary"):
        t = tmap[pick]
        db.add_sop_block(sop_id, t["id"], t["title"], t["content"])
        st.rerun()

    st.markdown("---")
    for i, b in enumerate(blocks):
        with st.container(border=True):
            bc = st.columns([6, 1, 1, 1])
            bc[0].markdown(f"**{b['title']}**")
            if bc[1].button("⬆", key=f"up_{b['id']}", disabled=(i == 0)):
                db.swap_block_order(blocks[i], blocks[i-1]); st.rerun()
            if bc[2].button("⬇", key=f"dn_{b['id']}", disabled=(i == len(blocks)-1)):
                db.swap_block_order(blocks[i], blocks[i+1]); st.rerun()
            if bc[3].button("🗑", key=f"del_{b['id']}"):
                db.delete_sop_block(b["id"]); st.rerun()
            nt = st.text_input("Titel", b["title"], key=f"bt_{b['id']}")
            nc = st.text_area("Tekst", b["content"], key=f"bc_{b['id']}", height=160)
            if st.button("Blok opslaan", key=f"sv_{b['id']}"):
                db.update_sop_block(b["id"], nt, nc)
                st.toast("Blok opgeslagen"); st.rerun()

    st.markdown("---")
    ac = st.columns(3)
    if ac[0].button("✅ Publiceren", type="primary"):
        db.publish_sop(sop_id, user["login"])
        st.success("Gepubliceerd — zichtbaar voor de klant."); st.rerun()
    if ac[1].button("📄 Genereer PDF"):
        sop, blocks = db.get_sop(sop_id)
        st.session_state.pdf = pdf_export.build_sop_pdf(sop, blocks)
    if ac[2].button("Sluiten"):
        st.session_state.pop("edit_sop", None); st.rerun()
    if "pdf" in st.session_state:
        st.download_button("⬇ Download PDF", st.session_state.pdf,
                           file_name=f"SOP_{sop['title']}.pdf", mime="application/pdf")


# ---------- Customer ----------
def customer_page(user):
    st.header("Uw SOP's")
    sops = db.list_sops(customer_id=user["customer_id"], only_published=True)
    if not sops:
        st.info("Er zijn nog geen gepubliceerde SOP's beschikbaar."); return
    titles = {s["title"]: s for s in sops}
    pick = st.selectbox("Selecteer SOP", list(titles.keys()))
    sop, blocks = db.get_sop(titles[pick]["id"])
    pdf = pdf_export.build_sop_pdf(sop, blocks)
    st.download_button("⬇ Download PDF", pdf, file_name=f"SOP_{sop['title']}.pdf",
                       mime="application/pdf", type="primary")
    st.divider()
    st.title(sop["title"])
    st.caption(f"Versie {sop['version']} · {sop['updated_at']}")
    for b in blocks:
        st.subheader(b["title"]); st.markdown(b["content"])


# ---------- Router ----------
def main():
    if "user" not in st.session_state:
        login_view(); return
    user = st.session_state.user
    with st.sidebar:
        st.markdown(f"**{user['login']}** · `{user['role']}`")
        page = (st.radio("Menu", ["SOP's", "Blok-bibliotheek"])
                if user["role"] == "admin" else "SOP's")
        st.button("Uitloggen", on_click=logout)
    if user["role"] == "customer":
        customer_page(user)
    elif page == "Blok-bibliotheek":
        templates_page()
    else:
        builder_page(user)


if __name__ == "__main__":
    main()
