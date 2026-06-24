#!/usr/bin/env python3
"""
generate_prompts.py — Favilla Blaze
=====================================
Estrae da ogni episodio JSON il contesto (personaggi, location, azione, umore)
e genera prompt ottimizzati per Leonardo.ai.

Output: assets/data/illustration_prompts.md (già esistente, sovrascritto con versione completa)
"""

import json, os, re
from pathlib import Path
from collections import defaultdict

os.chdir(Path(__file__).parent.parent)

# ─── Character descriptions (per Leonardo.ai consistency) ───
CHAR_DESC = {
    "favilla": "Favilla, blonde Italian woman, cat-eye black glasses, expressive face, athletic build, white blouse, tight jeans, black-and-white sneakers, warm smile, tired but determined",
    "favilla_blaze": "Favilla Blaze, blonde Italian superhero, floating glowing luminous hair like fire, no costume yet — same white blouse and jeans but radiating golden light, eyes glowing amber, powerful aura, energy crackling around her hands",
    "lex": "Lex, 7-month-old baby boy, light brown spiky hair with tiny mohawk like dad, big expressive eyes, tiny red sneakers, curious mischievous smile, two bottom teeth",
    "lex_pov": "Lex POV, view from a baby's perspective looking up, world seen through wide curious eyes, adults towering above, hands reaching for objects",
    "mallow": "Mallow, Italian man, light blue polo shirt or white hard-rock Osaka t-shirt, straight jeans, yellow high-top sneakers, mini-mohawk haircut, gentle easygoing expression, laptop nearby",
    "corvi": "Dr.ssa Livia Corvi, cold Italian school inspector, high heels, leather briefcase, severe expression, formal bureaucratic attire, intimidating professional aura",
    "collega": "Female colleague, school staff, casual work attire, friendly but observant expression",
    "carmela": "Signora Carmela, elderly Italian woman, white hair, straw hat, too-alert eyes that miss nothing, blue trolley, mysterious unsettling smile, always watching from across the street",
    "bambini": "group of young Italian elementary school children, chaotic playful energy, school uniforms",
    "bimbo_1": "young schoolboy, messy hair, holding eraser, arguing expression",
    "bimbo_2": "young schoolboy, arms crossed, claiming ownership expression",
    "siri": "Siri-like system voice, represented as subtle UI glow or abstract notification",
    "gatto": "Filippo, black cat with piercing yellow eyes, sleek fur, tail curled with knowing attitude, spies on everything, moves silently through Nova Tutinia",
    "ladro": "thief, dark hoodie, hood pulled down, fast-moving figure, anonymous threatening presence",
}

# ─── Location descriptions ───
LOC_DESC = {
    "casa": "warm cozy Italian apartment kitchen and living room, Via delle Vesciche e dei Brufoli 18, third floor, soft afternoon light through windows, messy but loved family home with baby toys scattered, pasta cooking on stove, laptop on table",
    "scuola": "Italian elementary school in Nova Tutinia, colorful hallways with children's drawings on walls, gym with metal shelves, morning light through windows, institutional but lively atmosphere",
    "scuola_bagno": "school bathroom ground floor, cramped institutional tiles, water rising from broken pipe, fluorescent lights flickering, claustrophobic threatening atmosphere",
    "supermercato": "IperPassata supermarket in Nova Tutinia, Saturday morning, bright neon lights, pasta aisle with colorful packages stacked high, shopping carts, Italian products",
    "parco": "Giardini Pubblici park in Nova Tutinia, Sunday morning, green trees, playground with swings, benches, pigeons, wooded grove area with dense trees and dappled shade, Italian urban park",
    "parco_boschetto": "dense wooded grove inside Nova Tutinia park, trees blocking sunlight, fallen leaves, narrow paths, hiding spots, mysterious semi-darkness, urban forest feel",
    "mare": "Italian beach near Nova Tutinia, summer sunny day, colorful umbrellas, blue sea sparking, sandy shore, beach bar nearby, relaxed vacation atmosphere, children playing",
    "mare_tramonto": "same Italian beach at golden sunset, orange and pink sky reflecting on calm sea, silhouettes, romantic warm light, long shadows on sand",
    "centro_commerciale": "GalaxiaMall shopping center, Sunday afternoon, modern Italian mall, piano terra ground floor, LED ceiling lights, crowd of shoppers, Bimbi & Fantasia toy store, supermarket section",
    "centro_commerciale_parcheggio": "GalaxiaMall parking lot, harsh concrete, bright sun beating down, cars, shopping bags",
    "asilo": "Asilo Comunale daycare in Nova Tutinia, colorful toys in courtyard, professional but tired teacher, morning drop-off, new territory feeling",
    "palestra": "Palestra Comunale gym in Nova Tutinia, disinfectant smell implied, rubber mats, buzzing fluorescent lights, weight room almost empty, mirrors on walls, afternoon solitude",
}

# ─── Style keywords for Leonardo.ai ───
STYLE = "Italian comic book illustration style, expressive line art, warm Mediterranean color palette, cinematic framing, Studio Ghibli meets European graphic novel, detailed backgrounds, emotional character expressions, soft natural lighting, 2D digital art"

NEGATIVE = "photorealistic, 3D render, anime, manga, chibi, deformed, blurry, text, watermark, signature, extra limbs, distorted face, ugly, low quality"

# ─── Extract scenes ───
def extract_scenes():
    """Walk all episode JSONs and return list of scene dicts."""
    scenes = []
    quest_dir = Path("assets/data/quests")

    # Episodes in narrative order
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
        ep_num = ep_files.index(ep_rel)

        def scan_pages(pages, section_name):
            for page in pages:
                bg = page.get("background", "")
                if not bg:
                    continue

                panels = page.get("panels", [])
                chars = set()
                types_seen = set()
                all_text = []
                mood = "neutral"

                for p in panels:
                    for c in p.get("characters", []):
                        chars.add(c)
                    for tb in p.get("text_blocks", []):
                        types_seen.add(tb.get("type"))
                        all_text.append(tb["text"])
                        # Detect mood from first narration/thought
                        if tb.get("type") in ("narration", "thought") and mood == "neutral":
                            t = tb["text"].lower()
                            if any(w in t for w in ["tremo", "paura", "scappa", "pericolo", "ansia", "no. no", "non ce la", "crolla", "troppo", "silenzio", "buio", "teso"]):
                                mood = "tense"
                            elif any(w in t for w in ["ride", "sorride", "ridono", "divertente", "caldo", "bene", "pace", "normale", "quasi felice"]):
                                mood = "warm"
                            elif any(w in t for w in ["triste", "piange", "ferito", "sofferen"]):
                                mood = "sad"
                            elif any(w in t for w in ["trasformazione", "lampo", "veloc", "forza", "esplode", "fuoco", "brilla"]):
                                mood = "power"

                # Determine location from context + background path
                bg_lower = bg.lower()
                context_lower = context.lower()

                # Detect from context keywords first
                if any(w in context_lower for w in ["scuola elementare", "scuola", "7:55", "ispezione", "corvi"]):
                    if "allagamento" in bg_lower or "bagno" in bg_lower:
                        location = "scuola_bagno"
                    else:
                        location = "scuola"
                elif "supermercato" in bg_lower or "spesa" in bg_lower or "iperpassata" in context_lower:
                    location = "supermercato"
                elif "spesa" in bg_lower or "supermercato" in bg_lower:
                    location = "supermercato"
                elif "domenica" in bg_lower or "parco" in bg_lower:
                    if "boschetto" in bg_lower or "trasformazione" in bg_lower or "branch_presa" in bg_lower or "branch_quasi" in bg_lower:
                        location = "parco_boschetto"
                    else:
                        location = "parco"
                elif "mare" in bg_lower:
                    if "tramonto" in bg_lower or "epilogue" in bg_lower:
                        location = "mare_tramonto"
                    else:
                        location = "mare"
                elif "centro_commerciale" in bg_lower:
                    if "parcheggio" in bg_lower or "gatto" in bg_lower:
                        location = "centro_commerciale_parcheggio"
                    else:
                        location = "centro_commerciale"
                elif "asilo" in bg_lower or "lunedi_asilo" in bg_lower:
                    location = "asilo"
                elif "palestra" in bg_lower:
                    location = "palestra"
                elif "mattina_dopo" in bg_lower or "ritorno_casa" in bg_lower or "cena" in bg_lower or "crepa" in bg_lower or "disegno" in bg_lower or "comare" in bg_lower or "prima_conseguenza" in bg_lower:
                    location = "casa"

                # Build context
                first_narration = ""
                first_thought = ""
                for t in all_text:
                    if "type" in str(type):
                        pass
                for p in panels:
                    for tb in p.get("text_blocks", []):
                        if tb.get("type") == "narration" and not first_narration:
                            first_narration = tb["text"]
                        if tb.get("type") == "thought" and not first_thought:
                            first_thought = tb["text"]

                context = first_narration or first_thought or all_text[0] if all_text else ""

                has_choice = "choice" in page
                page_idx = page.get("index", 0)

                scenes.append({
                    "ep_id": ep_id,
                    "ep_num": ep_num,
                    "bg_path": bg,
                    "section": section_name,
                    "page_idx": page_idx,
                    "characters": sorted(chars),
                    "context": context[:200],
                    "mood": mood,
                    "location": location,
                    "has_choice": has_choice,
                })

        # Main pages
        scan_pages(data.get("pages", []), "main")

        # Branch pages
        for bname, bdata in data.get("branches", {}).items():
            scan_pages(bdata.get("pages", []), f"branch:{bname}")

        # Epilogue pages
        epilogue = data.get("epilogue", {})
        scan_pages(epilogue.get("pages", []), "epilogue")

    return scenes

# ─── Generate prompt ───
def generate_prompt(scene):
    chars = scene["characters"]
    location = scene["location"]
    mood = scene["mood"]
    context = scene["context"]

    # Character description
    char_parts = []
    for c in chars:
        if c in CHAR_DESC:
            char_parts.append(CHAR_DESC[c])
    char_str = ". ".join(char_parts) if char_parts else "no specific characters"

    # Location description
    loc_str = LOC_DESC.get(location, "Italian apartment interior in Nova Tutinia")

    # Mood keywords
    mood_map = {
        "tense": "tense atmosphere, dramatic tension, shadows deepening, heart racing moment",
        "warm": "warm intimate atmosphere, soft golden light, family love, peaceful domestic bliss",
        "sad": "melancholic atmosphere, quiet sadness, emotional weight, soft muted colors",
        "power": "explosive energy, supernatural glow, hair blazing with golden light, dynamic action pose, sparks and embers floating, awe-inspiring moment",
        "neutral": "natural everyday atmosphere, slice of life, ordinary Italian family moment",
    }
    mood_str = mood_map.get(mood, mood_map["neutral"])

    # Action from context
    action = context[:150] if context else "quiet moment"
    # Clean action for prompt
    action = action.replace('"', '').replace("'", "")

    # Build final prompt
    prompt = f"{char_str}. Location: {loc_str}. Action: {action}. Mood: {mood_str}. Style: {STYLE}"

    # Truncate to reasonable length (Leonardo has token limits but handles long prompts well)
    if len(prompt) > 1500:
        prompt = prompt[:1500]

    return prompt

# ─── Main ───
scenes = extract_scenes()
print(f"Extracted {len(scenes)} scenes from 16 episodes\n")

# Deduplicate by bg_path (keep first occurrence's prompt)
seen_bgs = {}
unique_scenes = []
for s in scenes:
    bg = s["bg_path"]
    if bg not in seen_bgs:
        seen_bgs[bg] = s
        unique_scenes.append(s)

print(f"Unique backgrounds: {len(unique_scenes)}")

# Generate prompts
output_lines = []
output_lines.append("# 🎨 Favilla Blaze — Illustration Prompts for Leonardo.ai")
output_lines.append(f"*Auto-generated from {len(unique_scenes)} unique scenes across 16 episodes*")
output_lines.append("")
output_lines.append("## ⚙️ Leonardo.ai Configuration")
output_lines.append("")
output_lines.append("| Setting | Value |")
output_lines.append("|---|---|")
output_lines.append("| **Model** | Leonardo Lightning XL |")
output_lines.append("| **Style Preset** | Illustration / Cinematic |")
output_lines.append("| **Resolution** | 1216 x 832 (landscape comic panel) |")
output_lines.append("| **Steps** | 20-25 (Lightning optimized) |")
output_lines.append("| **Guidance Scale** | 7.0 |")
output_lines.append("| **Negative Prompts** | See below |")
output_lines.append("| **Format** | WEBP (lossless from PNG) |")
output_lines.append("")
output_lines.append("### Universal Negative Prompt")
output_lines.append(f"```\n{NEGATIVE}\n```")
output_lines.append("")
output_lines.append("### 💰 Cost Optimization Tips")
output_lines.append("- Use **Lightning XL** over standard models (~4x cheaper, faster)")
output_lines.append("- Generate **single image per prompt** (batch=1) — each panel has unique framing")
output_lines.append("- Resolution **1216x832** is the sweet spot for mobile comic panels")
output_lines.append("- **20 steps** is sufficient for Lightning models")
output_lines.append("- Reuse prompts for scenes with the same location/characters but different action")
output_lines.append("- Estimated cost: ~1 credit per image on Lightning XL (vs 4-8 on standard)")
output_lines.append("")
output_lines.append("### 🎯 Character Consistency Strategy")
output_lines.append("1. Generate **Favilla reference sheet** first: portrait, full body, expressions")
output_lines.append("2. Use Leonardo's **Image Guidance** with the reference for subsequent generations")
output_lines.append("3. Keep the **same seed** for scenes within the same episode")
output_lines.append("4. Generate all pages of one episode in the **same session** for style coherence")
output_lines.append("")
output_lines.append(f"---")
output_lines.append(f"**Total unique scenes:** {len(unique_scenes)}")
output_lines.append(f"**Estimated credits (Lightning XL):** ~{len(unique_scenes)} credits")
output_lines.append("")

# Group by episode
episodes_order = [
    ("prologo", "🎬 Prologo — Una Mattina Qualunque"),
    ("s1_mattina_dopo", "📖 EP1 — La Mattina Dopo"),
    ("s1_scuola_1", "📖 EP2 — Una Giornata Normale"),
    ("s1_ritorno_casa", "📖 EP3 — Il Ritorno a Casa"),
    ("s1_spesa_sabato", "📖 EP4 — La Spesa del Sabato"),
    ("s1_domenica_parco", "📖 EP5 — La Domenica al Parco"),
    ("s1_mare", "📖 EP6 — Un Giorno al Mare"),
    ("s1_centro_commerciale", "📖 EP6alt — GalaxiaMall"),
    ("s1_lunedi_asilo", "📖 EP7 — Il Lunedì dell'Asilo"),
    ("s1_palestra", "📖 EP7.5 — La Palestra"),
    ("s1_allagamento", "📖 EP8 — L'Allagamento"),
    ("s1_prima_conseguenza", "📖 EP9a — La Prima Conseguenza"),
    ("s1_comare", "📖 EP9b — La Comare"),
    ("s1_cena_famiglia", "📖 EP9c — Cena di Famiglia"),
    ("s1_crepa", "💔 La Crepa"),
    ("s1_disegno_lex", "🎨 Il Disegno di Lex"),
]

for ep_id, ep_title in episodes_order:
    ep_scenes = [s for s in unique_scenes if s["ep_id"] == ep_id]
    if not ep_scenes:
        continue

    output_lines.append(f"## {ep_title}")
    output_lines.append("")

    for i, scene in enumerate(ep_scenes):
        prompt = generate_prompt(scene)
        bg = scene["bg_path"]
        chars_str = ", ".join(scene["characters"])
        mood_emoji = {"tense": "🔴", "warm": "🟡", "sad": "🔵", "power": "⚡", "neutral": "⚪"}
        emoji = mood_emoji.get(scene["mood"], "⚪")

        # Output path
        out_path = bg.replace(".png", ".webp") if bg.endswith(".png") else bg

        output_lines.append(f"### {emoji} Page {scene['page_idx']} — `{out_path}`")
        output_lines.append(f"**Characters:** {chars_str} | **Section:** {scene['section']} | **Mood:** {scene['mood']}")
        output_lines.append(f"**Context:** {scene['context'][:150]}")
        output_lines.append("")
        output_lines.append(f"**Prompt:**")
        output_lines.append(f"```")
        output_lines.append(f"{prompt}")
        output_lines.append(f"```")
        output_lines.append("")
        output_lines.append(f"**Negative:** `{NEGATIVE}`")
        output_lines.append("")
        output_lines.append("---")
        output_lines.append("")

# Write output
out_path = "assets/data/illustration_prompts.md"
with open(out_path, "w") as f:
    f.write("\n".join(output_lines))

print(f"\n✅ Written {len(unique_scenes)} prompts to {out_path}")
print(f"   Estimated credits: ~{len(unique_scenes)} (Lightning XL)")
print(f"   Output format: markdown with embedded prompts + Leonardo config")
