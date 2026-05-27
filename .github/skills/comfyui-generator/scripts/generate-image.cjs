#!/usr/bin/env node
'use strict';

// generate-image.cjs
// Genera un'immagine via ComfyUI API usando il workflow multichar SDXL + IP-Adapter.
// Ogni personaggio ha il proprio IP-Adapter in catena; il weight viene impostato a
// 0.8 (on) per i personaggi nella scena e a 0.0 (off) per gli altri.
//
// Usage:
//   node generate-image.cjs \
//     --characters="favilla_blaze,lex" \
//     --scene="Favilla Blaze stands in the school corridor, golden light from her hands" \
//     --env="school" \
//     --output="page_3"
//
// --characters   Uno o più ID separati da virgola
//                Valori validi: favilla, favilla_blaze, mallow, lex
// --scene        Descrizione della scena in inglese (obbligatorio)
// --env          Ambiente: kitchen | bedroom | nursery | school (opzionale)
// --output       Prefisso file di output senza estensione (default: favillapp_output)
// --comfyui-url  URL di ComfyUI (default: dal config)
// --workflow     Path al workflow JSON (default: dal config)

const fs   = require('fs');
const path = require('path');
const http = require('http');
const os   = require('os');

// ── helpers ──────────────────────────────────────────────────────────────────

function expandHome(p) {
  if (!p) return p;
  return p.startsWith('~') ? path.join(os.homedir(), p.slice(1)) : p;
}

function parseArgs(argv) {
  const result = {};
  for (const arg of argv) {
    const m = arg.match(/^--([^=]+)=(.*)$/s);
    if (m) result[m[1]] = m[2];
    else if (arg.startsWith('--')) result[arg.slice(2)] = true;
  }
  return result;
}

function httpRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, res => {
      const chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString();
        try { resolve(JSON.parse(raw)); }
        catch { resolve(raw); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function postJson(comfyUrl, endpoint, data) {
  const body = Buffer.from(JSON.stringify(data));
  const u = new URL(comfyUrl + endpoint);
  return httpRequest({
    hostname: u.hostname, port: u.port, path: u.pathname,
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': body.length }
  }, body);
}

function getJson(comfyUrl, endpoint) {
  const u = new URL(comfyUrl + endpoint);
  return httpRequest({ hostname: u.hostname, port: u.port, path: u.pathname, method: 'GET' });
}

function uploadImage(comfyUrl, imagePath) {
  const filename = path.basename(imagePath);
  const ext      = path.extname(filename).slice(1).toLowerCase();
  const mimeType = ext === 'jpg' ? 'image/jpeg' : `image/${ext}`;
  const fileData = fs.readFileSync(imagePath);
  const boundary = `----FormBoundary${Date.now()}`;

  const header = Buffer.from(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="image"; filename="${filename}"\r\n` +
    `Content-Type: ${mimeType}\r\n\r\n`
  );
  const footer = Buffer.from(`\r\n--${boundary}--\r\n`);
  const body   = Buffer.concat([header, fileData, footer]);

  const u = new URL(comfyUrl + '/upload/image');
  return httpRequest({
    hostname: u.hostname, port: u.port, path: u.pathname,
    method: 'POST',
    headers: {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Content-Length': body.length
    }
  }, body);
}

async function pollUntilDone(comfyUrl, promptId, intervalMs = 2000) {
  process.stdout.write('⏳ ');
  while (true) {
    const history = await getJson(comfyUrl, `/history/${promptId}`);
    if (history[promptId]) {
      const status = history[promptId].status;
      if (status && status.completed) {
        process.stdout.write(' ✓\n');
        return history[promptId];
      }
      if (status && status.status_str === 'error') {
        process.stdout.write('\n');
        throw new Error('ComfyUI generation failed');
      }
    }
    process.stdout.write('.');
    await new Promise(r => setTimeout(r, intervalMs));
  }
}

// ── main ─────────────────────────────────────────────────────────────────────

async function main() {
  const args       = parseArgs(process.argv.slice(2));
  const configPath = path.join(__dirname, '..', 'config', 'characters.json');
  const config     = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

  const comfyUrl     = args['comfyui-url'] || config.comfyui_url;
  const workflowPath = expandHome(args['workflow'] || config.workflow_path);
  const sceneDesc    = args['scene'];
  const charList     = (args['characters'] || 'favilla').split(',').map(s => s.trim());
  const envKey       = args['env']    || null;
  const outputName   = args['output'] || 'favillapp_output';
  const sceneType    = args['type']   || 'portrait'; // portrait | scene

  if (!sceneDesc) {
    console.error('❌ --scene è obbligatorio.\n');
    console.error('Usage: node generate-image.cjs --scene="..." --characters="favilla,lex" [--env="kitchen"] [--type="scene"] [--output="page_0"]');
    process.exit(1);
  }

  // Valida i personaggi
  const unknownChars = charList.filter(id => !config.characters[id]);
  if (unknownChars.length > 0) {
    console.error(`❌ Personaggi sconosciuti: ${unknownChars.join(', ')}`);
    console.error(`   Validi: ${Object.keys(config.characters).join(', ')}`);
    process.exit(1);
  }

  // Carica il workflow
  if (!fs.existsSync(workflowPath)) {
    console.error(`❌ Workflow non trovato: ${workflowPath}`);
    console.error('   Assicurati che favilla_blaze_ipadapter.json sia sul Desktop.');
    process.exit(1);
  }
  const workflow = JSON.parse(fs.readFileSync(workflowPath, 'utf-8'));

  // Upload tutte le immagini reference (tutti i nodi LoadImage sono sempre nel grafo)
  console.log('📤 Upload immagini reference...');
  for (const [charId, charConf] of Object.entries(config.characters)) {
    const imagePath = expandHome(charConf.image);
    if (!fs.existsSync(imagePath)) {
      console.error(`❌ Immagine non trovata per ${charId}: ${imagePath}`);
      console.error('   Aggiorna il path in .github/skills/comfyui-generator/config/characters.json');
      process.exit(1);
    }
    const result = await uploadImage(comfyUrl, imagePath);
    if (!result.name) {
      console.error(`❌ Upload fallito per ${charId}:`, JSON.stringify(result));
      process.exit(1);
    }
    process.stdout.write(`   ✓ ${charId} (${result.name})\n`);
  }

  // Imposta ip_scale XLabs IPAdapter: ip_weight per i personaggi attivi, 0.0 per gli altri
  // In modalità scene usa scene_ip_weight (più basso) per lasciare spazio al testo
  const activeSet    = new Set(charList);
  const sceneWeight  = (sceneType === 'scene') ? (config.scene_ip_weight ?? 0.35) : null;
  for (const [charId, charConf] of Object.entries(config.characters)) {
    const nodeId   = config.nodes[charId].ipAdapter;
    const strength = activeSet.has(charId) ? (sceneWeight ?? charConf.ip_weight ?? 0.85) : 0.0;
    workflow[nodeId].inputs.ip_scale = strength;
  }

  // Costruisci il prompt positivo
  const styleBlock = (sceneType === 'scene' && config.scene_style_block)
    ? config.scene_style_block
    : config.style_block;

  const descriptors = charList
    .map(id => config.characters[id]?.descriptor)
    .filter(Boolean)
    .join(',\n');

  const envBlock = (envKey && config.environments[envKey]) ? config.environments[envKey] : '';

  const positivePrompt = [
    styleBlock,
    descriptors,
    `Scene: ${sceneDesc}`,
    envBlock
  ].filter(Boolean).join(',\n');

  // Patcha i nodi
  workflow[config.prompt_node].inputs.text           = positivePrompt;
  workflow[config.negative_node].inputs.text         = config.negative_block;
  workflow[config.sampler_node].inputs.seed          = Math.floor(Math.random() * 2 ** 32);
  workflow[config.save_node].inputs.filename_prefix  = outputName;

  // Info pre-generazione
  const activeWeights = charList.map(id => {
    const w = sceneWeight ?? config.characters[id]?.ip_weight ?? 0.80;
    return `${id}=${w} (strength)`;
  }).join(', ');
  console.log(`\n🎨 Personaggi attivi: ${activeWeights}`);
  console.log(`🔕 Disattivati (weight=0): ${Object.keys(config.characters).filter(id => !activeSet.has(id)).join(', ') || 'nessuno'}`);
  console.log(`🖼  Tipo composizione: ${sceneType}`);
  if (envKey) console.log(`🗺  Ambiente: ${envKey}`);
  console.log(`📝 Prompt positivo:\n${positivePrompt}\n`);

  // Invia a ComfyUI
  console.log('🚀 Invio a ComfyUI...');
  const queueResult = await postJson(comfyUrl, '/prompt', { prompt: workflow });
  const promptId = queueResult.prompt_id;
  if (!promptId) {
    console.error('❌ ComfyUI non ha restituito un prompt_id:', JSON.stringify(queueResult));
    process.exit(1);
  }
  console.log(`   prompt_id: ${promptId}`);

  // Attendi il completamento
  const done = await pollUntilDone(comfyUrl, promptId);

  // Trova l'immagine di output
  const imageNode = Object.values(done.outputs || {}).find(o => o.images?.length > 0);
  if (imageNode) {
    const img        = imageNode.images[0];
    const outputDir  = expandHome(config.output_dir);
    const outputFile = path.join(outputDir, img.subfolder || '', img.filename);
    console.log(`\n✅ Immagine generata:\n   ${outputFile}\n`);
    console.log('💡 Prossimi passi:');
    console.log(`   1. Converti in WebP:`);
    console.log(`      sips -s format webp -s formatOptions 85 "${outputFile}" --out "assets/episodes/<id>/${outputName}.webp"`);
    console.log('   2. Lancia la skill asset-check');
    console.log('   3. flutter run');
  } else {
    console.log(`\n✅ Completato! Controlla la cartella: ${expandHome(config.output_dir)}`);
  }
}

main().catch(err => {
  console.error('\n❌ Errore:', err.message);
  process.exit(1);
});

