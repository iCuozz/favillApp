#!/usr/bin/env node
/**
 * Genera scene del prologo — versione semplificata e robusta.
 * Ogni scena ha workflow separato con solo i personaggi necessari.
 *
 * Node ID scheme:
 *   1   UnetLoaderGGUF
 *   2   DualCLIPLoaderGGUF
 *   3   VAELoader
 *   4   CLIPVisionLoader (shared)
 *   5   StyleModelLoader Redux (shared)
 *   40  CLIPTextEncode (positive prompt)
 *   41  CLIPTextEncode (negative)
 *   50  EmptyLatentImage
 *   51  KSampler
 *   52  VAEDecode
 *   53  SaveImage
 *   60  FluxGuidance
 *
 *   Character chain (3 nodes each):
 *   11-13  Favilla (Load, Encode, Apply)
 *   14-16  Favilla Blaze
 *   17-19  Lex
 *   20-22  Mallow
 *   23-25  Carmela
 */

import fs from 'fs';
import http from 'http';

const API = "http://127.0.0.1:8188";
const OUTPUT = "/Users/andreacuozzo/Projects/favillApp/assets/episodes/prologo";

const BASE_STYLE = "digital comic illustration, semi-flat colors, bold clean black outlines, " +
  "expressive faces, Franco-Belgian comic style, warm Italian atmosphere, " +
  "portrait 9:16 vertical composition, cinematic lighting, " +
  "no text, no speech bubbles, no watermarks, high detail background.";

// Character definitions: [node_start_id, ref_image]
const CHARS = {
  favilla:  { start: 11, ref: 'favilla.png' },
  favlaze:  { start: 14, ref: 'favillaBlazeV1.png' },
  lex:      { start: 17, ref: 'lex.png' },
  mallow:   { start: 20, ref: 'mallow.png' },
  carmela:  { start: 23, ref: 'carmela.png' },
};

const SCENES = [
  {
    file: "page_0",
    prompt: "School classroom in Italy, afternoon light. A young woman with olive skin and " +
      "blonde ponytail in a blue school smock, surrounded by excited children " +
      "at small desks. She holds a pink eraser playfully. Colorful classroom with chalkboard and drawings.",
    chars: { favilla: 0.35 },
    seed: 1001,
  },
  {
    file: "page_1",
    prompt: "Italian home kitchen chaos. A tired young woman with olive skin and blonde ponytail. " +
      "A chubby baby with tiny red sneakers in a high chair laughing. " +
      "A man with mini-mohawk at the table with laptop. Dinner boiling on stove.",
    chars: { favilla: 0.35, lex: 0.40, mallow: 0.35 },
    seed: 1002,
  },
  {
    file: "page_2",
    prompt: "Messy kitchen counter close-up. Baby food splattered, flying spoon mid-air. " +
      "Woman's hands reaching. Baby in high chair mischievous. " +
      "Man at laptop in background. Pasta pot overflowing. Chaotic domestic scene.",
    chars: { favilla: 0.35, lex: 0.40, mallow: 0.20 },
    seed: 1003,
  },
  {
    file: "page_3",
    prompt: "Dramatic moment in kitchen. A baby in high chair leans dangerously forward tipping. " +
      "Woman reaches out desperately, glasses askew, panic on face. " +
      "Pasta boiling over. Phone falling. Man looks up alarmed. Suspended moment.",
    chars: { favilla: 0.38, lex: 0.40, mallow: 0.20 },
    seed: 1004,
  },
  {
    file: "page_4",
    prompt: "SUPERNATURAL TRANSFORMATION in kitchen. Woman with olive skin, " +
      "cat-eye glasses gone, hair erupting into golden-orange glowing flame-like light, " +
      "eyes glowing amber. She holds a baby safely. Kitchen perfectly in place. " +
      "Baby looks with wide eyes and joyful smile. Golden particles. Power and maternal love.",
    chars: { favilla: 0.15, favlaze: 0.45, lex: 0.35 },
    seed: 1005,
  },
  {
    file: "page_carmela",
    prompt: "Night view across quiet Italian street. Dark window on third floor of old building. " +
      "Elderly woman silhouette with grey hair bun in darkness. " +
      "Wide eyes with faint violet glow. She sensed something. Tense mystery. " +
      "Street lamp dim orange light on empty street.",
    chars: { carmela: 0.35 },
    seed: 1006,
  },
  {
    file: "page_5",
    prompt: "Kitchen after strange event. Woman with olive skin and blonde ponytail " +
      "stands with back to counter, trying to look normal. " +
      "Man enters looking concerned. Kitchen suspiciously clean. Warm domestic lighting.",
    chars: { favilla: 0.35, mallow: 0.35 },
    seed: 1007,
  },
  {
    file: "page_epilogo",
    prompt: "Bedroom at night. Woman with blonde hair sits on bed edge, " +
      "hugging herself, looking at reflection in dark window. Baby sleeping in crib. " +
      "Man quietly on laptop. Blue moonlight. Emotional solitude, scared and confused.",
    chars: { favilla: 0.35, mallow: 0.10 },
    seed: 1008,
  },
  // Branch pages
  {
    file: "page_branch_segreto",
    prompt: "Italian kitchen warm evening. A blonde woman at the stove serving pasta. " +
      "A man at the table smiling. A baby in a high chair with a knowing mischievous smile. " +
      "Peaceful family dinner. Shared secret between mother and baby. Comfortable home.",
    chars: { favilla: 0.35, lex: 0.35, mallow: 0.30 },
    seed: 1010,
  },
  {
    file: "page_branch_legame",
    prompt: "Italian kitchen evening. A blonde woman and a man with mini-mohawk at the table " +
      "facing each other. She looks tired and vulnerable. He reaches a hand across. " +
      "A baby in a high chair watches with big eyes. Emotional intimacy close framing.",
    chars: { favilla: 0.35, lex: 0.20, mallow: 0.35 },
    seed: 1011,
  },
];

function buildWorkflow(scene) {
  const prompt = {};

  // Base models (always present)
  prompt[1] = { class_type: 'UnetLoaderGGUF', inputs: { unet_name: 'flux1-dev-Q4_K_S.gguf' } };
  prompt[2] = { class_type: 'DualCLIPLoaderGGUF', inputs: { clip_name1: 'clip_l.safetensors', clip_name2: 't5-v1_1-xxl-encoder-Q4_K_M.gguf', type: 'flux' } };
  prompt[3] = { class_type: 'VAELoader', inputs: { vae_name: 'ae.safetensors' } };
  prompt[4] = { class_type: 'CLIPVisionLoader', inputs: { clip_name: 'sigclip_vision_patch14_384.safetensors' } };
  prompt[5] = { class_type: 'StyleModelLoader', inputs: { style_model_name: 'flux1-redux-dev.safetensors' } };

  // Text encodings
  prompt[40] = { class_type: 'CLIPTextEncode', inputs: { text: `${BASE_STYLE}\nScene: ${scene.prompt}`, clip: [2, 0] } };
  prompt[41] = { class_type: 'CLIPTextEncode', inputs: { text: '', clip: [2, 0] } };
  prompt[50] = { class_type: 'EmptyLatentImage', inputs: { width: 768, height: 1024, batch_size: 1 } };

  // Build character chain
  let prevCond = [40, 0];

  for (const [charName, strength] of Object.entries(scene.chars)) {
    const def = CHARS[charName];
    if (!def || strength <= 0) continue;

    const loadId = def.start;
    const encId = def.start + 1;
    const applyId = def.start + 2;

    prompt[loadId] = { class_type: 'LoadImage', inputs: { image: def.ref } };
    prompt[encId] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: [4, 0], image: [loadId, 0], crop: 'center' } };
    prompt[applyId] = {
      class_type: 'StyleModelApply',
      inputs: {
        conditioning: prevCond,
        style_model: [5, 0],
        clip_vision_output: [encId, 0],
        strength: strength,
        strength_type: 'multiply',
      },
    };

    prevCond = [applyId, 0];
  }

  // Flux guidance & sampling
  prompt[60] = { class_type: 'FluxGuidance', inputs: { conditioning: prevCond, guidance: 3.5 } };
  prompt[51] = {
    class_type: 'KSampler',
    inputs: {
      model: [1, 0],
      positive: [60, 0],
      negative: [41, 0],
      latent_image: [50, 0],
      seed: scene.seed,
      steps: 28,
      cfg: 1.0,
      sampler_name: 'euler',
      scheduler: 'simple',
      denoise: 1.0,
    },
  };
  prompt[52] = { class_type: 'VAEDecode', inputs: { samples: [51, 0], vae: [3, 0] } };
  prompt[53] = { class_type: 'SaveImage', inputs: { images: [52, 0], filename_prefix: `prologo_${scene.file}` } };

  return prompt;
}

function postJson(url, data) {
  return new Promise((resolve, reject) => {
    const json = JSON.stringify(data);
    const urlObj = new URL(url);
    const req = http.request({
      hostname: urlObj.hostname, port: urlObj.port, path: urlObj.pathname,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(json) },
    }, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch { resolve({ error: { message: 'Parse error' } }); }
      });
    });
    req.on('error', reject);
    req.write(json);
    req.end();
  });
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    http.get(new URL(url), (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch { resolve({}); }
      });
    }).on('error', reject);
  });
}

function extractImages(historyEntry) {
  const outputs = historyEntry.outputs || {};
  const images = [];
  for (const out of Object.values(outputs)) {
    for (const list of Object.values(out)) {
      if (Array.isArray(list)) {
        for (const item of list) {
          if (item && item.filename) images.push(item);
        }
      }
    }
  }
  return images;
}

async function waitForPrompt(promptId) {
  const start = Date.now();
  const timeout = 600000; // 10 minutes max per scene

  while (Date.now() - start < timeout) {
    // Check history
    try {
      const history = await getJson(`${API}/history/${promptId}`);
      if (history && history[promptId]) {
        return extractImages(history[promptId]);
      }
    } catch {}

    // Check queue status
    try {
      const queue = await getJson(`${API}/queue`);
      const all = [...(queue.queue_running || []), ...(queue.queue_pending || [])];
      const found = all.some(item => {
        if (!Array.isArray(item) || item.length < 2) return false;
        const id = String(item[1]);
        return id === promptId || id.startsWith(promptId);
      });
      if (!found) {
        await new Promise(r => setTimeout(r, 3000));
        try {
          const history = await getJson(`${API}/history/${promptId}`);
          if (history && history[promptId]) return extractImages(history[promptId]);
        } catch {}
        return null;
      }
    } catch {}

    const elapsed = Math.round((Date.now() - start) / 1000);
    if (elapsed % 15 < 5) process.stdout.write(`  ⏳ ${elapsed}s\r`);
    await new Promise(r => setTimeout(r, 5000));
  }
  return null;
}

async function main() {
  console.log('='.repeat(60));
  console.log('🔥 FAVILLA BLAZE — Generazione Scene Prologo');
  console.log('='.repeat(60));

  // Check ComfyUI
  try {
    const ver = await getJson(`${API}/api/version`);
    console.log(`✅ ComfyUI: v${ver.version || '?'}`);
  } catch (e) {
    console.log(`❌ ComfyUI not reachable: ${e.message}`);
    process.exit(1);
  }

  fs.mkdirSync(OUTPUT, { recursive: true });

  for (let i = 0; i < SCENES.length; i++) {
    const scene = SCENES[i];
    console.log(`\n${'='.repeat(60)}`);
    console.log(`[${i + 1}/${SCENES.length}] ${scene.file}`);
    console.log(`  Seed: ${scene.seed} | Chars: ${Object.keys(scene.chars).join(', ')}`);
    console.log('='.repeat(60));

    const workflow = buildWorkflow(scene);

    const result = await postJson(`${API}/prompt`, { prompt: workflow, client_id: 'favillapp' });
    if (!result || result.error) {
      console.log(`  ❌ API Error: ${result?.error?.message || 'Unknown'}`);
      if (result?.node_errors) {
        for (const [k, v] of Object.entries(result.node_errors)) {
          console.log(`     Node ${k}: ${JSON.stringify(v.errors).slice(0, 200)}`);
        }
      }
      continue;
    }

    const promptId = result.prompt_id;
    console.log(`  ⏳ Queued: ${promptId.slice(0, 8)}...`);

    const images = await waitForPrompt(promptId);
    if (images && images.length > 0) {
      console.log(`  ✅ Complete: ${images.map(i => i.filename).join(', ')}`);
      for (const img of images) {
        const src = `/Users/andreacuozzo/ComfyUI/output/${img.filename}`;
        const dst = `${OUTPUT}/${scene.file}.png`;
        try {
          fs.copyFileSync(src, dst);
          const s = fs.statSync(dst);
          const imgSize = (s.size / 1024).toFixed(0);
          console.log(`  💾 → ${scene.file}.png (${imgSize} KB)`);
        } catch (e) {
          console.log(`  ⚠️  Copy failed: ${e.message}`);
        }
      }
    } else {
      console.log(`  ⚠️  Timeout or no output`);
    }

    if (i < SCENES.length - 1) {
      console.log(`  ⏸️  Pausa 5s...`);
      await new Promise(r => setTimeout(r, 5000));
    }
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log('✅ GENERAZIONE COMPLETATA!');
  console.log(`   Immagini in: ${OUTPUT}`);
  console.log('='.repeat(60));
}

main().catch(e => {
  console.error('FATAL:', e);
  process.exit(1);
});
