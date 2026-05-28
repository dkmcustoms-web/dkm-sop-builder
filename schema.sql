-- ============================================================
-- DKM SOP Builder — Postgres schema (Neon)
-- Plak dit in de Neon SQL Editor (database: sopbuilder)
-- ============================================================

-- Tweetalig: elke tekstkolom heeft _nl en _en.
-- De app toont/exporteert in de gekozen taal van de SOP.

CREATE TABLE IF NOT EXISTS customers (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    eori        TEXT NOT NULL,
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
    prepared_on  DATE DEFAULT CURRENT_DATE,
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
-- SEED: blokken-bibliotheek (NL + EN), dollar-quoted (escape-vrij)
-- ============================================================

INSERT INTO block_templates
  (category, title_nl, title_en, content_nl, content_en, sort_order)
VALUES
($blk$Algemeen$blk$, $blk$Doel van dit document$blk$, $blk$Purpose of this document$blk$,
 $blk$Deze Standard Operating Procedure (SOP) beschrijft de afspraken, verantwoordelijkheden en werkwijze tussen DKM Customs en [KLANT] met betrekking tot het opmaken en verwerken van douaneaangiften. Doel is een efficiënte, correcte en transparante samenwerking te waarborgen, in overeenstemming met de geldende douane- en fiscale regelgeving.$blk$,
 $blk$This Standard Operating Procedure (SOP) describes the arrangements, responsibilities and working method between DKM Customs and [CUSTOMER] regarding the preparation and processing of customs declarations. The aim is to ensure efficient, correct and transparent cooperation, in accordance with the applicable customs and fiscal regulations.$blk$, 1),

($blk$Contact$blk$, $blk$Operationele contactgegevens$blk$, $blk$Operational contacts$blk$,
 $blk$**DKM Customs**
- Algemene mailbox: [mailbox]@dkm-customs.com
- Telefoon: +32 ...

**[KLANT]**
- Algemene mailbox: 
- Telefoon: $blk$,
 $blk$**DKM Customs**
- General mailbox: [mailbox]@dkm-customs.com
- Phone: +32 ...

**[CUSTOMER]**
- General mailbox: 
- Phone: $blk$, 2),

($blk$Contact$blk$, $blk$Escalatiecontacten$blk$, $blk$Escalation contacts$blk$,
 $blk$Indien operationele issues niet tijdig opgelost raken, kan worden geëscaleerd naar:

**DKM Customs – Escalatie**
- Luc De Kerf — luc.dekerf@dkm-customs.com — +32 479 11 16 33
- Bjorn Vanacker — bjorn.vanacker@dkm-customs.com — +32 3 205 60 22
- Kristof Ghys — kristof.ghys@dkm-customs.com — +32 494 59 75 49

**[KLANT] – Escalatie**
- Naam / functie: 
- E-mail: 
- Telefoon: $blk$,
 $blk$If operational issues are not resolved in time, escalation can be made to:

**DKM Customs – Escalation**
- Luc De Kerf — luc.dekerf@dkm-customs.com — +32 479 11 16 33
- Bjorn Vanacker — bjorn.vanacker@dkm-customs.com — +32 3 205 60 22
- Kristof Ghys — kristof.ghys@dkm-customs.com — +32 494 59 75 49

**[CUSTOMER] – Escalation**
- Name / role: 
- E-mail: 
- Phone: $blk$, 3),

($blk$Algemeen$blk$, $blk$Openingsuren$blk$, $blk$Office hours$blk$,
 $blk$DKM Customs is operationeel bereikbaar op:
- Werkdagen: 08:00 tot 17:30
- Weekend en feestdagen: enkel op voorafgaande afspraak

Buiten deze uren worden opdrachten verwerkt op de eerstvolgende werkdag.$blk$,
 $blk$DKM Customs is operationally available:
- Weekdays: 08:00 to 17:30
- Weekend and public holidays: by prior appointment only

Outside these hours, orders are processed on the next working day.$blk$, 4),

($blk$Documenten$blk$, $blk$Vereiste documenten voor een invoeraangifte$blk$, $blk$Required documents for an import declaration$blk$,
 $blk$[KLANT] dient tijdig en volledig de volgende documenten en gegevens aan te leveren:
- Commerciële factuur
- Paklijst
- Vervoersdocument (bv. B/L, AWB, CMR)
- Correcte goederencode (HS/CN/TARIC indien beschikbaar)
- Netto- en brutogewicht
- Douanewaarde en valuta
- Oorsprong van de goederen (met oorsprongsdocumenten indien van toepassing)
- Lossingslocatie (terminal of magazijn)
- Referenties (PO, dossiernummer, MRN indien van toepassing)
- Geldig en correct mandaat
- EORI-nummer importeur: [EORI]

DKM Customs behoudt zich het recht voor bijkomende informatie op te vragen indien vereist door de douanewetgeving.$blk$,
 $blk$[CUSTOMER] must provide the following documents and data timely and completely:
- Commercial invoice
- Packing list
- Transport document (e.g. B/L, AWB, CMR)
- Correct commodity code (HS/CN/TARIC if available)
- Net and gross weight
- Customs value and currency
- Origin of the goods (with origin documents if applicable)
- Place of unloading (terminal or warehouse)
- References (PO, file number, MRN if applicable)
- Valid and correct mandate
- Importer EORI number: [EORI]

DKM Customs reserves the right to request additional information if required by customs legislation.$blk$, 5),

($blk$Operationeel$blk$, $blk$Operationele werkwijze – Import Air$blk$, $blk$Operational workflow – Import Air$blk$,
 $blk$Alle aangifte-opdrachten worden verzonden naar [mailbox]@dkm-customs.com en bevatten:
- Factuur
- Paklijst
- MAWB
- Klantreferentie (HAWB)
- Locatiecode
- Goederencode
- EORI/btw-nummer

DKM maakt de aangiften klaar zodat ze onmiddellijk bij aankomst kunnen worden ingediend. Bij ontbrekende informatie verwittigt DKM de klant zo snel mogelijk om vertraging te vermijden. Na ontvangst van de NOA dient DKM de aangifte in het douane-DMS in. Bij vrijgave mailt het DKM-systeem een kopie van de vrijgave naar de klantmailbox. Bij selectie voor controle onderneemt DKM de nodige actie richting douane en informeert de klant.$blk$,
 $blk$All declaration orders are sent to [mailbox]@dkm-customs.com and include:
- Invoice
- Packing list
- MAWB
- Customer reference (HAWB)
- Location code
- Commodity code
- EORI/VAT number

DKM prepares the declarations so they can be submitted immediately upon arrival. If information is missing, DKM informs the customer as soon as possible to avoid delays. After receiving the NOA, DKM submits the declaration to the customs DMS. Upon release, the DKM system emails a copy of the release to the customer mailbox. If selected for inspection, DKM performs the necessary action towards customs and informs the customer.$blk$, 6),

($blk$Operationeel$blk$, $blk$Operationele werkwijze – Export$blk$, $blk$Operational workflow – Export$blk$,
 $blk$Alle aangifte-opdrachten worden verzonden naar [mailbox]@dkm-customs.com. DKM maakt alle documenten klaar zodat ze onmiddellijk bij beschikbaarheid op de goederenlocatie kunnen worden ingediend. Bij ontbrekende informatie verwittigt DKM de klant zo snel mogelijk. Na bericht dat de goederen beschikbaar zijn, dient DKM de aangifte zo snel mogelijk in bij DMS. Bij vrijgave mailt het DKM-systeem een kopie naar de klantmailbox.$blk$,
 $blk$All declaration orders are sent to [mailbox]@dkm-customs.com. DKM prepares all documents so they can be submitted immediately upon availability at the goods location. If information is missing, DKM informs the customer as soon as possible. After notification that the goods are available, DKM submits the declaration to DMS as soon as possible. Upon release, the DKM system emails a copy to the customer mailbox.$blk$, 7),

($blk$Operationeel$blk$, $blk$Responstijden$blk$, $blk$Response times$blk$,
 $blk$Indicatieve responstijden (het team handelt onmiddellijk indien telefonisch gecontacteerd en nodig):

*Binnen kantooruren*
- Export (voorbereid): 15–30 min — niet voorbereid: max. 3 werkuren
- Import (voorbereid): 15–30 min — niet voorbereid: max. 3 werkuren

*Buiten kantooruren*
- Import 's avonds: 30–90 min
- Weekend: 90–180 min (gestuurd door het team i.o.m. de klant)$blk$,
 $blk$Indicative response times (the team acts immediately if called and necessary):

*Within office hours*
- Export (prepared): 15–30 min — not prepared: max. 3 working hours
- Import (prepared): 15–30 min — not prepared: max. 3 working hours

*Outside office hours*
- Import in the evening: 30–90 min
- Weekend: 90–180 min (steered by the team together with the customer)$blk$, 8),

($blk$Juridisch$blk$, $blk$Verantwoordelijkheid inzake aangeleverde data$blk$, $blk$Responsibility for supplied data$blk$,
 $blk$- Alle door [KLANT] aangeleverde data, documenten, verklaringen en instructies worden geacht juist, volledig en conform de geldende regelgeving te zijn en vallen uitsluitend onder de verantwoordelijkheid van [KLANT] en/of haar opdrachtgever.
- DKM Customs verricht geen inhoudelijke, juridische of fiscale verificatie, maar beperkt zich tot een louter marginale controle op basis van de beschikbare documenten.
- [KLANT] vrijwaart DKM Customs volledig voor alle gevolgen, schade, boetes, naheffingen, interesten en kosten die voortvloeien uit onjuiste, onvolledige of laattijdig aangeleverde gegevens.
- Deze vrijwaring geldt eveneens bij controles of navorderingen door de douane- of fiscale autoriteiten.$blk$,
 $blk$- All data, documents, declarations and instructions supplied by [CUSTOMER] are deemed correct, complete and compliant with the applicable regulations and fall solely under the responsibility of [CUSTOMER] and/or its principal.
- DKM Customs performs no substantive, legal or fiscal verification, but limits itself to a purely marginal check based on the available documents.
- [CUSTOMER] fully indemnifies DKM Customs against all consequences, damages, fines, additional assessments, interest and costs arising from incorrect, incomplete or late data.
- This indemnification also applies in the event of checks or recovery actions by the customs or fiscal authorities.$blk$, 9),

($blk$Juridisch$blk$, $blk$Inspanningsverbintenis$blk$, $blk$Best-efforts obligation$blk$,
 $blk$- DKM Customs verbindt zich ertoe de opdrachten met de nodige zorg en binnen een redelijke termijn te verwerken, op voorwaarde dat het dossier volledig en correct werd aangeleverd.
- De verbintenis betreft een middelen- en inspanningsverbintenis, geen resultaatsverbintenis.
- Indien gegevens ontbreken of onjuist blijken, wordt [KLANT] zo spoedig mogelijk verwittigd.
- Zolang het dossier niet volledig is, wordt de verwerkingstermijn opgeschort zonder aansprakelijkheid voor DKM Customs.$blk$,
 $blk$- DKM Customs undertakes to process orders with due care and within a reasonable time, provided the file was supplied completely and correctly.
- The obligation is one of means and best efforts, not of result.
- If data is missing or proves incorrect, [CUSTOMER] is notified as soon as possible.
- As long as the file is incomplete, the processing period is suspended without liability for DKM Customs.$blk$, 10),

($blk$Juridisch$blk$, $blk$Mandaatvereiste en vertegenwoordiging$blk$, $blk$Mandate requirement and representation$blk$,
 $blk$- DKM Customs zal onder geen beding een aangifte indienen zonder een geldig, correct en rechtsgeldig ondertekend mandaat.
- Het mandaat moet ondubbelzinnig de aard van de vertegenwoordiging vermelden (directe of indirecte) en conform zijn met de bepalingen van het Douanewetboek van de Unie (DWU).$blk$,
 $blk$- DKM Customs will under no circumstances submit a declaration without a valid, correct and legally signed mandate.
- The mandate must unambiguously state the nature of the representation (direct or indirect) and comply with the provisions of the Union Customs Code (UCC).$blk$, 11),

($blk$Juridisch$blk$, $blk$Douanecontrole en taakverdeling$blk$, $blk$Customs inspection and task allocation$blk$,
 $blk$- Selecteert de douane een aangifte voor controle, dan stelt DKM Customs [KLANT] hiervan onverwijld in kennis.
- DKM contacteert in eerste instantie de douane om het platonummer te bekomen en bezorgt dit aan [KLANT].
- [KLANT] staat vervolgens zelf in voor alle verdere contacten met de douane en de praktische afspraken (tijdstip, locatie, aanwezigheid).
- Alle kosten, vertragingen en gevolgen van de controle zijn ten laste van [KLANT] en/of haar opdrachtgever, tenzij schriftelijk anders overeengekomen.
- Vereist de douane bijkomende technische of inhoudelijke toelichting, dan staat DKM Customs in voor die communicatie m.b.t. de aangifte.$blk$,
 $blk$- If customs selects a declaration for inspection, DKM Customs notifies [CUSTOMER] without delay.
- DKM first contacts customs to obtain the platform number and forwards it to [CUSTOMER].
- [CUSTOMER] is then responsible for all further contact with customs and the practical arrangements (timing, location, attendance).
- All costs, delays and consequences of the inspection are borne by [CUSTOMER] and/or its principal, unless agreed otherwise in writing.
- If customs requires additional technical or substantive clarification, DKM Customs handles that communication regarding the declaration.$blk$, 12),

($blk$Juridisch$blk$, $blk$Slot- en juridische bepalingen$blk$, $blk$Final and legal provisions$blk$,
 $blk$- Deze SOP vormt een integraal onderdeel van de samenwerking tussen DKM Customs en [KLANT] en kan als bijlage bij de SLA worden gehecht.
- Afwijkingen zijn slechts geldig indien uitdrukkelijk en schriftelijk door beide partijen overeengekomen.
- Indien één of meerdere bepalingen nietig blijken, blijft de geldigheid van de overige bepalingen behouden.
- Op deze SOP is uitsluitend het [recht] van toepassing; geschillen behoren tot de exclusieve bevoegdheid van de bevoegde rechtbanken.

Voor akkoord,
DKM Customs                         [KLANT]$blk$,
 $blk$- This SOP forms an integral part of the cooperation between DKM Customs and [CUSTOMER] and may be attached as an annex to the SLA.
- Deviations are only valid if expressly agreed in writing by both parties.
- If one or more provisions prove void, the validity of the remaining provisions is maintained.
- This SOP is governed solely by [law]; disputes fall under the exclusive jurisdiction of the competent courts.

Agreed,
DKM Customs                         [CUSTOMER]$blk$, 13);
