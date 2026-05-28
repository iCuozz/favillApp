# 🔥 FavillApp

![Status](https://img.shields.io/badge/status-in%20sviluppo-f59e0b)
![Flutter](https://img.shields.io/badge/Flutter-Android%20%2F%20iOS-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-app-blue?logo=dart&logoColor=white)

**FavillApp** è un fumetto digitale episodico con elementi RPG, dedicato all'universo di **Favilla Blaze**: una mamma collaboratrice scolastica che scopre di avere superpoteri e deve tenerli nascosti mentre gestisce casa, figlio, marito e 50 piccoli uragani a scuola.

---

## 🦸 Universo narrativo

### Favilla / Favilla Blaze
L'eroina principale. Collaboratrice scolastica di giorno, supermamma di notte — sospesa tra quotidianità e immaginario supereroistico. Ironica, affettuosa, stanca il giusto.

### Lex
Il figlio piccolo (7 mesi e mezzo). Caos puro, adorabile. L'unico che sa davvero cosa è sua madre.

### Mallow Bellow
Il marito. Sviluppatore software, presenza costante, occhio attento. Sospetta. Forse.

### Sparkle Ale
Presenza ricorrente nell'universo. Energia, caos, meraviglia.

---

## 🚀 Funzionalità principali

- **Prologo** — la storia inizia con il risveglio dei poteri di Favilla
- **Mappa di Nova Tutinia** — mondo esplorabile con location che si sbloccano avanzando
- **Quest narrative** — missioni a fumetto con pagine illustrate, dialoghi e pannelli
- **Branching con conseguenze** — le scelte cambiano lo stato RPG e la direzione narrativa
- **Sistema RPG a 4 stat** — Segreto, Legame, Scintille, Resistenza (0–100)
- **Lettura ad alta voce** — TTS on-device, voce diversa per personaggio (offline, gratis)
- **Localizzazione** — italiano (default) e inglese, con fallback automatico sui JSON

---

## 🗺️ Flusso di gioco

```
Avvio app
  └─► Prologo ("L'ombra della fiamma")
        └─► Completato → Mappa di Nova Tutinia
              └─► Location sbloccate → Quest disponibili
                    └─► Scelta → Branch narrativo → Effetti stat → Nuove location
```

Il prologo è sempre il punto di ingresso. Una volta completato, la mappa diventa il hub centrale da cui si avvia ogni quest.

---

## 🧱 Struttura contenuti

Ogni quest è un file JSON in `assets/data/quests/`:

```json
{
  "id": "s1_mattina_dopo",
  "pages": [
    {
      "index": 0,
      "background": "assets/episodes/s1_mattina_dopo/page_0.webp",
      "panels": [
        {
          "id": "md0_0",
          "characters": ["favilla"],
          "text_blocks": [
            { "id": "md0_0_tb_0", "type": "narration", "text": "5:12 del mattino." },
            { "id": "md0_0_tb_1", "type": "thought",   "text": "E io sono qui sveglia." }
          ],
          "interactions": []
        }
      ],
      "choice": {
        "id": "reazione",
        "prompt": "Come reagisce Favilla?",
        "options": [
          {
            "id": "sorriso",
            "label": "Un sorriso — piccolo, caldo.",
            "goto_branch": "branch_sorriso",
            "stat_effects": { "segreto": 10, "legame": 5 }
          }
        ]
      }
    }
  ],
  "branches": { "branch_sorriso": { "pages": [] } },
  "epilogue":  { "pages": [] }
}
```

**Tipi di `text_block`:** `narration`, `dialogue` (richiede `speaker`), `thought`, `system`  
**Personaggi:** definiti in `assets/data/comic_index.json` (id, display_name, ruolo)  
**Mappa:** location e quest definite in `assets/data/world_map.json`

---

## ⚙️ Comandi

```bash
# Setup dopo clone (abilita i pre-commit hooks)
git config core.hooksPath .github/hooks

# Avvia in debug (con dart-defines)
./run.sh

# Build APK release
flutter build apk --release --dart-define-from-file=dart_defines.json

# Analisi statica
flutter analyze

# Test
flutter test

# Verifica coerenza narrativa manuale
node .github/skills/narrative-flow-checker/scripts/check-narrative-flow.cjs .
```

In VS Code basta **F5**: il launch profile legge già `dart_defines.json`.

> **Pre-commit hooks** — ogni commit che tocca `assets/data/quests/` o `comic_data.dart` esegue automaticamente il **narrative-flow-checker** (256 percorsi simulati) e blocca il commit se trova inconsistenze. Richiede `git config core.hooksPath .github/hooks` dopo ogni clone.

---

## 🌐 Worker (Cloudflare)

Il Worker gestisce la feature "Chiedi a Favilla reale" — una coda moderata di domande degli utenti a cui risponde l'autrice. Vedere [`worker/README.md`](worker/README.md).
