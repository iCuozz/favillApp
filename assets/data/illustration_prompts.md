# FavillApp — Illustration Prompts

---

## 🎨 Stile globale

### STYLE BLOCK (positive — copia in OGNI prompt)
```
graphic novel style, cel shading, flat colors, bold outlines, comic book illustration,
2D art, clean linework, vibrant colors, full body portrait, smartphone portrait,
no text, no speech bubbles, no watermarks
```

### NEGATIVE BLOCK (usalo sempre)
```
realistic, 3d render, photo, blurry, ugly, deformed, extra limbs, watermark,
speech bubbles, text, letters, signature, low quality
```

---

## 👥 CHARACTER DESCRIPTORS (copia letteralmente nei prompt di scena — mai riformulare)

> Frammenti testuali da incollare inline nelle descrizioni di scena.
> La coerenza visiva viene dal character sheet in IP-Adapter: questi blocchi sono un rinforzo testuale.

### FAVILLA (versione normale)
```
FAVILLA: Italian woman mid-30s, warm olive skin, blonde hair in a soft ponytail,
brown expressive lively eyes, beautiful face full of energy,
athletic and sporty build, black cat-eye glasses (pointed upper frame),
slim white shirt, tight jeans, black-and-white sneakers
— at school: same outfit with blue school-worker smock over it
```

### FAVILLA BLAZE (versione supereroina — Stagione 1, senza costume)
```
FAVILLA BLAZE: same Italian woman mid-30s, olive skin, but glasses gone,
blonde hair loose and radiating warm golden amber light,
posture confident and tall, athletic build, soft golden light emanating from hands and eyes,
wearing the SAME everyday clothes as Favilla — NO superhero costume, NO cape, NO suit —
just her normal outfit illuminated from within by warm golden energy
```

> ⚠️ Stagione 1 = sempre senza costume. Il costume arriverà nelle stagioni successive.

### MALLOW (marito)
```
MALLOW: Italian man late-30s, tall slightly stooped posture, 
capelli con mini-mohawk, short dark stubble, 
always near a laptop, casual home clothes: polo azzurra, jeans dritti, sneakers gialle alte, 
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

## 🖼 CHARACTER SHEET PROMPTS (genera una sola volta per personaggio)

> Prompt completi per generare le immagini di riferimento canoniche.
> Il risultato va usato come immagine reference (IP-Adapter) per tutte le scene successive.

**Ordine di generazione:**
- [ ] Favilla (normale)
- [ ] Favilla Blaze — generala partendo dal character sheet di Favilla
- [ ] Mallow
- [ ] Lex

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
> ⚠️ **NON generare da zero.** Usa il character sheet di Favilla come immagine di input/reference.

```
[STYLE BLOCK]

FAVILLA BLAZE: the same woman from the reference image, but transformed —
glasses gone, blonde hair loose and radiating warm golden amber light,
posture confident and tall, soft golden light emanating from hands and eyes,
wearing the SAME everyday clothes — NO superhero costume, NO cape, NO suit.
Show 3 poses on white background: (1) standing tall arms slightly raised,
(2) reaching forward with glowing hands, (3) holding a baby safely.
Clean white background.

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
capelli castani chiari con mini-cresta come papà, two tiny bottom teeth, wide intelligent eyes.
Show 4 expressions on white background: 
(1) full open-mouthed laugh with two teeth showing, (2) intense stare, 
(3) arms raised mimicking effort, (4) sleepy. All from front/slight angle. 
sneakers rosse tiny.

[NEGATIVE BLOCK]
```

---

## 📂 Prompt per episodi e quest

I prompt scena-per-scena vivono in file dedicati nella cartella `prompts/`:

| Episodio | File |
|---|---|
| Prologo | [`prompts/prologo.md`](prompts/prologo.md) |
| Quest: s1_mattina_dopo | [`prompts/s1_mattina_dopo.md`](prompts/s1_mattina_dopo.md) |

> Per ogni nuova quest crea `prompts/<id>.md` seguendo lo stesso schema.

---

## ⚙️ Note tecniche
- **Dimensioni:** 432×768 px (portrait 9:16) — export `.webp` qualità 85
- **Nessun testo nelle immagini** — tutto il testo è gestito dall'app
- **Nessun fumetto** — l'app sovrappone i suoi componenti UI
- **IP-Adapter:** genera i character sheet PRIMA di qualsiasi scena
