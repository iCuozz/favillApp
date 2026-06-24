#!/usr/bin/env node
/**
 * Genera tutte le scene del prologo via ComfyUI API.
 * Usa FLUX + Redux con reference di Favilla, Lex, Mallow, Carmela.
 *
 * Usage: node generate_prologo.mjs
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
  {
    file: "page_0",
    prompt: "School classroom in Italy, afternoon light. A young woman with olive skin and " +
      "blonde ponytail in a blue school smock, surrounded by excited children " +
      "at small desks. She holds a pink eraser playfully. Colorful classroom with chalkboard and drawings.",
    chars: { favilla: 0.35, favlaze: 0, lex: 0, mallow: 0 },
    seed: 1001,
  },
  {
    file: "page_1",
    prompt: "Italian home kitchen chaos. A tired young woman with olive skin and blonde ponytail. " +
      "A chubby baby with tiny red sneakers in a high chair laughing. " +
      "A man with mini-mohawk at the table with laptop. Dinner boiling on stove.",
    chars: { favilla: 0.35, favlaze: 0, lex: 0.40, mallow: 0.35 },
    seed: 1002,
  },
  {
    file: "page_2",
    prompt: "Messy kitchen counter close-up. Baby food splattered, flying spoon mid-air. " +
      "Woman's hands reaching. Baby in high chair mischievous. " +
      "Man at laptop in background. Pasta pot overflowing. Chaotic domestic scene.",
    chars: { favilla: 0.35, favlaze: 0, lex: 0.40, mallow: 0.20 },
    seed: 1003,
  },
  {
    file: "page_3",
    prompt: "Dramatic moment in kitchen. A baby in high chair leans dangerously forward tipping. " +
      "Woman reaches out desperately, glasses askew, panic on face. " +
      "Pasta boiling over. Phone falling. Man looks up alarmed. Suspended moment.",
    chars: { favilla: 0.38, favlaze: 0, lex: 0.40, mallow: 0.20 },
    seed: 1004,
  },
  {
    file: "page_4",
    prompt: "SUPERNATURAL TRANSFORMATION in kitchen. Woman with olive skin, " +
      "cat-eye glasses gone, hair erupting into golden-orange glowing flame-like light, " +
      "eyes glowing amber. She holds a baby safely. Kitchen perfectly in place. " +
      "Baby looks with wide eyes and joyful smile. Golden particles. Power and maternal love.",
    chars: { favilla: 0.15, favlaze: 0.45, lex: 0.35, mallow: 0 },
    seed: 1005,
  },
  {
    file: "page_carmela",
    prompt: "Night view across quiet Italian street. Dark window on third floor of old building. " +
      "Elderly woman silhouette with grey hair bun in darkness. " +
      "Wide eyes with faint violet glow. She sensed something. Tense mystery. " +
      "Street lamp dim orange light on empty street.",
    chars: { favilla: 0, favlaze: 0, lex: 0, mallow: 0 },
    seed: 1006,
  },
  {
    file: "page_5",
    prompt: "Kitchen after strange event. Woman with olive skin and blonde ponytail " +
      "stands with back to counter, trying to look normal. " +
      "Man enters looking concerned. Kitchen suspiciously clean. Warm domestic lighting.",
    chars: { favilla: 0.35, favlaze: 0, lex: 0, mallow: 0.35 },
    seed: 1007,
  },
  {
    file: "page_epilogo",
    prompt: "Bedroom at night. Woman with blonde hair sits on bed edge, " +
      "hugging herself, looking at reflection in dark window. Baby sleeping in crib. " +
      "Man quietly on laptop. Blue moonlight. Emotional solitude, scared and confused.",
    chars: { favilla: 0.35, favlaze: 0, lex: 0, mallow: 0.10 },
    seed: 1008,
  },
];

// Build the base workflow in API format
function buildApiPrompt(scene) {
  const fullPrompt = `${BASE_STYLE}\nScene: ${scene.prompt}`;
  const { favilla, favlaze, lex, mallow } = scene.chars;

  // Node ID allocations. Using higher ranges to avoid conflicts.
  // 1-10: base model/loaders
  // 11-20: reference & encode for each char
  // 21-30: StyleModelApply for each char
  // 31-40: prompt, latent, guidance
  // 41-50: sampler, decode, save
  // Shared: CLIPVision (node 4), StyleModel (node 5)

  // We connect: text_prompt -> char1 -> char2 -> ... -> FluxGuidance -> KSampler
  // Character nodes: Node 11=Favilla, 14=FavillaBlaze, 17=Lex, 20=Mallow
  // Each char has 3 nodes: LoadImage, CLIPVisionEncode, StyleModelApply

  const charConfigs = [
    { id: 11, name: 'Favilla', ref: 'favilla.png', strength: favilla },
    { id: 14, name: 'FavillaBlaze', ref: 'favillaBlazeV1.png', strength: favlaze },
    { id: 17, name: 'Lex', ref: 'lex.png', strength: lex },
    { id: 20, name: 'Mallow', ref: 'mallow.png', strength: mallow },
    { id: 23, name: 'Carmela', ref: 'carmela.png', strength: 0.35 },
  ];

  // Filter active chars and build the chain
  const activeChars = charConfigs.filter(c => c.strength > 0);

  const prompt = {};

  // 1. UNet Loader GGUF
  prompt[1] = {
    class_type: 'UnetLoaderGGUF',
    inputs: { unet_name: 'flux1-dev-Q4_K_S.gguf' },
  };

  // 2. Dual CLIP Loader GGUF
  prompt[2] = {
    class_type: 'DualCLIPLoaderGGUF',
    inputs: {
      clip_name1: 'clip_l.safetensors',
      clip_name2: 't5-v1_1-xxl-encoder-Q4_K_M.gguf',
      type: 'flux',
    },
  };

  // 3. VAE Loader
  prompt[3] = {
    class_type: 'VAELoader',
    inputs: { vae_name: 'ae.safetensors' },
  };

  // 4. CLIP Vision Loader
  prompt[4] = {
    class_type: 'CLIPVisionLoader',
    inputs: { clip_name: 'sigclip_vision_patch14_384.safetensors' },
  };

  // 5. Style Model Loader (Redux)
  prompt[5] = {
    class_type: 'StyleModelLoader',
    inputs: { style_model_name: 'flux1-redux-dev.safetensors' },
  };

  // 6. Text prompt
  prompt[40] = {
    class_type: 'CLIPTextEncode',
    inputs: {
      text: fullPrompt,
      clip: [2, 0],
    },
  };

  // 7. Negative prompt (empty) — DualCLIPLoaderGGUF outputs 1 merged CLIP
  prompt[41] = {
    class_type: 'CLIPTextEncode',
    inputs: {
      text: '',
      clip: [2, 0],
    },
  };

  // 8. Empty latent
  prompt[50] = {
    class_type: 'EmptyLatentImage',
    inputs: {
      width: 768,
      height: 1024,
      batch_size: 1,
    },
  };

  // 9. Character chain: each active char has Load + Encode + Apply
  let prevCond = [40, 0]; // start from text prompt

  for (const char of activeChars) {
    const loadId = char.id;
    const encodeId = char.id + 1;
    const applyId = char.id + 2;

    // LoadImage
    prompt[loadId] = {
      class_type: 'LoadImage',
      inputs: { image: char.ref },
    };

    // CLIPVisionEncode
    prompt[encodeId] = {
      class_type: 'CLIPVisionEncode',
      inputs: {
        clip_vision: [4, 0],
        image: [loadId, 0],
        crop: 'center',
      },
    };

    // StyleModelApply
    prompt[applyId] = {
      class_type: 'StyleModelApply',
      inputs: {
        conditioning: prevCond,
        style_model: [5, 0],
        clip_vision_output: [encodeId, 0],
        strength: char.strength,
        strength_type: 'multiply',
      },
    };

    prevCond = [applyId, 0];
  }

  // 10. Flux Guidance
  prompt[60] = {
    class_type: 'FluxGuidance',
    inputs: {
      conditioning: prevCond,
      guidance: 3.5,
    },
  };

  // 11. KSampler
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

  // 12. VAE Decode
  prompt[52] = {
    class_type: 'VAEDecode',
    inputs: {
      samples: [51, 0],
      vae: [3, 0],
    },
  };

  // 13. Save Image
  prompt[53] = {
    class_type: 'SaveImage',
    inputs: {
      images: [52, 0],
      filename_prefix: `prologo_${scene.file}`,
    },
  };

  return prompt;
}

function postJson(url, data) {
  return new Promise((resolve, reject) => {
    const json = JSON.stringify(data);
    const urlObj = new URL(url);
    const opts = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(json) },
    };
    const req = http.request(opts, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch { resolve({ error: { message: 'Parse error', raw: body.slice(0, 200) } }); }
      });
    });
    req.on('error', reject);
    req.write(json);
    req.end();
  });
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    const opts = new URL(url);
    http.get(opts, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch { resolve(body); }
      });
    }).on('error', reject);
  });
}

async function waitForPrompt(promptId, timeout = 600) {
  const start = Date.now();
  while (Date.now() - start < timeout * 1000) {
    // Check history
    try {
      const history = await getJson(`${API}/history/${promptId}`);
      if (history && history[promptId]) {
        return extractImages(history[promptId]);
      }
    } catch { }

    // Check queue
    try {
      const queue = await getJson(`${API}/queue`);
      const running = queue.queue_running || [];
      const pending = queue.queue_pending || [];
      const stillRunning = [...running, ...pending].some(item => {
        if (Array.isArray(item) && item[1] === promptId) return true;
        if (Array.isArray(item) && item.length > 1 && String(item[1]).includes(promptId.slice(0, 8))) return true;
        return false;
      });
      if (!stillRunning) {
        // May have just finished — check history one more time after a delay
        await new Promise(r => setTimeout(r, 3000));
        try {
          const history = await getJson(`${API}/history/${promptId}`);
          if (history && history[promptId]) return extractImages(history[promptId]);
        } catch { }
        // Not in queue and not in history — might have errored
        console.log(`  ⚠️  Prompt ${promptId.slice(0, 8)} left queue without history entry`);
        return null;
      }
    } catch { }

    // Progress indicator
    const elapsed = Math.round((Date.now() - start) / 1000);
    if (elapsed % 30 < 5) {
      process.stdout.write(`  ⏳ ${elapsed}s...\r`);
    }

    await new Promise(r => setTimeout(r, 5000));
  }
  return null;
}

function extractImages(historyEntry) {
  const outputs = historyEntry.outputs || {};
  const images = [];
  for (const nodeId of Object.keys(outputs)) {
    const nodeOut = outputs[nodeId];
    for (const key of Object.keys(nodeOut)) {
      const list = nodeOut[key];
      if (Array.isArray(list)) {
        for (const item of list) {
          if (item && item.filename) images.push(item);
        }
      }
    }
  }
  return images;
}

async function main() {
  console.log('='.repeat(60));
  console.log('🔥 FAVILLA BLAZE — Generazione Scene Prologo');
  console.log('='.repeat(60));

  // Check API
  try {
    const ver = await getJson(`${API}/api/version`);
    console.log(`✅ ComfyUI: v${ver.version || '?'}`);
  } catch (e) {
    console.log(`❌ ComfyUI non raggiungibile: ${e.message}`);
    console.log('   Avvia con:');
    console.log('   cd /Users/andreacuozzo/ComfyUI-Installs/ComfyUI/ComfyUI && \\');
    console.log('     /Users/andreacuozzo/ComfyUI/.venv/bin/python main.py --listen 127.0.0.1');
    process.exit(1);
  }

  // Create output dir
  fs.mkdirSync(OUTPUT, { recursive: true });

  for (let i = 0; i < SCENES.length; i++) {
    const scene = SCENES[i];
    console.log(`\n${'='.repeat(60)}`);
    console.log(`[${i + 1}/${SCENES.length}] ${scene.file}`);
    console.log(`  Seed: ${scene.seed}`);
    console.log(`  Characters: ${JSON.stringify(scene.chars)}`);
    console.log('='.repeat(60));

    // Build API prompt
    const apiPrompt = buildApiPrompt(scene);

    // Queue
    try {
      const result = await postJson(`${API}/prompt`, {
        prompt: apiPrompt,
        client_id: 'favillapp-gen',
      });
      if (!result || result.error) {
        console.log(`  ❌ API Error: ${result?.error?.message || 'Unknown error'}`);
        if (result?.node_errors) {
          for (const [k, v] of Object.entries(result.node_errors)) {
            console.log(`     Node ${k}: ${JSON.stringify(v).slice(0, 150)}`);
          }
        }
        continue;
      }
      const promptId = result.prompt_id;
      console.log(`  ⏳ Queued: ${promptId.slice(0, 8)}...`);

      // Wait
      const images = await waitForPrompt(promptId);
      if (images && images.length > 0) {
        console.log(`  ✅ Generated: ${images.map(i => i.filename).join(', ')}`);

        // Copy to project
        for (const img of images) {
          const src = `/Users/andreacuozzo/ComfyUI/output/${img.filename}`;
          const dst = `${OUTPUT}/${scene.file}.png`;
          try {
            fs.copyFileSync(src, dst);
            const stats = fs.statSync(dst);
            console.log(`  💾 Saved: ${dst} (${Math.round(stats.size / 1024)} KB)`);
          } catch (e) {
            console.log(`  ⚠️  Copy failed: ${e.message}`);
          }
        }
      } else {
        console.log(`  ⚠️  Timeout — check ComfyUI GUI at http://127.0.0.1:8188`);
      }
    } catch (e) {
      console.log(`  ❌ Error: ${e.message}`);
    }

    // Brief pause between scenes
    await new Promise(r => setTimeout(r, 2000));
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log('✅ GENERAZIONE COMPLETATA!');
  console.log('='.repeat(60));
}

main().catch(console.error);
