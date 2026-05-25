---
name: prompt-generator
description: >
  Genera prompt per illustrazioni dettagliati per FavillApp basandosi su una descrizione della scena.
---

# Prompt Generator — FavillApp

Questa skill genera un prompt dettagliato per l'illustrazione di una scena.

## Workflow

1.  **Chiedi la descrizione della scena**: Chiedi all'utente di fornire una descrizione della scena che vuole illustrare.
2.  **Genera il prompt**: Esegui lo script `generate-prompt.cjs` per generare il prompt completo.
3.  **Mostra il prompt**: Mostra all'utente il prompt generato.

## Scripts

### `generate-prompt.cjs`

Genera un prompt completo per l'illustrazione di una scena.

**Usage:**
```bash
node .github/skills/prompt-generator/scripts/generate-prompt.cjs "<scene-description>"
```

## Riferimenti

-   `references/prompt-blocks.md`: Contiene i blocchi di testo riutilizzabili per la creazione dei prompt.
