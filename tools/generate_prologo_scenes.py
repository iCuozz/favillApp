#!/usr/bin/env python3
"""Genera tutte le scene del prologo via ComfyUI API.

Strategy: carica il workflow favilla_blaze_ipadapter.json di riferimento,
aggiunge Carmela, e per ogni scena modifica prompt, strengths, seed.
"""

import json
import time
import os
import sys
import re
import urllib.request
import urllib.error

API_URL = "http://127.0.0.1:8188"
OUTPUT_DIR = "/Users/andreacuozzo/Projects/favillApp/assets/episodes/prologo"

# ─── Style base (identico al workflow originale) ───
BASE_STYLE = (
    "digital comic illustration, semi-flat colors, bold clean black outlines, "
    "expressive faces, Franco-Belgian comic style, warm Italian atmosphere, "
    "portrait 9:16 vertical composition, cinematic lighting, "
    "no text, no speech bubbles, no watermarks, high detail background."
)

# ─── Scene definitions ───
SCENES = [
    {
        "file": "page_0",
        "prompt": (
            "School classroom in Italy, afternoon light. A young woman with olive skin and "
            "blonde ponytail in a blue school smock, surrounded by excited children "
            "at small desks. She holds a pink eraser playfully. Children reach for it. "
            "Colorful classroom with chalkboard, drawings on walls."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.0, "mallow": 0.0},
        "seed": 1001,
    },
    {
        "file": "page_1",
        "prompt": (
            "Italian home kitchen, chaos. A tired young woman with olive skin and blonde ponytail "
            "stands in the middle. A chubby baby with tiny red sneakers in a high chair, laughing. "
            "A man with a mini-mohawk at the table with laptop. Dinner boiling on stove."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.40, "mallow": 0.35},
        "seed": 1002,
    },
    {
        "file": "page_2",
        "prompt": (
            "Messy kitchen counter close-up. Baby food splattered, a flying spoon mid-air. "
            "Woman's hands reaching. Baby in high chair with mischievous face. "
            "Man at laptop in background. Pasta pot overflowing. Chaotic domestic scene."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.40, "mallow": 0.20},
        "seed": 1003,
    },
    {
        "file": "page_3",
        "prompt": (
            "Dramatic moment in a kitchen. A baby in a high chair leans dangerously forward, "
            "tipping. A woman reaches out desperately, glasses askew, panic on face. "
            "Pasta boiling over. Phone falling. Man looks up alarmed. Suspended moment."
        ),
        "strengths": {"favilla": 0.38, "favlaze": 0.0, "lex": 0.40, "mallow": 0.20},
        "seed": 1004,
    },
    {
        "file": "page_4",
        "prompt": (
            "SUPERNATURAL TRANSFORMATION in a kitchen. A young woman with olive skin, "
            "cat-eye glasses gone, hair erupting into golden-orange glowing light like flames, "
            "eyes glowing warm amber. She holds a baby safely in her arms. Kitchen perfectly "
            "in place. The baby looks with wide eyes and joyful smile. Warm golden particles. "
            "Power and maternal love in one frame."
        ),
        "strengths": {"favilla": 0.15, "favlaze": 0.45, "lex": 0.35, "mallow": 0.0},
        "seed": 1005,
    },
    {
        "file": "page_carmela",
        "prompt": (
            "Night view across a quiet Italian street. Dark window on third floor of an old building. "
            "An elderly woman's silhouette with grey hair bun becomes visible in the darkness. "
            "Wide eyes with faint violet glow. She has sensed something. Tense mysterious atmosphere. "
            "Street lamp casts dim orange light on the empty street below."
        ),
        "strengths": {"favilla": 0.0, "favlaze": 0.0, "lex": 0.0, "mallow": 0.0},
        "seed": 1006,
    },
    {
        "file": "page_5",
        "prompt": (
            "Kitchen after a strange event. A woman with olive skin and blonde ponytail stands "
            "with her back to the counter, trying to look normal. A man enters the room "
            "looking at her with concern. Kitchen is suspiciously clean. Warm domestic lighting."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.0, "mallow": 0.35},
        "seed": 1007,
    },
    {
        "file": "page_epilogo",
        "prompt": (
            "Bedroom at night. A woman with blonde hair sits on the edge of the bed, "
            "hugging herself, looking at her reflection in a dark window. Baby sleeping in a crib. "
            "Man quietly working on laptop. Blue moonlight. Emotional solitude, "
            "she looks scared and confused, touching her own hair."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.0, "mallow": 0.10},
        "seed": 1008,
    },
    {
        "file": "page_branch_segreto",
        "prompt": (
            "Italian kitchen, warm evening. A blonde woman at the stove serving pasta. "
            "A man at the table smiling. A baby in a high chair with a knowing, mischievous smile. "
            "Peaceful family dinner. Shared secret between mother and baby. Comfortable home."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.35, "mallow": 0.30},
        "seed": 1010,
    },
    {
        "file": "page_branch_legame",
        "prompt": (
            "Italian kitchen evening. A blonde woman and a man with mini-mohawk at the table "
            "facing each other. She looks tired and vulnerable. He reaches a hand across. "
            "A baby in a high chair watches with big eyes. Emotional intimacy close framing."
        ),
        "strengths": {"favilla": 0.35, "favlaze": 0.0, "lex": 0.20, "mallow": 0.35},
        "seed": 1011,
    },
]

# ─── Mappa: char name → (node_id per StyleModelApply, input_index_per_strength) ───
# These come from the favilla_blaze_ipadapter.json workflow
CHAR_STYLE_NODES = {
    "favilla": 12,     # StyleModelApply "Apply Favilla Style"
    "favlaze": 17,     # StyleModelApply "Apply Favilla Blaze Style"
    "lex": 22,         # StyleModelApply "Apply Lex Style"
    "mallow": 32,      # StyleModelApply "Apply Mallow Style"
}

PROMPT_NODE = 40        # CLIPTextEncode "✏️ PROMPT"
SEED_NODE = 51          # KSampler
SAVE_NODE = 53          # SaveImage


def load_base_workflow():
    """Load the existing favilla_blaze_ipadapter.json as the base."""
    path = "/Users/andreacuozzo/Desktop/favilla_blaze_ipadapter.json"
    with open(path) as f:
        wf = json.load(f)

    # Convert GUI format to API format: {node_id: {"class_type": ..., "inputs": {...}}}
    prompt_dict = {}
    for node in wf["nodes"]:
        nid = str(node["id"])
        inputs = {}
        class_type = node["type"]

        # Collect widget values
        widget_names = node.get("widgets_values", [])
        input_defs = []
        for inp in node.get("inputs", []):
            input_defs.append(inp)
        widget_inputs = [inp for inp in input_defs if inp.get("widget") is not None]

        # Build inputs dict
        # First add widget values in order
        for inp in input_defs:
            wname = inp.get("widget", {}).get("name") or inp.get("name")
            is_widget = inp.get("widget") is not None

        # Simpler: read from title to know what this node is
        prompt_dict[nid] = {
            "class_type": class_type,
            "inputs": {},
            "_meta": {
                "title": node.get("title", ""),
            }
        }

        # Now fill in inputs from links and widgets
        # We need the class_type to know the input schema
        # Let's get it from the API

    return prompt_dict, wf["nodes"], wf["links"]


def get_node_info():
    """Get input schema for all node types from ComfyUI API."""
    req = urllib.request.Request(f"{API_URL}/api/object_info")
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read())


def build_api_prompt(base_wf_nodes, base_wf_links, object_info, scene):
    """Build API format prompt dict from the base workflow + scene overrides."""
    # We need node class_type -> input schema mapping
    node_schemas = {}

    # First pass: build the mapping
    for node in base_wf_nodes:
        nid = node["id"]
        class_type = node["type"]
        if class_type in object_info:
            node_schemas[nid] = object_info[class_type]

    prompt = {}

    for node in base_wf_nodes:
        nid = str(node["id"])
        class_type = node["type"]
        inputs = {}
        title = node.get("title", "")

        # Get the input definitions from object_info
        class_info = object_info.get(class_type, {})
        required = class_info.get("input", {}).get("required", {})

        # Process inputs from links
        for inp in node.get("inputs", []):
            inp_name = inp["name"]
            inp_link = inp.get("link")

            if inp_link is not None:
                # Find the source node for this link
                for link in base_wf_links:
                    if link[0] == inp_link:
                        src_nid = str(link[1])
                        src_socket = link[2]
                        inputs[inp_name] = [src_nid, src_socket]
                        break
            elif inp_name in required:
                # This is a widget value - will be set below
                pass

        # Process widget values
        widget_values = node.get("widgets_values", [])
        widget_idx = 0

        # Get input order from required
        for inp_name, inp_def in required.items():
            if inp_name not in inputs:
                inp_type = inp_def[0] if isinstance(inp_def, list) else inp_def
                if isinstance(inp_type, list) and widget_idx < len(widget_values):
                    # It's a widget/choice
                    inputs[inp_name] = widget_values[widget_idx]
                    widget_idx += 1
                elif isinstance(inp_type, str) and inp_type in (
                    "INT", "FLOAT", "STRING", "BOOLEAN"
                ):
                    if widget_idx < len(widget_values):
                        inputs[inp_name] = widget_values[widget_idx]
                        widget_idx += 1

        # ─── Apply scene overrides ───
        if nid == str(PROMPT_NODE):
            inputs["text"] = f"{BASE_STYLE}\nScene: {scene['prompt']}"

        elif nid == str(SEED_NODE):
            inputs["seed"] = scene["seed"]

        elif nid == str(SAVE_NODE):
            # Modify filename prefix
            inputs["filename_prefix"] = f"prologo_{scene['file']}"

        elif nid in [str(v) for v in CHAR_STYLE_NODES.values()]:
            # Find which character this node represents
            char_key = None
            for k, v in CHAR_STYLE_NODES.items():
                if str(v) == nid:
                    char_key = k
                    break
            if char_key and char_key in scene["strengths"]:
                inputs["strength"] = scene["strengths"][char_key]

        prompt[nid] = {
            "class_type": class_type,
            "inputs": inputs,
        }

    return prompt


def queue_api_prompt(api_prompt):
    """Send API-format prompt to ComfyUI."""
    payload = {
        "prompt": api_prompt,
        "client_id": "favillapp-generator",
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{API_URL}/prompt",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())

    prompt_id = result.get("prompt_id")
    number = result.get("number")
    print(f"  ⏳ Queued: #{number} (ID: {prompt_id[:8]}...)")
    return prompt_id


def wait_for_completion(prompt_id, timeout=300):
    """Poll for prompt completion."""
    start = time.time()
    last_progress = 0

    while time.time() - start < timeout:
        # Check queue
        try:
            req = urllib.request.Request(f"{API_URL}/queue")
            with urllib.request.urlopen(req, timeout=5) as resp:
                queue = json.loads(resp.read())

            queue_running = queue.get("queue_running", [])
            queue_pending = queue.get("queue_pending", [])

            # Check if our prompt is in running/pending
            in_queue = False
            for item in queue_running:
                if isinstance(item, list) and len(item) > 0:
                    if item[0] == 1:  # running
                        in_queue = True
            for item in queue_pending:
                if isinstance(item, list) and len(item) > 0 and item[0] > 0:
                    in_queue = True

            if not in_queue:
                # Check history
                time.sleep(3)
                try:
                    req = urllib.request.Request(f"{API_URL}/history/{prompt_id}")
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        history = json.loads(resp.read())
                    if prompt_id in history:
                        outputs = history[prompt_id].get("outputs", {})
                        imgs = []
                        for nid, node_out in outputs.items():
                            for out_name, out_list in node_out.items():
                                if isinstance(out_list, list):
                                    for item in out_list:
                                        if isinstance(item, dict) and "filename" in item:
                                            imgs.append(item["filename"])
                        return imgs
                except (urllib.error.HTTPError, json.JSONDecodeError):
                    pass

                # Check if it's just finished but not yet in history
                time.sleep(2)

                try:
                    req = urllib.request.Request(f"{API_URL}/history/{prompt_id}")
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        history = json.loads(resp.read())
                    if prompt_id in history:
                        outputs = history[prompt_id].get("outputs", {})
                        imgs = []
                        for nid, node_out in outputs.items():
                            for out_name, out_list in node_out.items():
                                if isinstance(out_list, list):
                                    for item in out_list:
                                        if isinstance(item, dict) and "filename" in item:
                                            imgs.append(item["filename"])
                        return imgs
                except:
                    pass

        except Exception as e:
            pass

        time.sleep(5)

    return None


def copy_images_to_project(filenames):
    """Copy generated images from ComfyUI output to project assets."""
    comfy_output = "/Users/andreacuozzo/ComfyUI/output"
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    copied = []
    for fn in filenames:
        src = os.path.join(comfy_output, fn)
        if os.path.exists(src):
            # The filename might have _00001_ suffix
            # page_0 becomes page_0.webp
            base = fn.split("_0000")[0] if "_0000" in fn else fn.rsplit(".", 1)[0]
            # Remove 'prologo_' prefix from the filename
            scene_name = base.replace("prologo_", "", 1)
            dst = os.path.join(OUTPUT_DIR, f"{scene_name}.png")
            import shutil
            shutil.copy2(src, dst)
            copied.append(dst)
            print(f"  ✅ Copied: {dst}")
        else:
            print(f"  ⚠️  Not found: {src}")

    return copied


def main():
    print("=" * 60)
    print("🔥 FAVILLA BLAZE — Generazione Scene Prologo")
    print("=" * 60)

    # 1. Check ComfyUI
    try:
        req = urllib.request.Request(f"{API_URL}/api/version")
        with urllib.request.urlopen(req, timeout=5) as resp:
            ver = json.loads(resp.read())
            print(f"✅ ComfyUI: v{ver.get('version', '?')}")
    except Exception as e:
        print(f"❌ ComfyUI not reachable: {e}")
        print("   Run: cd /Users/andreacuozzo/ComfyUI-Installs/ComfyUI/ComfyUI &&")
        print("         /Users/andreacuozzo/ComfyUI/.venv/bin/python main.py --listen 127.0.0.1")
        sys.exit(1)

    # 2. Get node info
    print("📡 Fetching node schemas...")
    object_info = get_node_info()
    print(f"   {len(object_info)} node types available")

    # 3. Load base workflow
    print("📂 Loading base workflow...")
    base_wf_nodes, base_wf_links = None, None
    path = "/Users/andreacuozzo/Desktop/favilla_blaze_ipadapter.json"
    with open(path) as f:
        wf = json.load(f)
    base_wf_nodes = wf["nodes"]
    base_wf_links = wf["links"]
    print(f"   {len(base_wf_nodes)} nodes, {len(base_wf_links)} links")

    # 4. Generate each scene
    for i, scene in enumerate(SCENES):
        print(f"\n{'='*60}")
        print(f"[{i+1}/{len(SCENES)}] {scene['file']}")
        print(f"{'='*60}")

        api_prompt = build_api_prompt(
            base_wf_nodes, base_wf_links, object_info, scene
        )

        prompt_id = queue_api_prompt(api_prompt)
        if not prompt_id:
            continue

        images = wait_for_completion(prompt_id)
        if images:
            print(f"  ✅ Generated: {images}")
            copied = copy_images_to_project(images)
        else:
            print(f"  ⚠️  Timeout — check ComfyUI GUI at http://127.0.0.1:8188")

        # Small delay between scenes
        time.sleep(2)

    print(f"\n{'='*60}")
    print("✅ GENERAZIONE COMPLETATA!")
    print(f"   Immagini salvate in: {OUTPUT_DIR}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
