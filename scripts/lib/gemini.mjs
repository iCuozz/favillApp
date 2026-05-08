// Wrapper minimale sull'endpoint REST di Gemini 2.5 Flash Image.
// Doc: https://ai.google.dev/gemini-api/docs/image-generation

const MODEL = process.env.GEMINI_IMAGE_MODEL || 'gemini-2.5-flash-image';
const API_BASE = 'https://generativelanguage.googleapis.com/v1beta';

function getApiKey() {
  const key = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  if (!key) {
    throw new Error(
      'Manca GEMINI_API_KEY (oppure GOOGLE_API_KEY). Esporta la variabile d\'ambiente prima di lanciare lo script.\n' +
      'Esempio: export GEMINI_API_KEY="AIza..."',
    );
  }
  return key;
}

/**
 * Genera un'immagine.
 * @param {object} opts
 * @param {string} opts.prompt   Prompt completo (testo).
 * @param {Array<{mimeType:string,data:string}>} [opts.referenceImages] Immagini di riferimento (base64).
 * @param {number} [opts.maxAttempts=3]
 * @returns {Promise<{mimeType:string,data:Buffer}>}
 */
export async function generateImage({ prompt, referenceImages = [], maxAttempts = 3 }) {
  const apiKey = getApiKey();
  const url = `${API_BASE}/models/${MODEL}:generateContent`;

  const parts = [
    ...referenceImages.map((img) => ({
      inline_data: { mime_type: img.mimeType, data: img.data },
    })),
    { text: prompt },
  ];

  const body = {
    contents: [{ role: 'user', parts }],
    generationConfig: {
      responseModalities: ['IMAGE'],
    },
  };

  let lastErr;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: JSON.stringify(body),
      });

      if (!res.ok) {
        const errTxt = await res.text();
        throw new Error(`Gemini HTTP ${res.status}: ${errTxt.slice(0, 400)}`);
      }

      const json = await res.json();
      const candidates = json.candidates || [];
      for (const cand of candidates) {
        const candParts = cand?.content?.parts || [];
        for (const p of candParts) {
          const inline = p.inline_data || p.inlineData;
          if (inline?.data) {
            return {
              mimeType: inline.mime_type || inline.mimeType || 'image/png',
              data: Buffer.from(inline.data, 'base64'),
            };
          }
        }
      }
      const safety = JSON.stringify(candidates[0]?.safetyRatings || candidates[0]?.finishReason || 'no_image_in_response');
      throw new Error(`Nessuna immagine nella risposta (${safety})`);
    } catch (e) {
      lastErr = e;
      const wait = 1500 * attempt;
      console.warn(`  ⚠️  tentativo ${attempt}/${maxAttempts} fallito: ${e.message}`);
      if (attempt < maxAttempts) await new Promise((r) => setTimeout(r, wait));
    }
  }
  throw lastErr;
}
