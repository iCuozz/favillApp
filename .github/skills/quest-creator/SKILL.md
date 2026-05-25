---
name: quest-creator
description: >
  Automatizza la creazione di nuove quest per FavillApp. Genera il file JSON della quest,
  lo aggiunge a world_map.json e crea i prompt di placeholder per le illustrazioni.
---

# Quest Creator — FavillApp

Questa skill automatizza la creazione di una nuova quest.

## Workflow

1.  **Chiedi i dettagli della quest**: Chiedi all'utente l'ID della quest, il titolo, il sottotitolo, la stagione e l'ID della location.
2.  **Crea il file JSON della quest**: Esegui lo script `create-quest-json.cjs` per generare il file JSON della quest in `assets/data/quests`.
3.  **Aggiorna la mappa del mondo**: Esegui lo script `update-world-map.cjs` per aggiungere la nuova quest alla mappa del mondo in `assets/data/world_map.json`.
4.  **Genera i prompt per le illustrazioni**: Esegui lo script `generate-prompts.cjs` per aggiungere i prompt di placeholder per le illustrazioni in `assets/data/illustration_prompts.md`.
5.  **Conferma**: Mostra all'utente i file che sono stati creati e modificati.

## Scripts

### `create-quest-json.cjs`

Crea un nuovo file JSON per la quest in `assets/data/quests`.

**Usage:**
```bash
node .github/skills/quest-creator/scripts/create-quest-json.cjs <quest-id>
```

### `update-world-map.cjs`

Aggiunge la nuova quest al file `assets/data/world_map.json`.

**Usage:**
```bash
node .github/skills/quest-creator/scripts/update-world-map.cjs <quest-id> <title> <subtitle> <season> <location-id>
```

### `generate-prompts.cjs`

Aggiunge i prompt di placeholder per le illustrazioni al file `assets/data/illustration_prompts.md`.

**Usage:**
```bash
node .github/skills/quest-creator/scripts/generate-prompts.cjs <quest-id>
```

## Riferimenti

-   `references/quest-schema.json`: Lo schema JSON per i file delle quest.
