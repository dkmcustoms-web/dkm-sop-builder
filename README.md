# DKM SOP Builder

Streamlit-app om SOP's op te bouwen uit herbruikbare, **tweetalige (NL/EN)** blokken,
op te slaan in Neon (Postgres), en read-only ter beschikking te stellen aan klanten
met PDF-download in DKM-huisstijl.

## Neon opzetten (je hebt al een account)

1. **Console -> New Project.** Naam bv. `dkm-sop-builder`. Regio: kies een EU-regio
   (bv. `eu-central-1` / Frankfurt) - dichtbij en AVG-vriendelijk.
2. **Database aanmaken.** Neon maakt standaard `neondb` aan. Maak desgewenst een nette
   database `sopbuilder` (Branches -> je branch -> Databases -> New Database), of gebruik
   `neondb`. Een database voor deze app volstaat; hou ze los van je andere apps.
3. **Schema laden.** Open **SQL Editor**, plak de volledige inhoud van `schema.sql`
   en voer uit. Dit maakt alle tabellen en vult de tweetalige blokken-bibliotheek
   (gedestilleerd uit de Import4You- en Marken-SOP's).
4. **Connection string ophalen.** Klik **Connect** op het dashboard, kies branch +
   database + rol. Kopieer de string (vorm:
   `postgresql://user:pass@ep-xxx.eu-central-1.aws.neon.tech/sopbuilder?sslmode=require`).
5. **Lokaal draaien:**
   ```bash
   pip install -r requirements.txt
   export DATABASE_URL="postgresql://...?sslmode=require"
   streamlit run app.py
   ```

> De app draait `schema.sql` zelf ook automatisch bij eerste start als de tabellen nog
> niet bestaan (`init_schema`), dus stap 3 is optioneel - handig is het wel om de
> bibliotheek meteen te zien in de Neon-editor.

## Demo-logins (seed)
| Login      | Wachtwoord | Rol      |
|------------|-----------|----------|
| admin      | admin123  | beheert blok-bibliotheek (NL+EN) + SOP's |
| editor     | editor123 | maakt/vult SOP's, geen templatebeheer |
| import4you | klant123  | klant (read-only eigen gepubliceerde SOP's + PDF) |

> Wijzig deze wachtwoorden voor productie.

## Concept
- **block_templates** = bibliotheek van standaardblokken, elk met titel + tekst in
  **NL en EN**. Admin beheert.
- Bij aanmaken van een SOP kies je de **taal**; blokken worden in die taal getoond.
- Bij toevoegen wordt de tekst **gekopieerd** naar `sop_blocks` (snapshot). Latere
  wijziging van een template raakt bestaande SOP's dus niet.
- Editor kiest blokken, past tekst per blok aan, herschikt, publiceert.
- Klant logt in met eigen wachtwoord -> ziet enkel eigen **gepubliceerde** SOP's,
  online lezen + PDF-download. Kan niets wijzigen.

## Blokken in de bibliotheek (uit je echte SOP's)
Algemeen: Doel, Openingsuren. Contact: Operationele contacten, Escalatiecontacten.
Documenten: Vereiste documenten. Operationeel: Import Air, Export, Responstijden.
Juridisch: Verantwoordelijkheid data, Inspanningsverbintenis, Mandaatvereiste,
Douanecontrole, Slot- en juridische bepalingen.

Plaatshouders zoals `[KLANT]` / `[CUSTOMER]`, `[mailbox]`, `[recht]` pas je per SOP aan.

## Security (Neon)
- `sslmode=require` staat in de connection string (verplicht bij Neon).
- Wachtwoorden met **bcrypt**, nooit plaintext.
- `DATABASE_URL` als **env-var** (Azure App Service / Streamlit secrets), niet in code.
- Gebruik een **aparte read/write rol** i.p.v. de owner-rol; IP allow-list waar mogelijk.
- Volgende stap voor klant-facing productie: sessie-token met expiry i.p.v. enkel
  `st.session_state`.

## Bestanden
- `app.py` - Streamlit UI + routing per rol, taalkeuze, tweetalig templatebeheer
- `db.py` - psycopg/Postgres-laag, bcrypt-helpers, schema-bootstrap, queries
- `schema.sql` - tabellen + tweetalige seed-bibliotheek (plak in Neon SQL Editor)
- `pdf_export.py` - PDF met DKM-branding (#3cceff / #f35e40) + Unicode-font (DejaVu)
- `fonts/` - DejaVuSans (Unicode); zonder deze valt PDF terug op Helvetica
- `.env.example` - sjabloon voor DATABASE_URL
