# Copilot Instructions — FavillApp

## Build & Run Commands

### Flutter App
```bash
# Run (debug) — sempre con dart-defines
./run.sh
# oppure:
flutter run --dart-define-from-file=dart_defines.json

# Release APK
flutter build apk --release --dart-define-from-file=dart_defines.json

# Lint
flutter analyze

# Tests
flutter test
# File singolo
flutter test test/widget_test.dart
```

### Cloudflare Worker (`worker/`)
```bash
cd worker
npm install
cp .dev.vars.example .dev.vars   # aggiungi ADMIN_TOKEN
npm run dev          # locale su http://127.0.0.1:8787
npm run typecheck    # TypeScript check
npm run deploy       # deploy su Cloudflare
curl http://127.0.0.1:8787/health   # smoke test
```

## Architettura

Il progetto ha due componenti indipendenti:

### 1. Flutter App (`lib/`)
Fumetto digitale episodico con sistema RPG e mappa del mondo esplorabile.

**Flusso di gioco:**
```
Home → Prologo → (completato) → Mappa di Nova Tutinia → Quest → Mappa
```
Il prologo è il punto di ingresso obbligatorio. Al completamento, `WorldStateService.completeQuest('prologo')` sblocca la mappa. Da lì, ogni quest è avviata tramite `QuestLoaderPage` e al termine torna alla mappa.

**Struttura `lib/`:**
- `models/` — Modelli dati puri con factory `fromJson`:
  - `comic_data.dart` — gerarchia contenuti: `EpisodeContent → ComicPage → Panel → TextBlock/Choice/Branch`
  - `game_state.dart` — 4 stat RPG: `segreto`, `legame`, `scintille`, `resistenza` (0–100)
  - `world_map.dart` — `WorldMap → WorldLocation → WorldQuest`, con `WorldState`
  - `ComicIndex` — solo registry personaggi (characters); **non contiene più la lista episodi**

- `services/` — Due pattern:
  - **Singleton** (`GameStateService.instance`, `WorldStateService.instance`): costruttore `._()`, devono essere inizializzati in `main()` via `.init()`
  - **Statici** (`SettingsService`, `ProgressService`, `ComicLoader`): metodi statici + `ValueNotifier` per UI reattiva
  - Persistenza sempre via `SharedPreferences`; convenzione chiavi: `<service>.<campo>` (es. `game_state.segreto`)

- `pages/` — `HomeCoverPage`, `SettingsPage`, `WorldMapPage`
- `widgets/` — `ComicPageStage`, `ComicTextBlockWidget`, `ChoiceCard`, `StatsHudWidget`, `StatEffectToast`
- `l10n/app_strings.dart` — Stringhe bilingui manuali (IT default, EN override)

### 2. Cloudflare Worker (`worker/`)
Worker Hono/TypeScript per la feature **"Chiedi a Favilla reale"**: coda moderata di domande utenti → risposta manuale dell'autrice via pagina admin.

- Non usa AI/LLM — nessuna chiamata a Gemini
- `/v1/ask-real` — invia domanda (rate limit via `AI_KV`)
- `/admin/*` — moderazione protetta da `ADMIN_TOKEN` (Bearer)
- `/health` — smoke test

## Convenzioni chiave

### Flusso completamento prologo
`_startPrologo()` e `_continuePrologo()` in `HomeCoverPage` passano sempre `onEpisodeCompleted: () => WorldStateService.instance.completeQuest('prologo')`. Senza questo, la mappa non si sblocca (il check usa `WorldState.completedQuests`, non `ProgressService`).

### Struttura JSON quest
I contenuti vivono in `assets/data/`:
- `comic_index.json` — solo `characters` (id, display_name, role, variant)
- `world_map.json` — location e quest con `requires_completed`, `requires_stats`, `unlock_after_quest`
- `assets/data/episodes/prologo.json` — il prologo
- `assets/data/quests/<id>.json` — ogni quest della mappa

Una quest può avere `branches` (map id→Branch) e `epilogue` (Branch). La `choice` è su una `ComicPage` e ogni `ChoiceOption.gotoBranch` punta a una chiave in `branches`.

### Localizzazione
`ComicLoader._loadLocalized()` prova prima `<asset>.<lang>.json` (es. `prologo.en.json`) prima del file di default. Per localizzare una quest, aggiungi `<id>.en.json` nella stessa directory.

### Regole quest (design)
Ogni quest deve rispettare: obiettivo chiaro, motivazione credibile, ricompensa significativa (effetti stat o sblocco location), almeno una scelta con conseguenze, contesto narrativo radicato nel mondo. **Regola d'oro: al termine della quest qualcosa deve essere cambiato** — nel mondo, nel personaggio o nelle stat.

### Personaggi
I character ID (`favilla`, `favilla_blaze`, `sparkle_ale`, `mallow`, `mallow_bellow`, `lex`) sono definiti in `comic_index.json`. Usare sempre `ComicIndex.getSpeakerName(id)` per il nome visualizzato — mai hardcoded.

### Sentry
In `kDebugMode`, `beforeSend` restituisce `null` — gli eventi non vengono inviati in sviluppo locale.

