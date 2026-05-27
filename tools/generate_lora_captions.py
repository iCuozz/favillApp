#!/usr/bin/env python3
"""
generate_lora_captions.py
Genera i file .txt di caption per il training LoRA di FavillApp.

Uso:
    python3 tools/generate_lora_captions.py --dir ~/Desktop/favilla_training --character favilla
    python3 tools/generate_lora_captions.py --dir ~/Desktop/mallow_training --character mallow

Per ogni immagine nella cartella chiede interattivamente la descrizione della scena
e scrive il file .txt corrispondente con la caption nel formato corretto per Replicate.

Formati immagine supportati: .jpg, .jpeg, .png, .webp
"""

import os
import sys
import argparse
from pathlib import Path

CHARACTERS = {
    "favilla": {
        "trigger": "FAVILLA_lora",
        "hints": [
            "standing in a kitchen",
            "standing in a school corridor, blue school smock",
            "close-up portrait, cat-eye glasses",
            "sitting at a table",
            "smiling warmly",
            "serious expression",
            "surprised expression",
            "tired expression",
            "full body, white background",
        ],
    },
    "mallow": {
        "trigger": "MALLOW_lora",
        "hints": [
            "sitting at a desk with a laptop",
            "standing in a kitchen",
            "close-up portrait, dark stubble",
            "distracted on a call with headphones",
            "calm analytical expression",
            "full body, white background",
        ],
    },
    "lex": {
        "trigger": "LEX_lora",
        "hints": [
            "in a wooden highchair, laughing",
            "in a baby crib, awake",
            "close-up, two tiny bottom teeth visible",
            "arms raised, excited expression",
            "intense stare",
            "full body, white background",
        ],
    },
}

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
STYLE_SUFFIX = "digital comic illustration style, semi-flat colors, bold clean black outlines"


def find_images(directory: Path) -> list[Path]:
    images = sorted([
        p for p in directory.iterdir()
        if p.suffix.lower() in IMAGE_EXTENSIONS
    ])
    return images


def caption_exists(image_path: Path) -> bool:
    return image_path.with_suffix(".txt").exists()


def write_caption(image_path: Path, caption: str):
    txt_path = image_path.with_suffix(".txt")
    txt_path.write_text(caption, encoding="utf-8")
    print(f"  ✅ Scritto: {txt_path.name}")


def build_caption(trigger: str, scene: str) -> str:
    return f"{trigger}, {scene}, {STYLE_SUFFIX}"


def interactive_mode(directory: Path, character: str):
    config = CHARACTERS[character]
    trigger = config["trigger"]
    hints = config["hints"]

    images = find_images(directory)
    if not images:
        print(f"❌ Nessuna immagine trovata in {directory}")
        sys.exit(1)

    total = len(images)
    existing = sum(1 for img in images if caption_exists(img))

    print(f"\n📁 Cartella: {directory}")
    print(f"🖼  Immagini trovate: {total} ({existing} caption già esistenti)\n")
    print(f"Trigger word: {trigger}")
    print(f"Suffix fisso: {STYLE_SUFFIX}\n")
    print("─" * 60)
    print("Suggerimenti descrizione scena:")
    for i, hint in enumerate(hints, 1):
        print(f"  {i}. {hint}")
    print("─" * 60)
    print("Per ogni immagine: scrivi la descrizione della scena (o numero suggerimento).")
    print("Lascia vuoto per saltare. 'q' per uscire.\n")

    processed = 0
    for idx, image_path in enumerate(images, 1):
        if caption_exists(image_path):
            print(f"[{idx}/{total}] {image_path.name} → già captionata, skip")
            continue

        print(f"\n[{idx}/{total}] {image_path.name}")
        print(f"  → Apri il file per vederla: open '{image_path}'")

        while True:
            raw = input("  Descrizione scena: ").strip()

            if raw.lower() == "q":
                print(f"\n✅ Completato. Caption scritte: {processed}")
                sys.exit(0)

            if raw == "":
                print("  ⏭  Saltata.")
                break

            # Gestisci numero suggerimento
            if raw.isdigit():
                n = int(raw)
                if 1 <= n <= len(hints):
                    raw = hints[n - 1]
                    print(f"  → Usando suggerimento {n}: {raw}")
                else:
                    print(f"  ⚠️  Numero fuori range (1–{len(hints)}), riprova.")
                    continue

            caption = build_caption(trigger, raw)
            print(f"  Caption: {caption}")
            confirm = input("  Confermi? [Invio=sì / r=riscrivi]: ").strip().lower()

            if confirm == "r":
                continue

            write_caption(image_path, caption)
            processed += 1
            break

    print(f"\n✅ Completato. Caption scritte: {processed}/{total}")
    print(f"\nProssimo passo: crea uno ZIP di '{directory}' e caricalo su Replicate.")
    print("  cd " + str(directory.parent))
    print(f"  zip -r {character}_training.zip {directory.name}/")


def batch_mode(directory: Path, character: str, scene: str):
    """Applica la stessa caption a tutte le immagini senza caption."""
    config = CHARACTERS[character]
    trigger = config["trigger"]

    images = find_images(directory)
    caption = build_caption(trigger, scene)

    print(f"\nCaption da applicare: {caption}")
    print(f"Immagini senza caption: {sum(1 for img in images if not caption_exists(img))}\n")

    for image_path in images:
        if caption_exists(image_path):
            print(f"  Skip: {image_path.name} (già presente)")
            continue
        write_caption(image_path, caption)

    print("\n✅ Fatto.")


def main():
    parser = argparse.ArgumentParser(
        description="Genera caption .txt per il training LoRA di FavillApp"
    )
    parser.add_argument("--dir", required=True, help="Cartella con le immagini di training")
    parser.add_argument(
        "--character",
        required=True,
        choices=list(CHARACTERS.keys()),
        help="Personaggio da captionare",
    )
    parser.add_argument(
        "--batch-scene",
        metavar="SCENE",
        help="Modalità batch: applica questa scena a tutte le immagini senza caption",
    )

    args = parser.parse_args()
    directory = Path(args.dir).expanduser().resolve()

    if not directory.exists():
        print(f"❌ Cartella non trovata: {directory}")
        sys.exit(1)

    if args.batch_scene:
        batch_mode(directory, args.character, args.batch_scene)
    else:
        interactive_mode(directory, args.character)


if __name__ == "__main__":
    main()
