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

# Test (39 test)
flutter test

# Run
flutter run --dart-define-from-file=dart_defines.json
```

## Struttura progetto
```
assets/data/quests/s1/      → episodi JSON (IT = canonico, EN = traduzione)
assets/episodes/s1/<ep>/    → immagini .webp + prompt .txt generati
lib/                        → codice Dart (Flutter)
lib/models/                 → GameState, ComicData, WorldMap
lib/services/               → game_state_service, comic_loader, audio
lib/widgets/                → minigame_*.dart (12 tipi), stats_hud, comic_page
lib/tools/                  → narrative_validator.dart
tools/                      → generate_images.py, validate_narrative.py, translate_en.py
tools/episode_prompts/      → prompt globali per episodio (<ep_id>.txt)
tools/page_prompts/<ep_id>/ → prompt per singola pagina (label dello script)
docs/                       → symlink a Obsidian
test/                       → engine_test.dart (39 test), widget_test.dart (1 smoke)
```

## Modifiche agli episodi
1. Modificare `assets/data/quests/s1/<ep>.json` (IT, canonico)
2. **⚠️ Ogni pannello DEVE avere `characters` popolato** — mai array vuoto. L'AI senza characters non sa chi disegnare.
3. Copiare la struttura in `<ep>.en.json` e tradurre i campi `text`, `label`, `hint`, `prompt`
4. Eseguire `python3 tools/validate_narrative.py`
5. Se il validatore segnala errori, correggere prima di committare

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

### Comando
```bash
python3 tools/generate_images.py <episodio> --all
# La chiave API viene letta automaticamente da tools/.gpt_key (NON committare quel file)
```

### Come funziona `build_prompt()` (ordine delle sezioni)
1. **PAGE DETAILS** — dal page prompt (`tools/page_prompts/<ep>/<label>.txt`)
2. **EPISODE CONSISTENCY** — dall'episode prompt (`tools/episode_prompts/<ep>.txt`)
3. **CHARACTERS** — da `EP_CHAR_OVERRIDES[ep]` o `CHAR_DESC` (descrive i personaggi del pannello)
4. **SETTING + LOCATION DETAILS** — da `world_bible.json`
5. **SCENE** — prime frasi di narrazione dal JSON
6. **MOOD** — rilevato automaticamente (warm/tense/power/sad)
7. **STYLE + IMPORTANT** — fissi, mai troncati

### ⚠️ Regola critica: nomi dei page prompt
I file in `tools/page_prompts/<ep>/` devono avere il nome ESATTO della label usata dallo script:
- Main pages: `page_0.txt`, `page_1.txt`, …
- Branch: `branch_tardi_0.txt`, `branch_prima_1.txt`, …
- Stat entry: `intro_mani_calde.txt`, `intro_esausta.txt`
- Epilogue: `epilogue_ottimista.txt`, `epilogue_cauta.txt`

Lo script cerca `<label>.txt` con `/` → `_`. Se il file non esiste, PAGE DETAILS viene saltato e l'immagine non è fedele alla scena.

### EP_CHAR_OVERRIDES
In `generate_images.py`, la sezione `EP_CHAR_OVERRIDES[ep_id]` sovrascrive `CHAR_DESC` per i personaggi di quell'episodio.
Qui vanno definiti i VESTITI ESATTI dell'episodio. La descrizione DEVE essere identica in ogni punto:
- CHARACTERS (inglese, da EP_CHAR_OVERRIDES)
- EPISODE CONSISTENCY (italiano, da episode prompt)
- PAGE DETAILS / DETTAGLI (italiano, da ogni page prompt)

### Prompt trimming
Il contenuto (escluso STYLE+IMPORTANT) viene troncato a **800 parole**. Se l'episode prompt è troppo lungo, le parti importanti in fondo (SCENE, MOOD) vengono tagliate. Tenere l'episode prompt CONCISO (~100 parole).

### Specifiche immagini
- **Formato:** `.webp`, 1024×1536 (9:16 verticale)
- **Modello:** `gpt-image-2`, quality=medium
- **Peso atteso:** 2.5–3.5 MB

### Descrizioni canoniche personaggi (CHAR_DESC base)
- **favilla:** bionda italiana early 30s, occhiali neri cat-eye, occhi nocciola, camicia bianca, jeans attillati, sneakers bianco-nere, sorriso caldo ma stanco
- **favilla_blaze:** trasformata: occhiali scomparsi, occhi ambra luminosi, capelli fuoco dorato fluttuante, aureola di fiamme, energia dorata attorno alle mani
- **lex:** 7 mesi, capelli castano chiaro a mini-mohawk, grandi occhi nocciola espressivi, due dentini, body morbido, guance paffute — **NON cammina**, sta in seggiolone/braccio/carrello. **Ogni episodio sovrascrive i vestiti via EP_CHAR_OVERRIDES.**
- **mallow:** italiano early 30s, mini-mohawk castano, **maglietta NERA con PIPISTRELLO GIALLO** (mai polo azzurra), jeans dritti, **CONVERSE GIALLE** (mai altre scarpe), espressione tranquilla
- **carmela:** anziana italiana, capelli bianchi in chignon, occhi **VIOLA TENUE**, vestito floreale (toni azzurro-lilla), cestino di vimini, presenza inquietante. **OGNI EPISODIO PUÒ VARIARE I SUOI VESTITI** — definire sempre in EP_CHAR_OVERRIDES.
- **corvi:** ispettrice scolastica 50 anni, espressione severa, blazer scuro, tailleur, tacchi, cartella in pelle
- **bambini:** gruppo caotico di bambini 6-10 anni, uniformi colorate, capelli spettinati, zaini
- **gatto:** Filippo, gatto nero lucido, occhi giallo-verdi penetranti, movimenti silenziosi, sempre vigile

### Checklist per ogni nuovo episodio
1. Identificare tutte le immagini necessarie: `jq -r '..|.background?|select(.)' assets/data/quests/s1/<ep>.json | sort -u`
2. **Verificare che NESSUN pannello abbia `characters: []` vuoto** — è la causa #1 di immagini sbagliate
3. Creare `tools/episode_prompts/<ep_id>.txt` (CONCISO, ~100 parole, niente vestiti duplicati)
4. Creare `tools/page_prompts/<ep_id>/<label>.txt` per OGNI label unica (usare i nomi esatti dello script)
5. Aggiornare `EP_CHAR_OVERRIDES` in `generate_images.py` con i vestiti dell'episodio
6. Lanciare `python3 tools/generate_images.py <ep> --all`
7. Verificare: `ls -lh assets/episodes/s1/<ep>/`
