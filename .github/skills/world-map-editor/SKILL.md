---
name: world-map-editor
description: >
  Guida per aggiungere o modificare location e quest in world_map.json.
  Usa questa skill quando devi aggiungere una nuova location alla mappa,
  modificare la catena di sblocco delle quest, o aggiornare le posizioni
  dei nodi sulla mappa di Nova Tutinia.
---

# World Map Editor — FavillApp

## File da modificare

`assets/data/world_map.json`

---

## Schema completo di world_map.json

```json
{
  "locations": [
    {
      "id": "id_location",
      "name": "Nome Visibile",
      "emoji": "🏠",
      "description": "Descrizione breve mostrata nel tooltip della mappa.",
      "unlocked_by_default": false,
      "unlock_after_quest": "id_quest_che_sblocca",
      "position": {
        "x": 0.55,
        "y": 0.60
      },
      "quests": [
        {
          "id": "id_quest",
          "title": "Titolo Quest",
          "subtitle": "Breve descrizione evocativa.",
          "file": "assets/data/quests/id_quest.json",
          "thumbnail": "assets/episodes/id_quest/thumb.webp",
          "season": 1,
          "requires_completed": ["id_quest_precedente"],
          "requires_stats": {}
        }
      ]
    }
  ]
}
```

### Campi chiave

| Campo | Obbligatorio | Note |
|---|---|---|
| `id` | ✅ | snake_case univoco |
| `name` | ✅ | Mostrato sulla mappa |
| `emoji` | ✅ | Icona del nodo sulla mappa |
| `description` | ✅ | Tooltip al tap sul nodo |
| `unlocked_by_default` | ✅ | Solo `true` per Casa — tutte le altre `false` |
| `unlock_after_quest` | Se `unlocked_by_default: false` | ID della quest che sblocca questa location |
| `position.x` | ✅ | 0.0 (sinistra) → 1.0 (destra) |
| `position.y` | ✅ | 0.0 (alto) → 1.0 (basso) |
| `quests` | ✅ | Può essere `[]` se la location non ha ancora quest |

### Campi della quest dentro world_map.json

| Campo | Note |
|---|---|
| `requires_completed` | Array di ID quest che devono essere completate prima |
| `requires_stats` | Map stat→valore minimo, es. `{"segreto": 30}`. Usa `{}` se non ci sono requisiti |
| `thumbnail` | Path immagine preview. Usa `"assets/episodes/prologo/thumb.webp"` come placeholder |

---

## Catena di sblocco attuale (Stagione 1)

```
prologo (hardcoded in HomeCoverPage)
  └─→ sblocca WorldState → mappa accessibile
        └─→ Casa (unlocked_by_default: true)
              └─→ s1_mattina_dopo
                    └─→ sblocca: Scuola, Supermercato
                          └─→ s1_scuola_1
                                └─→ sblocca: Parco
```

Quando aggiungi una nuova quest o location, aggiorna questo schema mentalmente e verifica la coerenza della catena.

---

## Posizioni disponibili sulla mappa

La mappa di Nova Tutinia usa coordinate normalizzate (0.0–1.0).
Posizioni già occupate:

| Location | x | y |
|---|---|---|
| Casa | 0.55 | 0.60 |
| Scuola | 0.25 | 0.35 |
| Parco | 0.70 | 0.30 |
| Supermercato | 0.35 | 0.70 |

Evita sovrapposizioni. Lascia almeno 0.15 di distanza tra nodi.

---

## Checklist dopo ogni modifica a world_map.json

1. Verifica che ogni `unlock_after_quest` punti a un ID quest esistente
2. Verifica che ogni `requires_completed` punti a ID quest esistenti
3. Verifica che ogni `file` di quest punti a un file esistente in `assets/data/quests/`
4. Verifica che le posizioni `x`/`y` siano nel range 0.0–1.0
5. Lancia `flutter analyze` — zero errori
6. Lancia l'app e verifica che la mappa mostri i nodi correttamente

---

## Location esistenti in Stagione 1

| ID | Nome | Stato |
|---|---|---|
| `casa` | Casa | ✅ Attiva, ha quests |
| `scuola` | Scuola | ✅ Attiva, ha quests placeholder |
| `parco` | Parco | 🔲 Struttura creata, nessuna quest |
| `supermercato` | Supermercato | 🔲 Struttura creata, nessuna quest |

---

## Come aggiungere una nuova location

```json
{
  "id": "biblioteca",
  "name": "Biblioteca",
  "emoji": "📚",
  "description": "Biblioteca comunale di Nova Tutinia. Silenzio (obbligatorio).",
  "unlocked_by_default": false,
  "unlock_after_quest": "id_della_quest_che_la_sblocca",
  "position": { "x": 0.60, "y": 0.45 },
  "quests": []
}
```

Aggiungi l'oggetto all'array `locations` in `world_map.json`.
Poi aggiorna `unlock_after_quest` nella quest che deve sbloccarla.
