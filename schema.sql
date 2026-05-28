-- ============================================================
-- DKM SOP Builder — Postgres schema (Neon)
-- Plak dit in de Neon SQL Editor (database: sopbuilder)
-- ============================================================

-- Tweetalig: elke tekstkolom heeft _nl en _en.
-- De app toont/exporteert in de gekozen taal van de SOP.

CREATE TABLE IF NOT EXISTS customers (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    id             BIGSERIAL PRIMARY KEY,
    login          TEXT UNIQUE NOT NULL,
    password_hash  TEXT NOT NULL,
    role           TEXT NOT NULL CHECK (role IN ('admin','editor','customer')),
    customer_id    BIGINT REFERENCES customers(id),
    created_at     TIMESTAMPTZ DEFAULT now()
);

-- Herbruikbare blokken (admin beheert). Tweetalig.
CREATE TABLE IF NOT EXISTS block_templates (
    id              BIGSERIAL PRIMARY KEY,
    category        TEXT NOT NULL,
    title_nl        TEXT NOT NULL,
    title_en        TEXT NOT NULL,
    content_nl      TEXT NOT NULL,
    content_en      TEXT NOT NULL,
    sort_order      INTEGER DEFAULT 0,
    active           BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS sops (
    id           BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES customers(id),
    title        TEXT NOT NULL,
    lang         TEXT NOT NULL DEFAULT 'nl' CHECK (lang IN ('nl','en')),
    status       TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
    version      INTEGER DEFAULT 1,
    updated_by   TEXT,
    updated_at   TIMESTAMPTZ DEFAULT now()
);

-- Content GEKOPIEERD uit template bij toevoegen (snapshot in de SOP-taal).
CREATE TABLE IF NOT EXISTS sop_blocks (
    id           BIGSERIAL PRIMARY KEY,
    sop_id       BIGINT NOT NULL REFERENCES sops(id) ON DELETE CASCADE,
    template_id  BIGINT REFERENCES block_templates(id),
    title        TEXT NOT NULL,
    content      TEXT NOT NULL,
    sort_order   INTEGER DEFAULT 0
);

-- ============================================================
-- SEED: blokken-bibliotheek (NL + EN)
-- Gedestilleerd uit de Import4You- en Marken-SOP's.
-- ============================================================

INSERT INTO block_templates (category, title_nl, title_en, content_nl, content_en, sort_order) VALUES

('Algemeen',
 'Doel van dit document', 'Purpose of this document',
 'Deze Standard Operating Procedure (SOP) beschrijft de afspraken, verantwoordelijkheden en werkwijze tussen DKM Customs en [KLANT] met betrekking tot het opmaken en verwerken van douaneaangiften. Doel is een efficiënte, correcte en transparante samenwerking te waarborgen, in overeenstemming met de geldende douane- en fiscale regelgeving.',
 'This Standard Operating Procedure (SOP) describes the arrangements, responsibilities and working method between DKM Customs and [CUSTOMER] regarding the preparation and processing of customs declarations. The aim is to ensure efficient, correct and transparent cooperation, in accordance with the applicable customs and fiscal regulations.',
 1),

('Contact',
 'Operationele contactgegevens', 'Operational contacts',
 E'**DKM Customs**\n- Algemene mailbox: [mailbox]@dkm-customs.com\n- Telefoon: +32 ...\n\n**[KLANT]**\n- Algemene mailbox: \n- Telefoon: ',
 E'**DKM Customs**\n- General mailbox: [mailbox]@dkm-customs.com\n- Phone: +32 ...\n\n**[CUSTOMER]**\n- General mailbox: \n- Phone: ',
 2),

('Contact',
 'Escalatiecontacten', 'Escalation contacts',
 E'Indien operationele issues niet tijdig opgelost raken, kan worden geëscaleerd naar:\n\n**DKM Customs – Escalatie**\n- Luc De Kerf — luc.dekerf@dkm-customs.com — +32 479 11 16 33\n- Bjorn Vanacker — bjorn.vanacker@dkm-customs.com — +32 3 205 60 22\n- Kristof Ghys — kristof.ghys@dkm-customs.com — +32 494 59 75 49\n\n**[KLANT] – Escalatie**\n- Naam / functie: \n- E-mail: \n- Telefoon: ',
 E'If operational issues are not resolved in time, escalation can be made to:\n\n**DKM Customs – Escalation**\n- Luc De Kerf — luc.dekerf@dkm-customs.com — +32 479 11 16 33\n- Bjorn Vanacker — bjorn.vanacker@dkm-customs.com — +32 3 205 60 22\n- Kristof Ghys — kristof.ghys@dkm-customs.com — +32 494 59 75 49\n\n**[CUSTOMER] – Escalation**\n- Name / role: \n- E-mail: \n- Phone: ',
 3),

('Algemeen',
 'Openingsuren', 'Office hours',
 E'DKM Customs is operationeel bereikbaar op:\n- Werkdagen: 08:00 tot 17:30\n- Weekend en feestdagen: enkel op voorafgaande afspraak\n\nBuiten deze uren worden opdrachten verwerkt op de eerstvolgende werkdag.',
 E'DKM Customs is operationally available:\n- Weekdays: 08:00 to 17:30\n- Weekend and public holidays: by prior appointment only\n\nOutside these hours, orders are processed on the next working day.',
 4),

('Documenten',
 'Vereiste documenten voor een invoeraangifte', 'Required documents for an import declaration',
 E'[KLANT] dient tijdig en volledig de volgende documenten en gegevens aan te leveren:\n- Commerciële factuur\n- Paklijst\n- Vervoersdocument (bv. B/L, AWB, CMR)\n- Correcte goederencode (HS/CN/TARIC indien beschikbaar)\n- Netto- en brutogewicht\n- Douanewaarde en valuta\n- Oorsprong van de goederen (met oorsprongsdocumenten indien van toepassing)\n- Lossingslocatie (terminal of magazijn)\n- Referenties (PO, dossiernummer, MRN indien van toepassing)\n- Geldig en correct mandaat\n\nDKM Customs behoudt zich het recht voor bijkomende informatie op te vragen indien vereist door de douanewetgeving.',
 E'[CUSTOMER] must provide the following documents and data timely and completely:\n- Commercial invoice\n- Packing list\n- Transport document (e.g. B/L, AWB, CMR)\n- Correct commodity code (HS/CN/TARIC if available)\n- Net and gross weight\n- Customs value and currency\n- Origin of the goods (with origin documents if applicable)\n- Place of unloading (terminal or warehouse)\n- References (PO, file number, MRN if applicable)\n- Valid and correct mandate\n\nDKM Customs reserves the right to request additional information if required by customs legislation.',
 5),

('Operationeel',
 'Operationele werkwijze – Import Air', 'Operational workflow – Import Air',
 E'Alle aangifte-opdrachten worden verzonden naar [mailbox]@dkm-customs.com en bevatten:\n- Factuur\n- Paklijst\n- MAWB\n- Klantreferentie (HAWB)\n- Locatiecode\n- Goederencode\n- EORI/btw-nummer\n\nDKM maakt de aangiften klaar zodat ze onmiddellijk bij aankomst kunnen worden ingediend. Bij ontbrekende informatie verwittigt DKM de klant zo snel mogelijk om vertraging te vermijden. Na ontvangst van de NOA dient DKM de aangifte in het douane-DMS in. Bij vrijgave mailt het DKM-systeem een kopie van de vrijgave naar de klantmailbox. Bij selectie voor controle onderneemt DKM de nodige actie richting douane en informeert de klant.',
 E'All declaration orders are sent to [mailbox]@dkm-customs.com and include:\n- Invoice\n- Packing list\n- MAWB\n- Customer reference (HAWB)\n- Location code\n- Commodity code\n- EORI/VAT number\n\nDKM prepares the declarations so they can be submitted immediately upon arrival. If information is missing, DKM informs the customer as soon as possible to avoid delays. After receiving the NOA, DKM submits the declaration to the customs DMS. Upon release, the DKM system emails a copy of the release to the customer mailbox. If selected for inspection, DKM performs the necessary action towards customs and informs the customer.',
 6),

('Operationeel',
 'Operationele werkwijze – Export', 'Operational workflow – Export',
 E'Alle aangifte-opdrachten worden verzonden naar [mailbox]@dkm-customs.com. DKM maakt alle documenten klaar zodat ze onmiddellijk bij beschikbaarheid op de goederenlocatie kunnen worden ingediend. Bij ontbrekende informatie verwittigt DKM de klant zo snel mogelijk. Na bericht dat de goederen beschikbaar zijn, dient DKM de aangifte zo snel mogelijk in bij DMS. Bij vrijgave mailt het DKM-systeem een kopie naar de klantmailbox.',
 E'All declaration orders are sent to [mailbox]@dkm-customs.com. DKM prepares all documents so they can be submitted immediately upon availability at the goods location. If information is missing, DKM informs the customer as soon as possible. After notification that the goods are available, DKM submits the declaration to DMS as soon as possible. Upon release, the DKM system emails a copy to the customer mailbox.',
 7),

('Operationeel',
 'Responstijden', 'Response times',
 E'Indicatieve responstijden (het team handelt onmiddellijk indien telefonisch gecontacteerd en nodig):\n\n*Binnen kantooruren*\n- Export (voorbereid): 15–30 min — niet voorbereid: max. 3 werkuren\n- Import (voorbereid): 15–30 min — niet voorbereid: max. 3 werkuren\n\n*Buiten kantooruren*\n- Import ’s avonds: 30–90 min\n- Weekend: 90–180 min (gestuurd door het team i.o.m. de klant)',
 E'Indicative response times (the team acts immediately if called and necessary):\n\n*Within office hours*\n- Export (prepared): 15–30 min — not prepared: max. 3 working hours\n- Import (prepared): 15–30 min — not prepared: max. 3 working hours\n\n*Outside office hours*\n- Import in the evening: 30–90 min\n- Weekend: 90–180 min (steered by the team together with the customer)',
 8),

('Juridisch',
 'Verantwoordelijkheid inzake aangeleverde data', 'Responsibility for supplied data',
 E'- Alle door [KLANT] aangeleverde data, documenten, verklaringen en instructies worden geacht juist, volledig en conform de geldende regelgeving te zijn en vallen uitsluitend onder de verantwoordelijkheid van [KLANT] en/of haar opdrachtgever.\n- DKM Customs verricht geen inhoudelijke, juridische of fiscale verificatie, maar beperkt zich tot een louter marginale controle op basis van de beschikbare documenten.\n- [KLANT] vrijwaart DKM Customs volledig voor alle gevolgen, schade, boetes, naheffingen, interesten en kosten die voortvloeien uit onjuiste, onvolledige of laattijdig aangeleverde gegevens.\n- Deze vrijwaring geldt eveneens bij controles of navorderingen door de douane- of fiscale autoriteiten.',
 E'- All data, documents, declarations and instructions supplied by [CUSTOMER] are deemed correct, complete and compliant with the applicable regulations and fall solely under the responsibility of [CUSTOMER] and/or its principal.\n- DKM Customs performs no substantive, legal or fiscal verification, but limits itself to a purely marginal check based on the available documents.\n- [CUSTOMER] fully indemnifies DKM Customs against all consequences, damages, fines, additional assessments, interest and costs arising from incorrect, incomplete or late data.\n- This indemnification also applies in the event of checks or recovery actions by the customs or fiscal authorities.',
 9),

('Juridisch',
 'Inspanningsverbintenis', 'Best-efforts obligation',
 E'- DKM Customs verbindt zich ertoe de opdrachten met de nodige zorg en binnen een redelijke termijn te verwerken, op voorwaarde dat het dossier volledig en correct werd aangeleverd.\n- De verbintenis betreft een middelen- en inspanningsverbintenis, geen resultaatsverbintenis.\n- Indien gegevens ontbreken of onjuist blijken, wordt [KLANT] zo spoedig mogelijk verwittigd.\n- Zolang het dossier niet volledig is, wordt de verwerkingstermijn opgeschort zonder aansprakelijkheid voor DKM Customs.',
 E'- DKM Customs undertakes to process orders with due care and within a reasonable time, provided the file was supplied completely and correctly.\n- The obligation is one of means and best efforts, not of result.\n- If data is missing or proves incorrect, [CUSTOMER] is notified as soon as possible.\n- As long as the file is incomplete, the processing period is suspended without liability for DKM Customs.',
 10),

('Juridisch',
 'Mandaatvereiste en vertegenwoordiging', 'Mandate requirement and representation',
 E'- DKM Customs zal onder geen beding een aangifte indienen zonder een geldig, correct en rechtsgeldig ondertekend mandaat.\n- Het mandaat moet ondubbelzinnig de aard van de vertegenwoordiging vermelden (directe of indirecte) en conform zijn met de bepalingen van het Douanewetboek van de Unie (DWU).',
 E'- DKM Customs will under no circumstances submit a declaration without a valid, correct and legally signed mandate.\n- The mandate must unambiguously state the nature of the representation (direct or indirect) and comply with the provisions of the Union Customs Code (UCC).',
 11),

('Juridisch',
 'Douanecontrole en taakverdeling', 'Customs inspection and task allocation',
 E'- Selecteert de douane een aangifte voor controle, dan stelt DKM Customs [KLANT] hiervan onverwijld in kennis.\n- DKM contacteert in eerste instantie de douane om het platonummer te bekomen en bezorgt dit aan [KLANT].\n- [KLANT] staat vervolgens zelf in voor alle verdere contacten met de douane en de praktische afspraken (tijdstip, locatie, aanwezigheid).\n- Alle kosten, vertragingen en gevolgen van de controle zijn ten laste van [KLANT] en/of haar opdrachtgever, tenzij schriftelijk anders overeengekomen.\n- Vereist de douane bijkomende technische of inhoudelijke toelichting, dan staat DKM Customs in voor die communicatie m.b.t. de aangifte.',
 E'- If customs selects a declaration for inspection, DKM Customs notifies [CUSTOMER] without delay.\n- DKM first contacts customs to obtain the platform number and forwards it to [CUSTOMER].\n- [CUSTOMER] is then responsible for all further contact with customs and the practical arrangements (timing, location, attendance).\n- All costs, delays and consequences of the inspection are borne by [CUSTOMER] and/or its principal, unless agreed otherwise in writing.\n- If customs requires additional technical or substantive clarification, DKM Customs handles that communication regarding the declaration.',
 12),

('Juridisch',
 'Slot- en juridische bepalingen', 'Final and legal provisions',
 E'- Deze SOP vormt een integraal onderdeel van de samenwerking tussen DKM Customs en [KLANT] en kan als bijlage bij de SLA worden gehecht.\n- Afwijkingen zijn slechts geldig indien uitdrukkelijk en schriftelijk door beide partijen overeengekomen.\n- Indien één of meerdere bepalingen nietig blijken, blijft de geldigheid van de overige bepalingen behouden.\n- Op deze SOP is uitsluitend het [recht] van toepassing; geschillen behoren tot de exclusieve bevoegdheid van de bevoegde rechtbanken.\n\nVoor akkoord,\nDKM Customs                         [KLANT]',
 E'- This SOP forms an integral part of the cooperation between DKM Customs and [CUSTOMER] and may be attached as an annex to the SLA.\n- Deviations are only valid if expressly agreed in writing by both parties.\n- If one or more provisions prove void, the validity of the remaining provisions is maintained.\n- This SOP is governed solely by [law]; disputes fall under the exclusive jurisdiction of the competent courts.\n\nAgreed,\nDKM Customs                         [CUSTOMER]',
 13);
