#!/usr/bin/env python3
"""
generate_images.py — Favilla Blaze Image Generator (GPT Image 2)
=================================================================
Genera le illustrazioni degli episodi chiamando l'API OpenAI gpt-image-2.
Uso:
  python3 tools/generate_images.py prologo --pages 0,1
  python3 tools/generate_images.py prologo --all
  python3 tools/generate_images.py s1_mattina_dopo --all
"""

import json, os, sys, time, base64, argparse
from pathlib import Path
from openai import OpenAI

# Load .env file if it exists (so we don't need to export OPENAI_API_KEY each time)
_ENV_PATH = Path(__file__).parent.parent / ".env"
if _ENV_PATH.exists():
    with open(_ENV_PATH) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _key, _val = _line.split("=", 1)
                if _key.strip() not in os.environ:
                    os.environ[_key.strip()] = _val.strip()

# ─── Config ─────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"

# Canonic character descriptions (from SCENE_STANDARD + generate_prompts.py)
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
        "gentle easygoing expression, warm brown eyes, silver laptop nearby"
    ),
    "carmela": (
        "Signora Carmela, an elderly Italian woman, white hair under a wide straw hat or in a bun, "
        "too-alert knowing eyes with faint violet glow, floral dress, "
        "blue shopping trolley nearby, unsettling mysterious presence, always watching"
    ),
    "corvi": (
        "Dr. Livia Corvi, a cold Italian school inspector in her 50s, severe expression, "
        "tailored dark blazer and pencil skirt, high heels, leather briefcase, "
        "hair pulled back tightly, intimidating bureaucratic presence"
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
}

LOC_DESC = {
    "scuola": (
        "An Italian elementary school classroom in Nova Tutinia, colorful walls with children's "
        "drawings, tall windows with warm morning light, small wooden desks, chalk dust in the air, "
        "institutional but lively atmosphere"
    ),
    "casa": (
        "A warm cozy Italian apartment kitchen, Via delle Vesciche e dei Brufoli 18, "
        "terrazzo floors, high ceilings, baby toys scattered on the floor, "
        "laptop on wooden table, pasta pot on stove boiling, "
        "soft afternoon light through windows, lived-in family warmth, organized chaos"
    ),
    "casa_notte": (
        "Same Italian apartment kitchen at night, warm domestic lighting, "
        "kitchen suspiciously clean and in perfect order, soft shadows, "
        "contrast between the earlier chaos and now eerie calm"
    ),
    "strada_notte": (
        "Night view across a quiet Italian street in Nova Tutinia, "
        "dark window on third floor of old apartment building, "
        "elderly woman silhouette barely visible in darkness, "
        "orange street lamp glow on empty street below, tense mysterious atmosphere"
    ),
    "camera_notte": (
        "Bedroom at night, warm cozy Italian apartment, blue moonlight through window, "
        "baby sleeping peacefully in crib, man on laptop in background, "
        "emotional solitude, quiet introspection"
    ),
}

STYLE = (
    "Italian comic book illustration style, expressive line art, warm Mediterranean "
    "color palette, cinematic framing, Franco-Belgian comic style with bold clean black "
    "outlines, semi-flat colors, detailed backgrounds, emotional character expressions, "
    "soft natural lighting, 2D digital art, portrait 9:16 vertical composition, "
    "vibrant but grounded colors, no speech bubbles, no text, no watermarks"
)


def collect_all_pages(episode_data):
    """Collect ALL page descriptors from the episode: main pages, branches, epilogue.
    Returns list of (label, page_dict, bg_path_relative)."""
    results = []

    # Main pages
    for i, page in enumerate(episode_data.get("pages", [])):
        bg = page.get("background", "")
        results.append((f"page_{i}", page, bg))

    # Branch pages
    for branch_id, branch_data in episode_data.get("branches", {}).items():
        for i, page in enumerate(branch_data.get("pages", [])):
            bg = page.get("background", "")
            label = f"{branch_id}/{i}" if len(branch_data.get("pages", [])) > 1 else branch_id
            results.append((label, page, bg))

    # Epilogue pages
    epilogue_data = episode_data.get("epilogue", {})
    for i, page in enumerate(epilogue_data.get("pages", [])):
        bg = page.get("background", "")
        label = f"epilogue/{i}" if len(epilogue_data.get("pages", [])) > 1 else "epilogue"
        results.append((label, page, bg))

    return results


def build_prompt(page_data):
    """Build a detailed image prompt from a single page dict."""
    panels = page_data.get("panels", [])
    if not panels:
        return None

    panel = panels[0]
    characters = panel.get("characters", [])
    text_blocks = panel.get("text_blocks", [])

    # Determine location and mood from context
    bg_path = page_data.get("background", "")

    # Extract narrative context from text blocks
    narration_texts = []
    dialogue_texts = []
    thought_texts = []
    for tb in text_blocks:
        t = tb.get("text", "")
        if tb.get("type") == "narration":
            narration_texts.append(t)
        elif tb.get("type") == "dialogue":
            dialogue_texts.append(f"{tb.get('speaker','')}: {t}")
        elif tb.get("type") == "thought":
            thought_texts.append(t)

    # Determine location
    bg_lower = bg_path.lower()
    context_lower = " ".join(narration_texts).lower()

    if "carmela" in bg_lower or "strada" in context_lower or "finestra" in context_lower:
        location = "strada_notte"
    elif "epilogo" in bg_lower or "camera" in context_lower or "letto" in context_lower:
        location = "camera_notte"
    elif "scuola" in context_lower or "scuola" in bg_lower:
        location = "scuola"
    elif "notte" in context_lower or "buio" in context_lower:
        location = "casa_notte"
    else:
        location = "casa"

    # Determine mood
    mood = "warm"
    all_text_lower = " ".join(narration_texts + thought_texts).lower()
    if any(w in all_text_lower for w in ["no no", "trabocca", "pessima", "troppo", "disastro", "caos"]):
        mood = "tense"
    elif any(w in all_text_lower for w in ["trasformazione", "lampo", "fiamma", "luce", "fuoco", "scompar"]):
        mood = "power"
    elif any(w in all_text_lower for w in ["notte", "buio", "triste", "diventata", "sola"]):
        mood = "sad"

    # Build character descriptions for this scene
    char_descriptions = []
    for c in characters:
        desc = CHAR_DESC.get(c, "")
        if desc:
            char_descriptions.append(desc)

    # Get location description
    loc_desc = LOC_DESC.get(location, LOC_DESC["casa"])

    # Extract scene action from narration
    scene_action = " ".join(narration_texts[:3]) if narration_texts else "a quiet everyday moment in an Italian home"

    # Mood injection
    mood_injections = {
        "tense": "Tense atmosphere, dramatic side lighting, the moment before something breaks. "
                 "Everyone frozen mid-action, suspended in time.",
        "warm": "Warm intimate atmosphere, soft golden sunlight, family love and gentle chaos. "
                "The beauty of everyday life.",
        "power": "Supernatural energy explodes through the scene. Golden light radiates from Favilla, "
                 "sparks and embers float in the air, casting long dramatic shadows. "
                 "Awe-inspiring transformation moment.",
        "sad": "Quiet melancholy, soft muted cool colors, diffused flat light. "
               "A moment of stillness and introspection.",
    }

    # Build the final prompt
    prompt_parts = [
        f"CHARACTERS: {'; '.join(char_descriptions)}.",
        f"SETTING: {loc_desc}.",
        f"SCENE: {scene_action}.",
        f"MOOD: {mood_injections.get(mood, mood_injections['warm'])}",
        f"STYLE: {STYLE}.",
        f"IMPORTANT: No text, no letters, no speech bubbles, no watermarks, no signatures anywhere in the image.",
    ]

    prompt = " ".join(prompt_parts)

    # Trim to ~400 words (GPT Image 2 works best with detailed but focused prompts)
    words = prompt.split()
    if len(words) > 400:
        prompt = " ".join(words[:400])

    return prompt


def generate_image(client, prompt, output_path, size="1024x1536", quality="medium"):
    """Generate a single image and save it."""
    print(f"  🎨 Generating...")
    print(f"  📐 Size: {size}, Quality: {quality}")

    try:
        response = client.images.generate(
            model="gpt-image-2",
            prompt=prompt,
            size=size,
            n=1,
            quality=quality,
        )

        image_url = response.data[0].url
        if not image_url:
            # Check for b64_json fallback
            b64 = response.data[0].b64_json
            if b64:
                with open(output_path, "wb") as f:
                    f.write(base64.b64decode(b64))
                return True

        # Download from URL
        import urllib.request
        urllib.request.urlretrieve(image_url, output_path)

        file_size = os.path.getsize(output_path)
        print(f"  ✅ Saved: {output_path} ({file_size//1024} KB)")
        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Generate FavillApp episode illustrations")
    parser.add_argument("episode", help="Episode ID (e.g., prologo, s1_mattina_dopo)")
    parser.add_argument("--pages", help="Comma-separated page indexes (e.g., 0,1,2)")
    parser.add_argument("--all", action="store_true", help="Generate all pages")
    parser.add_argument("--quality", default="medium", choices=["low", "medium", "high"])
    parser.add_argument("--size", default="1024x1536", help="Output size (default: 1024x1536 portrait)")
    args = parser.parse_args()

    # Find episode JSON
    ep_paths = list(PROJECT_ROOT.glob(f"assets/data/quests/**/{args.episode}.json"))
    if not ep_paths:
        print(f"❌ Episode not found: {args.episode}")
        sys.exit(1)
    ep_path = ep_paths[0]

    with open(ep_path) as f:
        episode = json.load(f)

    ep_id = episode["id"]

    # Collect ALL pages: main, branches, epilogue
    all_pages = collect_all_pages(episode)

    # Determine which pages to generate
    if args.pages:
        # --pages only applies to main pages (index-based)
        page_indices = [int(p.strip()) for p in args.pages.split(",")]
        targets = [(f"page_{i}", episode["pages"][i], episode["pages"][i]["background"])
                   for i in page_indices if i < len(episode.get("pages", []))]
    elif args.all:
        targets = all_pages
    else:
        targets = all_pages  # default: generate everything

    print(f"{'='*60}")
    print(f"🔥 FAVILLA BLAZE — Image Generator (GPT Image 2)")
    print(f"{'='*60}")
    print(f"Episode: {ep_id} ({len(episode.get('pages',[]))} main + {len(episode.get('branches',{}))} branches + epilogue)")
    print(f"Pages to generate: {len(targets)}")
    print(f"Quality: {args.quality} | Size: {args.size}")
    print()

    # Init OpenAI client
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("❌ OPENAI_API_KEY not set in environment")
        sys.exit(1)
    client = OpenAI(api_key=api_key)

    # De-duplicate by output path (some stat_entry branches reuse the same background)
    seen_paths = set()
    unique_targets = []
    for label, page, bg_path in targets:
        output_path = str(PROJECT_ROOT / Path(bg_path).parent / Path(bg_path).name)
        if output_path not in seen_paths:
            seen_paths.add(output_path)
            unique_targets.append((label, page, bg_path))

    if len(unique_targets) < len(targets):
        skipped = len(targets) - len(unique_targets)
        print(f"ℹ️  Skipping {skipped} duplicate background(s) (same file, already in queue)\n")

    # Generate each page
    success = 0
    for i, (label, page, bg_path) in enumerate(unique_targets):
        bg_filename = Path(bg_path).name

        # Determine output path
        output_dir = PROJECT_ROOT / Path(bg_path).parent
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / bg_filename

        # Build prompt
        prompt = build_prompt(page)
        if not prompt:
            print(f"⚠️  [{label}] no panels found")
            continue

        chars = page.get("panels", [{}])[0].get("characters", [])
        print(f"[{i+1}/{len(targets)}] {label} → {bg_filename}")
        print(f"  Characters: {', '.join(chars)}")
        print(f"  Prompt length: {len(prompt)} chars, ~{len(prompt.split())} words")

        ok = generate_image(client, prompt, str(output_path), size=args.size, quality=args.quality)
        if ok:
            success += 1
            # Also save the prompt for reference
            prompt_path = output_path.with_suffix(".txt")
            with open(prompt_path, "w") as f:
                f.write(prompt)
        print()

    print(f"{'='*60}")
    print(f"✅ {success}/{len(unique_targets)} generated successfully")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
