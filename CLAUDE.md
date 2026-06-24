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
