import type { Context } from 'hono';
import type { Env } from '../env';
import { checkRateLimit, refundRateLimit } from '../lib/rate_limit';

interface PanelImageBody {
  missionSeed?: string;
  panelIndex?: number;
  sceneDescription?: string;
  /** Personaggi presenti nel pannello (per migliorare il prompt). */
  characters?: string[];
}

const PER_DAY = 60; // ~15 missioni complete/giorno per cliente
const MAX_SCENE_CHARS = 250;

// Stile coerente per tutto l'universo Favilla: master prompt fisso.
const MASTER_PROMPT_PREFIX =
  'comic book panel illustration, vibrant pop-art style, ' +
  'bold black ink outlines, halftone shading, cel-shaded, ' +
  'flat saturated colors, family friendly, cinematic lighting, ' +
  'detailed background, dynamic composition, ';

// Aggiunto a fine prompt sempre.
const MASTER_PROMPT_SUFFIX =
  ', no text, no speech bubbles, no letters, no captions, no logos, no watermark';

// Negative prompt globale.
const NEGATIVE_PROMPT =
  'text, letters, words, captions, speech bubbles, logo, watermark, signature, ' +
  'photorealistic, nsfw, nudity, blood, gore, ugly, deformed, low quality, ' +
  'bad anatomy, extra limbs, blurry';

const CHARACTER_HINTS: Record<string, string> = {
  favilla:
    'a cheerful tired supermom in her thirties with bright magenta hair in a messy bun, expressive eyes, casual home outfit, hero pose energy',
  sparkle_ale:
    'a tiny chaotic toddler boy with wild bright cyan hair and pajamas, huge sparkly eyes, mischievous grin, full of energy',
  mallow_bellow:
    'a kind sleepy dad in his thirties with soft teal hair, glasses, comfy hoodie, gentle smile',
};

export async function handlePanelImage(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const meta = c.var.meta;
  if (!c.env.AI) {
    return c.json({ error: 'ai_image_not_configured' }, 501);
  }

  let body: PanelImageBody;
  try {
    body = await c.req.json<PanelImageBody>();
  } catch {
    return c.json({ error: 'invalid_json' }, 400);
  }

  const scene = (body.sceneDescription ?? '').trim().slice(0, MAX_SCENE_CHARS);
  const missionSeed = (body.missionSeed ?? '').toString().slice(0, 64);
  const panelIndex = Number.isInteger(body.panelIndex) ? body.panelIndex! : 0;
  const characters = Array.isArray(body.characters)
    ? body.characters.filter((c) => typeof c === 'string').slice(0, 4)
    : [];

  if (!scene) {
    return c.json({ error: 'empty_scene' }, 400);
  }
  if (!missionSeed) {
    return c.json({ error: 'missing_seed' }, 400);
  }

  // Cache deterministica: stessa missione+pannello → stesso PNG.
  const cacheKey = `panelimg:v2:${missionSeed}:${panelIndex}`;
  const kv = c.env.AI_KV;

  if (kv) {
    const cached = await kv.get(cacheKey, 'arrayBuffer');
    if (cached && cached.byteLength > 0) {
      return new Response(cached, {
        status: 200,
        headers: imageHeaders('hit'),
      });
    }
  }

  const rl = await checkRateLimit(c.env, meta, 'panel_image', { perDay: PER_DAY });
  if (!rl.allowed) {
    return c.json(
      { error: 'quota_exceeded', remaining: 0, resetAt: rl.resetAt },
      429,
    );
  }

  const charBits = characters
    .map((id) => CHARACTER_HINTS[id])
    .filter(Boolean)
    .join('. ');

  const prompt =
    MASTER_PROMPT_PREFIX +
    (charBits ? `${charBits}. ` : '') +
    sanitizeScene(scene) +
    MASTER_PROMPT_SUFFIX;

  // Seed deterministico per migliorare la coerenza tra pannelli della
  // stessa missione (i.e. la stessa "estrazione" stilistica).
  const seedNumber = stringToSeed(missionSeed);

  let bytes: Uint8Array;
  try {
    const result = await c.env.AI.run(
      '@cf/bytedance/stable-diffusion-xl-lightning',
      {
        prompt,
        negative_prompt: NEGATIVE_PROMPT,
        num_steps: 4, // SDXL Lightning: 4 step bastano
        width: 768,
        height: 768,
        seed: seedNumber + panelIndex, // varia leggermente per scene diverse
      },
    );

    bytes = await readToBytes(result);
  } catch (err) {
    console.error(JSON.stringify({
      event: 'panel_image_error',
      message: (err as Error).message,
    }));
    // Errore upstream Workers AI: rimborsa il tentativo.
    await refundRateLimit(c.env, meta, 'panel_image');
    return c.json(
      { error: 'image_generation_failed', message: 'AI image upstream error.' },
      502,
    );
  }

  if (bytes.byteLength === 0) {
    await refundRateLimit(c.env, meta, 'panel_image');
    return c.json({ error: 'empty_image' }, 502);
  }

  // Salva in KV per ~30 giorni.
  if (kv) {
    try {
      await kv.put(cacheKey, bytes, {
        expirationTtl: 60 * 60 * 24 * 30,
      });
    } catch (e) {
      console.warn('panel_image kv_put_failed:', (e as Error).message);
    }
  }

  return new Response(bytes, {
    status: 200,
    headers: imageHeaders('miss'),
  });
}

function imageHeaders(cache: 'hit' | 'miss'): Record<string, string> {
  return {
    'content-type': 'image/jpeg',
    'cache-control': 'public, max-age=2592000, immutable',
    'x-image-cache': cache,
  };
}

function sanitizeScene(s: string): string {
  return s.replace(/["'`<>]/g, ' ').replace(/\s+/g, ' ').trim();
}

function stringToSeed(s: string): number {
  // Hash semplice → numero positivo a 31 bit.
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h) % 0x7fffffff;
}

async function readToBytes(
  result: ReadableStream | Uint8Array | { image?: string } | unknown,
): Promise<Uint8Array> {
  if (result instanceof ReadableStream) {
    const reader = result.getReader();
    const chunks: Uint8Array[] = [];
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) chunks.push(value);
    }
    let total = 0;
    for (const c of chunks) total += c.length;
    const out = new Uint8Array(total);
    let off = 0;
    for (const c of chunks) {
      out.set(c, off);
      off += c.length;
    }
    return out;
  }
  if (result instanceof Uint8Array) return result;
  if (result instanceof ArrayBuffer) return new Uint8Array(result);
  // Alcune risposte SDXL sono { image: base64 }.
  if (result && typeof result === 'object' && 'image' in result) {
    const b64 = (result as { image: string }).image;
    return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  }
  throw new Error('unexpected_ai_response_type');
}
