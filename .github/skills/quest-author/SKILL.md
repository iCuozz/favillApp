---
name: quest-author
description: >
  Guida alla creazione di nuove quest per FavillApp. Usa questa skill quando
  devi authoring un nuovo file JSON di quest, aggiungere una quest a world_map.json,
  o registrare i nuovi asset in pubspec.yaml. Include schema completo, regole di design,
  personaggi e stat di riferimento.
---

# Quest Author — FavillApp

## Checklist per ogni nuova quest

Quando crei una nuova quest, esegui SEMPRE questi passaggi nell'ordine:

1. Crea `assets/data/quests/<id>.json` con la struttura corretta (vedi schema sotto)
2. Aggiungi la quest all'array `quests` della location corretta in `assets/data/world_map.json`
3. Verifica che `assets/data/quests/` sia già registrato in `pubspec.yaml` (è già presente — non aggiungere duplicati)
4. Aggiorna `unlock_after_quest` nella location successiva se la quest sblocca un nuovo luogo
5. Esegui `flutter analyze` — zero errori prima di committare

---

## Schema JSON di una quest

```json
{
  "id": "id_univoco_snake_case",
  "pages": [
    {
      "index": 0,
      "background": "assets/episodes/<id>/page_0.webp",
      "panels": [
        {
          "id": "p0_0",
          "characters": ["favilla"],
          "text_blocks": [
            {
              "id": "p0_0_tb_0",
              "type": "narration",
              "text": "Testo narrativo in terza persona."
            },
            {
              "id": "p0_0_tb_1",
              "type": "dialogue",
              "speaker": "favilla",
              "text": "Dialogo del personaggio."
            },
            {
              "id": "p0_0_tb_2",
              "type": "thought",
              "text": "Pensiero interiore di Favilla."
            }
          ],
          "interactions": []
        }
      ]
    }
  ],
  "branches": {
    "branch_a": {
      "pages": [ /* stessa struttura di pages */ ]
    },
    "branch_b": {
      "pages": [ /* stessa struttura di pages */ ]
    }
  },
  "epilogue": {
    "pages": [
      {
        "index": 0,
        "background": "assets/episodes/<id>/epilogue.webp",
        "panels": [
          {
            "id": "ep_0",
            "characters": ["favilla"],
            "text_blocks": [
              {
                "id": "ep_0_tb_0",
                "type": "narration",
                "text": "Conclusione della quest."
              },
              {
                "id": "ep_0_tb_3",
                "type": "system",
                "text": "MISSIONE COMPLETATA — Titolo Quest"
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

### Tipi di text_block validi
| type | Uso |
|---|---|
| `narration` | Voce narrante in terza persona |
| `dialogue` | Dialogo di un personaggio (richiede `speaker`) |
| `thought` | Pensiero interiore di Favilla |
| `system` | Messaggi di sistema (MISSIONE COMPLETATA, FINE PROLOGO…) |

### Come aggiungere una scelta (choice)

La `choice` va aggiunta come campo della **page** (non del panel):

```json
{
  "index": 2,
  "background": "assets/episodes/<id>/page_2.webp",
  "panels": [ /* ... */ ],
  "choice": {
    "id": "id_scelta",
    "prompt": "Testo della domanda al giocatore?",
    "options": [
      {
        "id": "opzione_a",
        "label": "Testo del bottone scelta A",
        "hint": "Breve conseguenza visibile al giocatore.",
        "goto_branch": "branch_a",
        "stat_effects": { "segreto": 10, "legame": 5 }
      },
      {
        "id": "opzione_b",
        "label": "Testo del bottone scelta B",
        "hint": "Breve conseguenza.",
        "goto_branch": "branch_b",
        "stat_effects": { "segreto": -10, "legame": 5 }
      }
    ]
  }
}
```

---

## Stat del gioco

| Stat | Range | Significato |
|---|---|---|
| `segreto` | 0–100 | Quanto il segreto di Favilla è al sicuro |
| `legame` | 0–100 | Forza del legame con Mallow |
| `scintille` | 0–100 | Energia/potere supereroistico |
| `resistenza` | 0–100 | Resistenza fisica e mentale |

- Gli effetti (`stat_effects`) usano delta interi: `+10`, `-5`, ecc.
- Non superare ±20 per scelta — mantenere la progressione graduale
- Entrambe le scelte possono avere effetti positivi su stat diverse (no scelta "giusta/sbagliata")

---

## Character ID validi

| ID | Personaggio | Ruolo |
|---|---|---|
| `favilla` | Favilla | Collaboratrice scolastica (versione normale) |
| `favilla_blaze` | Favilla Blaze | Supereroina (versione trasformata) |
| `mallow` | Mallow | Marito, sviluppatore informatico |
| `mallow_bellow` | Mallow Bellow | Variante formale di Mallow |
| `lex` | Lex | Figlio neonato (7 mesi) |
| `sparkle_ale` | Sparkle Ale | Figlio maggiore |
| `bambini` | Bambini | Gruppo di bambini (scolari) |
| `bimbo_1` | Bimbo 1 | Comparsa scolastica |
| `bimbo_2` | Bimbo 2 | Comparsa scolastica |
| `siri` | Siri | Voce di sistema |

Usa SEMPRE questi ID — mai inventarne di nuovi senza aggiungerli prima a `comic_index.json`.

---

## Regole di design (obbligatorie)

Ogni quest DEVE rispettare tutti e 6 i punti:

1. **Obiettivo chiaro** — il giocatore sa cosa deve fare
2. **Motivazione credibile** — c'è un "perché" che ha senso nel mondo di gioco
3. **Ricompensa significativa** — effetti stat o sblocco location che valgono lo sforzo
4. **Scelte con conseguenze** — almeno un bivio che cambia l'esito (branching narrativo)
5. **Contesto narrativo** — radicata nel mondo di Nova Tutinia e nei personaggi
6. **Scala di difficoltà adeguata** — né troppo banale né frustrante

**Regola d'oro:** al termine della quest qualcosa deve essere cambiato — nel mondo, nel personaggio, o nelle stat. Se finita la quest tutto è uguale a prima, non valeva la pena farla.

---

## Entry in world_map.json

Aggiungi la quest nell'array `quests` della location corretta:

```json
{
  "id": "id_quest",
  "title": "Titolo Visibile",
  "subtitle": "Sottotitolo breve e evocativo.",
  "file": "assets/data/quests/id_quest.json",
  "thumbnail": "assets/episodes/id_quest/thumb.webp",
  "season": 1,
  "requires_completed": ["id_quest_precedente"],
  "requires_stats": {}
}
```

Se la quest sblocca una nuova location, aggiorna il campo `unlock_after_quest` di quella location:

```json
{
  "id": "nuova_location",
  "unlock_after_quest": "id_quest"
}
```

---

## Convenzione ID

- ID quest: `s<stagione>_<location>_<numero>` → es. `s1_scuola_1`, `s1_parco_1`
- ID panel: `<prefisso_pagina>_<indice_panel>` → es. `md0_0`, `sc1_0`
- ID text_block: `<id_panel>_tb_<indice>` → es. `md0_0_tb_0`
- ID choice: nome descrittivo → es. `reazione_lex`, `risposta_mallow`
- ID branch: `branch_<nome_esito>` → es. `branch_sorriso`, `branch_fuga`
