#!/usr/bin/env python3
"""
generate_prompts.py — Favilla Blaze per Leonardo.ai
=====================================================
Genera prompt ottimizzati per Leonardo.ai da ogni episodio JSON.
Output: assets/data/illustration_prompts.md

Leonardo.ai settings:
  Model: Leonardo Lightning XL o Phoenix
  Style preset: Illustration / Cinematic
  Resolution: 1216x832 (landscape comic panel)
  Steps: 20-25 (Lightning optimized)
  Guidance Scale: 7.0
  Format: PNG / WEBP
"""

import json, os, re
from pathlib import Path

os.chdir(Path(__file__).parent.parent)

# ─── Leonardo.ai style ───
STYLE = "Italian comic book illustration style, expressive line art, warm Mediterranean color palette, cinematic framing, Studio Ghibli meets European graphic novel, detailed backgrounds, emotional character expressions, soft natural lighting, 2D digital art, vibrant but grounded colors"

NEGATIVE = "photorealistic, 3D render, anime, manga, chibi, deformed, blurry, text, watermark, signature, extra limbs, distorted face, ugly, low quality, oversaturated, plastic-looking"


# ─── Character descriptions ───
CHAR_DESC = {
    "favilla": "Favilla, a blonde Italian woman in her early 30s, cat-eye black glasses, expressive hazel eyes, athletic build, white blouse, tight jeans, black-and-white sneakers, warm but tired smile, blonde hair tied back loosely",
    "favilla_blaze": "Favilla Blaze, blonde Italian superhero form, same white blouse and jeans, but her hair has transformed into floating luminous golden fire, glasses vanished, eyes glowing bright amber, golden energy crackling around her hands, sparks and embers floating upward, warm radiant aura",
    "lex": "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, wearing a soft onesie and miniature red sneakers",
    "mallow": "Mallow, an Italian man in his early 30s, light blue polo shirt or faded white hard-rock Osaka t-shirt, straight jeans, yellow high-top sneakers, short mini-mohawk haircut, gentle easygoing expression, warm brown eyes",
    "corvi": "Dr. Livia Corvi, a cold Italian school inspector in her 50s, severe expression, tailored dark blazer and pencil skirt, high heels, leather briefcase, hair pulled back tightly, intimidating bureaucratic presence",
    "collega": "A female colleague at the school, in her 40s, kind but worried expression, casual professional attire, cardigan over blouse",
    "carmela": "Signora Carmela, an elderly Italian woman, white hair under a wide straw hat, too-alert knowing eyes, floral dress, blue shopping trolley, unsettling mysterious smile, always watching",
    "bambini": "A chaotic group of Italian elementary school children, ages 6-10, colorful school uniforms, messy hair, backpacks, running laughing arguing, pure childhood energy",
    "gatto": "Filippo, a sleek black cat with piercing yellow-green eyes, luminous in dim light, smooth fur, curled tail, silent graceful movements, always watching with unsettling intelligence",
    "ladro": "A thief in a dark hoodie, hood pulled low, fast-moving anonymous figure, caught mid-stride, menacing presence",
}

# ─── Location descriptions ───
LOC_DESC = {
    "casa": "A warm cozy Italian apartment kitchen and living room, Via delle Vesciche e dei Brufoli 18, terrazzo floors, high ceilings, baby toys scattered, laptop on wooden table, pasta on stove, soft afternoon light through windows, lived-in family warmth",
    "scuola": "An Italian elementary school in Nova Tutinia, colorful hallways with children's drawings on walls, tall windows with morning light, gymnasium with metal shelves and polished floors, chalk dust in the air, institutional but lively",
    "scuola_bagno": "A cramped school bathroom, institutional pale green tiles, flickering fluorescent lights, broken pipe gushing water across the floor, cold damp air, claustrophobic threatening atmosphere",
    "supermercato": "IperPassata supermarket in Nova Tutinia, Saturday morning crowds, bright neon lights, endless aisles of colorful products, shopping carts, the pasta aisle stacked high, cool air-conditioned air",
    "parco": "Giardini Pubblici park in Nova Tutinia, Sunday morning, ancient trees with dappled light, playground with swings and slide, green benches, pigeons near a fountain, peaceful urban park atmosphere",
    "parco_boschetto": "A dense wooded grove inside the park, tall trees blocking sunlight, cathedral-like dimness, fallen leaves on winding paths, isolated golden sunbeams through the canopy, mysterious urban wilderness",
    "mare": "A sunny Italian beach near Nova Tutinia, colorful striped umbrellas on golden sand, sparkling blue Mediterranean sea, thatched beach bar, children playing in the shallows, relaxed summer vacation mood",
    "mare_tramonto": "The same beach at golden sunset, orange and pink sky reflecting on calm sea, long shadows on sand, warm romantic light, silhouettes of umbrellas and distant figures",
    "centro_commerciale": "GalaxiaMall shopping center, Sunday afternoon, polished stone floors, geometric LED ceiling lights, modern sleek architecture, Bimbi & Fantasia toy store, shoppers and families moving through",
    "centro_commerciale_parcheggio": "The GalaxiaMall parking lot, harsh afternoon sun on hot concrete, rows of parked cars, heat shimmering above the asphalt, shopping bags, mundane liminal space",
    "asilo": "Asilo Comunale daycare in Nova Tutinia, colorful courtyard with plastic slides, low tables and tiny chairs inside, a teacher in apron, morning drop-off mixed with cheerful chaos and separation anxiety",
    "palestra": "Palestra Comunale gym in the afternoon, rubber mat flooring, buzzing fluorescent lights, mirrors on walls, weight rack in the corner, almost empty, the smell of disinfectant and solitary effort",
}

# ─── Mood → visual description ───
MOOD_DESC = {
    "tense": "tense atmosphere, dramatic side lighting with deep shadows, cool blue-gray tones, heart racing moment, the calm before something breaks, shallow depth of field",
    "warm": "warm intimate atmosphere, soft golden sunlight, family love and peace, gentle ambient glow, cozy domestic warmth, Mediterranean golden hour feeling",
    "sad": "melancholic atmosphere, quiet sadness and emotional weight, soft muted cool colors, diffused flat light, a moment of stillness and introspection",
    "power": "explosive supernatural energy, golden light radiating from within, dynamic action, hovering sparks and embers, awe-inspiring transformation, fire and light against darkness",
    "neutral": "natural everyday slice-of-life atmosphere, soft balanced lighting, ordinary family moment, the beauty of the banal, documentary warmth",
}

ACTION_HINTS = {
    "tense": "suspense hangs in the air, every muscle tense, the moment before everything changes",
    "warm": "love radiates through simple gestures, a gentle touch, a shared smile, peace found in small moments",
    "sad": "exhaustion weighs heavy, the mask slips in solitude, quiet tears or hollow stillness",
    "power": "an explosion of light and energy, transformation mid-burst, sparks flying, reality bending around the sudden power",
    "neutral": "an ordinary moment unfolds, nothing special happening and that is exactly the point",
}


# ─── Mood → expression hint ───
EXPRESSION_HINTS = {
    ("favilla", "tense"): ", jaw clenched, eyes wide with forced calm, a thin sweat on her brow",
    ("favilla", "warm"): ", a genuine tired smile crinkling her eyes, warmth cutting through exhaustion",
    ("favilla", "sad"): ", hollow eyes staring at nothing, dark circles, the weight of the secret visible",
    ("favilla", "power"): ", mouth open in shock, eyes reflecting golden light, wonder and fear mixed",
    ("favilla", "neutral"): ", a polite professional mask hiding deep weariness",

    ("favilla_blaze", "power"): ", eyes blazing golden, expression of surprised discovery, hair a corona of flames",
    ("favilla_blaze", "tense"): ", intense focused gaze, barely containing the energy crackling around her",
    ("favilla_blaze", "warm"): ", a soft protective smile despite the flames, warm gentle eyes",

    ("lex", "tense"): ", wide watchful eyes, a serious knowing look on his tiny face",
    ("lex", "warm"): ", whole face lit in a gummy two-toothed grin, eyes squeezed in joy",
    ("lex", "power"): ", eyes wide with wonder, mouth forming a little O of amazement",
    ("lex", "neutral"): ", curious head-tilt, big hazel eyes taking in everything",

    ("mallow", "tense"): ", a slight concerned frown, studying something with worried eyes",
    ("mallow", "warm"): ", an easy loving smile, relaxed and content in the moment",
    ("mallow", "neutral"): ", relaxed easygoing expression, comfortable at home",

    ("carmela", "tense"): ", a knowing unsettling smile, eyes too bright, looking right through you",
    ("carmela", "neutral"): ", a pleasant hollow smile that never reaches her too-alert eyes",

    ("corvi", "tense"): ", cold unreadable mask, thin lips tight, narrow eyes of suspicion",
    ("corvi", "neutral"): ", professional blankness, face betraying nothing",

    ("gatto", "tense"): ", yellow-green eyes fixed, ears slightly back, unnaturally still",
    ("gatto", "neutral"): ", half-lidded luminous eyes, only the tip of the tail moving",
}


# ─── Extract scenes ───
def extract_scenes():
    scenes = []
    quest_dir = Path("assets/data/quests")

    ep_files = [
        "prologo.json",
        "s1/s1_mattina_dopo.json",
        "s1/s1_scuola_1.json",
        "s1/s1_ritorno_casa.json",
        "s1/s1_spesa_sabato.json",
        "s1/s1_domenica_parco.json",
        "s1/s1_mare.json",
        "s1/s1_centro_commerciale.json",
        "s1/s1_lunedi_asilo.json",
        "s1/s1_palestra.json",
        "s1/s1_allagamento.json",
        "s1/s1_prima_conseguenza.json",
        "s1/s1_comare.json",
        "s1/s1_cena_famiglia.json",
        "s1/s1_crepa.json",
        "s1/s1_disegno_lex.json",
    ]

    for ep_rel in ep_files:
        ep_path = quest_dir / ep_rel
        if not ep_path.exists():
            continue

        with open(ep_path) as f:
            data = json.load(f)

        ep_id = data["id"]

        def scan_pages(pages, section_name):
            for page in pages:
                bg = page.get("background", "")
                if not bg:
                    continue

                panels = page.get("panels", [])
                chars = set()
                all_text = []
                mood = "neutral"
                narration_text = ""
                thought_text = ""

                for p in panels:
                    for c in p.get("characters", []):
                        chars.add(c)
                    for tb in p.get("text_blocks", []):
                        all_text.append(tb["text"])
                        if tb.get("type") == "narration" and not narration_text:
                            narration_text = tb["text"]
                        if tb.get("type") == "thought" and not thought_text:
                            thought_text = tb["text"]

                        if tb.get("type") in ("narration", "thought") and mood == "neutral":
                            t = tb["text"].lower()
                            if any(w in t for w in ["tremo", "paura", "scappa", "pericolo", "ansia", "non ce la", "crolla", "silenzio", "buio", "teso"]):
                                mood = "tense"
                            elif any(w in t for w in ["ride", "sorride", "ridono", "divertente", "caldo", "bene", "pace", "normale", "quasi felice"]):
                                mood = "warm"
                            elif any(w in t for w in ["triste", "piange", "ferito", "sofferen"]):
                                mood = "sad"
                            elif any(w in t for w in ["trasformazione", "lampo", "veloc", "forza", "esplode", "fuoco", "brilla"]):
                                mood = "power"

                bg_lower = bg.lower()
                context = narration_text or thought_text or (all_text[0] if all_text else "")
                context_lower = context.lower()[:300]

                location = determine_location(bg_lower, context_lower)

                scenes.append({
                    "ep_id": ep_id,
                    "bg_path": bg,
                    "section": section_name,
                    "page_idx": page.get("index", 0),
                    "characters": sorted(chars),
                    "context": context[:200],
                    "mood": mood,
                    "location": location,
                    "narration": narration_text[:300] if narration_text else "",
                })

        scan_pages(data.get("pages", []), "main")
        for bname, bdata in data.get("branches", {}).items():
            scan_pages(bdata.get("pages", []), f"branch:{bname}")
        epilogue = data.get("epilogue", {})
        scan_pages(epilogue.get("pages", []), "epilogue")

    return scenes


def determine_location(bg_lower, context_lower=""):
    combined = f"{bg_lower} {context_lower}"
    if "bagno" in bg_lower and "allagamento" in bg_lower: return "scuola_bagno"
    if "allagamento" in bg_lower: return "scuola_bagno"
    if "scuola" in bg_lower: return "scuola"
    if "mare" in bg_lower: return "mare"
    if "tramonto" in bg_lower: return "mare_tramonto"
    if "centro_commerciale" in bg_lower: return "centro_commerciale"
    if "parcheggio" in bg_lower: return "centro_commerciale_parcheggio"
    if "boschetto" in bg_lower or "trasformazione" in bg_lower: return "parco_boschetto"
    if "domenica" in bg_lower or "parco" in bg_lower: return "parco"
    if "spesa" in bg_lower or "supermercato" in bg_lower: return "supermercato"
    if "palestra" in bg_lower: return "palestra"
    if "asilo" in bg_lower: return "asilo"

    # Context fallback
    if "scuola elementare" in context_lower: return "scuola"
    if "supermercato" in context_lower or "iperpassata" in context_lower: return "supermercato"
    if "mare" in context_lower or "spiaggia" in context_lower or "ombrellone" in context_lower: return "mare"
    if "tramonto" in context_lower: return "mare_tramonto"
    if "giardini" in context_lower or "altalena" in context_lower: return "parco"
    if "boschetto" in context_lower: return "parco_boschetto"
    if "galaxiamall" in context_lower or "centro commerciale" in context_lower: return "centro_commerciale"
    if "asilo" in context_lower: return "asilo"
    if "palestra" in context_lower: return "palestra"
    if "scuola" in context_lower and ("corvi" in context_lower or "ispezione" in context_lower): return "scuola"
    return "casa"


# ─── Generate prompt ───
def generate_prompt(scene):
    chars = scene["characters"]
    location = scene["location"]
    mood = scene["mood"]
    context = scene.get("context", "")[:200]

    has_blaze = "favilla_blaze" in chars

    # Character descriptions with expressions
    char_parts = []
    for c in chars:
        base = CHAR_DESC.get(c, "")
        if not base:
            continue
        # Add expression
        expr = EXPRESSION_HINTS.get((c, mood), "")
        # Add pose hint
        pose = ""
        if c == "favilla" and not has_blaze:
            if "lex" in chars:
                pose = ", holding her baby Lex on one hip, supporting him with her arm"
            elif mood == "sad":
                pose = ", sitting slumped, head in her hands or staring into space"
            elif mood == "tense":
                pose = ", standing alert, body tense and ready"
            else:
                pose = ", standing with a slight slump of exhaustion, weight shifting from one foot to the other"
        elif c == "favilla_blaze":
            pose = ", standing with arms slightly raised, golden energy crackling between her fingers, hair floating upward like fire"
        elif c == "lex":
            if "favilla" in chars or "favilla_blaze" in chars:
                pose = ", reaching toward her with both hands, determined baby focus"
            elif "mallow" in chars:
                pose = ", sitting on his lap or in his highchair, looking around with curiosity"
            else:
                pose = ", sitting up and reaching for something with determined baby energy"
        elif c == "mallow":
            if "lex" in chars:
                pose = ", watching Lex with a loving expression, relaxed at home"
            elif "favilla" in chars:
                pose = ", looking at her with gentle concern and warmth"
            else:
                pose = ", relaxed and easygoing, comfortable in his space"
        elif c == "carmela":
            pose = ", standing still at the edge of the frame, hands on her blue trolley, head slightly tilted"
        elif c == "corvi":
            pose = ", standing ramrod straight, briefcase held in front of her like a shield"
        elif c == "gatto":
            pose = ", sitting with tail curled around paws, watching with luminous unblinking eyes"
        elif c == "bambini":
            pose = ", running in all directions, arms waving, pure chaotic energy"

        full = f"{base}{expr}{pose}"
        char_parts.append(full)

    char_str = ". ".join(char_parts)

    # Location
    loc_str = LOC_DESC.get(location, LOC_DESC["casa"])

    # Mood
    mood_str = MOOD_DESC.get(mood, MOOD_DESC["neutral"])

    # Action
    action = context[:150].replace('"', "'").replace("'", "") if context else "a quiet everyday moment"
    action_hint = ACTION_HINTS.get(mood, "")

    # Key visual focus
    focus = ""
    if has_blaze:
        focus = "The scene is illuminated by Favilla's golden glow. Her fire-light spills across the room, casting long dramatic shadows. Sparks and embers float in the air around her."
    elif mood == "tense":
        focus = "Deep shadows and tense composition. Something is about to happen — the air itself feels charged."
    elif mood == "warm":
        focus = "Golden light bathes the scene like a warm embrace. Every shadow is soft, every edge gentle."
    elif mood == "sad":
        focus = "Muted colors and soft diffused light. The image breathes stillness and quiet melancholy."

    # Build final prompt
    prompt = f"{char_str}. Setting: {loc_str}. Action: {action} — {action_hint}. Mood: {mood_str}. {focus} Style: {STYLE}"

    # Truncate if too long for Leonardo
    if len(prompt) > 1800:
        prompt = prompt[:1800]

    return prompt


# ══════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════

scenes = extract_scenes()
print(f"Estratte {len(scenes)} scene da 16 episodi")

# Deduplicate by (bg_path, episode_id) — keep same background in different episodes
seen_bgs = set()
unique_scenes = []
for s in scenes:
    key = (s["bg_path"], s["ep_id"])
    if key not in seen_bgs:
        seen_bgs.add(key)
        unique_scenes.append(s)

print(f"Scene uniche: {len(unique_scenes)}")

# Generate output
out = []
out.append("# 🎨 FavillApp — Illustration Prompts per Leonardo.ai")
out.append(f"*{len(unique_scenes)} scene uniche da 16 episodi — prompt ottimizzati per Leonardo.ai*")
out.append("")
out.append("---")
out.append("")

# ── Config section ──
out.append("## ⚙️ Guida all'uso su Leonardo.ai")
out.append("")
out.append("### 1️⃣ Vai su [leonardo.ai](https://leonardo.ai) e fai login")
out.append("")
out.append("### 2️⃣ Clicca **\"Image Generation\"** → **\"Text to Image\"**")
out.append("")
out.append("### 3️⃣ Imposta questi parametri:")
out.append("")
out.append("| Impostazione | Valore |")
out.append("|---|---|")
out.append("| **Model** | Leonardo Lightning XL o Phoenix |")
out.append("| **Style Preset** | Illustration |")
out.append("| **Resolution** | 1216×832 (landscape, 16:9) |")
out.append("| **Steps** | 20-25 |")
out.append("| **Guidance Scale** | 7.0 |")
out.append("| **PhotoReal** | Disabilitato (vogliamo illustrazione) |")
out.append("| **Alchemy** | Disabilitato |")
out.append("| **Format** | PNG (o WEBP per risparmiare spazio) |")
out.append("")
out.append("### 4️⃣ Copia il prompt qui sotto e incollalo nel box \"Prompt\"")
out.append("")
out.append("### 5️⃣ Nel box \"Negative Prompt\" incolla:")
out.append("```")
out.append(NEGATIVE)
out.append("```")
out.append("")
out.append("### 6️⃣ Clicca **Generate**")
out.append("")
out.append("### 💰 Costo indicativo")
out.append("- Leonardo Lightning XL: ~1 credito per immagine (1216×832)")
out.append("- Piano gratuito: 150 crediti/giorno")
out.append("- Piano Essential ($12/mese): 1500 crediti/giorno")
out.append("- Con 91 scene: **~91 crediti totali** (un giorno di free tier)")
out.append("")
out.append("### 🎯 Consigli per la consistenza")
out.append("1. **Reference sheet**: genera prima un ritratto di Favilla da usare come Image Guidance")
out.append("2. **Stesso seed**: usa lo stesso seed per tutte le scene di uno stesso episodio")
out.append("3. **Episodio per episodio**: genera tutte le scene di un episodio nella stessa sessione")
out.append("4. **Semi casuali consigliati**: vedi sotto per ogni episodio")
out.append("")
out.append("---")
out.append("")

# Seeds consigliati
out.append("## Seeds consigliati per episodio")
out.append("")
out.append("| Episodio | Seed | | Episodio | Seed |")
out.append("|---|---|---|---|")
out.append("| 🎬 Prologo | 42 | 📖 EP6alt | 650 |")
out.append("| 📖 EP1 | 100 | 📖 EP7 | 700 |")
out.append("| 📖 EP2 | 200 | 📖 EP7.5 | 750 |")
out.append("| 📖 EP3 | 300 | 📖 EP8 | 800 |")
out.append("| 📖 EP4 | 400 | 📖 EP9a | 900 |")
out.append("| 📖 EP5 | 500 | 📖 EP9b | 920 |")
out.append("| 📖 EP6 | 600 | 📖 EP9c | 940 |")
out.append("| — | — | 💔 Crepa | 960 |")
out.append("| — | — | 🎨 Disegno | 980 |")
out.append("")
out.append("---")
out.append("")

# Episodes
EPISODES = [
    ("prologo", "🎬 Prologo — Una Mattina Qualunque", 42),
    ("s1_mattina_dopo", "📖 EP1 — La Mattina Dopo", 100),
    ("s1_scuola_1", "📖 EP2 — Una Giornata Normale", 200),
    ("s1_ritorno_casa", "📖 EP3 — Il Ritorno a Casa", 300),
    ("s1_spesa_sabato", "📖 EP4 — La Spesa del Sabato", 400),
    ("s1_domenica_parco", "📖 EP5 — La Domenica al Parco", 500),
    ("s1_mare", "📖 EP6 — Un Giorno al Mare", 600),
    ("s1_centro_commerciale", "📖 EP6alt — GalaxiaMall", 650),
    ("s1_lunedi_asilo", "📖 EP7 — Il Lunedì dell'Asilo", 700),
    ("s1_palestra", "📖 EP7.5 — La Palestra", 750),
    ("s1_allagamento", "📖 EP8 — L'Allagamento", 800),
    ("s1_prima_conseguenza", "📖 EP9a — La Prima Conseguenza", 900),
    ("s1_comare", "📖 EP9b — La Comare", 920),
    ("s1_cena_famiglia", "📖 EP9c — Cena di Famiglia", 940),
    ("s1_crepa", "💔 La Crepa", 960),
    ("s1_disegno_lex", "🎨 Il Disegno di Lex", 980),
]

for ep_id, ep_title, ep_seed in EPISODES:
    ep_scenes = [s for s in unique_scenes if s["ep_id"] == ep_id]
    if not ep_scenes:
        continue

    out.append(f"## {ep_title}")
    out.append(f"**Seed:** {ep_seed}")
    out.append("")

    for i, scene in enumerate(ep_scenes):
        prompt = generate_prompt(scene)
        bg = scene["bg_path"]
        chars_str = ", ".join(scene["characters"])
        mood_emoji = {"tense": "🔴", "warm": "🟡", "sad": "🔵", "power": "⚡", "neutral": "⚪"}
        emoji = mood_emoji.get(scene["mood"], "⚪")

        out.append(f"### {emoji} Page {scene['page_idx']} — `{bg.split('/')[-1]}`")
        out.append(f"**Characters:** {chars_str} | **Mood:** {scene['mood']}")
        out.append("")
        out.append("**Prompt:**")
        out.append("```")
        out.append(prompt)
        out.append("```")
        out.append("")
        out.append("**Negative:** `photorealistic, 3D render, anime, manga...`")
        out.append("")
        out.append("---")
        out.append("")

# Write
path = "assets/data/illustration_prompts.md"
with open(path, "w") as f:
    f.write("\n".join(out))

print(f"\n✅ Scritti {len(unique_scenes)} prompt in {path}")
print(f"   Piattaforma: Leonardo.ai")
print(f"   Costo stimato: ~{len(unique_scenes)} crediti (Lightning XL)")
