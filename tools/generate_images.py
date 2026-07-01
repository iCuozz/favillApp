#!/usr/bin/env python3
"""
generate_images.py — Favilla Blaze Image Generator (GPT Image 2)
=================================================================
Ogni episodio necessita di un prompt globale in tools/episode_prompts/<ep_id>.txt
prima di poter essere generato. Mostra il prompt in italiano all'utente per approvazione.

Uso:
  python3 tools/generate_images.py prologo --all
  python3 tools/generate_images.py s1_domenica_parco --pages 0,1
"""

import json, os, sys, time, base64, argparse
from pathlib import Path
from openai import OpenAI

# ─── API Key ─────────────────────────────────────────────────────────
_KEY_PATH = Path(__file__).parent / ".gpt_key"
if _KEY_PATH.exists():
    os.environ["OPENAI_API_KEY"] = _KEY_PATH.read_text().strip()

# ─── Paths ───────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
PROMPTS_DIR = Path(__file__).parent / "episode_prompts"
BIBLE_PATH = Path(__file__).parent / "world_bible.json"

# ─── Load World Bible ────────────────────────────────────────────────
with open(BIBLE_PATH) as f:
    _bible = json.load(f)

LOC_DESC = {k: v["loc_desc"] for k, v in _bible.items()}
WORLD_DETAIL = {k: v["world_detail"] for k, v in _bible.items()}

# ─── Style ──────────────────────────────────────────────────────────
STYLE = (
    "Italian comic book illustration style, expressive line art, warm Mediterranean "
    "color palette, cinematic framing, Franco-Belgian comic style with bold clean black "
    "outlines, semi-flat colors, detailed backgrounds, emotional character expressions, "
    "soft natural lighting, 2D digital art, portrait 9:16 vertical composition, "
    "vibrant but grounded colors, no speech bubbles, no text, no watermarks. "
    "CRITICAL VISUAL CONSISTENCY: ALL images in this episode series MUST share the EXACT "
    "SAME visual style — identical line weight (consistent black outlines of uniform "
    "thickness), identical color saturation (warm Mediterranean tones, muted but rich), "
    "identical rendering technique (clean 2D digital art with semi-flat cel shading), "
    "identical level of background detail, identical lighting approach (soft natural "
    "light with gentle shadows). Every page must look like it belongs to the SAME comic "
    "book drawn by the SAME artist. No variation in art style between pages."
)

# ─── Canonic Character Descriptions ──────────────────────────────────
CHAR_DESC = {
    "favilla": (
        "Favilla, a blonde Italian woman in her early 30s, cat-eye black glasses, "
        "expressive hazel eyes, athletic build, white blouse, tight jeans, "
        "black-and-white sneakers, warm but tired smile, blonde hair tied back loosely"
    ),
    "favilla_blaze": (
        "Favilla Blaze, same woman transformed: cat-eye glasses vanished, eyes glowing bright amber, "
        "blonde hair erupting into floating luminous golden fire like a corona of flames, "
        "white blouse and jeans still on, golden energy crackling around her hands, "
        "sparks and embers floating upward, warm radiant supernatural aura, "
        "expression of shock mixed with wonder and discovery"
    ),
    "lex": (
        "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, "
        "big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, "
        "wearing a soft onesie and miniature red sneakers, chubby cheeks"
    ),
    "mallow": (
        "Mallow, an Italian man in his early 30s, short mini-mohawk light brown hair, "
        "light blue polo shirt, straight jeans, yellow high-top sneakers, "
        "gentle easygoing expression, warm brown eyes"
    ),
    "carmela": (
        "Signora Carmela, an elderly Italian woman, white hair under a wide straw hat or in a bun, "
        "too-alert knowing eyes with faint violet glow, floral dress, "
        "blue shopping trolley nearby, unsettling mysterious presence, always watching"
    ),
    "corvi": (
        "Dr. Livia Corvi, a cold Italian school inspector in her 50s, severe expression, "
        "tailored dark blazer and pencil skirt, high heels, leather briefcase, "
        "dark hair pulled back tightly in a severe bun, intimidating bureaucratic presence"
    ),
    "bambini": (
        "A chaotic group of Italian elementary school children, ages 6-10, "
        "colorful school uniforms, messy hair, backpacks, running laughing arguing, "
        "pure childhood energy"
    ),
    "gatto": (
        "Filippo, a sleek black cat with piercing yellow-green eyes, luminous in dim light, "
        "smooth fur, curled tail, silent graceful movements, always watching"
    ),
    "ladro": (
        "A young Italian man in his 20s, skinny build, dark hoodie pulled over head, "
        "nervous darting eyes, sneakers, moving fast, rough desperate appearance"
    ),
}

# ─── Episode Character Overrides (clothing) ──────────────────────────
EP_CHAR_OVERRIDES = {
    "prologo": {
        "lex": (
            "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, "
            "big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, "
            "wearing a soft baby-blue onesie with a tiny teddy bear print, white socks, "
            "chubby bare legs"
        ),
    },
    "s1_scuola_1": {
        "favilla": (
            "Favilla, a blonde Italian woman in her early 30s, slim athletic build, "
            "cat-eye black glasses, expressive hazel eyes, "
            "wearing the EXACT SAME plain white blouse with small dark 'Stars Hollow' "
            "lettering on the chest in every scene, "
            "tight blue skinny jeans, black-and-white Nike Panda sneakers, "
            "blonde hair tied back in a ponytail, at work in a school"
        ),
    },
    "s1_ritorno_casa": {
        "favilla": (
            "Favilla, a blonde Italian woman in her early 30s, slim athletic build, "
            "cat-eye black glasses, expressive hazel eyes, tired after a long day, "
            "wearing a formal BUTTON-DOWN white blouse with a COLLAR and BUTTONS down "
            "the front — this is a proper formal blouse, NOT a t-shirt, NOT a tank top, "
            "NOT a casual shirt — with small dark 'Stars Hollow' lettering on the chest, "
            "tight blue skinny jeans, "
            "black-and-white Nike Panda sneakers, "
            "blonde hair tied back in a slightly messy ponytail — "
            "in some variant scenes the blouse has scorch marks on HER LEFT side of "
            "the chest (Favilla's own left, the side closest to her heart — viewer's "
            "right side of the image when she faces the viewer), "
            "always in the EXACT SAME spots: three or four small dark holes "
            "with blackened edges on her LEFT chest"
        ),
        "mallow": (
            "Mallow, an Italian man in his early 30s, short mini-mohawk light brown hair, "
            "wearing a BLACK t-shirt with a large YELLOW BAT graphic in the center, "
            "straight blue jeans, YELLOW CONVERSE sneakers (always yellow Converse, never any other shoe), "
            "gentle easygoing expression, warm brown eyes, relaxed casual evening at home"
        ),
        "lex": (
            "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, "
            "big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, "
            "wearing a soft light onesie, BAREFEET (no socks, no shoes of any kind), "
            "chubby bare toes visible, chubby cheeks"
        ),
    },
    "s1_spesa_sabato": {
        "favilla": (
            "Favilla, a blonde Italian woman in her early 30s, slim athletic build, "
            "blonde hair tied back in a ponytail, "
            "wearing a WHITE SHORT-SLEEVE BUTTON-UP BLOUSE with an all-over print of "
            "IDENTICAL SMALL YELLOW LEMONS (each lemon is exactly the same — small, "
            "bright yellow, about 2-3cm, with a tiny green leaf, arranged in a regular "
            "repeating grid pattern covering the entire blouse evenly like polka dots), "
            "straight beige trousers (NOT jeans), "
            "dark-framed SUNGLASSES (NOT prescription glasses, NOT cat-eye glasses), "
            "simple flat shoes, "
            "relaxed weekend look, distracted, looking at her phone"
        ),
        "favilla_blaze": (
            "Favilla Blaze, same woman transformed: SUNGLASSES vanished, eyes glowing bright amber, "
            "blonde hair erupting into floating luminous golden fire like a corona of flames, "
            "WHITE BLOUSE WITH IDENTICAL SMALL YELLOW LEMON PRINT and straight beige trousers still on, "
            "golden energy crackling around her hands, "
            "sparks and embers floating upward, warm radiant supernatural aura"
        ),
        "lex": (
            "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk, "
            "big expressive hazel eyes, two tiny bottom teeth, chubby cheeks, "
            "wearing a RED T-SHIRT with THE FLASH superhero logo on the chest "
            "(a yellow lightning bolt inside a white circle on red background), "
            "red shorts, "
            "ALWAYS BAREFOOT — bare feet with tiny toes always clearly visible, "
            "NO socks, NO shoes of any kind, "
            "sitting in a shopping cart baby seat"
        ),
        "carmela": (
            "Signora Carmela, an elderly Italian woman, white hair gathered in a soft bun, "
            "eyes with a faint VIOLET glow, unsettling too-alert knowing eyes, "
            "wearing a floral dress (light blue and lilac flower pattern on white background, "
            "modest cut, long sleeves, below-knee length), "
            "holding a wicker basket with a bottle of tomato passata inside, "
            "mysterious and quiet presence. "
            "HER OUTFIT NEVER CHANGES — always this exact floral dress, white bun, and wicker basket."
        ),
    },
    "s1_domenica_parco": {
        "favilla": (
            "Favilla, a blonde Italian woman in her early 30s, cat-eye black glasses, "
            "expressive hazel eyes, athletic build, wearing a vintage white 'Hard Rock Stars Hollow' "
            "concert t-shirt with retro lettering, light denim shorts, bare legs, "
            "black-and-white Nike Panda sneakers (exact black-and-white Nike Panda model with black swoosh), "
            "blonde hair tied back loosely, relaxed Sunday look"
        ),
        "favilla_blaze": (
            "Favilla Blaze, same woman transformed: cat-eye glasses vanished, eyes glowing bright amber, "
            "blonde hair erupting into floating luminous golden fire like a corona of flames, "
            "white Hard Rock Stars Hollow t-shirt and denim shorts still on, "
            "golden energy crackling around her hands, "
            "sparks and embers floating upward, warm radiant supernatural aura, "
            "expression of shock mixed with wonder and discovery"
        ),
        "mallow": (
            "Mallow, an Italian man in his early 30s, short mini-mohawk light brown hair, "
            "wearing a black 'Hard Rock Osaka' concert t-shirt with bold white lettering, "
            "khaki shorts, WHITE CONVERSE sneakers (high-top, specifically Converse brand, white color — NOT yellow, NOT any other color), bare legs, "
            "gentle easygoing expression, warm brown eyes, relaxed Sunday look"
        ),
        "lex": (
            "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, "
            "big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, "
            "wearing a purple-and-gold Los Angeles Lakers baby onesie, "
            "COMPLETELY BAREFOOT — no socks, no shoes of any kind, bare feet with tiny toes always clearly visible, "
            "chubby bare legs, sitting securely in a baby stroller"
        ),
        "ladro": (
            "A young Italian man in his 20s, skinny build, dark grey hoodie, "
            "ripped jeans, worn sneakers, nervous darting eyes, "
            "sweating and out of breath, a desperate park thief"
        ),
    },
    "s1_mare": {
        "favilla": (
            "Favilla, a blonde Italian woman in her early 30s, athletic build, "
            "blonde hair loose and flowing, "
            "wearing a YELLOW BIKINI (two-piece bright yellow bikini — yellow top and yellow bottom), "
            "dark sunglasses, barefoot on the beach, "
            "sometimes with a light white or beige beach cover-up/kimono over the bikini, "
            "relaxed beach look, warm expression"
        ),
        "mallow": (
            "Mallow, an Italian man in his early 30s, short mini-mohawk light brown hair, "
            "wearing colorful BIRD-PATTERN SWIM TRUNKS (tropical print shorts with exotic bird motifs, "
            "NOT regular shorts, NOT jeans), barefoot or simple flip-flops, "
            "bare chest or light linen shirt sometimes, "
            "gentle easygoing expression, warm brown eyes, relaxed beach day"
        ),
        "lex": (
            "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, "
            "big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, "
            "wearing a duck-print swim diaper (little yellow duck pattern on light blue/white background), "
            "diaper visible, "
            "COMPLETELY BAREFOOT — no socks, no shoes of any kind, bare feet with tiny toes always clearly visible, "
            "chubby bare legs, on a beach towel or in someone's arms"
        ),
        "gatto": (
            "Filippo, a sleek black cat, "
            "piercing yellow-green eyes, silent graceful movements, "
            "always watchful and knowing, sitting on a seaside wall"
        ),
    },
    "s1_centro_commerciale": {
        "favilla": (
            "Favilla, a blonde Italian woman in her early 30s, cat-eye black glasses, "
            "expressive hazel eyes, athletic build, blonde hair down, "
            "wearing a SOLID ORANGE DRESS with a LONG FULL SKIRT (vestitino arancione "
            "tinta unita con gonnellone lungo — same solid orange dress in EVERY scene), "
            "YELLOW GOLD HOOP EARRINGS (orecchini a cerchio oro giallo — "
            "visible in EVERY scene, NEVER missing), "
            "open flat shoes (scarpe basse aperte — open-toe flat sandals, same pair in EVERY scene), "
            "carrying a small shoulder bag"
        ),
        "mallow": (
            "Mallow, an Italian man in his early 30s, short mini-mohawk light brown hair, "
            "wearing a VINTAGE NOVELTY SHIRT covered in printed retro objects and patterns "
            "(NOT a plain t-shirt, NOT the Hard Rock Osaka shirt, "
            "a colorful vintage short-sleeve button-up shirt with whimsical object prints), "
            "VINTAGE BEIGE CONVERSE sneakers (beige/cream-colored Converse high-tops, "
            "vintage worn-in look, NOT any other color, NOT any other brand), "
            "jeans or casual trousers, "
            "gentle easygoing expression, warm brown eyes, relaxed mall day"
        ),
        "lex": (
            "Lex, a 7-month-old baby boy, light brown spiky hair in a tiny mohawk like his dad, "
            "big expressive hazel eyes, mischievous curious smile, two tiny bottom teeth, "
            "wearing a BABY T-SHIRT (soft cotton, any color) and BABY SHORTS (pantaloncino), "
            "COMPLETELY BAREFOOT — no socks, no shoes of any kind, bare feet with tiny toes always clearly visible, "
            "chubby bare legs, sitting in a baby stroller"
        ),
        "carmela": (
            "Signora Carmela, an elderly Italian woman in her late 70s, "
            "white hair gathered in a soft bun, stern knowing face, "
            "wearing a floral dress (light blue and lilac flower pattern on white background, "
            "modest cut, long sleeves, below-knee length), "
            "a straw sun hat, holding a blue shopping trolley, "
            "unsettling too-alert eyes with a faint VIOLET glow, mysterious quiet presence"
        ),
    },
}

# ─── Mood ────────────────────────────────────────────────────────────
MOOD_DESC = {
    "tense": "Tense atmosphere, dramatic side lighting, the moment before something breaks. Suspended in time.",
    "warm": "Warm intimate atmosphere, soft golden sunlight, family love and gentle chaos. The beauty of everyday life.",
    "warm_parco": "Golden morning sunlight filtering through tree leaves, dappled shadows on grass, "
                  "families laughing in the distance, a perfect peaceful Sunday at the park.",
    "warm_boschetto": "Muted green light through dense foliage, shafts of sunlight breaking through the canopy, "
                      "isolated quiet within the city noise, nature all around.",
    "warm_mare": "Golden seaside light, warm Mediterranean sun, the sound of waves, relaxed beach atmosphere, "
                 "sunlight reflecting off the water creating sparkling highlights.",
    "warm_centro_commerciale": "Bright indoor shopping mall lighting, colorful storefronts, the hum of weekend crowds, "
                               "a modern consumer cathedral of glass and light.",
    "power": "Supernatural energy explodes through the scene. Golden light radiates from Favilla, "
             "sparks and embers float in the air, casting long dramatic shadows. Awe-inspiring transformation moment.",
    "sad": "Quiet melancholy, soft muted cool colors, diffused flat light. A moment of stillness and introspection.",
}

# ─── Helpers ─────────────────────────────────────────────────────────

def collect_all_pages(episode_data):
    results = []
    for i, page in enumerate(episode_data.get("pages", [])):
        results.append((f"page_{i}", page, page.get("background", "")))
    for branch_id, branch_data in episode_data.get("branches", {}).items():
        bp = branch_data.get("pages", [])
        for i, page in enumerate(bp):
            label = f"{branch_id}/{i}" if len(bp) > 1 else branch_id
            results.append((label, page, page.get("background", "")))
    epi = episode_data.get("epilogue", {})
    ep_pages = epi.get("pages", [])
    for i, page in enumerate(ep_pages):
        label = f"epilogue/{i}" if len(ep_pages) > 1 else "epilogue"
        results.append((label, page, page.get("background", "")))
    return results


def detect_location(bg_path, narration_texts):
    bg_lower = bg_path.lower()
    ctx = " ".join(narration_texts).lower()
    if "scuola" in ctx or "scuola" in bg_lower:
        return "scuola"
    if "galaxiamall" in bg_lower or "centro commerciale" in ctx or "mall" in ctx:
        return "centro_commerciale"
    if "parcheggio" in bg_lower or "parking" in ctx:
        return "parcheggio_mall"
    if "supermercato" in ctx or "iperpassata" in ctx or "spesa" in bg_lower or "cassa" in ctx or "scaffale" in ctx or "carrello" in ctx:
        return "supermercato"
    if "boschetto" in ctx or "boschetto" in bg_lower:
        return "boschetto"
    if "parco" in ctx or "giardini" in ctx:
        return "parco"
    if "mare" in ctx or "spiaggia" in ctx or "lido" in ctx or "ombrellone" in ctx:
        return "mare"
    if "carmela" in bg_lower or ("carmela" in ctx and "strada" in ctx):
        return "strada_notte"
    if ("strada" in ctx or "finestra" in ctx) and ("notte" in ctx or "buio" in ctx):
        return "strada_notte"
    if "epilogo" in bg_lower or "camera" in ctx or "letto" in ctx:
        return "camera_notte"
    if "notte" in ctx or "buio" in ctx:
        return "casa_notte"
    return "casa"


def detect_mood(narration_texts, thought_texts):
    all_t = " ".join(narration_texts + thought_texts).lower()
    tense = ["no no", "trabocca", "pessima", "troppo", "disastro", "caos",
             "corre", "rincorsa", "strappa", "rallenta", "gambe cedono", "stringe", "fugge"]
    power = ["trasformazione", "lampo", "fiamma", "luce", "fuoco", "scompar"]
    sad = ["notte", "buio", "triste", "diventata", "sola"]
    if any(w in all_t for w in tense):
        return "tense"
    if any(w in all_t for w in power):
        return "power"
    if any(w in all_t for w in sad):
        return "sad"
    return "warm"


def get_mood_desc(mood, location):
    if mood == "warm":
        return MOOD_DESC.get(f"warm_{location}", MOOD_DESC["warm"])
    return MOOD_DESC.get(mood, MOOD_DESC["warm"])


def load_episode_prompt(episode_id):
    """Load the global episode prompt from tools/episode_prompts/<ep_id>.txt."""
    path = PROMPTS_DIR / f"{episode_id}.txt"
    if not path.exists():
        return None
    return path.read_text().strip()


def load_page_prompt(episode_id, label):
    """Load page-specific prompt from tools/page_prompts/<ep_id>/<label>.txt
    Label slashes become underscores: branch_segreto/0 -> branch_segreto_0.txt"""
    safe = label.replace("/", "_")
    path = Path(__file__).parent / "page_prompts" / episode_id / f"{safe}.txt"
    if not path.exists():
        return None
    return path.read_text().strip()


def build_prompt(page_data, episode_id="", episode_global_prompt="", page_prompt=""):
    """Build a detailed image prompt from a single page dict."""
    panels = page_data.get("panels", [])
    if not panels:
        return None

    panel = panels[0]
    characters = panel.get("characters", [])
    text_blocks = panel.get("text_blocks", [])
    bg_path = page_data.get("background", "")

    narration_texts, dialogue_texts, thought_texts = [], [], []
    for tb in text_blocks:
        t = tb.get("text", "")
        tt = tb.get("type", "")
        if tt == "narration":
            narration_texts.append(t)
        elif tt == "dialogue":
            dialogue_texts.append(f"{tb.get('speaker','')}: {t}")
        elif tt == "thought":
            thought_texts.append(t)

    location = detect_location(bg_path, narration_texts)
    mood = detect_mood(narration_texts, thought_texts)

    ep_overrides = EP_CHAR_OVERRIDES.get(episode_id, {})
    char_descriptions = []
    for c in characters:
        desc = ep_overrides.get(c) or CHAR_DESC.get(c, "")
        if desc:
            char_descriptions.append(desc)

    loc_desc = LOC_DESC.get(location, LOC_DESC["casa"])
    world_detail = WORLD_DETAIL.get(location, WORLD_DETAIL["casa"])
    scene_action = " ".join(narration_texts[:3]) if narration_texts else "a quiet everyday moment"
    mood_desc = get_mood_desc(mood, location)

    # Build content parts (these get trimmed if too long)
    content_parts = [
        f"CHARACTERS: {'; '.join(char_descriptions)}.",
        f"SETTING: {loc_desc}",
        f"LOCATION DETAILS: {world_detail}",
        f"SCENE: {scene_action}.",
        f"MOOD: {mood_desc}",
    ]

    if page_prompt:
        content_parts.insert(1, f"PAGE DETAILS: {page_prompt}")
    if episode_global_prompt:
        content_parts.insert(2, f"EPISODE CONSISTENCY: {episode_global_prompt}")

    # Fixed parts — NEVER trimmed
    fixed_parts = [
        f"STYLE: {STYLE}.",
        "IMPORTANT: No text, no letters, no speech bubbles, no watermarks, "
        "no signatures anywhere in the image.",
    ]

    content = " ".join(content_parts)
    fixed = " ".join(fixed_parts)
    full = f"{content} {fixed}"

    words = content.split()
    if len(words) > 800:
        content = " ".join(words[:800])

    prompt = f"{content} {fixed}"
    return prompt


def generate_image(client, prompt, output_path, size="1024x1536", quality="medium"):
    print(f"  🎨 Generating...")
    print(f"  📐 Size: {size}, Quality: {quality}")
    try:
        response = client.images.generate(
            model="gpt-image-2", prompt=prompt,
            size=size, n=1, quality=quality,
        )
        url = response.data[0].url
        if not url:
            b64 = response.data[0].b64_json
            if b64:
                with open(output_path, "wb") as f:
                    f.write(base64.b64decode(b64))
                return True
        import urllib.request
        urllib.request.urlretrieve(url, output_path)
        print(f"  ✅ Saved: {output_path} ({os.path.getsize(output_path)//1024} KB)")
        return True
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Generate FavillApp episode illustrations")
    parser.add_argument("episode", help="Episode ID (e.g., prologo, s1_mattina_dopo)")
    parser.add_argument("--pages", help="Comma-separated page indexes")
    parser.add_argument("--all", action="store_true", help="Generate all pages")
    parser.add_argument("--quality", default="medium", choices=["low", "medium", "high"])
    parser.add_argument("--size", default="1024x1536")
    args = parser.parse_args()

    # Load episode data
    ep_paths = list(PROJECT_ROOT.glob(f"assets/data/quests/**/{args.episode}.json"))
    if not ep_paths:
        print(f"❌ Episode not found: {args.episode}")
        sys.exit(1)
    with open(ep_paths[0]) as f:
        episode = json.load(f)
    ep_id = episode["id"]

    # ⚠️ MUST have episode global prompt
    ep_prompt = load_episode_prompt(ep_id)
    if not ep_prompt:
        print(f"\n{'='*60}")
        print(f"❌ EPISODE GLOBAL PROMPT NON TROVATO")
        print(f"{'='*60}")
        print(f"Devi creare il file: tools/episode_prompts/{ep_id}.txt")
        print(f"\nQuesto file deve contenere il prompt globale per l'episodio")
        print(f"(vestiti dei personaggi, dettagli specifici, coerenza interna).")
        print(f"\nSenza di esso, la generazione non può partire.")
        print(f"{'='*60}\n")
        sys.exit(1)

    # Collect pages
    all_pages = collect_all_pages(episode)
    if args.pages:
        indices = [int(p.strip()) for p in args.pages.split(",")]
        targets = [(f"page_{i}", episode["pages"][i], episode["pages"][i]["background"])
                   for i in indices if i < len(episode.get("pages", []))]
    else:
        targets = all_pages

    info = f"Episode: {ep_id} ({len(episode.get('pages',[]))} main + {len(episode.get('branches',{}))} branches + epilogue)"
    print(f"{'='*60}")
    print(f"🔥 FAVILLA BLAZE — Image Generator")
    print(f"{'='*60}")
    print(info)
    print(f"Pages to generate: {len(targets)}")
    print(f"Quality: {args.quality} | Size: {args.size}")
    print()

    # Init API
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("❌ OPENAI_API_KEY not set")
        sys.exit(1)
    client = OpenAI(api_key=api_key)

    # Deduplicate
    seen = set()
    unique = []
    for label, page, bg_path in targets:
        out = str(PROJECT_ROOT / Path(bg_path).parent / Path(bg_path).name)
        if out not in seen:
            seen.add(out)
            unique.append((label, page, bg_path))

    skipped = len(targets) - len(unique)
    if skipped:
        print(f"ℹ️  Skipping {skipped} duplicate background(s)\n")

    # Generate
    success = 0
    for i, (label, page, bg_path) in enumerate(unique):
        bg_filename = Path(bg_path).name
        out_dir = PROJECT_ROOT / Path(bg_path).parent
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / bg_filename

        page_extra = load_page_prompt(ep_id, label) or ""
        prompt = build_prompt(page, ep_id, ep_prompt, page_extra)
        if not prompt:
            print(f"⚠️  [{label}] no panels")
            continue

        chars = page.get("panels", [{}])[0].get("characters", [])
        print(f"[{i+1}/{len(targets)}] {label} → {bg_filename}")
        print(f"  Characters: {', '.join(chars)}")
        print(f"  Prompt length: {len(prompt)} chars, ~{len(prompt.split())} words")

        ok = generate_image(client, prompt, str(out_path), size=args.size, quality=args.quality)
        if ok:
            success += 1
            with open(out_path.with_suffix(".txt"), "w") as pf:
                pf.write(prompt)
        print()

    print(f"{'='*60}")
    print(f"✅ {success}/{len(unique)} generated successfully")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
