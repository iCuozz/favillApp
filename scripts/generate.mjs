#!/usr/bin/env node
// Entry point degli script di generazione asset.
//
// Uso:
//   GEMINI_API_KEY=... node generate.mjs refs                       # genera le character sheet
//   GEMINI_API_KEY=... node generate.mjs episode missione_5         # genera tutte le pagine
//   GEMINI_API_KEY=... node generate.mjs episode missione_5 --page page_4
//   GEMINI_API_KEY=... node generate.mjs episode missione_5 --force # sovrascrive esistenti

import { mkdir, readFile, writeFile, access, readdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import sharp from 'sharp';

import { generateImage } from './lib/gemini.mjs';
import { REFERENCE_SHEETS } from './lib/refs.mjs';
import {
  buildScenePrompt,
  CHARACTER_REFS,
  STYLE_REFERENCE_IMAGE,
  COHERENCE_REFERENCE_EPISODE,
} from './lib/style.mjs';
import { parseStoryboard, extractCharactersByPage } from './lib/parse_storyboard.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, '..');
const REFS_DIR = join(__dirname, '_refs');

async function fileExists(p) {
  try { await access(p); return true; } catch { return false; }
}

async function toWebp(buffer, { width, height, quality = 88 } = {}) {
  let img = sharp(buffer);
  if (width && height) {
    img = img.resize(width, height, { fit: 'cover', position: 'centre' });
  }
  return img.webp({ quality }).toBuffer();
}

async function loadStyleReference() {
  if (!STYLE_REFERENCE_IMAGE) return null;
  const path = join(REPO_ROOT, STYLE_REFERENCE_IMAGE);
  if (!existsSync(path)) {
    console.warn(`  ⚠️  style reference non trovata: ${path}`);
    return null;
  }
  const data = await readFile(path);
  return { mimeType: 'image/webp', data: data.toString('base64'), _path: STYLE_REFERENCE_IMAGE };
}

async function loadCoherenceReferences(currentEpisodeId) {
  if (!COHERENCE_REFERENCE_EPISODE) return [];
  const dir = join(REPO_ROOT, COHERENCE_REFERENCE_EPISODE);
  if (!existsSync(dir)) {
    console.warn(`  ⚠️  coherence episode non trovato: ${dir}`);
    return [];
  }
  // Evita di allegare le immagini dell'episodio che stiamo generando
  // (es. se per errore COHERENCE_REFERENCE_EPISODE punta allo stesso id).
  if (COHERENCE_REFERENCE_EPISODE.endsWith(`/${currentEpisodeId}`)) {
    return [];
  }
  const entries = (await readdir(dir))
    .filter((f) => f.toLowerCase().endsWith('.webp'))
    .sort();
  const out = [];
  for (const f of entries) {
    const rel = `${COHERENCE_REFERENCE_EPISODE}/${f}`;
    const data = await readFile(join(dir, f));
    out.push({ mimeType: 'image/webp', data: data.toString('base64'), _path: rel });
  }
  return out;
}

async function loadRefAsInline(charId) {
  const ref = CHARACTER_REFS[charId];
  if (!ref) return null;
  const path = join(REFS_DIR, ref.file);
  if (!existsSync(path)) {
    console.warn(`  ⚠️  reference mancante per "${charId}": ${path} (esegui prima: node generate.mjs refs)`);
    return null;
  }
  const data = await readFile(path);
  return { mimeType: 'image/webp', data: data.toString('base64') };
}

async function cmdRefs({ force }) {
  await mkdir(REFS_DIR, { recursive: true });
  console.log(`📐 Genero ${REFERENCE_SHEETS.length} character sheet in ${REFS_DIR}\n`);

  for (const sheet of REFERENCE_SHEETS) {
    const out = join(REFS_DIR, sheet.file);
    if (!force && (await fileExists(out))) {
      console.log(`  ⏭️  ${sheet.file} esiste già (--force per rigenerare)`);
      continue;
    }
    console.log(`  🎨 ${sheet.id} → ${sheet.file}`);
    const img = await generateImage({ prompt: sheet.prompt });
    const webp = await toWebp(img.data, { width: 1024, height: 1024 });
    await writeFile(out, webp);
    console.log(`     ✅ salvato (${(webp.length / 1024).toFixed(0)} KB)`);
  }

  console.log('\n✨ Reference pronte. Ora puoi generare un episodio:');
  console.log('   node generate.mjs episode missione_5');
}

async function listCoherenceRefPaths(currentEpisodeId) {
  if (!COHERENCE_REFERENCE_EPISODE) return [];
  const dir = join(REPO_ROOT, COHERENCE_REFERENCE_EPISODE);
  if (!existsSync(dir)) return [];
  if (COHERENCE_REFERENCE_EPISODE.endsWith(`/${currentEpisodeId}`)) return [];
  const entries = (await readdir(dir))
    .filter((f) => f.toLowerCase().endsWith('.webp'))
    .sort();
  return entries.map((f) => `${COHERENCE_REFERENCE_EPISODE}/${f}`);
}

async function cmdPrompts(episodeId, { onlyPage }) {
  const storyboardPath = join(REPO_ROOT, 'assets', 'episodes', episodeId, 'STORYBOARD.md');
  const jsonPath = join(REPO_ROOT, 'assets', 'data', 'episodes', `${episodeId}.json`);
  const outFile = join(REPO_ROOT, 'assets', 'episodes', episodeId, 'PROMPTS.txt');

  if (!existsSync(storyboardPath)) throw new Error(`STORYBOARD non trovato: ${storyboardPath}`);
  if (!existsSync(jsonPath)) throw new Error(`JSON episodio non trovato: ${jsonPath}`);

  const pages = await parseStoryboard(storyboardPath);
  const charsByPage = await extractCharactersByPage(jsonPath);
  if (!pages.length) throw new Error('Nessuna pagina parsata dallo STORYBOARD.md.');

  const coherencePaths = await listCoherenceRefPaths(episodeId);
  const styleAnchor = STYLE_REFERENCE_IMAGE || null;
  const styleAndCoherence = styleAnchor
    ? [styleAnchor, ...coherencePaths.filter((p) => p !== styleAnchor)]
    : coherencePaths;

  const blocks = [];
  blocks.push(`# Prompts pronti per Google AI Studio — episodio ${episodeId}`);
  blocks.push(`# Modello consigliato: gemini-2.5-flash-image (web UI, free)`);
  blocks.push(`# Per OGNI pagina: allega in AI Studio nell'ordine indicato`);
  blocks.push(`# (1) le STYLE & COHERENCE references, (2) le CHARACTER reference sheets,`);
  blocks.push(`# poi incolla il PROMPT e genera. Salva l'output come pageN.webp.`);
  blocks.push('');

  for (const page of pages) {
    if (onlyPage && page.id !== onlyPage) continue;
    const chars = charsByPage[page.id] || [];
    const charRefPaths = chars
      .filter((id) => CHARACTER_REFS[id])
      .map((id) => `scripts/_refs/${CHARACTER_REFS[id].file}`);
    const fullPrompt = buildScenePrompt(page.prompt, chars);

    blocks.push('═'.repeat(78));
    blocks.push(`## ${page.outFile}   (${page.id})`);
    blocks.push(`Personaggi in scena: ${chars.length ? chars.join(', ') : '— nessuno —'}`);
    blocks.push('');
    blocks.push('IMMAGINI DA ALLEGARE (in questo ordine):');
    blocks.push('  -- Style & coherence (da missione_4) --');
    for (const p of styleAndCoherence) blocks.push(`    • ${p}`);
    if (charRefPaths.length) {
      blocks.push('  -- Character sheet --');
      for (const p of charRefPaths) blocks.push(`    • ${p}`);
    }
    blocks.push('');
    blocks.push('PROMPT:');
    blocks.push(fullPrompt);
    blocks.push('');
  }

  await writeFile(outFile, blocks.join('\n'));
  console.log(`✅ Prompts salvati in: ${outFile}`);
  console.log(`   Pagine incluse: ${pages.filter((p) => !onlyPage || p.id === onlyPage).length}`);
  console.log(`   Style/coherence refs: ${styleAndCoherence.length}`);
}

async function cmdEpisode(episodeId, { force, onlyPage }) {
  const storyboardPath = join(REPO_ROOT, 'assets', 'episodes', episodeId, 'STORYBOARD.md');
  const jsonPath = join(REPO_ROOT, 'assets', 'data', 'episodes', `${episodeId}.json`);
  const outDir = join(REPO_ROOT, 'assets', 'episodes', episodeId);

  if (!existsSync(storyboardPath)) {
    throw new Error(`STORYBOARD non trovato: ${storyboardPath}`);
  }
  if (!existsSync(jsonPath)) {
    throw new Error(`JSON episodio non trovato: ${jsonPath}`);
  }

  const pages = await parseStoryboard(storyboardPath);
  const charsByPage = await extractCharactersByPage(jsonPath);

  if (!pages.length) {
    throw new Error('Nessuna pagina parsata dallo STORYBOARD.md.');
  }

  console.log(`📖 Episodio ${episodeId}: ${pages.length} immagini da considerare\n`);

  const styleRef = await loadStyleReference();
  const coherenceRefs = await loadCoherenceReferences(episodeId);
  // Dedup: lo style reference esplicito ha priorità, le pagine dell'episodio
  // di coerenza vengono dopo (escludendo quella già usata come style anchor).
  const coherenceBlock = styleRef
    ? coherenceRefs.filter((r) => r._path !== styleRef._path)
    : coherenceRefs;
  const allStyleRefs = styleRef ? [styleRef, ...coherenceBlock] : coherenceBlock;
  if (allStyleRefs.length) {
    console.log(`🎨 Style/coherence references (${allStyleRefs.length}):`);
    for (const r of allStyleRefs) console.log(`   • ${r._path}`);
    console.log('');
  }

  for (const page of pages) {
    if (onlyPage && page.id !== onlyPage) continue;

    const out = join(outDir, page.outFile);
    if (!force && (await fileExists(out))) {
      console.log(`  ⏭️  ${page.outFile} esiste già (--force per rigenerare)`);
      continue;
    }

    // Per la cover usiamo i char del primo page disponibile o lasciamo vuoto
    let chars = charsByPage[page.id] || [];
    if (page.id === 'thumb.webp') {
      chars = chars.length ? chars : Array.from(new Set(Object.values(charsByPage).flat()));
    }

    const charRefs = (await Promise.all(chars.map(loadRefAsInline))).filter(Boolean);
    // Ordine importante: prima style+coherence references, poi le character sheet.
    const refImages = [...allStyleRefs, ...charRefs];
    const fullPrompt = buildScenePrompt(page.prompt, chars);

    console.log(`  🎬 ${page.outFile}  [chars: ${chars.join(', ') || '—'}]  refs allegate: ${refImages.length}`);

    const img = await generateImage({ prompt: fullPrompt, referenceImages: refImages });
    // 16:9 per le pagine, 1:1 per la thumb
    const dims = page.id === 'thumb.webp'
      ? { width: 1024, height: 1024 }
      : { width: 1920, height: 1080 };
    const webp = await toWebp(img.data, dims);
    await writeFile(out, webp);
    console.log(`     ✅ ${out} (${(webp.length / 1024).toFixed(0)} KB)`);
  }

  console.log('\n✨ Fatto.');
}

function parseArgs(argv) {
  const args = { force: false, onlyPage: null, _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--force') args.force = true;
    else if (a === '--page') args.onlyPage = argv[++i];
    else args._.push(a);
  }
  return args;
}

async function main() {
  const argv = process.argv.slice(2);
  const args = parseArgs(argv);
  const cmd = args._[0];

  if (!cmd || cmd === 'help' || cmd === '--help') {
    console.log(`
favillApp · generatore asset visivi (Gemini 2.5 Flash Image)

Comandi:
  refs                          Genera le 4 character sheet in scripts/_refs/
                                (eseguire UNA volta, prima degli episodi).
                                Richiede billing Gemini attivo.
  episode <id> [--page X] [--force]
                                Genera tutte le immagini dell'episodio in
                                assets/episodes/<id>/ leggendo lo STORYBOARD.md.
                                Richiede billing Gemini attivo.
  prompts <id> [--page X]       Esporta in assets/episodes/<id>/PROMPTS.txt
                                tutti i prompt finali + elenco immagini da
                                allegare, pronti per copia/incolla manuale
                                in Google AI Studio (free tier web).

Flag:
  --force         Sovrascrive file già esistenti.
  --page page_N   Genera solo quella pagina (es. page_4, thumb.webp).

Variabili d'ambiente:
  GEMINI_API_KEY      richiesta. (alias: GOOGLE_API_KEY)
  GEMINI_IMAGE_MODEL  default: gemini-2.5-flash-image

Esempi:
  GEMINI_API_KEY=AIza... npm run refs
  GEMINI_API_KEY=AIza... npm run episode -- missione_5
  GEMINI_API_KEY=AIza... npm run episode -- missione_5 --page page_4 --force
`);
    return;
  }

  if (cmd === 'refs') {
    await cmdRefs({ force: args.force });
    return;
  }

  if (cmd === 'prompts') {
    const id = args._[1];
    if (!id) throw new Error('Manca <id>. Esempio: node generate.mjs prompts missione_5');
    await cmdPrompts(id, { onlyPage: args.onlyPage });
    return;
  }

  if (cmd === 'episode') {
    const id = args._[1];
    if (!id) throw new Error('Manca <id>. Esempio: node generate.mjs episode missione_5');
    await cmdEpisode(id, { force: args.force, onlyPage: args.onlyPage });
    return;
  }

  throw new Error(`Comando sconosciuto: ${cmd}. Usa "node generate.mjs help".`);
}

main().catch((e) => {
  console.error('\n❌', e.message);
  process.exit(1);
});
