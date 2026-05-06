import type { Context } from 'hono';
import type { Env } from '../env';
import { callGemini, GeminiError } from '../lib/gemini';
import { checkRateLimit, refundRateLimit } from '../lib/rate_limit';
import { charactersShortBlock, charactersFullBlock } from '../lib/characters';

interface BranchHistoryItem {
  choice?: string;
  summary?: string;
}

interface BranchBody {
  lang?: 'it' | 'en';
  history?: BranchHistoryItem[];
  lastChoice?: string | null;
  depth?: number;
  seed?: string;
}

const PER_DAY = 30; // ~6 partite complete (5 step) al giorno per cliente
const MAX_DEPTH = 4;
const MAX_HISTORY = 6;

const SCENE_TAGS = [
  'kitchen_calm',
  'kitchen_chaos',
  'living_calm',
  'living_chaos',
  'bedroom_night',
  'bathroom',
  'street',
  'supermarket',
  'blaze_aura',
  'victory_glow',
  'sad_rain',
  'funny_explosion',
] as const;

const SYSTEM_IT = (forceEnding: boolean) => `Sei l'autore segreto del fumetto FavillApp e stai conducendo una storia INTERATTIVA "scegli tu" per il lettore.

${charactersFullBlock('it')}

${charactersShortBlock('it')}

Regole:
- Tono luminoso, ironico, da fumetto. Italiano.
- Niente consigli medici, legali, finanziari, di sicurezza. Niente parolacce, violenza, contenuti per adulti.
- Genera UNA SOLA scena (1 pannello) come prossimo nodo della storia.
- La scena ha 2-4 blocchi di testo (max 140 caratteri ciascuno, idealmente molto meno per dialoghi).
- Tipi blocco: "narration" (speaker "narrator"), "dialogue", "thought" (solo per favilla).
- Coinvolgi i personaggi in modo coerente con la storia ricevuta.
- Scegli il campo "sceneTag" SOLO tra: ${SCENE_TAGS.join(', ')}. Sceglilo coerente col mood della scena.
${forceEnding
  ? '- Questo è l\'ULTIMO pannello: scrivi un finale soddisfacente (battuta calda di Favilla che chiude). Imposta "isEnding": true e dai un "endingTitle" breve (max 6 parole, in italiano). NON proporre "choices" (lista vuota).'
  : '- Genera 2 o 3 "choices" SHORT (max 5 parole ciascuna, in italiano), DIVERSE tra loro, che lascino al lettore scelte interessanti su come proseguire. Imposta "isEnding": false e "endingTitle": null.'}
- Niente link, email, numeri di telefono, nomi propri reali. Parla in seconda persona quando serve.

Ritorna ESCLUSIVAMENTE JSON valido conforme allo schema. Niente markdown, niente testo extra.`;

const SYSTEM_EN = (forceEnding: boolean) => `You are the secret author of the FavillApp comic and you are running an INTERACTIVE "choose your own" story for the reader.

${charactersFullBlock('en')}

${charactersShortBlock('en')}

Rules:
- Bright, ironic, comic-book tone. English.
- No medical, legal, financial, or safety advice. No profanity, violence, or adult content.
- Generate ONLY ONE scene (1 panel) as the next node of the story.
- The scene has 2-4 text blocks (max 140 chars each, ideally much shorter for dialogue).
- Block types: "narration" (speaker "narrator"), "dialogue", "thought" (only for favilla).
- Involve the characters consistently with the story so far.
- Choose the "sceneTag" field ONLY from: ${SCENE_TAGS.join(', ')}. Pick one matching the scene mood.
${forceEnding
  ? '- This is the LAST panel: write a satisfying ending (warm closing line by Favilla). Set "isEnding": true and provide a short "endingTitle" (max 6 words, in English). Do NOT propose any "choices" (empty list).'
  : '- Generate 2 or 3 SHORT "choices" (max 5 words each, in English), DIFFERENT from each other, that give the reader interesting next steps. Set "isEnding": false and "endingTitle": null.'}
- No links, emails, phone numbers, real names. Use second person when needed.

Return ONLY valid JSON conforming to the schema. No markdown, no extra text.`;

const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    page: {
      type: 'OBJECT',
      properties: {
        sceneTag: { type: 'STRING', enum: [...SCENE_TAGS] },
        blocks: {
          type: 'ARRAY',
          minItems: 2,
          maxItems: 4,
          items: {
            type: 'OBJECT',
            properties: {
              type: { type: 'STRING', enum: ['narration', 'dialogue', 'thought'] },
              speaker: {
                type: 'STRING',
                enum: ['favilla', 'sparkle_ale', 'mallow_bellow', 'narrator'],
              },
              text: { type: 'STRING' },
            },
            required: ['type', 'speaker', 'text'],
          },
        },
      },
      required: ['sceneTag', 'blocks'],
    },
    choices: {
      type: 'ARRAY',
      maxItems: 3,
      items: {
        type: 'OBJECT',
        properties: {
          id: { type: 'STRING' },
          label: { type: 'STRING' },
        },
        required: ['id', 'label'],
      },
    },
    isEnding: { type: 'BOOLEAN' },
    endingTitle: { type: 'STRING', nullable: true },
  },
  required: ['page', 'choices', 'isEnding'],
};

export async function handleBranch(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const meta = c.var.meta;

  let body: BranchBody;
  try {
    body = await c.req.json<BranchBody>();
  } catch {
    return c.json({ error: 'invalid_json' }, 400);
  }

  const lang = body.lang === 'en' ? 'en' : 'it';
  const depth = Math.max(0, Math.min(MAX_DEPTH, Number(body.depth) || 0));
  const lastChoice = (body.lastChoice ?? '').toString().slice(0, 80);
  const history = Array.isArray(body.history)
    ? body.history.slice(-MAX_HISTORY).map((h) => ({
        choice: (h.choice ?? '').toString().slice(0, 80),
        summary: (h.summary ?? '').toString().slice(0, 240),
      }))
    : [];
  const seed = (body.seed ?? '').toString().slice(0, 64);

  const forceEnding = depth >= MAX_DEPTH - 1; // ultimo livello: ending obbligato

  const rl = await checkRateLimit(c.env, meta, 'branch', { perDay: PER_DAY });
  if (!rl.allowed) {
    return c.json(
      { error: 'quota_exceeded', remaining: 0, resetAt: rl.resetAt },
      429,
    );
  }

  const system = lang === 'en' ? SYSTEM_EN(forceEnding) : SYSTEM_IT(forceEnding);

  const historyTxt = history.length === 0
    ? (lang === 'en' ? '(none yet — this is the very first scene)' : '(nessuna ancora — questa è la prima scena)')
    : history.map((h, i) =>
        `${i + 1}. ${lang === 'en' ? 'Choice' : 'Scelta'}: "${h.choice || '-'}" → ${h.summary || ''}`,
      ).join('\n');

  const userPrompt = lang === 'en'
    ? `Story seed / opening: """${seed || 'a generic Favilla family chaos morning'}"""

History so far:
${historyTxt}

Last reader choice: "${lastChoice || '(start)'}"
Current depth: ${depth} / ${MAX_DEPTH}

Generate the NEXT scene as JSON.`
    : `Spunto / apertura della storia: """${seed || 'un mattino di caos in famiglia Favilla'}"""

Storia finora:
${historyTxt}

Ultima scelta del lettore: "${lastChoice || '(inizio)'}"
Profondità attuale: ${depth} / ${MAX_DEPTH}

Genera la PROSSIMA scena come JSON.`;

  let text: string;
  try {
    const r = await callGemini(c.env, meta, {
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
      generationConfig: {
        temperature: 1.0,
        topP: 0.95,
        maxOutputTokens: 1200,
        responseMimeType: 'application/json',
        responseSchema: RESPONSE_SCHEMA,
        thinkingConfig: { thinkingBudget: 0 },
      },
    });
    text = r.text;
  } catch (err) {
    if (err instanceof GeminiError && err.status >= 500) {
      await refundRateLimit(c.env, meta, 'branch');
    }
    throw err;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    await refundRateLimit(c.env, meta, 'branch');
    return c.json({ error: 'bad_ai_response' }, 502);
  }

  if (!isValidBranch(parsed)) {
    await refundRateLimit(c.env, meta, 'branch');
    return c.json({ error: 'bad_ai_response' }, 502);
  }

  // Sanitize sceneTag: forza al fallback se valore inatteso (defensive).
  const node = parsed as BranchNode;
  if (!SCENE_TAGS.includes(node.page.sceneTag as typeof SCENE_TAGS[number])) {
    node.page.sceneTag = 'living_calm';
  }
  // Forza coerenza ending vs choices.
  if (node.isEnding) {
    node.choices = [];
  } else if (node.choices.length === 0) {
    // L'AI è stata pigra: facciamo un finale comunque per non bloccare.
    node.isEnding = true;
  }

  return c.json({
    ...node,
    depth,
    remaining: rl.remaining,
    resetAt: rl.resetAt,
  });
}

interface BranchNode {
  page: {
    sceneTag: string;
    blocks: Array<{ type: string; speaker: string; text: string }>;
  };
  choices: Array<{ id: string; label: string }>;
  isEnding: boolean;
  endingTitle?: string | null;
}

function isValidBranch(v: unknown): v is BranchNode {
  if (!v || typeof v !== 'object') return false;
  const r = v as Record<string, unknown>;
  const page = r.page as Record<string, unknown> | undefined;
  if (!page || typeof page !== 'object') return false;
  if (typeof page.sceneTag !== 'string') return false;
  if (!Array.isArray(page.blocks) || page.blocks.length < 1) return false;
  for (const b of page.blocks) {
    if (!b || typeof b !== 'object') return false;
    const bb = b as Record<string, unknown>;
    if (typeof bb.text !== 'string' || !bb.text.trim()) return false;
    if (!['narration', 'dialogue', 'thought'].includes(bb.type as string)) return false;
    if (!['favilla', 'sparkle_ale', 'mallow_bellow', 'narrator'].includes(bb.speaker as string)) return false;
  }
  if (!Array.isArray(r.choices)) return false;
  for (const c of r.choices) {
    if (!c || typeof c !== 'object') return false;
    const cc = c as Record<string, unknown>;
    if (typeof cc.id !== 'string' || typeof cc.label !== 'string') return false;
  }
  if (typeof r.isEnding !== 'boolean') return false;
  return true;
}
