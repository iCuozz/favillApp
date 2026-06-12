#!/usr/bin/env node
'use strict';

// generate-flux.cjs — Genera immagini via ComfyUI con workflow FLUX + Redux
// Costruisce la prompt API direttamente conoscendo la struttura fissa del workflow.
//
// Usage:
//   node .github/skills/comfyui-generator/scripts/generate-flux.cjs \
//     --scene="Favilla in cucina con Lex" \
//     --characters="favilla,lex" --env="kitchen" --output="page_0"

const fs = require('fs');
const path = require('path');
const http = require('http');
const os = require('os');

function expandHome(p) { return p ? p.replace(/^~/, os.homedir()) : p; }

function parseArgs(argv) {
  const r = {};
  for (const a of argv) {
    const m = a.match(/^--([^=]+)=(.*)$/s);
    if (m) r[m[1]] = m[2]; else if (a.startsWith('--')) r[a.slice(2)] = true;
  }
  return r;
}

function httpReq(opts, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(opts, res => {
      const chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString();
        try { resolve(JSON.parse(raw)); } catch { resolve(raw); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function uploadImage(comfyUrl, imagePath) {
  const filename = path.basename(imagePath);
  const ext = path.extname(filename).slice(1).toLowerCase();
  const mime = ext === 'jpg' ? 'image/jpeg' : `image/${ext}`;
  const data = fs.readFileSync(imagePath);
  const boundary = `----${Date.now()}`;
  const head = Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="image"; filename="${filename}"\r\nContent-Type: ${mime}\r\n\r\n`);
  const foot = Buffer.from(`\r\n--${boundary}--\r\n`);
  const body = Buffer.concat([head, data, foot]);
  const u = new URL(comfyUrl + '/upload/image');
  return httpReq({ hostname: u.hostname, port: u.port, path: u.pathname, method: 'POST',
    headers: { 'Content-Type': `multipart/form-data; boundary=${boundary}`, 'Content-Length': body.length }
  }, body);
}

// ─── Build API prompt directly for this FLUX workflow ────────────────────────

function buildPrompt(positiveText, negativeText, activeChars, sceneType, prefix, config) {
  const isScene = sceneType === 'scene';
  const config2 = config; // passed from main

  // Character Redux map: LoadImage node → charId
  const reduxNodes = { 10: 'favilla', 15: 'favilla_blaze', 20: 'mallow', 30: 'lex' };
  const active = new Set(activeChars);

  // StyleModelApply nodes are at LoadImage+2: 12, 17, 22, 32
  // Low strength = more influence from text prompt, less from reference image
  const reduxStrength = isScene ? (config2.scene_ip_weight ?? 0.12) : 0.20;

  const prompt = {};

  prompt[1] = { class_type: 'UnetLoaderGGUF', inputs: { unet_name: 'flux1-dev-Q4_K_S.gguf' } };
  prompt[2] = { class_type: 'DualCLIPLoaderGGUF', inputs: { clip_name1: 'clip_l.safetensors', clip_name2: 't5-v1_1-xxl-encoder-Q4_K_M.gguf', type: 'flux' } };
  prompt[3] = { class_type: 'VAELoader', inputs: { vae_name: 'ae.safetensors' } };
  prompt[4] = { class_type: 'CLIPVisionLoader', inputs: { clip_name: 'sigclip_vision_patch14_384.safetensors' } };
  prompt[5] = { class_type: 'StyleModelLoader', inputs: { style_model_name: 'flux1-redux-dev.safetensors' } };

  // Character LoadImage nodes → upload already done
  for (const [nid, charId] of Object.entries(reduxNodes)) {
    const imgFile = path.basename(expandHome(config.characters[charId].image));
    prompt[nid] = { class_type: 'LoadImage', inputs: { image: imgFile, upload: 'image' } };
  }

  prompt[11] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: ['4', 0], image: ['10', 0], crop: 'center' } };
  prompt[12] = { class_type: 'StyleModelApply', inputs: { style_model: ['5', 0], clip_vision_output: ['11', 0], strength: active.has('favilla') ? reduxStrength : 0, strength_type: 'multiply' } };

  prompt[16] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: ['4', 0], image: ['15', 0], crop: 'center' } };
  prompt[17] = { class_type: 'StyleModelApply', inputs: { style_model: ['5', 0], clip_vision_output: ['16', 0], strength: active.has('favilla_blaze') ? reduxStrength : 0, strength_type: 'multiply' } };

  prompt[21] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: ['4', 0], image: ['20', 0], crop: 'center' } };
  prompt[22] = { class_type: 'StyleModelApply', inputs: { style_model: ['5', 0], clip_vision_output: ['21', 0], strength: active.has('mallow') ? reduxStrength : 0, strength_type: 'multiply' } };

  prompt[31] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: ['4', 0], image: ['30', 0], crop: 'center' } };
  prompt[32] = { class_type: 'StyleModelApply', inputs: { style_model: ['5', 0], clip_vision_output: ['31', 0], strength: active.has('lex') ? reduxStrength : 0, strength_type: 'multiply' } };

  // Positive + negative prompts
  prompt[40] = { class_type: 'CLIPTextEncode', inputs: { text: positiveText, clip: ['2', 0] } };
  prompt[41] = { class_type: 'CLIPTextEncode', inputs: { text: negativeText, clip: ['2', 0] } };

  // FLUX guidance
  prompt[60] = { class_type: 'FluxGuidance', inputs: { conditioning: ['40', 0], guidance: 3.5 } };

  // Latent image + sampler
  prompt[50] = { class_type: 'EmptyLatentImage', inputs: { width: 576, height: 1024, batch_size: 1 } };

  const seed = Math.floor(Math.random() * 2 ** 32);
  prompt[51] = {
    class_type: 'KSampler',
    inputs: {
      model: ['1', 0],
      positive: ['60', 0],
      negative: ['41', 0],
      latent_image: ['50', 0],
      seed, steps: 15, cfg: 1,
      sampler_name: 'euler', scheduler: 'simple', denoise: 1
    }
  };

  prompt[52] = { class_type: 'VAEDecode', inputs: { samples: ['51', 0], vae: ['3', 0] } };
  prompt[53] = { class_type: 'SaveImage', inputs: { images: ['52', 0], filename_prefix: prefix } };

  return prompt;
}

// ─── Polling ──────────────────────────────────────────────────────────────────

async function poll(comfyUrl, promptId, ms = 3000) {
  process.stdout.write('⏳');
  for (;;) {
    const u = new URL(`${comfyUrl}/history/${promptId}`);
    const data = await httpReq({ hostname: u.hostname, port: u.port, path: u.pathname, method: 'GET' });
    if (data[promptId]) {
      const s = data[promptId].status;
      if (s?.completed) { process.stdout.write(' ✓\n'); return data[promptId]; }
      if (s?.status_str === 'error') { process.stdout.write('\n'); throw new Error('ComfyUI error'); }
    }
    process.stdout.write('.');
    await new Promise(r => setTimeout(r, ms));
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const configPath = path.join(__dirname, '..', 'config', 'characters.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
  const comfyUrl = args['comfyui-url'] || config.comfyui_url;
  const sceneDesc = args['scene'];
  const charList = (args['characters'] || 'favilla').split(',').map(s => s.trim());
  const envKey = args['env'] || null;
  const outputName = args['output'] || 'favillapp_output';
  const sceneType = args['type'] || 'scene';

  if (!sceneDesc) { console.error('❌ --scene obbligatorio'); process.exit(1); }

  // 1. Upload reference images
  console.log('📤 Upload immagini reference...');
  for (const [charId, charConf] of Object.entries(config.characters)) {
    const imgPath = expandHome(charConf.image);
    if (!fs.existsSync(imgPath)) { console.error(`❌ Immagine mancante: ${imgPath}`); process.exit(1); }
    const r = await uploadImage(comfyUrl, imgPath);
    if (!r.name) { console.error(`❌ Upload fallito ${charId}:`, JSON.stringify(r)); process.exit(1); }
    console.log(`   ✓ ${charId}`);
  }

  // 2. Build prompt text
  const styleBlock = config.style_block;
  const descriptors = charList.map(id => config.characters[id]?.descriptor).filter(Boolean).join(',\n');
  const envBlock = envKey && config.environments[envKey] ? config.environments[envKey] : '';
  const positivePrompt = [styleBlock, descriptors, `Scene: ${sceneDesc}`, envBlock].filter(Boolean).join(',\n');
  const negativePrompt = config.negative_block || '';

  // 3. Build API prompt
  const apiPrompt = buildPrompt(positivePrompt, negativePrompt, charList, sceneType, outputName, config);

  const reduxDisplay = sceneType === 'scene' ? (config.scene_ip_weight ?? 0.12) : 0.20;
  const activeInfo = charList.map(id => `${id}=${reduxDisplay}`).join(', ');
  console.log(`🎨 Personaggi attivi: ${activeInfo}`);
  if (envKey) console.log(`🗺  Ambiente: ${envKey}`);
  console.log(`📝 Prompt:\n${positivePrompt.substring(0, 200)}...\n`);

  // 4. Send to ComfyUI
  console.log('🚀 Invio a ComfyUI...');
  const u = new URL(comfyUrl + '/prompt');
  const result = await httpReq({
    hostname: u.hostname, port: u.port, path: u.pathname,
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, JSON.stringify({ prompt: apiPrompt }));

  const promptId = result.prompt_id;
  if (!promptId) { console.error('❌ Errore ComfyUI:', JSON.stringify(result)); process.exit(1); }
  console.log(`   prompt_id: ${promptId}`);

  // 5. Wait
  const done = await poll(comfyUrl, promptId);
  const imgNode = Object.values(done.outputs || {}).find(o => o.images?.length > 0);
  if (imgNode) {
    const img = imgNode.images[0];
    const outDir = expandHome(config.output_dir);
    const outFile = path.join(outDir, img.subfolder || '', img.filename);
    console.log(`\n✅ ${outFile}`);
    console.log(`\n💡 Convert to WebP:\n   sips -s format webp -s formatOptions 85 "${outFile}" --out assets/episodes/prologo/${outputName}.webp`);
  } else {
    console.log(`\n✅ Completato! Output in: ${expandHome(config.output_dir)}`);
  }
}

main().catch(e => { console.error('\n❌', e.message); process.exit(1); });
