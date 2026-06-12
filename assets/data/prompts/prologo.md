# Prompt illustrazioni — PROLOGO (Raffinati v2)

> **Massima fedeltà narrativa.** Ogni prompt è ancorato al testo esatto del prologo.
> Workflow ComfyUI: `~/Desktop/favilla_blaze_ipadapter.json`
> Modello: FLUX.1-dev Q4_K_S GGUF | 576×1024 | 20 steps | Euler | Guidance 3.5
> IP-Adapter: FLUX Redux + SigCLIP, strength 0.30 per personaggio

---

## ✅ Checklist (`assets/episodes/prologo/`)

- [ ] page_0.png — Favilla a scuola, bambini litigano per la gomma
- [ ] page_1.png — Casa serale, Lex sul seggiolone, Mallow in call
- [ ] page_2.png — Caos cucina: cucchiaino volante, pasta sul fuoco, Mallow oblivious
- [ ] page_3.png — Momento critico: Lex si sporge, pasta trabocca, telefono suona
- [ ] page_4.png — Trasformazione Favilla Blaze, Lex salvo, Mallow ignaro

---

## 🖼️ SCENE 0 — Scuola, i bambini litigano per la gomma

**File:** `page_0.png`
**Personaggi attivi:** Favilla, 2 bambini
**Tono:** Commedia, energia caotica, calore

### Personaggi da caricare nel workflow
- ✅ Favilla (strength 0.30)
- ❌ Favilla Blaze
- ❌ Lex
- ❌ Mallow

### ✏️ PROMPT

```
digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, warm Italian atmosphere, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail backgrounds.

ENV SCHOOL: Italian elementary school corridor, 1980s institutional architecture, pale green walls, fluorescent ceiling lights, colorful children's drawings on walls, linoleum floor in beige, metal coat hooks at child height.

SCENE: Nova Tutinia elementary school. FAVILLA stands center frame — Italian woman mid-30s, warm olive skin, blonde hair in a soft ponytail, brown lively eyes, black cat-eye glasses, wearing blue school-worker smock over white shirt and tight jeans, black-and-white sneakers. She has a knowing half-smile, full of energy, slightly leaning down toward the children. Two BAMBINI — Italian children age 5-6 maximum, very young and small, white school smocks — argue intensely at her sides. One child is pulling a tiny pink eraser toward himself, the other reaching for it with an outraged expression, mouths open mid-shout. More tiny children run and play in the blurred background. Warm fluorescent light overhead. Slightly chaotic, comedic energy. The eraser is the focal point of the argument between the two kids.
```

### 🚫 NEGATIVE PROMPT
```
realistic photo, 3D render, anime, manga, chibi, watercolor, oil painting, speech bubbles, text, letters, watermark, signature, blurry, low quality, extra limbs, deformed hands, ugly faces, adult proportions on children, teenagers, school uniform modern, empty corridor
```

---

## 🖼️ SCENE 1 — Casa serale, Lex sul seggiolone, Mallow in call

**File:** `page_1.png`
**Personaggi attivi:** Favilla, Lex, Mallow
**Tono:** Famiglia, calore, caos affettuoso

### Personaggi da caricare nel workflow
- ✅ Favilla (strength 0.30)
- ❌ Favilla Blaze
- ✅ Lex (strength 0.30)
- ✅ Mallow (strength 0.30)

### ✏️ PROMPT

```
digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, warm Italian atmosphere, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail backgrounds.

ENV KITCHEN: small cozy Italian apartment kitchen, colorful ceramic tiled floor in terracotta and white, wooden table center frame, small gas stovetop, cluttered countertops with Italian pantry items, single window with thin curtains, warm amber and cream walls. Evening warm light pours through the window.

SCENE: FAVILLA — Italian woman mid-30s, olive skin, blonde hair in a soft ponytail, brown lively eyes, black cat-eye glasses, wearing white shirt and tight jeans — stands near the wooden table, leaning slightly toward LEX with a gentle amused expression. LEX — tiny baby boy ONLY 7 months old, very chubby rounded baby face, big round cheeks, rosy olive skin, light brown baby fuzz hair with mini-cresta like dad, two tiny bottom teeth, huge curious round eyes, tiny baby hands and feet, wears tiny red sneakers, clearly an infant not a toddler — is strapped in a wooden highchair, arms waving energetically above his head, mouth open in a loud baby babble. MALLOW — Italian man late-30s, tall slightly stooped posture, capelli con mini-mohawk, short dark stubble, polo azzurra, jeans dritti, sneakers gialle alte — sits at the wooden table with an open laptop, headphones around his neck, looking toward Favilla with a half-distracted expression. Warm amber light bathes the scene. Family chaos, affectionate energy, lived-in feeling.
```

### 🚫 NEGATIVE PROMPT
```
realistic photo, 3D render, anime, manga, chibi, watercolor, oil painting, speech bubbles, text, letters, watermark, signature, blurry, low quality, extra limbs, deformed hands, ugly faces, toddler, walking child, standing baby
```

---

## 🖼️ SCENA 2 — Cucina nel caos, cucchiaino volante

**File:** `page_2.png`
**Personaggi attivi:** Favilla, Lex, Mallow
**Tono:** Commedia frenetica, caos domestico

### Personaggi da caricare nel workflow
- ✅ Favilla (strength 0.30)
- ❌ Favilla Blaze
- ✅ Lex (strength 0.30)
- ✅ Mallow (strength 0.30)

### ✏️ PROMPT

```
digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, warm Italian atmosphere, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail backgrounds.

ENV KITCHEN: small cozy Italian apartment kitchen, colorful ceramic tiled floor in terracotta and white, wooden table center frame, small gas stovetop, cluttered countertops with Italian pantry items, single window with thin curtains, warm amber and cream walls. Evening.

SCENE: A pasta pot is boiling over violently on the small gas stovetop in the background left, white steam rising. LEX — tiny baby boy ONLY 7 months old, very chubby rounded baby face, rosy olive skin, light brown baby fuzz hair with mini-cresta, two tiny bottom teeth showing, huge round baby eyes sparkling with mischief, clearly an infant not a toddler, tiny red sneakers — sits in the wooden highchair center frame, laughing triumphantly with mouth wide open, having just thrown a baby spoon with tiny chubby baby hand. The spoon arcs through the air mid-frame, a tiny silver object frozen in flight. FAVILLA — Italian woman mid-30s, olive skin, blonde hair in soft ponytail, brown lively eyes wide with alertness, black cat-eye glasses, white shirt and tight jeans — ducks sideways to dodge the flying spoon, one arm reaching instinctively toward the stove. MALLOW — tall Italian man, capelli con mini-mohawk, polo azzurra, jeans dritti, sneakers gialle alte — sits at the wooden table foreground right, laptop open, headphones on, completely oblivious, staring at his screen. Steam haze from the boiling pot. Comedic energy, slightly chaotic. Warm amber light with hint of steam diffusion.
```

### 🚫 NEGATIVE PROMPT
```
realistic photo, 3D render, anime, manga, chibi, watercolor, oil painting, speech bubbles, text, letters, watermark, signature, blurry, low quality, extra limbs, deformed hands, ugly faces, toddler, walking child, standing baby, calm kitchen, tidy kitchen, modern kitchen
```

---

## 🖼️ SCENA 3 — Il momento critico: Lex si sporge

**File:** `page_3.png`
**Personaggi attivi:** Favilla, Lex
**Tono:** Tensione, urgenza, paura

### Personaggi da caricare nel workflow
- ✅ Favilla (strength 0.30)
- ❌ Favilla Blaze
- ✅ Lex (strength 0.30)
- ❌ Mallow

### ✏️ PROMPT

```
digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, warm Italian atmosphere, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail backgrounds.

ENV KITCHEN: small cozy Italian apartment kitchen, colorful ceramic tiled floor in terracotta and white, wooden table center frame, small gas stovetop, cluttered countertops with Italian pantry items, single window with thin curtains, warm amber and cream walls.

SCENE: Dramatic split-moment, maximum tension. The kitchen is in simultaneous crisis. THREE things happen at once: (1) Pasta pot boiling over violently on the gas stovetop background left, white steam erupting, water spilling onto the flame. (2) A smartphone on the wooden table background right, screen lit up with an incoming call, vibrating. (3) LEX — tiny baby boy ONLY 7 months old, very chubby rounded baby face, rosy olive skin, light brown baby fuzz hair with mini-cresta, wearing tiny red sneakers — is leaning DANGEROUSLY far forward over the edge of the wooden highchair in center foreground, his tiny chubby arms reaching out, body tilted past the point of no return, about to fall. His baby face shows innocent curiosity — he doesn't understand the danger. FAVILLA — Italian woman mid-30s, olive skin, blonde hair in soft ponytail, brown eyes WIDE with pure terror, black cat-eye glasses, white shirt — stands frozen mid-motion, body rigid with panic, arms half-raised but too far away to catch him. Slightly tilted Dutch angle composition to increase unease. Deep warm reds and ambers with harsh shadows. Cinematic, tense, urgent, the longest split-second of a mother's life.
```

### 🚫 NEGATIVE PROMPT
```
realistic photo, 3D render, anime, manga, chibi, watercolor, oil painting, speech bubbles, text, letters, watermark, signature, blurry, low quality, extra limbs, deformed hands, ugly faces, toddler, walking child, standing baby, calm scene, baby safely seated
```

---

## 🖼️ SCENA 4 — La trasformazione: Favilla Blaze

**File:** `page_4.png`
**Personaggi attivi:** Favilla Blaze, Lex, Mallow (background)
**Tono:** Meraviglia, magia, intimità, segreto
**Riusata per:** branch_segreto, branch_legame, epilogo

### Personaggi da caricare nel workflow
- ❌ Favilla
- ✅ Favilla Blaze (strength 0.30)
- ✅ Lex (strength 0.30)
- ✅ Mallow (strength 0.20 — solo sfondo)

### ✏️ PROMPT

```
digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, warm Italian atmosphere, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail backgrounds.

ENV KITCHEN: small cozy Italian apartment kitchen, colorful ceramic tiled floor in terracotta and white, wooden table center frame, small gas stovetop, cluttered countertops with Italian pantry items, single window with thin curtains, warm amber and cream walls. The kitchen is now strangely calm and orderly — no pasta boiling over, no chaos, everything in its place.

SCENE: Magical moment, the birth of a secret. FAVILLA BLAZE — same Italian woman mid-30s, warm olive skin, but her black cat-eye glasses are GONE, her blonde hair is now LOOSE and flowing, radiating warm golden amber light from within each strand, her posture is confident and tall, athletic build. Soft golden light emanates from her hands and eyes — not like fire, but like warm sunlight made liquid. She wears the SAME everyday clothes as before (white shirt, tight jeans, black-and-white sneakers) — NO superhero costume, NO cape, NO suit — just her normal outfit illuminated from within by warm golden energy. She stands protectively near the wooden highchair, one glowing hand gently resting near LEX. LEX — tiny baby boy ONLY 7 months old, chubby rounded baby face, rosy olive skin, light brown baby fuzz hair with mini-cresta, two tiny bottom teeth fully visible, tiny red sneakers — is completely safe in the highchair, staring at her with enormous wide eyes full of wonder, then his face breaks into a full open-mouthed baby laugh of pure joy, the only person in the world who sees what just happened. Background: MALLOW — tall Italian man, mini-mohawk hair, polo azzurra — is visible through a doorway or in the far background, still on his laptop, completely unaware, facing away. High saturation warm gold on Favilla Blaze, desaturated and slightly darker surroundings. Awe, warmth, intimacy. A secret being born between a mother and her baby.
```

### 🚫 NEGATIVE PROMPT
```
realistic photo, 3D render, anime, manga, chibi, watercolor, oil painting, speech bubbles, text, letters, watermark, signature, blurry, low quality, extra limbs, deformed hands, ugly faces, superhero costume, cape, suit, mask, armor, fire, flames, explosion, aggressive, angry, scary, horror, toddler, standing baby, walking child
```

---

## 🖼️ SCENA CARMELA — La finestra buia

**File:** `page_carmela.png`
**Personaggi attivi:** Carmela (solo occhi visibili)
**Tono:** Mistero, minaccia silenziosa, presagio

### Personaggi da caricare nel workflow
- ❌ Favilla
- ❌ Favilla Blaze
- ❌ Lex
- ❌ Mallow
- ⚠️ Carmela non ha IP-Adapter nel workflow — genera con solo prompt testuale

### ✏️ PROMPT

```
digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, dark atmospheric Italian night, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail backgrounds.

SCENE: Night view from across a narrow Italian street. An old apartment building window on the second floor, seen from outside, from the perspective of someone looking up from the street below. The window is completely dark — no light inside, curtains slightly parted. The surrounding building wall is textured aged plaster in warm ochre tones typical of Italian provincial towns. Other windows in the building are dimly lit or dark. The street below is empty, a single orange streetlamp casting long shadows. In the dark window, barely visible at first: two eyes snap open. CARMELA's eyes — an elderly woman's eyes, sharp, ancient, knowing, intense — gleam in the absolute darkness of the room, catching a faint reflection from the streetlamp. The eyes are the focal point: they are STILL, AWAKE, watching. Something has caught her attention from across the street. The rest of her face is lost in shadow. Ominous, quiet, the calm before the storm.
```

### 🚫 NEGATIVE PROMPT
```
realistic photo, 3D render, anime, manga, chibi, watercolor, oil painting, speech bubbles, text, letters, watermark, signature, blurry, low quality, extra limbs, deformed hands, ugly faces, full face visible, bright window, lit room, daytime, daylight, vampire, monster, glowing eyes supernatural
```
