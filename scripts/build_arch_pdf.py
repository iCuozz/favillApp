#!/usr/bin/env python3
"""Genera docs/architecture.pdf: legenda + diagramma + spiegazioni."""
import os
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image, PageBreak, Table, TableStyle,
    NextPageTemplate, PageTemplate, Frame,
)
from reportlab.lib.enums import TA_LEFT

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIAGRAM = os.path.join(REPO, "docs", "architecture.png")
OUT = os.path.join(REPO, "docs", "architecture.pdf")

styles = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=styles["Heading1"], fontSize=20, leading=24,
                    textColor=colors.HexColor("#E65100"), spaceAfter=8)
H2 = ParagraphStyle("H2", parent=styles["Heading2"], fontSize=14, leading=18,
                    textColor=colors.HexColor("#1B5E20"), spaceBefore=10, spaceAfter=4)
H3 = ParagraphStyle("H3", parent=styles["Heading3"], fontSize=12, leading=15,
                    textColor=colors.HexColor("#0D47A1"), spaceBefore=6, spaceAfter=2)
P  = ParagraphStyle("P",  parent=styles["BodyText"], fontSize=10, leading=14,
                    alignment=TA_LEFT, spaceAfter=4)
SMALL = ParagraphStyle("S", parent=P, fontSize=9, leading=12, textColor=colors.grey)

# Page templates: portrait per testo, landscape per il diagramma
A4_W, A4_H = A4
def _portrait_frame(): return Frame(18*mm, 18*mm, A4_W-36*mm, A4_H-36*mm, id="p")
def _landscape_frame():
    w, h = landscape(A4)
    return Frame(15*mm, 15*mm, w-30*mm, h-30*mm, id="l")

doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=18*mm, rightMargin=18*mm,
                        topMargin=18*mm, bottomMargin=18*mm, title="FavillApp · Architettura")
doc.addPageTemplates([
    PageTemplate(id="portrait",  frames=[_portrait_frame()],  pagesize=A4),
    PageTemplate(id="landscape", frames=[_landscape_frame()], pagesize=landscape(A4)),
])

story = []

# =============== PAGINA 1: COPERTINA + TL;DR ===============
story.append(Paragraph("FavillApp · Architettura", H1))
story.append(Paragraph(
    "Progetto Flutter (Android) per fumetti episodici. Tutti gli asset (testi, immagini, "
    "branch narrativi) sono <b>pre-generati</b> e committati nel repo: l'app funziona "
    "completamente <b>offline</b> per la lettura. Il backend serverless serve solo per le "
    "feature opzionali AI e per il loop \u201cchiedi a Favilla reale\u201d.", P))

story.append(Paragraph("TL;DR sui due servizi cloud", H2))
tldr = [
    ["Servizio", "A che serve", "Cosa NON fa"],
    [Paragraph("<b>Cloudflare Worker</b><br/>(<font color='#555'>worker/</font>)", P),
     Paragraph("Proxy HTTP verso Google Gemini. <b>Nasconde la API key</b> "
               "(secret Wrangler, mai nell'APK), applica <b>rate-limit</b> e validazione "
               "header (KV <font face='Courier'>AI_KV</font>), persiste le domande "
               "\u201ca Favilla reale\u201d (D1 <font face='Courier'>favilla-questions</font>), "
               "genera le immagini dei pannelli a runtime tramite Workers AI (SDXL Lightning), "
               "e invia le push via FCM dalla UI <font face='Courier'>/admin</font>.", P),
     Paragraph("Non serve gli asset del fumetto (sono nell'APK). "
               "Non sostituisce gli script offline in <font face='Courier'>scripts/</font>.", P)],
    [Paragraph("<b>Firebase</b>", P),
     Paragraph("<b>Solo Cloud Messaging (FCM)</b>: notifica push al device quando "
               "Andrea risponde da <font face='Courier'>/admin</font> e l'app è chiusa. "
               "Il token FCM viene registrato dal device verso il Worker; il Worker firma "
               "l'invio con <font face='Courier'>FCM_SERVICE_ACCOUNT_JSON</font>.", P),
     Paragraph("Niente Firestore, niente Auth, niente Analytics, niente Crashlytics. "
               "Senza FCM l'app funziona lo stesso: l'inbox si sincronizza alla riapertura.", P)],
]
t = Table(tldr, colWidths=[28*mm, 75*mm, 65*mm])
t.setStyle(TableStyle([
    ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#FFE0B2")),
    ("TEXTCOLOR",  (0,0), (-1,0), colors.HexColor("#7A2E00")),
    ("FONTNAME",   (0,0), (-1,0), "Helvetica-Bold"),
    ("BACKGROUND", (0,1), (0,-1), colors.HexColor("#FFF3E0")),
    ("VALIGN",     (0,0), (-1,-1), "TOP"),
    ("GRID",       (0,0), (-1,-1), 0.4, colors.HexColor("#BBBBBB")),
    ("LEFTPADDING",(0,0), (-1,-1), 6), ("RIGHTPADDING",(0,0),(-1,-1),6),
    ("TOPPADDING", (0,0), (-1,-1), 5), ("BOTTOMPADDING",(0,0),(-1,-1),5),
]))
story.append(t)

story.append(Paragraph("Legenda colori del diagramma", H2))
legend = [
    ["", "Blocco", "Cosa contiene"],
    ["", Paragraph("<b>App Flutter (Android)</b>", P),
         Paragraph("<font face='Courier'>lib/</font>: pages, widgets, models, services. "
                   "Gira sul telefono, legge gli asset bundled.", P)],
    ["", Paragraph("<b>Assets bundled</b>", P),
         Paragraph("<font face='Courier'>assets/</font>: indici episodi, JSON pannelli, WebP. "
                   "Tutto è dentro l'APK \u2192 lettura offline.", P)],
    ["", Paragraph("<b>Scripts offline</b>", P),
         Paragraph("<font face='Courier'>scripts/</font>: tooling Node che dalla dev box "
                   "trasforma <font face='Courier'>STORYBOARD.md</font> + character sheet "
                   "in immagini WebP da committare.", P)],
    ["", Paragraph("<b>Cloudflare Worker</b>", P),
         Paragraph("Backend serverless edge (Hono). Routes <font face='Courier'>/v1/*</font> "
                   "per l'app, <font face='Courier'>/admin</font> per Andrea. "
                   "Storage: KV (rate limit) + D1 (domande).", P)],
    ["", Paragraph("<b>Servizi esterni</b>", P),
         Paragraph("Google Gemini API, Firebase Cloud Messaging, e Andrea (admin umano).", P)],
]
swatches = [
    None,
    ("#FFE0B2", "#E65100"),
    ("#BBDEFB", "#0D47A1"),
    ("#E1BEE7", "#4A148C"),
    ("#C8E6C9", "#1B5E20"),
    ("#FFF59D", "#827717"),
]
ttable = Table(legend, colWidths=[10*mm, 45*mm, 113*mm])
tstyle = [
    ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#EEEEEE")),
    ("FONTNAME",   (0,0), (-1,0), "Helvetica-Bold"),
    ("VALIGN",     (0,0), (-1,-1), "MIDDLE"),
    ("GRID",       (0,0), (-1,-1), 0.3, colors.HexColor("#BBBBBB")),
    ("LEFTPADDING",(0,0), (-1,-1), 5), ("RIGHTPADDING",(0,0),(-1,-1),5),
    ("TOPPADDING", (0,0), (-1,-1), 4), ("BOTTOMPADDING",(0,0),(-1,-1),4),
]
for i, sw in enumerate(swatches):
    if sw is None: continue
    fill, border = sw
    tstyle += [
        ("BACKGROUND", (0,i), (0,i), colors.HexColor(fill)),
        ("BOX",        (0,i), (0,i), 1.2, colors.HexColor(border)),
    ]
ttable.setStyle(TableStyle(tstyle))
story.append(ttable)

story.append(Spacer(1, 4*mm))
story.append(Paragraph(
    "<b>Note sulle frecce</b>: continue \u2192 chiamate / dipendenze attive in produzione; "
    "tratteggiate \u2192 percorsi opzionali (es. <font face='Courier'>generate.mjs</font> "
    "verso Gemini API, oggi disabilitato perché senza billing).", SMALL))

# =============== PAGINA 2: DIAGRAMMA (landscape, fit-to-page) ===============
story.append(NextPageTemplate("landscape"))
story.append(PageBreak())
story.append(Paragraph("Diagramma dell'architettura", H1))

# Calcola dimensioni immagine per riempire la pagina landscape
from reportlab.lib.utils import ImageReader
ir = ImageReader(DIAGRAM)
iw, ih = ir.getSize()
w_page, h_page = landscape(A4)
max_w = w_page - 30*mm
max_h = h_page - 35*mm  # spazio per il titolo
ratio = min(max_w/iw, max_h/ih)
story.append(Image(DIAGRAM, width=iw*ratio, height=ih*ratio))

# =============== PAGINA 3: FLUSSI ===============
story.append(NextPageTemplate("portrait"))
story.append(PageBreak())
story.append(Paragraph("Flussi tipici, passo per passo", H1))

story.append(Paragraph("1) Lettura di un episodio (offline, niente cloud)", H2))
story.append(Paragraph(
    "L'utente apre <i>Episodes List</i> \u2192 <font face='Courier'>comic_loader</font> "
    "legge <font face='Courier'>assets/data/comic_index.json</font> (sezione "
    "<font face='Courier'>episodes</font>; gli ID in <font face='Courier'>_drafts</font>, "
    "come <b>missione_5</b> oggi, vengono ignorati). Per l'episodio scelto carica "
    "<font face='Courier'>assets/data/episodes/&lt;id&gt;.json</font> (panel + branch + "
    "characters per pannello) e mostra le WebP da "
    "<font face='Courier'>assets/episodes/&lt;id&gt;/</font>. Il TTS on-device "
    "(<font face='Courier'>services/tts/*</font>) legge a voce alta. "
    "<b>Nessuna chiamata di rete.</b>", P))

story.append(Paragraph("2) \u201cChiedi a Favilla\u201d (chat AI \u2192 Worker \u2192 Gemini)", H2))
story.append(Paragraph(
    "L'utente scrive in <font face='Courier'>pages/ai/*</font>. "
    "<font face='Courier'>services/ai/*</font> chiama "
    "<font face='Courier'>POST /v1/chat</font> sul Worker con header "
    "<font face='Courier'>X-App-Version</font> + <font face='Courier'>X-Client-Id</font>. "
    "Il Worker valida (guard.ts), incrementa il contatore in KV "
    "<font face='Courier'>AI_KV</font> (rate-limit), costruisce il prompt con il blocco "
    "personaggi (<font face='Courier'>lib/characters.ts</font>) e chiama Google Gemini "
    "usando il secret <font face='Courier'>GEMINI_API_KEY</font>. "
    "La risposta torna all'app. La key non lascia mai il Worker.", P))

story.append(Paragraph("3) \u201cChiedi a Favilla reale\u201d (loop umano con push)", H2))
story.append(Paragraph(
    "L'utente invia una domanda \u201cumana\u201d \u2192 "
    "<font face='Courier'>POST /v1/ask-real</font> \u2192 il Worker la persiste in D1 "
    "(<font face='Courier'>favilla-questions</font>). Andrea apre la UI "
    "<font face='Courier'>/admin</font>, scrive la risposta. Il Worker la salva, e usa "
    "<font face='Courier'>FCM_SERVICE_ACCOUNT_JSON</font> per inviare una push via "
    "Firebase Messaging al token registrato dal device "
    "(<font face='Courier'>services/push_service.dart</font>). All'apertura della notifica "
    "(o al riapri-app) <font face='Courier'>inbox_service</font> fa polling di "
    "<font face='Courier'>/v1/inbox/*</font> e scarica la risposta. "
    "Senza FCM funziona lo stesso, ma niente notifica live.", P))

story.append(Paragraph("4) Generazione immagini di un nuovo episodio (offline tooling)", H2))
story.append(Paragraph(
    "Si scrive <font face='Courier'>assets/episodes/&lt;id&gt;/STORYBOARD.md</font> + "
    "<font face='Courier'>assets/data/episodes/&lt;id&gt;.json</font>. Da "
    "<font face='Courier'>scripts/</font> si lancia "
    "<font face='Courier'>node generate.mjs episode &lt;id&gt;</font>: lo script allega le "
    "<i>character sheet</i> da <font face='Courier'>scripts/_refs/</font> e tutte le immagini "
    "dell'episodio precedente come <i>coherence reference</i>, e chiama Gemini Image. "
    "Salva le WebP in <font face='Courier'>assets/episodes/&lt;id&gt;/</font>, che si "
    "committano. <b>Stato attuale</b>: l'API Gemini Image richiede billing; per ora si usa "
    "<font face='Courier'>node generate.mjs prompts &lt;id&gt;</font> per esportare i "
    "prompt pronti da incollare a mano in Google AI Studio (free tier web).", P))

story.append(Paragraph("Convenzioni utili", H2))
story.append(Paragraph(
    "\u2022 <b>Disattivare un episodio</b>: spostarne l'oggetto da "
    "<font face='Courier'>episodes</font> a <font face='Courier'>_drafts</font> in "
    "<font face='Courier'>comic_index.json</font> e <font face='Courier'>comic_index.en.json</font>. "
    "L'app salta automaticamente i drafts.", P))
story.append(Paragraph(
    "\u2022 <b>Internazionalizzazione</b>: ogni asset di testo ha la coppia "
    "<font face='Courier'>foo.json</font> + <font face='Courier'>foo.en.json</font>. Le "
    "immagini sono condivise.", P))
story.append(Paragraph(
    "\u2022 <b>Secrets Worker</b>: <font face='Courier'>GEMINI_API_KEY</font>, "
    "<font face='Courier'>ADMIN_TOKEN</font>, <font face='Courier'>FCM_SERVICE_ACCOUNT_JSON</font> "
    "via <font face='Courier'>wrangler secret put</font>. In locale stanno in "
    "<font face='Courier'>worker/.dev.vars</font> (gitignored).", P))

doc.build(story)
print(f"OK -> {OUT}  ({os.path.getsize(OUT)} bytes)")
