# FavillApp — Illustration Prompts

## 🛠 Tool consigliato: Draw Things (gratis, nativo M5)

**[drawthings.ai](https://drawthings.ai)** — App gratuita, ottimizzata Apple Silicon, supporta FLUX, SDXL, ControlNet, IP-Adapter.

---

## 📱 Come usare Draw Things — Guida completa

### 1. Installazione
1. Scarica **Draw Things** dall'App Store (è gratis)
2. Apri l'app — al primo avvio ti chiede di scaricare un modello
3. **Scegli il modello:** cerca `FLUX.1-schnell` nella lista e scaricalo
   - È veloce (~4 step per immagine) e gratuito
   - Se vuoi qualità superiore, scarica anche `FLUX.1-dev` (più lento, risultati migliori)
   - In alternativa cerca `Illustrious XL` o `SDXL` + cerca un LoRA "comic book style"

---

### 2. Interfaccia base — prima immagine

Quando apri un nuovo canvas vedi:

```
┌─────────────────────────────────┐
│  [Canvas — anteprima immagine]  │
├─────────────────────────────────┤
│  Prompt (testo positivo)        │
│  Negative Prompt                │
├──────────┬──────────┬───────────┤
│  Model   │  Steps   │   CFG     │
│  Width   │  Height  │   Seed    │
└──────────┴──────────┴───────────┘
            [Generate]
```

**Impostazioni di partenza per FavillApp:**
| Campo | Valore |
|---|---|
| Width | 768 |
| Height | 1365 (oppure 1024×1820 se ha abbastanza RAM) |
| Steps | 4 (FLUX schnell) / 20 (FLUX dev) |
| CFG Scale | 1.0 (FLUX schnell) / 3.5 (FLUX dev) |
| Sampler | Euler (FLUX schnell) / DPM++ 2M (FLUX dev) |
| Seed | -1 la prima volta, poi annota quello che ti piace |

> **Perché 768×1365?** È il rapporto 9:16 che usa l'app. Draw Things scala automaticamente.

---

### 3. Come inserire un prompt

1. Tocca il campo **Prompt**
2. Incolla il testo del prompt da questo file (vedi sezioni sotto)
3. Sostituisci `[STYLE BLOCK]` con il testo dello Style Block
4. Sostituisci `[ENV KITCHEN]` (o l'ambiente giusto) con il testo dell'ENV Block
5. Tocca il campo **Negative Prompt** e incolla il NEGATIVE BLOCK
6. Premi **Generate**

**Esempio concreto per page_0 del prologo:**
```
Prompt:
digital comic illustration, semi-flat colors, bold clean black outlines, 
expressive faces, Franco-Belgian comic style, warm Italian atmosphere, 
portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, 
no watermarks, high detail backgrounds,
Italian elementary school corridor, 1980s institutional architecture, pale green walls, 
fluorescent ceiling lights, colorful children's drawings on walls, linoleum floor,
Scene: FAVILLA (Italian woman mid-30s, warm olive skin, dark brown hair in a messy bun, 
round tortoiseshell glasses, blue school-worker smock) stands center frame...

Negative Prompt:
realistic photo, 3D render, anime, manga, chibi, watercolor, 
speech bubbles, text, letters, watermark, signature, blurry, 
low quality, extra limbs, deformed hands, ugly faces
```

---

### 4. Generare i Character Sheet (PRIMA COSA DA FARE)

Prima di ogni scena con personaggi, genera un **character sheet** per ognuno.
Il character sheet sarà poi usato come reference in IP-Adapter.

1. Usa il prompt del character sheet (vedi sezione CHARACTER SHEET più avanti)
2. Genera 4–6 varianti (cambia seed con `-1`)
3. Scegli la migliore — quella che "sembra" più il personaggio
4. **Salvala** nella Libreria di Draw Things (tieni premuto → Salva)
5. Annota il **seed** dell'immagine migliore (visibile nell'info dell'immagine)

---

### 5. IP-Adapter — il segreto della coerenza

IP-Adapter permette di "portare" il volto/stile di una reference image nella nuova generazione.

**Come attivarlo:**
1. Nella schermata principale, tocca **"+"** o cerca il pannello **"Image Input"**
2. Seleziona **IP-Adapter**
3. Tocca **"Choose Image"** → seleziona il character sheet generato prima
4. Imposta **Strength: 0.65** (bilancia tra coerenza e libertà creativa)
5. Genera normalmente con il prompt della scena

**Quando usarlo:** su OGNI immagine che contiene Favilla, Mallow o Lex.
**Non serve su:** sfondi puri, oggetti, ambienti senza personaggi.

> 💡 Se il personaggio appare ma il volto non è coerente, alza la Strength a 0.75–0.80.
> Se la scena è troppo simile alla reference e perde il contesto, abbassa a 0.50–0.55.

---

### 6. Seed — bloccare lo stile

Il **seed** è il numero casuale che determina il risultato. Stesso seed + stesso prompt = stessa immagine.

**Workflow:**
1. Prima generazione: seed `-1` (casuale)
2. Trovi un risultato con lo stile giusto → annota il seed (visibile toccando l'immagine → Info)
3. Per le immagini successive dello stesso episodio: inserisci quel seed fisso
4. Cambia solo il prompt descrittivo della scena, non il seed

---

### 7. Esportare le immagini

1. Tieni premuto sull'immagine generata → **"Export"**
2. Scegli **WebP** come formato (quello che usa l'app Flutter)
3. Qualità: **85** (buon bilanciamento qualità/peso)
4. Salva in una cartella di lavoro, poi sposta in:
   - `favillApp/assets/episodes/prologo/` per il prologo
   - `favillApp/assets/episodes/s1_mattina_dopo/` per la prima quest (crea la cartella)
5. Rinomina il file secondo il path indicato in ogni prompt (es. `page_0.webp`)

---

### 8. Workflow completo dall'inizio alla fine

```
FASE 1 — Setup (una volta sola)
  └─ Installa Draw Things
  └─ Scarica FLUX.1-schnell
  └─ Imposta dimensioni 768×1365, Steps 4, CFG 1.0

FASE 2 — Character Sheet (una volta per personaggio)
  └─ Usa il prompt CHARACTER SHEET di questo file
  └─ Genera 4-6 varianti, scegli la migliore
  └─ Salva nella libreria + annota il seed

FASE 3 — Genera ogni scena
  └─ Apri nuovo canvas
  └─ Incolla STYLE BLOCK + ENV BLOCK + descrizione scena nel prompt
  └─ Incolla NEGATIVE BLOCK nel negative prompt
  └─ Attiva IP-Adapter con il character sheet del personaggio principale
  └─ Imposta seed fisso (quello dello stile che ti piace)
  └─ Genera → se non va, cambia seed o aggiusta il prompt
  └─ Esporta come WebP 85% qualità

FASE 4 — Integra nell'app
  └─ Sposta i .webp nelle cartelle assets/
  └─ Aggiorna i path nel JSON della quest (s1_mattina_dopo)
  └─ flutter run per verificare
```

---

### 9. Problemi comuni e soluzioni

| Problema | Soluzione |
|---|---|
| Il personaggio cambia aspetto da un'immagine all'altra | Attiva IP-Adapter con il character sheet, alza Strength a 0.7 |
| Lo stile cambia tra le pagine | Usa sempre lo stesso seed fisso |
| L'immagine ha testo o fumetti | Aggiungi "no text, no speech bubbles" al prompt E al negative |
| Le mani sono deformate | Aggiungi "perfect hands, detailed hands" al prompt positivo |
| L'immagine è troppo scura/chiara | Aggiungi "well lit, balanced lighting" al prompt |
| Il bambino sembra troppo grande/piccolo | Specifica "7 months old baby, infant, very young baby" |
| FLUX genera immagini troppo realistiche | Aggiungi "illustration, drawn, comic art" all'inizio del prompt |

---

### Workflow in sintesi
```
Character Sheet → IP-Adapter reference → Seed fisso → Scene per scene → Export WebP
```

> ⚠️ **Regola d'oro:** la coerenza non viene dal prompt — viene dall'IP-Adapter.
> Il prompt descrive la scena, l'IP-Adapter "porta" il personaggio.

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
FAVILLA: Italian woman mid-30s, warm olive skin, dark brown hair in a messy bun 
with loose strands, round tortoiseshell glasses, kind tired eyes, 
slight roundness in the face, practical everyday home clothes or blue school-worker smock
```

### FAVILLA BLAZE (versione supereroina)
```
FAVILLA BLAZE: same Italian woman mid-30s, olive skin, but glasses gone, 
dark hair loose and radiating warm golden amber light, 
posture confident and tall, soft golden light emanating from hands and eyes, 
same clothes as before — no costume — just illuminated from within
```

### MALLOW (marito)
```
MALLOW: Italian man late-30s, tall slightly stooped posture, 
dark hair slightly disheveled, short dark stubble, 
always near a laptop or phone, casual home clothes: grey sweater, jeans, 
calm analytical expression
```

### LEX (neonato)
```
LEX: chubby baby boy 7 months old, rosy olive skin, 
two tiny bottom teeth visible when smiling, wide curious intelligent eyes, 
rounded baby face, expressive — laughs big or stares intensely
```

### BAMBINI (scuola)
```
BAMBINI: Italian elementary school children age 6-8, 
white or blue school smocks (grembiulini), varied heights, energetic expressions
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

Character sheet of FAVILLA: Italian woman mid-30s, warm olive skin, dark brown hair 
in a messy bun with loose strands, round tortoiseshell glasses, kind tired eyes, 
slight roundness in the face. Show 4 expressions on white background: 
(1) neutral slight smile, (2) tired worried, (3) determined, (4) surprised.
Same character, consistent face across all 4 panels. Clean white background.

[NEGATIVE BLOCK]
```

### CHARACTER SHEET: Favilla Blaze
```
[STYLE BLOCK]

Character sheet of FAVILLA BLAZE: same Italian woman mid-30s as Favilla but transformed — 
glasses gone, dark hair loose radiating warm golden amber light, 
confident tall posture, golden light from hands and eyes, same casual clothes. 
Show 3 poses on white background: (1) standing tall arms slightly raised, 
(2) reaching forward, (3) holding a baby safely. Clean white background.

[NEGATIVE BLOCK]
```

### CHARACTER SHEET: Mallow
```
[STYLE BLOCK]

Character sheet of MALLOW: Italian man late-30s, tall slightly stooped, 
dark disheveled hair, short dark stubble, casual grey sweater and jeans. 
Show 3 expressions on white background: 
(1) distracted on laptop, (2) calm analytical stare, (3) warm genuine smile.

[NEGATIVE BLOCK]
```

### CHARACTER SHEET: Lex
```
[STYLE BLOCK]

Character sheet of LEX: chubby Italian baby boy 7 months, rosy olive skin, 
two tiny bottom teeth, wide intelligent eyes. Show 4 expressions on white background: 
(1) full open-mouthed laugh with two teeth showing, (2) intense stare, 
(3) arms raised mimicking effort, (4) sleepy. All from front/slight angle. 

[NEGATIVE BLOCK]
```

---

## 📖 PROLOGO

### page_0 — Favilla a scuola
`assets/episodes/prologo/page_0.webp`

```
[STYLE BLOCK]
[ENV SCHOOL]

Scene: FAVILLA (Italian woman mid-30s, warm olive skin, dark brown hair in a messy bun, 
round tortoiseshell glasses, blue school-worker smock) stands center frame in the school 
corridor with a knowing tired half-smile. Two BAMBINI (Italian children 6-8, white school 
smocks) argue intensely at her sides, both reaching for a tiny eraser between them. 
More children run in blurred background. Warm fluorescent light overhead. 
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

Evening warm light. Scene: FAVILLA (Italian woman mid-30s, olive skin, dark messy bun, 
round glasses, home clothes) stands near the wooden table, leaning slightly toward LEX 
(chubby baby 7 months, two bottom teeth, wide excited eyes) who is strapped in a 
wooden highchair, arms waving energetically. MALLOW (Italian man late-30s, tall, 
dark stubble, grey sweater) sits at the table with an open laptop and headphones 
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
LEX (chubby baby 7 months) in the wooden highchair laughing triumphantly, 
having just thrown a baby spoon that flies through the air mid-frame. 
FAVILLA (Italian woman mid-30s, olive skin, dark messy bun, round glasses) 
ducks sideways to dodge the spoon while reaching toward the stove. 
MALLOW (Italian man, tall, dark stubble) is on a laptop call with headphones, 
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
(3) LEX (chubby baby 7 months) leaning dangerously far over the edge of the 
wooden highchair, about to fall, center foreground. 
FAVILLA (Italian woman mid-30s, olive skin, dark messy bun, round glasses) 
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
dark hair loose and radiating warm golden amber light, posture confident and tall, 
soft golden light from hands and eyes, same home clothes. 
She stands protectively near LEX (chubby baby 7 months, two bottom teeth) 
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
FAVILLA (Italian woman mid-30s, olive skin, dark hair spread loose on pillow, 
no glasses — she's in bed) lies awake, eyes wide open staring at the ceiling. 
MALLOW (Italian man, dark stubble) sleeps peacefully beside her, relaxed face. 
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
FAVILLA (Italian woman mid-30s, olive skin, dark hair loose, no glasses, home clothes) 
leans over a white wooden baby crib. LEX (chubby baby 7 months, two bottom teeth, 
wide intelligent eyes) is awake, staring directly at her face with an unnervingly aware, 
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

Morning light. LEX (chubby baby 7 months, two tiny bottom teeth) in the wooden highchair: 
arms raised and thrust forward with maximum baby effort, face scrunched in intense 
concentration — clearly imitating a superpower pose. 
FAVILLA (Italian woman mid-30s, olive skin, dark messy bun, round glasses, home clothes) 
stands facing him, expression unreadable — the choice is hers. 
MALLOW (Italian man, dark stubble, grey sweater) looks up from his phone toward Favilla, 
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

Morning. FAVILLA (Italian woman mid-30s, olive skin, dark messy bun, round glasses) 
gives a small, warm, private smile looking at the baby — something knowing in her eyes, 
a shared secret. LEX (chubby baby 7 months) erupts in full open-mouthed laughter 
showing two tiny bottom teeth, arms still raised. MALLOW (Italian man, dark stubble, 
grey sweater) looks at both of them with a wide genuine smile, completely unaware 
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

Morning. FAVILLA (Italian woman mid-30s, olive skin, dark messy bun, round glasses) 
has stiffened — a half-smile that convinces no one, eyes slightly wide, 
a single bead of cold sweat on her temple. MALLOW (Italian man, dark stubble) 
has lowered his phone and looks at her with quiet precise attention — 
the focused calm of someone connecting the dots. LEX (chubby baby 7 months) 
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
FAVILLA (Italian woman mid-30s, olive skin, dark hair in messy bun, round glasses, 
home clothes) stands at the counter holding a small espresso cup, LEX (chubby baby 
7 months) balanced on her hip — the classic Italian motherhood "third arm". 
MALLOW (Italian man, tall, dark stubble) sits at the table facing away, 
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
