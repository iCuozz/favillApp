# CLAUDE.md — FavillApp / Favilla Blaze

> Convenzioni di sviluppo per lavorare su questo progetto.
> Per i capisaldi narrativi vedi `docs/NARRATIVE_BIBLE.md`.
> Per le regole inviolabili vedi memoria `favillapp-capisaldi`.

## Comandi essenziali
```bash
# Validazione narrativa (DA ESEGUIRE dopo ogni modifica agli episodi)
python3 tools/validate_narrative.py

# Analisi statica
flutter analyze

# Test
flutter test

# Run
flutter run --dart-define-from-file=dart_defines.json
```

## Struttura progetto
```
assets/data/quests/s1/   → episodi JSON (IT + EN)
assets/data/comic_index.json → personaggi
assets/data/world_map.json   → location
lib/                        → codice Dart (Flutter)
lib/models/                 → GameState, ComicData, WorldMap
lib/services/               → game_state_service, comic_loader, audio, etc.
lib/widgets/                → minigame_*.dart (12 minigame), stats_hud, comic_page
lib/tools/                  → narrative_validator.dart (validazione runtime)
tools/                      → validate_narrative.py, translate_en.py, gen*.mjs/py
docs/                       → symlink a Obsidian (NARRATIVE_BIBLE, MAPPA_NARRATIVA, etc.)
test/                       → engine_test.dart (37 test), widget_test.dart (1 smoke)
```

## Modifiche agli episodi
1. Modificare `assets/data/quests/s1/<ep>.json` (IT, canonico)
2. Copiare la struttura in `<ep>.en.json` e tradurre i campi `text`, `label`, `hint`, `prompt`
3. Eseguire `python3 tools/validate_narrative.py`
4. Se il validatore segnala errori, correggere prima di committare

## Sistema stat
- Floor: Segreto≥5, Legame≥0, Scintille≥0, Resistenza≥1
- Valori iniziali: tutti 50
- Clamp: 0-100 (con floor specifici)
- Il motore filtra automaticamente le opzioni che violano i floor
- Le soglie narrative attivano branch `stat_entry` con `prepend: true`

## World flags
I flag booleani persistono tra episodi in `GameState.flags`.
Si impostano con `set_flags` nelle opzioni, si leggono con `flag_conditions` nei `stat_entry`.
Flag assente ≡ false.

## Documenti Obsidian
I file in `docs/` sono symlink a iCloud. Per modificarli:
```bash
readlink -f docs/NARRATIVE_BIBLE.md
# → /Users/andreacuozzo/Library/Mobile Documents/iCloud~md~obsidian/...
```
Usare il path reale per Read/Edit.

## 🎨 Generazione Immagini (OpenAI GPT Image 2)

### Comando unico
```bash
OPENAI_API_KEY=sk-... python3 tools/generate_images.py <episodio>
# genera TUTTO: main pages + branch + epilogue
```

### ⚠️ Chiave API — regola critica
**MAI salvare la chiave su file** (`.env`, script, o altro). Il provider la blocca se rileva storage su disco.
Passarla sempre e solo come variabile d'ambiente a runtime: `OPENAI_API_KEY=sk-...`

### Script canonico: `tools/generate_images.py`
- Raccoglie tutte le pagine con `collect_all_pages()`: main array, `branches.*.pages`, `epilogue.pages`
- Costruisce il prompt con `build_prompt(page_dict)` da descrizioni canoniche e testo narrativo
- Genera `.webp` a 1024×1536 (portrait 9:16), quality=medium, modello `gpt-image-2`
- Salva l'immagine nel path indicato dal campo `background` del JSON
- Salva anche un `.txt` con il prompt usato (per debug/ripetibilità)

### Prompt pattern (invariato per coerenza stilistica tra episodi)
```
CHARACTERS: [CHAR_DESC per ogni personaggio nella scena, separati da ;]
SETTING: [LOC_DESC — casa, scuola, strada_notte, camera_notte, casa_notte]
SCENE: [prime 2-3 frasi di narrazione dalla pagina]
MOOD: [warm / tense / power / sad, con injection descrittiva]
STYLE: Italian comic book illustration style, expressive line art, warm Mediterranean
       color palette, cinematic framing, Franco-Belgian comic style with bold clean black
       outlines, semi-flat colors, detailed backgrounds, emotional character expressions,
       soft natural lighting, 2D digital art, portrait 9:16 vertical composition,
       vibrant but grounded colors, no speech bubbles, no text, no watermarks.
IMPORTANT: No text, no letters, no speech bubbles, no watermarks, no signatures anywhere in the image.
```

### Specifiche tecniche immagini
- **Formato:** `.webp` (S1 episodi), `.png` (prologo legacy)
- **Dimensione:** 1024×1536 (portrait 9:16 verticale)
- **Qualità:** medium (bilancio costo/qualità)
- **Peso atteso:** 2.5–3.5 MB per immagine

### Descrizioni canoniche personaggi (da CHAR_DESC)
- **favilla:** bionda italiana early 30s, occhiali neri cat-eye, occhi nocciola, camicia bianca, jeans attillati, sneakers bianco-nere, sorriso caldo ma stanco
- **favilla_blaze:** trasformata: occhiali scomparsi, occhi ambra luminosi, capelli fuoco dorato fluttuante, aureola di fiamme, energia dorata attorno alle mani
- **lex:** 7 mesi, capelli castano chiaro a mini-mohawk, grandi occhi nocciola espressivi, due dentini, body morbido, sneakers rosse minuscole, guance paffute — **NON cammina**, sta in seggiolone o in braccio
- **mallow:** italiano early 30s, mini-mohawk castano, polo azzurra, jeans dritti, sneakers gialle alte, espressione tranquilla, laptop argentato
- **carmela:** anziana italiana, cappello di paglia o chignon, occhi viola tenue, vestito floreale, carrello blu della spesa, presenza inquietante
- **corvi:** ispettrice scolastica 50 anni, espressione severa, blazer scuro, tailleur, tacchi, cartella in pelle
- **bambini:** gruppo caotico di bambini 6-10 anni, uniformi colorate, capelli spettinati, zaini
- **gatto:** Filippo, gatto nero lucido, occhi giallo-verdi penetranti, movimenti silenziosi, sempre vigile

### Checklist per ogni nuovo episodio
1. Identificare tutte le immagini necessarie: `jq -r '..|.background?|select(.)' assets/data/quests/s1/<ep>.json | sort -u`
2. Verificare che Lex sia descritto come infante NON deambulante nel prompt
3. Impostare `OPENAI_API_KEY` a runtime (mai su file)
4. Lanciare `python3 tools/generate_images.py <ep>`
5. Verificare: `ls -lh assets/episodes/s1/<ep>/`
