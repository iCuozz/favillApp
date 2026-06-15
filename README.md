# 🔥 FavillApp — Favilla Blaze

![Status](https://img.shields.io/badge/status-S1%20completa%20(15%20episodi)-22c55e)
![Flutter](https://img.shields.io/badge/Flutter-Android%20%2F%20iOS-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart&logoColor=white)

**FavillApp** è un fumetto digitale episodico con elementi RPG, dedicato all'universo di **Favilla Blaze**: una mamma collaboratrice scolastica che scopre di avere superpoteri e deve tenerli nascosti mentre gestisce casa, figlio, marito e 50 piccoli uragani a scuola.

Il caffè è la sua kryptonite. Il figlio Lex è l'unico testimone. Il marito Mallow non deve sapere.

---

## 📖 Stagione 1 — "Alba Strana" (15 episodi)

### Episodi principali
| # | Episodio | Location | Tono |
|---|---|---|---|
| P | **Prologo** - *Una Mattina Qualunque* | Scuola → Casa | Nascita dei poteri |
| 1 | **La Mattina Dopo** | Casa | Kryptonite del caffè |
| 2 | **Una Giornata Normale** | Scuola | La Corvi, primi segni |
| 3 | **Il Ritorno a Casa** | Casa | Lex tenta di svelare il segreto |
| 4 | **La Spesa del Sabato** | Supermercato | Lex Strike! + Carmela |
| 5 | **La Domenica al Parco** | Parco | Rincorsa, trasformazione pubblica |
| 6 | **Un Giorno al Mare** 🏖️ | Spiaggia | *Condizionale: resistenza < 30* |
| 6alt | **GalaxiaMall** 🛍️ | Centro Commerciale | *Condizionale: resistenza ≥ 30* |
| 7 | **Il Lunedì dell'Asilo** | Casa | Lex cracka la password |
| 7.5 | **La Palestra** 🏋️ | Palestra | *Condizionale: resistenza < 40* |
| 8 | **L'Allagamento** | Scuola | Thriller: Corvi + porta bloccata |
| 9a | **La Prima Conseguenza** | Casa | *Flag: favilla_transformed_public* |
| 9b | **La Comare** | Casa | *Flag: carmela_ha_notato* |
| 9c | **Cena di Famiglia** | Casa | *Stat: legame ≥ 70* |

### Episodi condizionali S1 (fork binari)
| Fork | Condizione | Episodio A | Episodio B |
|---|---|---|---|
| Dopo EP5 | resistenza < 30 / ≥ 30 | EP6 🌊 Mare | EP6alt 🛍️ Mall |
| Dopo EP9 | segreto ≤ 10 / > 10 + `lex_ha_un_piano` | 💔 **La Crepa** | 🎨 **Il Disegno di Lex** |

---

## 🎮 Meccaniche

### Sistema RPG (4 stat)
| Stat | Descrizione | Floor |
|---|---|---|
| 🔒 **Segreto** | Quanto il segreto di Favilla è al sicuro | **5** |
| 💞 **Legame** | Intensità del rapporto con Mallow e Lex | 0 |
| ✨ **Scintille** | **Forza in combattimento.** Influenza i minigame di potenza. | 0 |
| 💪 **Resistenza** | Capacità di reggere il caos quotidiano | **1** |

- **Scintille ≥ 10** → Favilla può trasformarsi in Favilla Blaze
- **Scintille < 10** → Trasformazione impossibile

### ☕ Kryptonite del caffè
Il caffè non alimenta più i poteri — **li spegne**: `✨ Scintille -8, 💪 Resistenza +1`.

### ⚡ Scintille = Forza in combattimento
Scintille influenza la difficoltà dei minigame `respira`, `rincorsa`, `rincorsa_lex`:
`modifier = ((scintille - 50) / 10 × 0.05), clamped [-0.25, +0.25]`

### 🎯 Minigame
| Minigame | Episodio | Meccanica |
|---|---|---|
| `respira` | EP1 | Tap rapido + beat bar, scalato con Scintille |
| `schiva_lex` | EP3 | 3 round schivate a tempo |
| `lex_strike` | EP4 | Slingshot, 12 prodotti, chain reaction |
| `rincorsa` | EP5 | Temple Run bosco, 3 corsie, gap tap |
| `rincorsa_lex` | EP6 | Temple Run spiaggia, Lex verso il mare |
| `carmela_dialogo` | EP6alt / EP9b | Quick-time dialogo, timer decrescente |
| `crack_password` | EP7 | Baby Mastermind, 4 simboli |
| `lockpick` | EP8 | 5 perni, timing window |
| `mash_door` | EP8 | Mash rapido sfondamento |
| `disegna` | EP9c | Stealth drawing sabotage |
| `quasi_confessa` | 💔 La Crepa | Dialogo a tempo vero/sfumato |
| `costruzione` | 🎨 Disegno di Lex | Assemblaggio rilevatore |

### 🏴 World Flags
Flag che persistono tra episodi e sbloccano contenuti condizionali:
`shirt_in_backpack`, `favilla_transformed_public`, `carmela_ha_notato`, `lex_ha_un_piano`, `video_virale_visto`, `carmela_respinta`, `carmela_segno`, `cena_famiglia_fatta`, `quasi_confessato`, `detector_costruito`, `crepa_svolta`, `crepa_silenzio`.

---

## 🗺️ Location di Nova Tutinia

| Location | Sblocco |
|---|---|
| 🏠 Casa | Default |
| 🏫 Scuola | Dopo EP1 |
| 🛒 Supermercato | Dopo EP3 |
| 🌳 Parco | Dopo EP4 |
| 🏖️ Mare | Dopo EP5 se resistenza < 30 |
| 🛍️ GalaxiaMall | Dopo EP5 se resistenza ≥ 30 |
| 🏫🧸 Asilo | Dopo EP7 (sempre) |
| 🏋️ Palestra | Dopo EP7 se resistenza < 40 |

---

## 🧱 Struttura tecnica

Ogni episodio è un file JSON in `assets/data/quests/`:

```json
{
  "id": "s1_mattina_dopo",
  "pages": [ ... ],
  "branches": { "branch_id": { "pages": [...] } },
  "epilogue": { "pages": [...] },
  "stat_entry": [ ... ]
}
```

**Tipi di text_block:** `narration`, `dialogue` (richiede `speaker`), `thought`, `system`
**Personaggi:** definiti in `assets/data/comic_index.json`
**Mappa:** location e quest in `assets/data/world_map.json`
**Localizzazione:** `file.en.json` = traduzione inglese (struttura identica, solo testi)

---

## ⚙️ Comandi

```bash
# Avvia in debug (VS Code: F5)
flutter run --dart-define-from-file=dart_defines.json

# Build APK release
flutter build apk --release --dart-define-from-file=dart_defines.json

# Build iOS release
flutter build ios --release --dart-define-from-file=dart_defines.json

# Analisi statica
flutter analyze

# Test
flutter test

# Validazione narrativa (floor, soglie, worst-case)
python3 tools/validate_narrative.py
```

---

## 🛠️ Strumenti di authoring

| Strumento | Cosa fa |
|---|---|
| `tools/validate_narrative.py` | Verifica floor, soglie, worst-case su tutti i 15 episodi |
| `tools/hooks/pre-commit` | Hook git: validazione automatica prima del commit |
| `tools/install_hooks.sh` | Installa i pre-commit hooks |

---

## 📚 Documenti narrativi

I capisaldi della storia vivono in Obsidian (`docs/` → symlink):
- **NARRATIVE_BIBLE.md** — mondo, personaggi, stat, minigame, flag
- **Mappa Narrativa.md** — flow episodici, condizioni d'ingresso, grafi
- **Libro dei Mondi.md** — prosa completa con bivi
- **Idee & Direzioni Future.md** — planning e backlog

---

## 🌐 Localizzazione

- 🇮🇹 Italiano (sorgente canonico) — `assets/data/quests/*.json`
- 🇬🇧 Inglese — `assets/data/quests/*.en.json`

---

## 📦 Versioni

- **FavillApp:** 1.0.6+9
- **Flutter:** 3.10+
- **Dart:** 3.0+
- **Dipendenze:** Firebase, Sentry, TTS, audio

---

## 👥 Personaggi

| Personaggio | Ruolo | Sa del segreto? |
|---|---|---|
| **Favilla** | Collaboratrice scolastica, supereroina involontaria | 👑 |
| **Favilla Blaze** | Alter ego — quando i capelli si accendono | — |
| **Lex** | Figlio di 7 mesi e mezzo, testimone silenzioso | ✅ |
| **Mallow** | Marito, sviluppatore, bonaccione | ❌ (fino a S3+) |
| **Dott.ssa Corvi** | Ispettrice distrettuale, minaccia burocratica | ❌ |
| **Signora Carmela** | Vicina, parassita empatica | ⚠️ Sospetta |

---

## 📄 Licenza

© 2026 Andrea Cuozzo. All rights reserved.
Favilla Blaze — proprietà intellettuale riservata.
