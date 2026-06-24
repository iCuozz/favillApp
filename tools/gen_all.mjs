#!/usr/bin/env node
/** Generates ALL prologo scenes — max 2 Redux chars each, one at a time */
import fs from 'fs';
import http from 'http';

const API = "http://127.0.0.1:8188";
const OUT = "/Users/andreacuozzo/Projects/favillApp/assets/episodes/prologo";
const BASE = "digital comic illustration, semi-flat colors, bold clean black outlines, expressive faces, Franco-Belgian comic style, warm Italian atmosphere, portrait 9:16 vertical composition, cinematic lighting, no text, no speech bubbles, no watermarks, high detail background.";

const SCENES = [
  {f:"page_0",s:1001,c:{favilla:0.35},p:"School classroom Italy afternoon. Young woman olive skin blonde ponytail blue school smock, surrounded by excited children at small desks. She holds pink eraser playfully. Colorful classroom chalkboard drawings."},
  {f:"page_1",s:1002,c:{favilla:0.3,lex:0.35},p:"Italian home kitchen chaos. Tired young woman olive skin blonde ponytail. Chubby baby tiny red sneakers in high chair laughing. Man with mini-mohawk at table laptop dinner boiling. Family domestic scene."},
  {f:"page_2",s:1003,c:{favilla:0.3,lex:0.35},p:"Messy kitchen counter close-up. Baby food splattered flying spoon mid-air. Womans hands reaching. Baby in high chair mischievous. Man at laptop background. Pasta pot overflowing. Chaotic domestic scene."},
  {f:"page_3",s:1004,c:{favilla:0.35,lex:0.35},p:"Dramatic moment kitchen. Baby in high chair leans dangerously forward tipping. Woman reaches desperately glasses askew panic. Pasta boiling. Phone falling. Man alarmed. Suspended disaster moment."},
  {f:"page_4",s:1005,c:{favlaze:0.4,lex:0.3},p:"SUPERNATURAL TRANSFORMATION kitchen. Woman transformed olive skin hair erupting golden-orange glowing flame-like light eyes amber, holds baby safely in arms. Kitchen perfectly in place. Baby looks with wide eyes joyful smile. Golden particles supernatural warm glow."},
  {f:"page_carmela",s:1006,c:{carmela:0.35},p:"Night view across quiet Italian street. Dark window third floor old building. Elderly woman silhouette grey hair bun in darkness. Wide eyes faint violet glow sensing something. Tense mysterious atmosphere. Street lamp orange light."},
  {f:"page_5",s:1007,c:{favilla:0.3,mallow:0.3},p:"Kitchen after strange event. Woman olive skin blonde ponytail stands with back to counter trying to look normal. Man enters looking concerned. Kitchen suspiciously clean. Warm domestic lighting."},
  {f:"page_epilogo",s:1008,c:{favilla:0.35},p:"Bedroom night. Woman blonde hair sits on bed edge hugging herself, looking at reflection in dark window. Baby sleeping in crib. Man quietly on laptop. Blue moonlight. Emotional solitude scared confused."},
  {f:"page_branch_segreto",s:1010,c:{favilla:0.3,lex:0.3},p:"Italian kitchen warm evening. Blonde woman at stove serving pasta. Man at table smiling. Baby in high chair with knowing mischievous smile. Peaceful family dinner. Comfortable home atmosphere."},
  {f:"page_branch_legame",s:1011,c:{favilla:0.3,mallow:0.3},p:"Italian kitchen evening. Blonde woman and man with mini-mohawk at table facing each other. She looks tired vulnerable. He reaches hand across. Baby in high chair watches. Emotional intimate moment."},
];

const CM = { favilla: {s:11,r:'favilla.png'}, favlaze: {s:14,r:'favillaBlazeV1.png'}, lex: {s:17,r:'lex.png'}, mallow: {s:20,r:'mallow.png'}, carmela: {s:23,r:'carmela.png'} };

function build(sc) {
  const p = {};
  p[1] = { class_type: 'UnetLoaderGGUF', inputs: { unet_name: 'flux1-dev-Q4_K_S.gguf' } };
  p[2] = { class_type: 'DualCLIPLoaderGGUF', inputs: { clip_name1: 'clip_l.safetensors', clip_name2: 't5-v1_1-xxl-encoder-Q4_K_M.gguf', type: 'flux' } };
  p[3] = { class_type: 'VAELoader', inputs: { vae_name: 'ae.safetensors' } };
  p[4] = { class_type: 'CLIPVisionLoader', inputs: { clip_name: 'sigclip_vision_patch14_384.safetensors' } };
  p[5] = { class_type: 'StyleModelLoader', inputs: { style_model_name: 'flux1-redux-dev.safetensors' } };
  p[40] = { class_type: 'CLIPTextEncode', inputs: { text: BASE+'\nScene: '+sc.p, clip: ['2',0] } };
  p[41] = { class_type: 'CLIPTextEncode', inputs: { text: '', clip: ['2',0] } };
  p[50] = { class_type: 'EmptyLatentImage', inputs: { width: 768, height: 1024, batch_size: 1 } };
  let prev = ['40', 0];
  const entries = Object.entries(sc.c).filter(([,v]) => v > 0).slice(0, 2); // max 2!
  for (const [cn, str] of entries) {
    const d = CM[cn]; if (!d) continue;
    p[d.s] = { class_type: 'LoadImage', inputs: { image: d.r } };
    p[d.s+1] = { class_type: 'CLIPVisionEncode', inputs: { clip_vision: ['4',0], image: [d.s,0], crop: 'center' } };
    p[d.s+2] = { class_type: 'StyleModelApply', inputs: { conditioning: prev, style_model: ['5',0], clip_vision_output: [d.s+1,0], strength: str, strength_type: 'multiply' } };
    prev = [d.s+2, 0];
  }
  p[60] = { class_type: 'FluxGuidance', inputs: { conditioning: prev, guidance: 3.5 } };
  p[51] = { class_type: 'KSampler', inputs: { model: ['1',0], positive: ['60',0], negative: ['41',0], latent_image: ['50',0], seed: sc.s, steps: 28, cfg: 1.0, sampler_name: 'euler', scheduler: 'simple', denoise: 1.0 } };
  p[52] = { class_type: 'VAEDecode', inputs: { samples: ['51',0], vae: ['3',0] } };
  p[53] = { class_type: 'SaveImage', inputs: { images: ['52',0], filename_prefix: 'prologo_'+sc.f } };
  return p;
}

async function post(d) {
  const j = JSON.stringify(d);
  return new Promise(r => {
    http.request({hostname:'127.0.0.1',port:8188,path:'/prompt',method:'POST',
      headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(j)}},
      resp => { let b=''; resp.on('data',c=>b+=c); resp.on('end',()=>r(JSON.parse(b))); }).write(j);
  });
}
async function get(path) {
  return new Promise(r => http.get('http://127.0.0.1:8188'+path, resp => { let b=''; resp.on('data',c=>b+=c); resp.on('end',()=>{ try{r(JSON.parse(b))}catch{r({})}}); }));
}

async function gen(sc) {
  const r = await post({ prompt: build(sc), client_id: 'gen_'+sc.f });
  if (!r.prompt_id) { console.log('  FAILED'); return false; }
  const pid = r.prompt_id;
  process.stdout.write('  '+pid.slice(0,8));
  while (true) {
    await new Promise(r => setTimeout(r, 10000)); process.stdout.write('.');
    const h = await get('/history/'+pid);
    if (h && h[pid]) {
      const imgs = []; for (const o of Object.values(h[pid].outputs||{})) for (const l of Object.values(o)) if (Array.isArray(l)) for (const i of l) if (i?.filename) imgs.push(i);
      if (imgs.length) { for (const i of imgs) { fs.copyFileSync('/Users/andreacuozzo/ComfyUI/output/'+i.filename, OUT+'/'+sc.f+'.png'); } return true; }
      return false;
    }
    const q = await get('/queue');
    if (![...(q.queue_running||[]),...(q.queue_pending||[])].some(a => Array.isArray(a) && a[1]===pid)) {
      await new Promise(r => setTimeout(r, 5000));
      const h = await get('/history/'+pid);
      if (h && h[pid]) { const imgs = []; for (const o of Object.values(h[pid].outputs||{})) for (const l of Object.values(o)) if (Array.isArray(l)) for (const i of l) if (i?.filename) imgs.push(i); if (imgs.length) { for (const i of imgs) fs.copyFileSync('/Users/andreacuozzo/ComfyUI/output/'+i.filename, OUT+'/'+sc.f+'.png'); return true; } }
      return false;
    }
  }
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  console.log('='.repeat(60)+'\n🔥 FAVILLA BLAZE — Prologo\n'+'='.repeat(60));
  for (let i = 0; i < SCENES.length; i++) {
    const sc = SCENES[i];
    const start = Date.now();
    const chars = Object.keys(sc.c).join('+');
    console.log(`\n[${i+1}/${SCENES.length}] ${sc.f} (${chars})`);
    const ok = await gen(sc);
    if (ok) {
      const kb = Math.round(fs.statSync(OUT+'/'+sc.f+'.png').size/1024);
      console.log(` ✅ ${kb}KB, ${Math.round((Date.now()-start)/60)}min`);
    } else console.log(` ❌`);
  }
  console.log('\n✅ ALL DONE');
}
main().catch(e => console.error(e));
