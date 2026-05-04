import type { Env, RequestMeta } from '../env';

export interface GeminiContent {
  role: 'user' | 'model';
  parts: Array<{ text: string } | { inlineData: { mimeType: string; data: string } }>;
}

export interface GeminiRequest {
  systemInstruction?: { parts: Array<{ text: string }> };
  contents: GeminiContent[];
  generationConfig?: {
    temperature?: number;
    topP?: number;
    maxOutputTokens?: number;
    responseMimeType?: 'text/plain' | 'application/json';
    responseSchema?: Record<string, unknown>;
    thinkingConfig?: { thinkingBudget?: number };
  };
  safetySettings?: Array<{ category: string; threshold: string }>;
}

export interface GeminiResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string }> };
    finishReason?: string;
  }>;
  promptFeedback?: { blockReason?: string };
}

const SAFETY_STRICT = [
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_LOW_AND_ABOVE' },
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_LOW_AND_ABOVE' },
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_LOW_AND_ABOVE' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_LOW_AND_ABOVE' },
];

export async function callGemini(
  env: Env,
  meta: RequestMeta,
  request: GeminiRequest,
): Promise<{ text: string; raw: GeminiResponse }> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`;

  const body: GeminiRequest = {
    ...request,
    safetySettings: request.safetySettings ?? SAFETY_STRICT,
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    throw new GeminiError(
      `Gemini upstream error ${res.status}`,
      res.status >= 500 ? 502 : 400,
      errText.slice(0, 500),
    );
  }

  const json = (await res.json()) as GeminiResponse;
  if (json.promptFeedback?.blockReason) {
    throw new GeminiError(
      `Blocked by safety: ${json.promptFeedback.blockReason}`,
      400,
    );
  }

  const text = json.candidates?.[0]?.content?.parts
    ?.map((p) => ('text' in p ? p.text ?? '' : ''))
    .join('')
    .trim() ?? '';

  if (!text) {
    throw new GeminiError('Empty response from Gemini', 502);
  }

  // Logging minimale (no body utente, no PII).
  console.log(JSON.stringify({
    event: 'gemini_call',
    client: meta.clientId,
    model: env.GEMINI_MODEL,
    bytes: text.length,
  }));

  return { text, raw: json };
}

export class GeminiError extends Error {
  constructor(message: string, public status: number, public detail?: string) {
    super(message);
  }
}
