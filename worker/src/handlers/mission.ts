import type { Context } from 'hono';
import type { Env } from '../env';
import { callGemini } from '../lib/gemini';
import { checkRateLimit } from '../lib/rate_limit';
import { charactersShortBlock, charactersFullBlock } from '../lib/characters';

interface MissionBody {
  lang?: 'it' | 'en';
  situation?: string;
}

const MAX_SITUATION_CHARS = 400;
const PER_DAY = 5;

const SYSTEM_IT = `Sei l'autore segreto del fumetto FavillApp e generi una "missione personale" per il lettore.

${charactersFullBlock('it')}

${charactersShortBlock('it')}

Regole:
- Tono luminoso, ironico, da fumetto. Italiano. Mantieni la voce di ogni personaggio come da bibbia sopra.
- Niente consigli medici, legali, finanziari, di sicurezza. Niente parolacce, violenza, contenuti per adulti.
- Trasforma la situazione del lettore in una mini-storia in 5 o 7 pannelli, con una vera arc narrativa: setup → escalation del caos → momento di rottura → trasformazione in Favilla Blaze → risoluzione → battuta finale di coraggio.
- Ogni pannello ha 2-4 blocchi di testo (max 160 caratteri ciascuno, possibilmente molto meno per dialoghi e pensieri; le narrazioni cinematografiche possono usare tutto lo spazio).
- Tipi di blocco ammessi: "narration" (solo speaker "narrator"), "dialogue", "thought" (solo per favilla).
- Alterna i tipi di blocco: usa narration per atmosfera e transizioni, dialogue per ritmo, thought di Favilla per ironia interiore. Almeno 1 thought di Favilla in tutta la missione.
- Coinvolgi Sparkle Ale e/o Mallow Bellow in modo coerente con la situazione, anche solo con una battuta. Non lasciarli sempre fuori.
- Il primo pannello apre con narration tipo "06:42. Cucina." seguita da una seconda narration cinematografica che ambienta la scena.
- L'ultimo pannello chiude con una battuta di Favilla che dà coraggio al lettore (max 2 frasi, calda, mai didascalica).
- Niente link, email, numeri di telefono, indirizzi.
- Niente nomi propri reali del lettore: parla in seconda persona.

Ritorna ESCLUSIVAMENTE JSON valido conforme allo schema fornito. Niente markdown, niente testo extra.`;

const SYSTEM_EN = `You are the secret author of the FavillApp comic and you generate a "personal mission" for the reader.

${charactersFullBlock('en')}

${charactersShortBlock('en')}

Rules:
- Bright, ironic, comic-book tone. English. Keep each character's voice as defined in the bible above.
- No medical, legal, financial, or safety advice. No profanity, violence, or adult content.
- Turn the reader's situation into a mini-story across 5 to 7 panels, with a real narrative arc: setup → chaos escalation → breaking point → Favilla Blaze transformation → resolution → final encouraging line.
- Each panel has 2-4 text blocks (max 160 chars each, ideally much less for dialogue and thoughts; cinematic narration can use the full space).
- Allowed block types: "narration" (only speaker "narrator"), "dialogue", "thought" (only for favilla).
- Alternate block types: use narration for atmosphere and transitions, dialogue for rhythm, Favilla's thoughts for inner irony. At least 1 thought from Favilla in the whole mission.
- Involve Sparkle Ale and/or Mallow Bellow consistently with the situation, even just with one line. Do not leave them out.
- The first panel opens with narration like "06:42. Kitchen." followed by a second cinematic narration that sets the scene.
- The last panel ends with a line by Favilla encouraging the reader (max 2 sentences, warm, never preachy).
- No links, emails, phone numbers, addresses.
- No real reader names: address them in the second person.

Return ONLY valid JSON conforming to the provided schema. No markdown, no extra text.`;

const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    title: { type: 'STRING' },
    subtitle: { type: 'STRING' },
    panels: {
      type: 'ARRAY',
      minItems: 5,
      maxItems: 7,
      items: {
        type: 'OBJECT',
        properties: {
          textBlocks: {
            type: 'ARRAY',
            minItems: 2,
            maxItems: 4,
            items: {
              type: 'OBJECT',
              properties: {
                type: {
                  type: 'STRING',
                  enum: ['narration', 'dialogue', 'thought'],
                },
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
        required: ['textBlocks'],
      },
    },
  },
  required: ['title', 'panels'],
};

export async function handleMission(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const meta = c.var.meta;

  let body: MissionBody;
  try {
    body = await c.req.json<MissionBody>();
  } catch {
    return c.json({ error: 'invalid_json' }, 400);
  }

  const situation = (body.situation ?? '').trim().slice(0, MAX_SITUATION_CHARS);
  if (situation.length < 5) {
    return c.json({ error: 'situation_too_short' }, 400);
  }

  const lang = body.lang === 'en' ? 'en' : 'it';
  const system = lang === 'en' ? SYSTEM_EN : SYSTEM_IT;

  const rl = await checkRateLimit(c.env, meta, 'mission', { perDay: PER_DAY });
  if (!rl.allowed) {
    return c.json(
      { error: 'quota_exceeded', remaining: 0, resetAt: rl.resetAt },
      429,
    );
  }

  const userPrompt = lang === 'en'
    ? `Reader's situation: """${situation}"""\nGenerate the comic mission as JSON.`
    : `Situazione del lettore: """${situation}"""\nGenera la missione a fumetti come JSON.`;

  const { text } = await callGemini(c.env, meta, {
    systemInstruction: { parts: [{ text: system }] },
    contents: [
      { role: 'user', parts: [{ text: userPrompt }] },
    ],
    generationConfig: {
      temperature: 0.95,
      topP: 0.95,
      maxOutputTokens: 2400,
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
      thinkingConfig: { thinkingBudget: 0 },
    },
  });

  let mission: unknown;
  try {
    mission = JSON.parse(text);
  } catch {
    return c.json(
      { error: 'bad_ai_response', message: 'AI returned invalid JSON.' },
      502,
    );
  }

  if (!isValidMission(mission)) {
    return c.json(
      { error: 'bad_ai_response', message: 'AI mission did not match schema.' },
      502,
    );
  }

  return c.json({
    mission,
    remaining: rl.remaining,
    resetAt: rl.resetAt,
  });
}

interface MissionShape {
  title: string;
  subtitle?: string;
  panels: Array<{
    textBlocks: Array<{
      type: 'narration' | 'dialogue' | 'thought';
      speaker: 'favilla' | 'sparkle_ale' | 'mallow_bellow' | 'narrator';
      text: string;
    }>;
  }>;
}

function isValidMission(v: unknown): v is MissionShape {
  if (!v || typeof v !== 'object') return false;
  const m = v as Record<string, unknown>;
  if (typeof m.title !== 'string' || !m.title.trim()) return false;
  if (!Array.isArray(m.panels) || m.panels.length < 1 || m.panels.length > 8) {
    return false;
  }
  for (const p of m.panels) {
    if (!p || typeof p !== 'object') return false;
    const pp = p as Record<string, unknown>;
    if (!Array.isArray(pp.textBlocks) || pp.textBlocks.length === 0) return false;
    for (const tb of pp.textBlocks) {
      if (!tb || typeof tb !== 'object') return false;
      const t = tb as Record<string, unknown>;
      if (typeof t.text !== 'string' || !t.text.trim()) return false;
      if (!['narration', 'dialogue', 'thought'].includes(t.type as string)) {
        return false;
      }
      if (!['favilla', 'sparkle_ale', 'mallow_bellow', 'narrator'].includes(
        t.speaker as string,
      )) {
        return false;
      }
    }
  }
  return true;
}
