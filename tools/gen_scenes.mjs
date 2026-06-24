#!/usr/bin/env node
/**
 * Genera scene del prologo — ONE AT A TIME, aspetta che ciascuna finisca.
 */

import fs from 'fs';
import http from 'http';

const API = "http://127.0.0.1:8188";
const OUTPUT = "/Users/andreacuozzo/Projects/favillApp/assets/episodes/prologo";

const BASE_STYLE = "digital comic illustration, semi-flat colors, bold clean black outlines, " +
  "expressive faces, Franco-Belgian comic style, warm Italian atmosphere, " +
  "portrait 9:16 vertical composition, cinematic lighting, " +
  "no text, no speech bubbles, no watermarks, high detail background.";

const SCENES = [
  { file: "page_0",  seed: 1001, chars: {favilla:0.35},
    prompt: "School classroom Italy afternoon. Young woman olive skin blonde ponytail blue school smock, surrounded by excited children at small desks. Holds pink eraser playfully. Colorful classroom chalkboard drawings." },
  { file: "page_1",  seed: 1002, chars: {favilla:0.35, lex:0.40, mallow:0.35},
    prompt: "Italian home kitchen chaos. Tired woman with olive skin blonde ponytail. Chubby baby with tiny red sneakers in high chair laughing. Man with mini-mohawk at table with laptop. Dinner boiling." },
  { file: "page_2",  seed: 1003, chars: {favilla:0.35, lex:0.40, mallow:0.20},
    prompt: "Messy kitchen counter close-up. Baby food splattered, flying spoon mid-air. Womans hands reaching. Baby in high chair mischievous. Man at laptop background. Pasta pot overflowing." },
  { file: "page_3",  seed: 1004, chars: {favilla:0.38, lex:0.40, mallow:0.20},
    prompt: "Dramatic moment kitchen. Baby in high chair leans dangerously forward tipping. Woman reaches desperately glasses askew panic. Pasta boiling. Phone falling. Man alarmed. Suspended moment." },
  { file: "page_4",  seed: 1005, chars: {favilla:0.15, favlaze:0.45, lex:0.35},
    prompt: "SUPERNATURAL TRANSFORMATION kitchen. Woman olive skin cat-eye glasses gone, hair erupting golden-orange glowing flame-like light, eyes amber. Holds baby safely. Kitchen perfect. Baby joyful smile. Golden particles." },
  { file: "page_carmela", seed: 1006, chars: {carmela:0.35},
    prompt: "Night view across quiet Italian street. Dark window third floor old building. Elderly woman silhouette grey hair bun in darkness. Wide eyes faint violet glow. Tense mystery. Street lamp orange on empty street." },
  { file: "page_5",  seed: 1007, chars: {favilla:0.35, mallow:0.35},
    prompt: "Kitchen after strange event. Woman olive skin blonde ponytail stands back to counter. Man enters looking concerned. Kitchen suspiciously clean. Warm domestic lighting." },
  { file: "page_epilogo", seed: 1008, chars: {favilla:0.35, mallow:0.10},
    prompt: "Bedroom night. Woman blonde hair sits on bed edge hugging herself, looking at reflection in dark window. Baby sleeping crib. Man on laptop. Blue moonlight. Emotional solitude." },
  { file: "page_branch_segreto", seed: 1010, chars: {favilla:0.35, lex:0.35, mallow:0.30},
    prompt: "Italian kitchen warm evening. Blonde woman at stove serving pasta. Man at table smiling. Baby in high chair knowing mischievous smile. Peaceful family dinner. Shared secret." },
  { file: "page_branch_legame", seed: 1011, chars: {favilla:0.35, lex:0.20, mallow:0.35},
    prompt: "Italian kitchen evening. Blonde woman and man with mini-mohawk at table facing. She looks tired vulnerable. He reaches hand across. Baby in high chair watches. Emotional intimacy." },
];

function buildPrompt(scene) {
  const p = {};
  p[1] = { class_type: 'UnetLoaderGGUF', inputs: { unet_name: 'flux1-dev-Q4_K_S.gguf' } };
  p[2] = { class_type: 'DualCLIPLoaderGGUF', inputs: { clip_name1: 'clip_l.safetensors', clip_name2: 't5-v1_1-xxl-encoder-Q4_K_M.gguf', type: 'flux' } };
  p[3] = { class_type: 'VAELoader', inputs: { vae_name: 'ae.safetensors' } };
  p[4] = { class_type: 'CLIPVisionLoader', inputs: { clip_name: 'sigclip_vision_patch14_384.safetensors' } };
  p[5] = { class_type: 'StyleModelLoader', inputs: { style_model_name: 'flux1-redux-dev.safetensors' } };
  p[40] = { class_type: 'CLIPTextEncode', inputs: { text: `${BASE_STYLE}\nScene: ${scene.prompt}`, clip: ['2', 0] } };
  p[41] = { class_type: 'CLIPTextEncode', inputs: { text: '', clip: ['2', 0] } };
  p[50] = { class_type: 'EmptyLatentImage', inputs: { width: 768, height: 1024, batch_size: 1 } };

  const cm = {
    favilla:  { start: 11, ref: 'favilla.png' },
    favlaze:  { start: 14, ref: 'favillaBlazeV1.png' },
    lex:      { start: 17, ref: 'lex.png' },
    mallow:   { start: 20, ref: 'mallow.png' },
    carmela:  { start: 23, ref: 'carmela.png' },
  };

  let prev = ['40', 0];
  for (const [cn, str] of Object.entries(scene.chars)) {
    if (!cm[cn] || str <= 0) continue;
    const s = cm[cn].start;
    p[s] = { class_type: 'LoadImage', inputs: { image: cm[cn].ref } };
    p[s + 1] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: ['4', 0], image: [s, 0], crop: 'center' } };
    p[s + 2] = { class_type: 'StyleModelApply', inputs: { conditioning: prev, style_model: ['5', 0], clip_vision_output: [s + 1, 0], strength: str, strength_type: 'multiply' } };
    prev = [s + 2, 0];
  }

  p[60] = { class_type: 'FluxGuidance', inputs: { conditioning: prev, guidance: 3.5 } };
  p[51] = { class_type: 'KSampler', inputs: { model: ['1', 0], positive: ['60', 0], negative: ['41', 0], latent_image: ['50', 0], seed: scene.seed, steps: 28, cfg: 1.0, sampler_name: 'euler', scheduler: 'simple', denoise: 1.0 } };
  p[52] = { class_type: 'VAEDecode', inputs: { samples: ['51', 0], vae: ['3', 0] } };
  p[53] = { class_type: 'SaveImage', inputs: { images: ['52', 0], filename_prefix: `prologo_${scene.file}` } };
  return p;
}

function apiPost(path, data) {
  return new Promise((resolve) => {
    const json = JSON.stringify(data);
    const u = new URL(API + path);
    const req = http.request({ hostname: u.hostname, port: u.port, path: u.pathname,
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(json) },
    }, (r) => { let b = ''; r.on('data', c => b += c); r.on('end', () => { try { resolve({status: r.statusCode, body: JSON.parse(b)}); } catch { resolve({status: r.statusCode, body: b}); } }); });
    req.on('error', e => resolve({status: 0, error: e.message}));
    req.write(json); req.end();
  });
}

function apiGet(path) {
  return new Promise((resolve) => {
    http.get(new URL(API + path), (r) => { let b = ''; r.on('data', c => b += c); r.on('end', () => { try { resolve(JSON.parse(b)); } catch { resolve({}); } }); })
      .on('error', () => resolve({}));
  });
}

function extractImgs(entry) {
  const imgs = [];
  for (const out of Object.values(entry.outputs || {}))
    for (const list of Object.values(out))
      if (Array.isArray(list))
        for (const item of list)
          if (item?.filename) imgs.push(item);
  return imgs;
}

async function waitExecution(promptId) {
  const start = Date.now();
  while (Date.now() - start < 900000) {
    await new Promise(r => setTimeout(r, 10000));
    try {
      const h = await apiGet(`/history/${promptId}`);
      if (h && h[promptId]) return extractImgs(h[promptId]);
    } catch {}
    // Check if still in queue
    try {
      const q = await apiGet('/queue');
      const all = [...(q.queue_running || []), ...(q.queue_pending || [])];
      const found = all.some(a => Array.isArray(a) && a[1] === promptId);
      if (!found) {
        await new Promise(r => setTimeout(r, 5000));
        try { const h = await apiGet(`/history/${promptId}`); if (h?.[promptId]) return extractImgs(h[promptId]); } catch {}
        return null;
      }
    } catch {}
    const elapsed = Math.round((Date.now()-start)/1000);
    process.stdout.write(`  ⏳ ${elapsed}s\r`);
  }
  return null;
}

async function main() {
  console.log('='.repeat(60));
  console.log('🔥 FAVILLA BLAZE — Prologo Scene Generator');
  console.log('='.repeat(60));

  // Verify API
  try {
    const test = await apiGet('/prompt');
    if (!test || test.error) throw new Error('No response');
    console.log(`✅ ComfyUI ready (queue: ${test?.exec_info?.queue_remaining || '?'})`);
  } catch (e) {
    console.log(`❌ ComfyUI not reachable: ${e.message}`);
    process.exit(1);
  }

  fs.mkdirSync(OUTPUT, { recursive: true });

  for (let i = 0; i < SCENES.length; i++) {
    const sc = SCENES[i];
    console.log(`\n${'='.repeat(60)}`);
    console.log(`[${i+1}/${SCENES.length}] ${sc.file}  (seed ${sc.seed}, chars: ${Object.keys(sc.chars).join(', ')})`);

    // Build and queue
    const prompt = buildPrompt(sc);
    const result = await apiPost('/prompt', { prompt, client_id: 'favillapp_gen' });

    if (!result.body?.prompt_id) {
      console.log(`  ❌ Queue failed: ${result.body?.error?.message || JSON.stringify(result.body).slice(0,200)}`);
      continue;
    }

    const pid = result.body.prompt_id;
    console.log(`  ⏳ Queued: ${pid.slice(0,8)}... waiting for execution...`);

    // Wait for COMPLETION
    const imgs = await waitExecution(pid);
    if (!imgs || imgs.length === 0) {
      console.log(`  ⚠️  No output or timeout`);
      continue;
    }

    console.log(`  ✅ Generated: ${imgs.map(i => i.filename).join(', ')}`);

    for (const img of imgs) {
      const src = `/Users/andreacuozzo/ComfyUI/output/${img.filename}`;
      const dst = `${OUTPUT}/${sc.file}.png`;
      try {
        fs.copyFileSync(src, dst);
        const kb = Math.round(fs.statSync(dst).size / 1024);
        console.log(`  💾 → ${sc.file}.png (${kb} KB)`);
      } catch (e) {
        console.log(`  ⚠️  Copy error: ${e.message}`);
      }
    }
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log('✅ ALL DONE');
  console.log(`   ${OUTPUT}`);
  console.log('='.repeat(60));
}

main().catch(e => { console.error('FATAL:', e); process.exit(1); });
