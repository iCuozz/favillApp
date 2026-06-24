# 🎬 FavillApp — Standard di Generazione Scene

> **Scopo:** Definire un unico formato autorevole per tutte le scene (JSON episodio), eliminando le attuali inconsistenze di naming e struttura. Ogni nuovo episodio DEVE rispettare queste regole.

---

## 1. Architettura del File Episodio

```
assets/data/quests/
  <episodio>.json          # 🇮🇹 IT — sorgente canonico
  <episodio>.en.json       # 🇬🇧 EN — traduzione (solo campi testo)
```

**Regola:** I file IT ed EN condividono IDENTICA struttura. Solo `text`, `label`, `hint`, `prompt` differiscono. Id, flag, branch name, chiavi tecniche restano invariati.

---

## 2. Struttura JSON — Schema Completo

```jsonc
{
  // === META ===
  "id": "s1_episodio_id",              // kebab-case, univoco
  "audio_theme": "nome_tema",          // opzionale, file in assets/audio/ambient/

  // === STAT ENTRY (opzionale) ===
  "stat_entry": [ /* vedi §3 */ ],

  // === PAGINE PRINCIPALI ===
  "pages": [ /* vedi §4 */ ],

  // === BRANCH (opzionale) ===
  "branches": { /* vedi §7 */ },

  // === EPILOGO (opzionale) ===
  "epilogue": { /* Branch con unico scopo: finale */ }
}
```

---

## 3. Stat Entry — Regole d'Ingresso

Valutate in ordine. La PRIMA che fa match determina il branch d'ingresso.

```jsonc
{
  "stat_entry": [
    // Priorità 0: condizione più restrittiva per prima
    {
      "stat": "segreto",
      "op": "lte",
      "value": 10,
      "goto_branch": "intro_precaria",
      "prepend": true              // anteposto alle pagine principali
    },
    // Priorità 1: condizione AND
    {
      "all_of": [
        { "stat": "segreto", "op": "lt", "value": 50 },
        { "stat": "resistenza", "op": "gte", "value": 55 }
      ],
      "goto_branch": "intro_particolare",
      "flag_conditions": [         // flag in AND con le stat
        { "flag": "carmela_ha_notato", "is": true }
      ]
    }
  ]
}
```

**Regole:**
- Ordinare dalla condizione PIÙ RESTRITTIVA alla più lasca (match anticipato)
- `prepend: true` = antepone il branch alle pagine principali (es. intro condizionali)
- `prepend: false` (default) = sostituisce le pagine principali
- Non mischiare flag_conditions con `all_of` se non serve — `all_of` + `flag_conditions` è sempre AND
- Single-stat è preferibile a `all_of` con un solo elemento

---

## 4. Pagine — Struttura

```jsonc
{
  // Per le pagine principali (pages[]):
  "index": 0,                     // SEMPRE integer, progressivo

  // Per le pagine nei branch/epilogo:
  "id": "bb_p0",                  // SEMPRE stringa univoca (codice:branch_pagina)

  // Campi comuni:
  "background": "assets/episodes/s1/s1_esempio/page_0.webp",
  "panels": [ /* §5 */ ],
  "choice": { /* §6 — opzionale */ },
  "vfx": { /* §8 — opzionale */ }
}
```

### 4.1 Regola Page ID

| Dove | Campo | Formato | Esempio |
|------|-------|---------|---------|
| `pages[]` (main) | `index` | integer, 0-based | `"index": 0` |
| `branches[].pages[]` | `id` | `<prefix>_p<#>` | `"id": "bb_p0"` |
| `epilogue.pages[]` | `id` | `ep_p<#>` | `"id": "ep_p0"` |

**MAI usare `id` e `index` insieme sulla stessa pagina.**

### 4.2 Background

Pattern del path:
```
assets/episodes/s1/<episodio_id>/page_<branch_prefix>_<#>.webp
```

| Tipo | Path | Esempio |
|------|------|---------|
| Main | `assets/episodes/s1/s1_spesa_sabato/page_0.webp` | — |
| Branch | `assets/episodes/s1/s1_spesa_sabato/page_bt_0.webp` | `bt` = branch_tardi |
| Entry | `assets/episodes/s1/s1_spesa_sabato/page_entry.webp` | intro condizionali |
| Epilogo | `assets/episodes/s1/s1_spesa_sabato/page_epilogo.webp` | — |

---

## 5. Pannelli e Text Block

### 5.1 Panel

```jsonc
{
  "id": "ss0_0",                  // <episodio_prefix>_<pagina>_<pannello>
  "characters": [ "favilla", "lex" ],
  "text_blocks": [ /* §5.2 */ ],
  "interactions": [ /* §5.3 */ ]
}
```

### 5.2 Text Block — Schema OBBLIGATORIO

```jsonc
{
  "id": "ss0_0_tb_0",             // <panel_id>_tb_<#>
  "type": "narration",            // UNO di: narration | dialogue | thought | system
  "speaker": "favilla",           // OBBLIGATORIO se type=dialogue o type=thought
  "text": "Il testo narrativo."   // MAI vuoto
}
```

#### 5.2.1 Tipi di Text Block

| Type | Quando usare | `speaker` | Tono visivo |
|------|-------------|-----------|-------------|
| `narration` | Voce narrante esterna, descrizione | OMISSIS | Neutro |
| `dialogue` | Personaggio parla ad alta voce | OBBLIGATORIO | Dialogue focus |
| `thought` | Pensiero non detto (POV personaggio) | OBBLIGATORIO | Thought vignette |
| `system` | Testo diegetico (UI, telefono, SMS, schermate) | OMISSIS | System pulse |

⚠️ **REGOLE:**
- `type` è SEMPRE obbligatorio — MAI ometterlo
- `speaker` è OBBLIGATORIO per `dialogue` e `thought`
- `speaker` va OMESSO (non stringa vuota) per `narration` e `system`
- `"speaker": ""` NON è valido — o lo ometti o ci metti un id personaggio reale
- `text` non deve mai essere vuoto
- Massimo 6-7 text_blocks per panel (leggibilità mobile)

#### 5.2.2 Naming Convention ID

```
<ep_prefix>_<pagina>_<pannello>_tb_<progressivo>
```

| Elemento | Valore |
|----------|--------|
| ep_prefix | `ss` (spesa_sabato), `cr` (crepa), `dl` (disegno_lex) |
| pagina | `0`, `1`, `2`... per main; `p0`, `p1`... per branch/epilogo |
| pannello | lettera: `a`, `b` (se più pannelli per pagina) |
| progressivo | `0`, `1`, `2`... |

Esempi:
- `ss0_a_tb_0` → spesa_sabato, main page 0, pannello A, text block 0
- `ss0_a_tb_1` → spesa_sabato, main page 0, pannello A, text block 1
- `btp_0_a_tb_0` → branch_tardi_parziale, page 0, pannello A, text block 0
- `cr_p1_a_tb_4` → crepa, branch page 1, pannello A, text block 4

### 5.3 Interaction

```jsonc
{
  "interactions": [
    {
      "type": "transform",     // "transform" | "scene_change" | "sound"
      "target": "favilla",     // chi/subject dell'interazione
      "effect": "glow",        // effetto visivo
      "sound": "whoosh"        // opzionale, file in assets/audio/
    }
  ]
}
```

Attualmente non usato attivamente — placeholder per future animazioni panel-level.

---

## 6. Choice — Struttura delle Opzioni

```jsonc
{
  "choice": {
    "id": "crepa_choice",             // <ep_prefix>_choice_<nome>
    "prompt": "Contesto della scelta (testo descrittivo lungo).",
    "options": [
      {
        "id": "fidati",               // parola chiave, breve
        "label": "«Testo della scelta.»",  // visibile al giocatore
        "hint": "Sfumatura emotiva.",      // opzionale
        "goto_branch": "branch_svolta",    // branch di destinazione
        "stat_effects": { "segreto": 10, "legame": 3, "resistenza": -5 },
        "set_flags": { "crepa_svolta": true },
        "set_memories": { "choice.s1_crepa": "svolta" },
        "minigame": { /* §9 */ }          // opzionale
      }
    ]
  }
}
```

### 6.1 Regole Opzioni

- **Almeno 2 opzioni, mai più di 4** (schermo mobile)
- **Label in «»** per dialoghi diretti, **senza «»** per azioni descrittive
- **Label descrive l'azione**, non l'effetto — mai "Aumenta segreto"
- **Prompt è il setup narrativo** — frase breve (15-25 parole) che contestualizza
- **Hint è opzionale ma raccomandato** — dà al giocatore una sfumatura emotiva extra
- **Almeno un'opzione "sicura"** per ogni floor — regola d'authoring ferrea
- **stat_effects non deve mai far scendere una stat sotto floor** (validato da validate_narrative.py)
- **set_memories** sempre presente per tracciare le scelte del giocatore: formato `"choice.<episodio_id>": "<valore>"`

### 6.2 Label Convention

```
«dialogo diretto»   → il personaggio PARLA
Azione descrittiva   → il giocatore AGISCE
Opzione con hint     → "Azione." — hint: "Sfumatura emotiva"
```

---

## 7. Branch — Naming e Struttura

### 7.1 Naming Convention

```
<prefix>_<descrizione>
```

| Prefix | Uso | Esempi |
|--------|-----|--------|
| `intro_` | Stat entry branch (prepend) | `intro_mani_calde`, `intro_esausta` |
| `branch_` | Branch narrativo principale | `branch_tardi`, `branch_prima` |
| `epilogue_` | Branch finale (scelta epilogo) | `epilogue_ottimista`, `epilogue_cauta` |

<details>
<summary>Elenco completo prefixes usati</summary>

- `intro_*` — stat entry, prepend di solito
- `branch_*` — rami narrativi da scelta
- `epilogue_*` — finali alternativi (dentro epilogue.pages[].choice)
- Branche derivate: `branch_<nome>_<sottobranch>`

</details>

### 7.2 Regole Struttura

```jsonc
{
  "branch_tardi": {
    // id OPPURE index sulle pages interne (vedi §4.1)
    "pages": [ /* ... */ ]
  },
  "branch_tardi_parziale": {
    "skips_epilogue": true,           // evita l'epilogo globale
    "pages": [
      { "id": "btp_p0", /* ... */ },
      {
        "id": "btp_p1",
        // può avere una choice interna
        "choice": { /* ... */ }
      }
    ]
  }
}
```

### 7.3 skips_epilogue — Quando usarlo

- `true` se il branch ha una sua **risoluzione narrativa autonoma**
- I branch con `skips_epilogue: true` **possono avere una loro scelta interna** che porta a sub-branch
- I sub-branch devono concludere l'episodio (non si appoggiano all'epilogo globale)
- `false` (default) se il branch ha bisogno dell'epilogo globale

---

## 8. VFX — Effetti Visivi

```jsonc
{
  "vfx": {
    "scene": "rain",            // "rain" | "mist" | "lights" | "dust" (default)
    "focus": "dialogue",        // "dialogue" | "thought" | "system" | "neutral" (default)
    "force_power": false,       // true = forza modalità potenza
    "cinematic_bars": true,     // barre nere orizzontali
    "intensity": 1.0            // 0.25 — 2.0 (default 1.0)
  }
}
```

### 8.1 Regole VFX

- **Non specificare il default** — se scene=dust, focus=neutral, intensity=1.0, ometti il campo
- **Usare VFX solo quando serve** — non su ogni pagina
- `scene` è rilevato automaticamente dal background + testo se non specificato (keyword matching)
- `force_power: true` forza il glow arancione e lo shake
- `cinematic_bars: true` per momenti drammatici/trasformazioni
- `intensity > 1.0` per climax, `intensity < 1.0` per scene intime

### 8.2 Scene — Mappa Keyword

| scene | Keywords nel background/text |
|-------|-----------------------------|
| `rain` | allag, piogg, tempesta, storm, rain |
| `mist` | notte, night, ombra, fumo, smoke, foschia, fog, balcone |
| `lights` | galaxia, mall, centro_commerciale, parcheggio, led, neon |
| `dust` | *(fallback)* — nessuna keyword matchata |

---

## 9. Minigame Integration

```jsonc
{
  "minigame": {
    "type": "lex_strike",
    "products_total": 12,         // contestuale al tipo
    "duration_seconds": 9,        // per minigame a timer
    "rounds": 3,                  // per minigame a round
    "theme": "beach",             // tema visivo opzionale (rincorsa_lex)
    "tiers": [
      // Ordinati dal PIÙ ALTO al PIÙ BASSO (minProducts decrescente)
      { "min": 8,  "label": "STRIKE! 🎳",   "goto_branch": "branch_tardi",          "stat_effects": {...}, "set_flags": {...} },
      { "min": 3,  "label": "Colpo parziale","goto_branch": "branch_tardi_parziale", "stat_effects": {...} },
      { "min": 0,  "label": "Mancato!",      "goto_branch": "branch_tardi_mancato",  "stat_effects": {} }
    ]
  }
}
```

### 9.1 Regole Tier

- **Ordinamento decrescente** — primo tier = massimo punteggio
- **`goto_branch`** per tier sovrascrive il `goto_branch` dell'opzione padre
- **`stat_effects`** dell'opzione contiene il **worst-case** (usato dal filtro floor)
- Ogni tier deve rispettare i floor dato lo stato minimo in cui la scelta è visibile
- Tier con `goto_branch` che punta a un branch con `skips_epilogue: true` = percorso breve

---

## 10. Convenzione ID Completa

### 10.1 Episodio Prefix

| File | Prefix | Esempio ID panel |
|------|--------|-----------------|
| `prologo` | `pl` | `pl_p0_a` |
| `s1_mattina_dopo` | `md` | `md_0_a_tb_0` |
| `s1_scuola_1` | `sc1` | `sc1_0_a_tb_0` |
| `s1_ritorno_casa` | `rc` | `rc_0_a_tb_0` |
| `s1_spesa_sabato` | `ss` | `ss0_a_tb_0` |
| `s1_domenica_parco` | `dp` | `dp_0_a_tb_0` |
| `s1_mare` | `ma` | `ma_0_a_tb_0` |
| `s1_centro_commerciale` | `cc` | `cc_0_a_tb_0` |
| `s1_lunedi_asilo` | `la` | `la_0_a_tb_0` |
| `s1_palestra` | `pls` | `pls_0_a_tb_0` |
| `s1_allagamento` | `al` | `al_0_a_tb_0` |
| `s1_prima_conseguenza` | `pc` | `pc_0_a_tb_0` |
| `s1_comare` | `co` | `co_0_a_tb_0` |
| `s1_cena_famiglia` | `cf` | `cf_0_a_tb_0` |
| `s1_crepa` | `cr` | `cr_p0_a_tb_0` |
| `s1_disegno_lex` | `dl` | `dl_p0_a_tb_0` |

### 10.2 Pattern Completo ID

```
<prefix><pagina>_<pannello>_tb_<progressivo>
                ↓
          lettera: a, b, c
```

Per le pagine main:
```
ss0_a_tb_0    → spesa_sabato, page 0, pannello A, text block 0
ss0_a_tb_1    → spesa_sabato, page 0, pannello A, text block 1
ss1_a_tb_0    → spesa_sabato, page 1, pannello A, text block 0
```

Per le pagine branch (usano `p` invece del numero diretto):
```
cr_p0_a_tb_0  → crepa, page 0, pannello A, text block 0
bt_p0_a_tb_0  → branch_tardi, page 0, pannello A, text block 0
bt_p1_a_tb_0  → branch_tardi, page 1, pannello A, text block 0
bp_p0_a_tb_0  → branch_prima, page 0, pannello A, text block 0
```

Panel ID:
```
ss0_a      → spesa_sabato, page 0, pannello A
cr_p0_a    → crepa, page 0, pannello A
bt_p0_a    → branch_tardi, page 0, pannello A
```

Page ID (per branch pages):
```
bt_p0      → branch_tardi, page 0
bp_p0      → branch_prima, page 0
btp_p0     → branch_tardi_parziale, page 0
```

---

## 11. Regole Generali d'Authoring

### 11.1 Lunghezza e Struttura

| Campo | Max | Note |
|-------|-----|------|
| `prompt` (choice) | 25 parole | Contesto della scelta |
| `label` (option) | 8 parole | Azione del giocatore |
| `hint` (option) | 8 parole | Sfumatura emotiva |
| `text` (text_block) | 3 frasi | Se più lungo, spezza in più text_blocks |
| Text blocks per panel | 7 | Oltre è illeggibile su mobile |
| Panels per pagina | 1-2 | Più di 2 non sono supportati dal renderer attuale |

### 11.2 Tono e Voce

- **Narrazione**: terza persona, presente indicativo, ironia leggera
- **Dialogue**: personaggio parla — `speaker` OBBLIGATORIO
- **Thought**: corsivo mentale, POV del personaggio — `speaker` OBBLIGATORIO
- **System**: testi diegetici (UI, SMS, schermate) — MAI per narrazione

### 11.3 Personaggi

Gli ID personaggio nel campo `characters` e `speaker` devono corrispondere a quelli in `comic_index.json`:

| ID | Display Name |
|----|-------------|
| `favilla` | Favilla |
| `mallow` | Mallow |
| `lex` | Lex |
| `lex_pov` | *(voce interiore Lex)* |
| `carmela` | Signora Carmela |
| `corvi` | Dott.ssa Corvi |

### 11.4 Localizzazione

- File sorgente: `<ep>.json` (IT)
- Traduzione: `<ep>.en.json` (EN)
- Solo IT passa la validazione narrativa
- I campi tradotti sono: `text`, `label`, `hint`, `prompt`
- Tutti gli id, flag, branch name, chiavi tecniche restano invariati

---

## 12. Checklist di Validazione

Prima di mergeare un nuovo episodio, verificare:

- [ ] `id` episodio univoco e in kebab-case
- [ ] Ogni `text_block` ha `type` (mai `"speaker": ""`)
- [ ] Ogni `dialogue`/`thought` ha `speaker` valido
- [ ] Main pages hanno `index`, branch pages hanno `id` (mai entrambi)
- [ ] Almeno un'opzione sicura per ogni floor
- [ ] `stat_effects` non viola floor in nessun percorso
- [ ] `set_memories` presente su ogni scelta chiave
- [ ] File EN presente con struttura identica
- [ ] `validate_narrative.py` passa su IT
- [ ] Background path esiste in assets/
- [ ] VFX omesso se default (scene=dust, focus=neutral, intensity=1.0)

---

## 13. Appendice A — Template Minimo Episodio

```json
{
  "id": "s1_esempio",
  "audio_theme": "tema_ambient",
  "pages": [
    {
      "index": 0,
      "background": "assets/episodes/s1/s1_esempio/page_0.webp",
      "panels": [
        {
          "id": "es0_a",
          "characters": ["favilla"],
          "text_blocks": [
            {
              "id": "es0_a_tb_0",
              "type": "narration",
              "text": "Testo narrativo."
            },
            {
              "id": "es0_a_tb_1",
              "type": "dialogue",
              "speaker": "favilla",
              "text": "Testo dialogato."
            }
          ],
          "interactions": []
        }
      ]
    },
    {
      "index": 1,
      "background": "assets/episodes/s1/s1_esempio/page_1.webp",
      "panels": [
        {
          "id": "es1_a",
          "characters": ["favilla", "lex"],
          "text_blocks": [
            {
              "id": "es1_a_tb_0",
              "type": "thought",
              "speaker": "favilla",
              "text": "Pensiero di Favilla."
            }
          ],
          "interactions": []
        }
      ],
      "choice": {
        "id": "es_choice_main",
        "prompt": "Contesto della scelta.",
        "options": [
          {
            "id": "opzione_a",
            "label": "«Testo scelta A.»",
            "goto_branch": "branch_a",
            "stat_effects": {},
            "set_memories": {
              "choice.s1_esempio": "opzione_a"
            }
          },
          {
            "id": "opzione_b",
            "label": "Testo scelta B.",
            "goto_branch": "branch_b",
            "stat_effects": {},
            "set_memories": {
              "choice.s1_esempio": "opzione_b"
            }
          }
        ]
      }
    }
  ],
  "branches": {
    "branch_a": {
      "pages": [
        {
          "id": "ba_p0",
          "background": "assets/episodes/s1/s1_esempio/page_ba_0.webp",
          "panels": [
            {
              "id": "ba_p0_a",
              "characters": ["favilla"],
              "text_blocks": [
                {
                  "id": "ba_p0_a_tb_0",
                  "type": "narration",
                  "text": "Conclusione branch A."
                }
              ],
              "interactions": []
            }
          ]
        }
      ]
    },
    "branch_b": {
      "pages": [
        {
          "id": "bb_p0",
          "background": "assets/episodes/s1/s1_esempio/page_bb_0.webp",
          "panels": [
            {
              "id": "bb_p0_a",
              "characters": ["favilla"],
              "text_blocks": [
                {
                  "id": "bb_p0_a_tb_0",
                  "type": "narration",
                  "text": "Conclusione branch B."
                }
              ],
              "interactions": []
            }
          ]
        }
      ]
    }
  },
  "epilogue": {
    "pages": [
      {
        "id": "ep_p0",
        "background": "assets/episodes/s1/s1_esempio/page_epilogo.webp",
        "panels": [
          {
            "id": "ep_p0_a",
            "characters": ["favilla"],
            "text_blocks": [
              {
                "id": "ep_p0_a_tb_0",
                "type": "narration",
                "text": "Epilogo."
              }
            ],
            "interactions": []
          }
        ]
      }
    ]
  }
}
```

---

*Standard v1.0 — 16/06/2026*
*Da applicare a tutti i nuovi episodi e ai refactor dei JSON esistenti.*
