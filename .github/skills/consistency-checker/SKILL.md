---
name: consistency-checker
description: >
  Verifica la coerenza tra i character block di illustration_prompts.md e le
  descrizioni canoniche in docs/NARRATIVE_BIBLE.md. Usa questa skill dopo aver
  modificato i prompt di illustrazione o il Narrative Bible per assicurarti che
  i personaggi siano descritti in modo coerente in entrambi i file.
---

# Consistency Checker — FavillApp

Verifica che i character block in `assets/data/illustration_prompts.md` siano
coerenti con le descrizioni fisiche canoniche in `docs/NARRATIVE_BIBLE.md`.

## Quando usarla

- Dopo aver modificato un character block in `illustration_prompts.md`
- Dopo aver aggiornato l'aspetto di un personaggio in `NARRATIVE_BIBLE.md`
- Prima di generare un batch di nuove illustrazioni

## Workflow

1. Esegui lo script `check-consistency.cjs` dalla root del progetto:

```bash
node .github/skills/consistency-checker/scripts/check-consistency.cjs
```

2. Lo script confronta i seguenti attributi per ogni personaggio:

| Personaggio | Attributi verificati |
|---|---|
| Favilla | capelli biondi (`biondi hair`) |
| Mallow | polo azzurra, mini-mohawk |
| Lex | capelli castani chiari |

3. Output:
   - `✅ Tutti i character block sono coerenti` — tutto ok
   - `❌ Inconsistenze trovate` — lista JSON con character, campo e differenza

## In caso di inconsistenza

Aggiorna il character block in `illustration_prompts.md` per allinearlo al Narrative Bible (il Bible è la fonte canonica). Non modificare il Bible per adattarlo ai prompt.

## Script

### `check-consistency.cjs`

**Usage:**
```bash
node .github/skills/consistency-checker/scripts/check-consistency.cjs [project-root]
```

`project-root` è opzionale — default: directory corrente.

