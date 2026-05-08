# scripts/ — Generatore asset visivi

Script standalone (Node ≥20) per pre-generare le immagini degli episodi
con **Gemini 2.5 Flash Image** ("Nano Banana") e salvarle in
`assets/episodes/<episodio>/`.

A differenza del Cloudflare Worker in `worker/` (che genera immagini a
runtime nell'app), questo script serve a creare gli asset di **produzione**
una volta sola e committarli nel repo.

## Setup

```bash
cd scripts
npm install
export GEMINI_API_KEY="AIza..."   # da https://aistudio.google.com/apikey
```

## Workflow consigliato

### 1. Genera le character sheet (UNA volta sola)

```bash
npm run refs
```

Crea 4 file in `scripts/_refs/`:
- `_ref_favilla.webp` — Favilla in look elegante (per M5)
- `_ref_favilla_blaze.webp` — modalità eroe
- `_ref_mallow.webp` — Mallow Bellow
- `_ref_ale.webp` — Sparkle Ale (7 mesi)

Queste reference vengono allegate automaticamente a OGNI prompt scena
per garantire che i personaggi restino visivamente identici.

> ⚠️ Le ref **non vanno committate** se vuoi rigenerarle stagionalmente.
> Sono già in `.gitignore`.

### 2. Genera un episodio

```bash
npm run episode -- missione_5
```

Lo script:
1. legge `assets/episodes/missione_5/STORYBOARD.md` ed estrae i prompt
2. legge `assets/data/episodes/missione_5.json` per sapere quali
   personaggi compaiono in ogni pagina (incluso branch path)
3. avvolge ogni prompt con `STYLE_LOCK` + lista personaggi + `SAFETY`
4. chiama Gemini con le character sheet allegate come immagini di input
5. salva i WebP in `assets/episodes/missione_5/` (1920×1080, thumb 1024²)
6. **non sovrascrive** i file già esistenti (usa `--force` per farlo)

### 3. Rigenera una sola pagina

```bash
npm run episode -- missione_5 --page page_4 --force
```

## Personalizzare lo stile

- Modifica `lib/style.mjs` per cambiare `STYLE_LOCK` / `SAFETY_BLOCK`
  globali (impatta tutti gli episodi).
- Modifica `lib/refs.mjs` per cambiare i prompt delle character sheet
  (poi rilancia `npm run refs --force`).
- I prompt scena vivono nello `STORYBOARD.md` di ciascun episodio.

## Aggiungere un nuovo episodio

1. Crea `assets/episodes/<id>/STORYBOARD.md` con sezioni `## page_N — titolo`
   contenenti `**Prompt**:` seguito da un blockquote `> ...`.
2. Crea `assets/data/episodes/<id>.json` con i `characters` per panel.
3. Lancia `npm run episode -- <id>`.
