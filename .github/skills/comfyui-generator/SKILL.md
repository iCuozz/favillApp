---
name: comfyui-generator
description: >
  Genera illustrazioni per FavillApp inviando automaticamente il workflow a ComfyUI.
  Imposta l'IP-Adapter reference e il peso in base ai personaggi della scena,
  costruisce il prompt completo (STYLE BLOCK + CHARACTER DESCRIPTORS + Scene + ENV),
  e attende il completamento. Usa questa skill quando l'utente vuole generare un'immagine
  per una pagina o scena specifica.
---

# ComfyUI Generator — FavillApp

Questa skill genera un'illustrazione per FavillApp inviando il workflow SDXL + IP-Adapter a ComfyUI in esecuzione in locale.

## Prerequisiti

- ComfyUI in esecuzione su `http://127.0.0.1:8188`
- Workflow `favilla_blaze_multichar.json` sul Desktop
- Modelli scaricati: `sd_xl_base_1.0.safetensors`, `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`, `ip-adapter-plus_sdxl_vit-h.safetensors`
- Immagini reference in `~/Projects/Illustrations/Characters/`

## Workflow

1. **Chiedi i dettagli della scena** all'utente:
   - Descrizione della scena (obbligatorio)
   - Personaggi presenti: `favilla`, `favilla_blaze`, `mallow`, `lex` (separati da virgola; il primo è l'IP-Adapter reference)
   - Ambiente (opzionale): `kitchen`, `bedroom`, `nursery`, `school`
   - Nome del file di output senza estensione (es. `page_0`)

2. **Esegui lo script** `generate-image.cjs`

3. **Mostra il risultato** all'utente (path immagine generata + istruzioni per integrarla)

## Script

### `generate-image.cjs`

**Usage:**
```bash
node .github/skills/comfyui-generator/scripts/generate-image.cjs \
  --characters="favilla_blaze" \
  --scene="Favilla stands in the school corridor, golden light emanating from her hands" \
  --env="school" \
  --output="page_3"
```

**Argomenti:**

| Argomento | Obbligatorio | Descrizione |
|---|---|---|
| `--scene` | ✅ | Descrizione della scena in inglese |
| `--characters` | — | ID personaggi separati da virgola (default: `favilla`). Il primo diventa il reference IP-Adapter. |
| `--env` | — | Ambiente: `kitchen` \| `bedroom` \| `nursery` \| `school` |
| `--output` | — | Prefisso output senza estensione (default: `favillapp_output`) |
| `--comfyui-url` | — | URL ComfyUI (default: `http://127.0.0.1:8188`) |
| `--workflow` | — | Path al workflow JSON (default: `~/Desktop/favilla_blaze_sdxl_ipadapter.json`) |

- Ogni personaggio ha il proprio IP-Adapter in catena; il weight viene impostato a
  `0.8` (on) per i personaggi nella scena e a `0.0` (off) per gli altri.
- Non è più necessario un "personaggio primario": tutti i personaggi attivi hanno lo stesso peso.

## Configurazione

Il file `config/characters.json` contiene:
- Path immagini reference per ogni personaggio
- CHARACTER DESCRIPTORS (incollati automaticamente nel prompt)
- ENV BLOCKS
- STYLE BLOCK e NEGATIVE BLOCK
- URL ComfyUI e path workflow

Per aggiungere un personaggio o modificare i path, edita `config/characters.json`.

## Esempio di interazione

Utente: "Genera page_2 del prologo: Favilla è in cucina, tiene Lex in braccio, guarda fuori dalla finestra"

Copilot esegue:
```bash
node .github/skills/comfyui-generator/scripts/generate-image.cjs \
  --characters="favilla,lex" \
  --scene="Favilla stands near the kitchen window holding Lex in her arms, gazing outside with a tired but loving expression" \
  --env="kitchen" \
  --output="page_2"
```
