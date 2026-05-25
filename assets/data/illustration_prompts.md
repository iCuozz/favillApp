# FavillApp — Illustration Prompts

## 🛠 Tool consigliato: Draw Things

**[drawthings.ai](https://drawthings.ai)** — App gratuita, ottimizzata Apple Silicon, supporta FLUX, SDXL, ControlNet, IP-Adapter.

---

## 📱 Guida completa Draw Things — Generare le illustrazioni di FavillApp

---

### FASE 1 — Installazione e setup (una volta sola)

1. Scarica **Draw Things** dall'App Store (gratuito)
2. Apri l'app → nella schermata modelli cerca e scarica **`FLUX.1-dev`**
   - È il modello con la qualità migliore per illustrazioni
   - Se il Mac ha poca RAM, usa **`FLUX.1-schnell`** (più veloce, qualità leggermente inferiore)
3. Imposta le **dimensioni di default** per FavillApp:
   - Tocca l'ingranaggio ⚙️ → Image Size
   - **Width: 768 — Height: 1365** (rapporto 9:16, verticale)
4. Imposta i **parametri base**:

| Campo | FLUX.1-dev | FLUX.1-schnell |
|---|---|---|
| Steps | 20–28 | 4 |
| CFG Scale | 3.5 | 1.0 |
| Sampler | DPM++ 2M | Euler |
| Seed | -1 (casuale per ora) | -1 |

---

### FASE 2 — Genera i Character Sheet (OBBLIGATORIO prima di tutto)

I character sheet sono le immagini di riferimento che userai con IP-Adapter per mantenere i personaggi **sempre identici** in tutte le scene.

**Genera un character sheet per ogni personaggio principale:**
1. Apri un nuovo canvas
2. Nel campo **Prompt**, incolla il CHARACTER SHEET del personaggio (vedi sezione CHARACTER SHEET più avanti in questo file)
   - Sostituisci `[STYLE BLOCK]` con il testo dello STYLE BLOCK
   - Sostituisci `[NEGATIVE BLOCK]` con il testo del NEGATIVE BLOCK
3. Nel campo **Negative Prompt**, incolla il NEGATIVE BLOCK
4. Imposta **Seed: -1** (casuale)
5. Premi **Generate** — genera **almeno 6 varianti** (cambia seed ogni volta)
6. Scegli la variante che somiglia di più al personaggio descritto
7. **Salvala** nella libreria: tieni premuto sull'immagine → "Salva in libreria"
8. **Annota il seed** di quella variante (tocca l'immagine → Info → seed number)

**Personaggi da generare (in ordine):**
- [ ] CHARACTER SHEET: Favilla (normale)
- [ ] CHARACTER SHEET: Favilla Blaze
- [ ] CHARACTER SHEET: Mallow
- [ ] CHARACTER SHEET: Lex

> ⚠️ Non saltare questa fase. Senza character sheet, ogni scena avrà un personaggio diverso.

---

### FASE 3 — Blocca il seed di stile

Il seed determina l'"impronta visiva" di tutte le immagini. Usare lo stesso seed su scene diverse garantisce coerenza nello stile di tratto, palette colori e illuminazione.

1. Genera una scena qualsiasi con seed `-1`
2. Scorri i risultati — quando trovi uno stile di tratto che ti piace (anche se la scena non è perfetta), annota quel seed
3. **Da quel momento usa sempre quel seed fisso** per tutte le immagini dello stesso episodio
4. Cambia seed solo se cambi episodio o vuoi un look radicalmente diverso

> 💡 Annota i seed qui o in una nota sul Mac: `seed_stile_prologo: XXXXXXXX`

---

### FASE 4 — Genera ogni scena

Per ogni immagine (ogni `page_X.webp`):

**Step 1 — Costruisci il prompt positivo**
Copia il blocco della pagina da questo file e sostituisci le macro:

```
[STYLE BLOCK]     →  incolla il testo dello STYLE BLOCK (vedi sezione 🎨 sotto)
[ENV KITCHEN]     →  incolla il testo ENV KITCHEN (o ENV SCHOOL, ENV BEDROOM, ecc.)
[ENV SCHOOL]      →  stesso principio
[NEGATIVE BLOCK]  →  va nel campo Negative Prompt, non qui
```

Il prompt finale avrà questa forma:
```
digital comic illustration, semi-flat colors, bold clean black outlines...  ← STYLE BLOCK
ENV KITCHEN: small cozy Italian apartment kitchen...                        ← ENV BLOCK
Scene: FAVILLA (...) stands near the table...                               ← DESCRIZIONE SCENA
```

**Step 2 — Incolla nel Negative Prompt**
Copia il NEGATIVE BLOCK nel campo Negative Prompt di Draw Things.

**Step 3 — Attiva IP-Adapter**
1. Nella schermata principale cerca il pannello **"Image Input"** (icona immagine o "+")
2. Seleziona **IP-Adapter**
3. Tocca **"Choose Image"** → scegli dalla libreria il character sheet del personaggio principale della scena
4. Imposta **Strength: 0.65**

| Situazione | Strength consigliata |
|---|---|
| Scena normale con personaggio | 0.65 |
| Volto non abbastanza simile | 0.72–0.80 |
| Scena perde contesto per troppa somiglianza | 0.50–0.58 |
| Scena con più personaggi | 0.60 (usa il personaggio principale) |

**Step 4 — Imposta il seed fisso**
Inserisci il seed annotato nella FASE 3 (non `-1`).

**Step 5 — Generate**
- Se il risultato non va, **cambia solo il seed** (+1, +2...) senza toccare il prompt
- Se un elemento specifico è sbagliato (pose, espressione), aggiusta la descrizione di quella parte nel prompt
- Non cambiare mai lo STYLE BLOCK o il NEGATIVE BLOCK tra una pagina e l'altra dello stesso episodio

---

### FASE 5 — Esporta e integra nell'app

1. Tieni premuto sull'immagine → **"Export"**
2. Formato: **WebP** — Qualità: **85**
3. Salva in una cartella di lavoro temporanea
4. Rinomina il file esattamente come indicato sopra ogni prompt (es. `page_0.webp`)
5. Spostalo nella cartella assets corrispondente:
   - `assets/episodes/prologo/` per il prologo
   - `assets/episodes/s1_mattina_dopo/` per la prima quest
   - `assets/episodes/<id>/` per le altre quest
6. Dopo ogni batch di immagini: lancia `asset-check` skill per verificare che non manchi nulla
7. Poi `flutter run` per vedere le immagini nell'app

---

### 🔁 Workflow rapido in sintesi

```
SETUP (1 volta)
  └─ Installa Draw Things + scarica FLUX.1-dev
  └─ Dimensioni 768×1365, Steps 20, CFG 3.5

CHARACTER SHEET (1 volta per personaggio)
  └─ Genera 6+ varianti con seed -1
  └─ Scegli la migliore → salva in libreria → annota seed

SEED DI STILE (1 volta per episodio)
  └─ Genera una scena con seed -1 finché lo stile ti piace
  └─ Annota quel seed → usalo fisso per tutto l'episodio

PER OGNI SCENA
  └─ STYLE BLOCK + ENV BLOCK + descrizione → campo Prompt
  └─ NEGATIVE BLOCK → campo Negative Prompt
  └─ IP-Adapter → character sheet del personaggio principale (Strength 0.65)
  └─ Seed fisso dell'episodio
  └─ Generate → aggiusta solo se necessario → Export WebP 85%

INTEGRAZIONE
  └─ Rinomina → sposta in assets/ → asset-check → flutter run
```

---

### 🛠 Problemi comuni e soluzioni

| Problema | Causa | Soluzione |
|---|---|---|
| Il personaggio cambia faccia da una scena all'altra | IP-Adapter disattivato o Strength troppo bassa | Attiva IP-Adapter, porta Strength a 0.72 |
| Lo stile di tratto cambia tra le pagine | Seed diverso o STYLE BLOCK modificato | Usa sempre lo stesso seed fisso e STYLE BLOCK identico |
| L'immagine ha testo, lettere o fumetti | Il modello li genera di default | Aggiungi `no text, no letters, no speech bubbles` sia al prompt che al negative |
| Le mani sono deformate | Problema comune di tutti i modelli AI | Aggiungi `perfect hands, well-defined fingers` al prompt positivo |
| Favilla sembra diversa (capelli, occhiali sbagliati) | Descrizione nel prompt incompleta | Copia il CHARACTER BLOCK di Favilla word-for-word dal blocco FAVILLA di questo file |
| I bambini sembrano troppo grandi | Mancano indicatori di età precisi | Aggiungi `very young children age 5-6, small and chubby, kindergarten size` |
| Lex sembra troppo grande/vecchio | Il modello non capisce "7 mesi" | Aggiungi `7 months old baby, infant, pre-crawling, chubby baby face` |
| FLUX genera foto realistiche invece che fumetto | STYLE BLOCK mancante o incompleto | Assicurati che il prompt inizi con `digital comic illustration, semi-flat colors, bold clean black outlines` |
| L'immagine è scura o sovraesposta | Illuminazione non specificata | Aggiungi la palette mood della scena (vedi sezione 🎭 Palette) |
| IP-Adapter "schiaccia" troppo la scena verso la reference | Strength troppo alta | Abbassa a 0.55–0.60 |

---

> ⚠️ **Regola d'oro:** la coerenza visiva non viene dal prompt — viene dall'**IP-Adapter + seed fisso**.
> Il prompt descrive *cosa succede*, IP-Adapter + seed garantiscono *come appare*.

---

## 🎨 Stile globale (STYLE BLOCK — copia in OGNI prompt)

```
digital comic illustration, semi-flat colors, bold clean black outlines, 
expressive faces, Franco-Belgian comic style, warm Italian atmosphere, 
portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, 
no watermarks, high detail backgrounds
```

### Negative prompt (NEGATIVE BLOCK — usalo sempre)
```
realistic photo, 3D render, anime, manga, chibi, watercolor, 
speech bubbles, text, letters, watermark, signature, blurry, 
low quality, extra limbs, deformed hands, ugly faces
```

---

## 👥 CHARACTER BLOCKS (copia letteralmente nei prompt — mai riformulare)

Questi blocchi vanno incollati **word for word** nel prompt. La coerenza viene dalla ripetizione identica + IP-Adapter.

### FAVILLA (versione normale)
```
FAVILLA: Italian woman mid-30s, warm olive skin, blonde hair in a soft ponytail,
brown expressive lively eyes, beautiful face full of energy,
athletic and sporty build, black cat-eye glasses (pointed upper frame),
slim white shirt, tight jeans, black-and-white sneakers
— at school: same outfit with blue school-worker smock over it
```

### FAVILLA BLAZE (versione supereroina)
```
FAVILLA BLAZE: same Italian woman mid-30s, olive skin, but glasses gone,
blonde hair loose and radiating warm golden amber light,
posture confident and tall, athletic build, soft golden light emanating from hands and eyes,
same clothes as before — no costume — just illuminated from within
```

### MALLOW (marito)
```
MALLOW: Italian man late-30s, tall slightly stooped posture, 
capelli con mini-mohawk, short dark stubble, 
always near a laptop or phone, casual home clothes: polo azzurra, jeans dritti, sneakers gialle alte, 
calm analytical expression
```

### LEX (neonato)
```
LEX: chubby baby boy 7 mesi e mezzo, rosy olive skin, capelli castani chiari con mini-cresta come papà, 
two tiny bottom teeth visible when smiling, wide curious intelligent eyes, 
rounded baby face, expressive — laughs big or stares intensely, sneakers rosse tiny
```

### BAMBINI (scuola)
```
BAMBINI: Italian elementary school children age 5-6 maximum, very young, 
white or blue school smocks (grembiulini), small and chubby, energetic expressions
```

---

## 🗺 Ambienti (ENV BLOCKS — copia nei prompt per coerenza)

### CUCINA DI CASA
```
ENV KITCHEN: small cozy Italian apartment kitchen, 
colorful ceramic tiled floor in terracotta and white, 
wooden table center frame, small gas stovetop, 
cluttered countertops with Italian pantry items, 
single window with thin curtains, warm amber and cream walls
```

### CAMERA DA LETTO
```
ENV BEDROOM: modest Italian apartment bedroom, 
double bed with white linen, wooden nightstand with phone, 
thin curtains filtering outside light, simple wardrobe, intimate and slightly cluttered
```

### CAMERETTA LEX
```
ENV NURSERY: small Italian apartment nursery, 
white wooden crib, soft pastel walls, simple baby mobile above crib, 
morning light through thin curtains, warm and gentle
```

### SCUOLA (corridoio)
```
ENV SCHOOL: Italian elementary school corridor, 
1980s institutional architecture, pale green walls, 
fluorescent ceiling lights, colorful children's drawings on walls, 
linoleum floor in beige, metal coat hooks at child height
```

---

## 🎭 Palette per mood

| Mood | Palette |
|---|---|
| Scuola caotica | Giallo caldo, verde istituzionale, luce fluorescente |
| Casa serale | Ambra, crema, luce calda soffusa |
| Alba / notte | Blu desaturato, ombra profonda, solo luce del display |
| Trasformazione | Burst oro/ambra, alta saturazione, sfondo desaturato |
| Tensione | Contrasto alto, luce fredda laterale, tavolozza compressa |
| Famiglia distesa | Caldi naturali, luce piena, composizione aperta |

---

## 📋 ORDINE DI GENERAZIONE CONSIGLIATO

Prima genera i **character sheet** — poi usa quelli come IP-Adapter in ogni scena.

### CHARACTER SHEET: Favilla
```
[STYLE BLOCK]

Character sheet of FAVILLA: Italian woman mid-30s, warm olive skin, blonde hair
in a soft ponytail, brown expressive lively eyes, beautiful face full of energy,
athletic and sporty build, black cat-eye glasses (pointed upper frame),
slim white shirt, tight jeans, black-and-white sneakers.
Show 4 expressions on white background: 
(1) neutral slight smile, (2) tired worried, (3) determined, (4) surprised.
Same character, consistent face across all 4 panels. Clean white background.

[NEGATIVE BLOCK]
```

### CHARACTER SHEET: Favilla Blaze
```
[STYLE BLOCK]

Character sheet of FAVILLA BLAZE: same Italian woman mid-30s as Favilla but transformed — 
glasses gone, blonde hair loose radiating warm golden amber light, 
confident tall posture, athletic build, golden light from hands and eyes, same casual clothes. 
Show 3 poses on white background: (1) standing tall arms slightly raised, 
(2) reaching forward, (3) holding a baby safely. Clean white background.

[NEGATIVE BLOCK]
```

### CHARACTER SHEET: Mallow
```
[STYLE BLOCK]

Character sheet of MALLOW: Italian man late-30s, tall slightly stooped, 
capelli con mini-mohawk, short dark stubble, casual home clothes: polo azzurra, jeans dritti, sneakers gialle alte. 
Show 3 expressions on white background: 
(1) distracted on laptop, (2) calm analytical stare, (3) warm genuine smile.

[NEGATIVE BLOCK]
```

### CHARACTER SHEET: Lex
```
[STYLE BLOCK]

Character sheet of LEX: chubby Italian baby boy 7 mesi e mezzo, rosy olive skin, 
capelli castani chiari con mini-cresta come papà, two tiny bottom teeth, wide intelligent eyes. Show 4 expressions on white background: 
(1) full open-mouthed laugh with two teeth showing, (2) intense stare, 
(3) arms raised mimicking effort, (4) sleepy. All from front/slight angle. 
sneakers rosse tiny. 

[NEGATIVE BLOCK]
```

---

## 📖 PROLOGO

### page_0 — Favilla a scuola
`assets/episodes/prologo/page_0.webp`

```
[STYLE BLOCK]
[ENV SCHOOL]

Scene: FAVILLA (Italian woman mid-30s, warm olive skin, blonde hair in a soft ponytail, 
brown lively eyes, black cat-eye glasses, blue school-worker smock over white shirt and tight jeans) 
stands center frame in the school corridor with a knowing half-smile, full of energy. 
Two BAMBINI (Italian children age 5-6, very young and small, white school smocks) 
argue intensely at her sides, both reaching for a tiny eraser between them. 
More tiny children run in blurred background. Warm fluorescent light overhead. 
Slightly chaotic, comedic energy.

[NEGATIVE BLOCK]
```
> 💡 IP-Adapter: character sheet Favilla (normal)

---

### page_1 — Casa serale, Lex sul seggiolone
`assets/episodes/prologo/page_1.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Evening warm light. Scene: FAVILLA (Italian woman mid-30s, olive skin, blonde hair in a soft ponytail, 
brown lively eyes, black cat-eye glasses, home clothes: white shirt tight jeans black-and-white sneakers) 
stands near the wooden table, leaning slightly toward LEX 
(chubby baby 7 mesi e mezzo, two bottom teeth, wide excited eyes, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) who is strapped in a 
wooden highchair, arms waving energetically. MALLOW (Italian man late-30s, tall, 
capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte) sits at the table with an open laptop and headphones 
around neck, half-distracted. Warm amber light. Family chaos, affectionate.

[NEGATIVE BLOCK]
```
> 💡 IP-Adapter: character sheet Favilla + Mallow

---

### page_2 — Cucina nel caos, cucchiaino volante
`assets/episodes/prologo/page_2.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Evening. Scene: Pasta pot boiling over on the gas stovetop (background left). 
LEX (chubby baby 7 mesi e mezzo, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) in the wooden highchair laughing triumphantly, 
having just thrown a baby spoon that flies through the air mid-frame. 
FAVILLA (Italian woman mid-30s, olive skin, blonde hair in a soft ponytail, brown lively eyes, black cat-eye glasses, white shirt tight jeans) 
ducks sideways to dodge the spoon while reaching toward the stove. 
MALLOW (Italian man, tall, capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte) is on a laptop call with headphones, 
completely oblivious. Steam haze from the boiling pot. Comedic energy, slightly chaotic. 
Warm amber with hint of steam.

[NEGATIVE BLOCK]
```

---

### page_3 — Il momento critico
`assets/episodes/prologo/page_3.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Dramatic split-moment, high tension. Three simultaneous events: 
(1) pasta pot boiling over violently on stove, background left — 
(2) phone buzzing on table, background right — 
(3) LEX (chubby baby 7 mesi e mezzo, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) leaning dangerously far over the edge of the 
wooden highchair, about to fall, center foreground. 
FAVILLA (Italian woman mid-30s, olive skin, blonde hair in a soft ponytail, brown lively eyes, black cat-eye glasses) 
stares in sudden wide-eyed panic, body frozen mid-motion. 
Slightly tilted composition, deep warm reds and ambers. Cinematic, tense, urgent.

[NEGATIVE BLOCK]
```

---

### page_4 — Trasformazione Favilla Blaze
`assets/episodes/prologo/page_4.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Magical moment. Kitchen now strangely calm and orderly. 
FAVILLA BLAZE: same Italian woman mid-30s, olive skin, but glasses gone, 
blonde hair loose and radiating warm golden amber light, posture confident and tall, athletic build,
soft golden light from hands and eyes, same home clothes. 
She stands protectively near LEX (chubby baby 7 mesi e mezzo, two bottom teeth, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) 
who is completely safe, staring at her with enormous wide eyes then breaking 
into a full open-mouthed laugh. Background: MALLOW still on laptop, unaware. 
High saturation warm gold on Favilla, desaturated surroundings. 
Awe, warmth, secret being born.

[NEGATIVE BLOCK]
```
> 💡 IP-Adapter: character sheet Favilla Blaze

---

## 📖 QUEST: s1_mattina_dopo

> Salva in `assets/episodes/s1_mattina_dopo/` e aggiorna i path nel JSON.

---

### page_0 — 5:12 AM, insonnia
`assets/episodes/s1_mattina_dopo/page_0.webp`

```
[STYLE BLOCK]
[ENV BEDROOM]

Deep night, 5:12 AM. The phone screen glows cold blue on the nightstand showing 5:12. 
FAVILLA (Italian woman mid-30s, olive skin, biondi hair spread loose on pillow, 
no glasses — she's in bed) lies awake, eyes wide open staring at the ceiling. 
MALLOW (Italian man, capelli con mini-mohawk) sleeps peacefully beside her, relaxed face. 
Only light source: cold blue glow of the phone screen softly illuminating their faces. 
Cool desaturated blues, deep shadows, intimate stillness. Quiet intensity in her expression — 
a thousand thoughts.

[NEGATIVE BLOCK]
```

---

### page_1 — Lex la fissa consapevole
`assets/episodes/s1_mattina_dopo/page_1.webp`

```
[STYLE BLOCK]
[ENV NURSERY]

Early morning, soft dawn light through thin curtains. 
FAVILLA (Italian woman mid-30s, olive skin, biondi hair loose, no glasses, home clothes) 
leans over a white wooden baby crib. LEX (chubby baby 7 mesi e mezzo, two bottom teeth, 
wide intelligent eyes, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) is awake, staring directly at her face with an unnervingly aware, 
intense gaze — not at a bottle, not at a toy, just at her. She stares back, 
slightly surprised, a small knot between her brows. Warm early morning amber and pale gold. 
Quiet, slightly mysterious. The eye contact is the whole scene.

[NEGATIVE BLOCK]
```

---

### page_2 — Lex imita i superpoteri
`assets/episodes/s1_mattina_dopo/page_2.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Morning light. LEX (chubby baby 7 mesi e mezzo, two tiny bottom teeth, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) in the wooden highchair: 
arms raised and thrust forward with maximum baby effort, face scrunched in intense 
concentration — clearly imitating a superpower pose. 
FAVILLA (Italian woman mid-30s, olive skin, biondi hair in a soft ponytail, round glasses, home clothes) 
stands facing him, expression unreadable — the choice is hers. 
MALLOW (Italian man, capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte) looks up from his phone toward Favilla, 
waiting for her reaction. Moment frozen in expectation. Warm morning light, 
slight comedic tension in the composition.

[NEGATIVE BLOCK]
```

---

### branch_sorriso — Sorriso complice
`assets/episodes/s1_mattina_dopo/branch_sorriso.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Morning. FAVILLA (Italian woman mid-30s, olive skin, biondi hair in a soft ponytail, round glasses) 
gives a small, warm, private smile looking at the baby — something knowing in her eyes, 
a shared secret. LEX (chubby baby 7 mesi e mezzo, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) erupts in full open-mouthed laughter 
showing two tiny bottom teeth, arms still raised. MALLOW (Italian man, capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte) looks at both of them with a wide genuine smile, completely unaware 
of the shared meaning. Warm amber morning light, joyful family warmth. 
Open composition, relaxed energy.

[NEGATIVE BLOCK]
```

---

### branch_sudore — Mezzo sorriso che non convince
`assets/episodes/s1_mattina_dopo/branch_sudore.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

Morning. FAVILLA (Italian woman mid-30s, olive skin, biondi hair in a soft ponytail, round glasses) 
has stiffened — a half-smile that convinces no one, eyes slightly wide, 
a single bead of cold sweat on her temple. MALLOW (Italian man, capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte) 
has lowered his phone and looks at her with quiet precise attention — 
the focused calm of someone connecting the dots. LEX (chubby baby 7 mesi e mezzo, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) 
looks back and forth between them, sensing the shift. Subtle underlying tension. 
Cooler, slightly desaturated morning light cutting the warm amber. Closed composition.

[NEGATIVE BLOCK]
```

---

### epilogue — 7:30, normalità apparente
`assets/episodes/s1_mattina_dopo/epilogue.webp`

```
[STYLE BLOCK]
[ENV KITCHEN]

7:30 AM, morning sun streaming through the small kitchen window. 
FAVILLA (Italian woman mid-30s, olive skin, biondi hair in a soft ponytail, round glasses, 
home clothes) stands at the counter holding a small espresso cup, LEX (chubby baby 
7 mesi e mezzo, capelli castani chiari con mini-cresta come papà, sneakers rosse tiny) balanced on her hip — the classic Italian motherhood "third arm". 
MALLOW (Italian man, tall, capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte) sits at the table facing away, 
laptop open, already on a call. Favilla looks out the window — a quiet complex 
expression, somewhere between determination and wonder. Everything looks the same. 
Nothing is the same. Warm golden ordinary morning light.

[NEGATIVE BLOCK]
```

---

## ✅ Checklist

### Prologo (`assets/episodes/prologo/`)
- [ ] CHARACTER SHEET: Favilla (genera per prima — usala come IP-Adapter)
- [ ] CHARACTER SHEET: Favilla Blaze
- [ ] CHARACTER SHEET: Mallow
- [ ] CHARACTER SHEET: Lex
- [ ] page_0.webp — Favilla a scuola, bambini litigano
- [ ] page_1.webp — Casa serale, Lex + Mallow
- [ ] page_2.webp — Caos cucina, cucchiaino volante
- [ ] page_3.webp — Momento critico, Lex cade
- [ ] page_4.webp — Trasformazione Favilla Blaze

### Quest s1_mattina_dopo (`assets/episodes/s1_mattina_dopo/`)
- [ ] page_0.webp — 5:12 AM, insonnia
- [ ] page_1.webp — Lex la fissa consapevole
- [ ] page_2.webp — Lex imita i superpoteri
- [ ] branch_sorriso.webp — Sorriso complice
- [ ] branch_sudore.webp — Mezzo sorriso, tensione
- [ ] epilogue.webp — 7:30, caffè + Lex sull'anca

---

## ⚙️ Note tecniche
- **Dimensioni:** 1080×1920 px (portrait 9:16) — export `.webp` qualità 85
- **Nessun testo nelle immagini** — tutto il testo è gestito dall'app
- **Nessun fumetto** — l'app sovrappone i suoi componenti UI
- **IP-Adapter:** genera i character sheet PRIMA di qualsiasi scena
- **Seed stile:** annota il seed che ti piace di più e usalo per tutte le pagine dello stesso episodio
