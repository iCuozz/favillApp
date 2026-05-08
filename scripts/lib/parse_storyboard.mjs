// Parser dello STORYBOARD.md (formato attuale di assets/episodes/<id>/STORYBOARD.md).
// Estrae i blocchi pagina nella forma:
//
//   ## page_3 — IL COLPO
//   **Beat**: ...
//   **Prompt**:
//   > <prompt su una o più righe blockquote>
//
// Restituisce anche il prompt di "thumb.webp" se presente.

import { readFile } from 'node:fs/promises';

/**
 * @param {string} path  Path assoluto allo STORYBOARD.md.
 * @returns {Promise<Array<{id:string, outFile:string, prompt:string}>>}
 */
export async function parseStoryboard(path) {
  const md = await readFile(path, 'utf8');
  const lines = md.split('\n');

  const pages = [];
  let current = null;

  const flush = () => {
    if (!current) return;
    if (current.promptLines.length) {
      const prompt = current.promptLines
        .map((l) => l.replace(/^>\s?/, ''))
        .join(' ')
        .replace(/\s+/g, ' ')
        .trim();
      pages.push({ id: current.id, outFile: current.outFile, prompt });
    }
    current = null;
  };

  let inPromptBlock = false;

  for (const raw of lines) {
    const line = raw.trimEnd();

    const headerMatch = line.match(/^##\s+(page_\d+|thumb\.webp)\b/);
    if (headerMatch) {
      flush();
      const tag = headerMatch[1];
      const outFile = tag === 'thumb.webp' ? 'thumb.webp' : `${tag}.webp`;
      current = { id: tag, outFile, promptLines: [] };
      inPromptBlock = false;
      continue;
    }

    if (!current) continue;

    if (/^\*\*Prompt\*\*:/i.test(line)) {
      inPromptBlock = true;
      continue;
    }

    if (inPromptBlock) {
      if (line.startsWith('>')) {
        current.promptLines.push(line);
      } else if (line.trim() === '') {
        // riga vuota: continua il blockquote se la prossima riga è '>'
        // (gestito implicitamente: niente da fare)
      } else if (/^---/.test(line) || /^##\s+/.test(line)) {
        inPromptBlock = false;
      }
    }
  }
  flush();
  return pages;
}

/**
 * Carica il JSON dell'episodio (assets/data/episodes/<id>.json) e ricava
 * la mappa { "page_0": ["favilla","sparkle_ale"], ... } sommando i character
 * di tutti i panel della pagina (anche dei branch).
 *
 * @param {string} jsonPath
 * @returns {Promise<Record<string,string[]>>}
 */
export async function extractCharactersByPage(jsonPath) {
  const ep = JSON.parse(await readFile(jsonPath, 'utf8'));
  const map = {};

  const collectFromPages = (pages) => {
    if (!Array.isArray(pages)) return;
    for (const page of pages) {
      const bg = page?.background || '';
      // Estrae "page_3" da "assets/episodes/missione_5/page_3.webp"
      const m = bg.match(/(page_\d+)\.webp$/);
      if (!m) continue;
      const key = m[1];
      const set = new Set(map[key] || []);
      for (const panel of page.panels || []) {
        for (const c of panel.characters || []) set.add(c);
      }
      map[key] = [...set];
    }
  };

  collectFromPages(ep.pages);
  if (ep.branches && typeof ep.branches === 'object') {
    for (const branch of Object.values(ep.branches)) {
      collectFromPages(branch?.pages);
    }
  }

  return map;
}
