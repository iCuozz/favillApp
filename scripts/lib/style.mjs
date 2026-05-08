// Blocchi di prompt riusabili per garantire stile e safety coerenti
// in tutta la produzione visiva di Favilla. Ogni scena viene avvolta da:
//   STYLE_LOCK + scene + CHARACTERS list + SAFETY_BLOCK

export const STYLE_LOCK = `
The FIRST GROUP of attached images are STYLE & COHERENCE REFERENCES taken
from the PREVIOUS EPISODE of the same series: match their exact art style,
line weight, color palette, shading technique, level of detail, lighting and
overall illustration "feel". Treat them as the canonical look of the series
AND as the canonical appearance of every recurring character (faces, hair,
outfits, proportions). The new scene must look like it could sit next to
them in the same episode without any visual discontinuity.

The LAST GROUP of attached images are CHARACTER REFERENCE SHEETS: keep the
characters visually identical to those references — same faces, same hair
(color, length, crest/mohawk shape), same outfits, same proportions, same
color palette. Do NOT redesign the characters. Do NOT change their hair color.

STYLE: cute cartoon illustration, friendly all-ages animated comic style,
chibi-friendly proportions, soft cel-shading, flat warm colors, clean line art,
soft warm lighting, cozy storybook atmosphere, single illustrated panel,
no panel borders, no speech bubbles.
`.trim();

export const SAFETY_BLOCK = `
SAFETY: wholesome, safe-for-kids, modest full-coverage clothing,
baby always smiling and properly dressed, baby always secured in a high chair
with safety harness, no real weapons, no violence, no blood, no scary faces.

DO NOT INCLUDE: text, letters, words, captions, speech bubbles, logos,
brand names, watermarks, signatures, photoreal rendering, 3D render,
extra fingers, deformed hands, multiple heads, duplicated characters,
inconsistent outfits, characters that don't match the reference sheets.
`.trim();

// Mappa logica → file ref + label umana per il prompt CHARACTERS.
// L'alias "favilla_blaze" usa la ref hero, "favilla" usa quella standard.
export const CHARACTER_REFS = {
  favilla:        { file: '_ref_favilla.webp',     label: 'Favilla (blonde mom, white shirt + black pencil skirt + Chanel-style bag)' },
  favilla_blaze:  { file: '_ref_favilla_blaze.webp', label: 'Favilla Blaze (hero mode: glowing white shirt, violet flowing cape, golden mane)' },
  mallow_bellow:  { file: '_ref_mallow.webp',      label: 'Mallow Bellow (geek dad, light brown hair with soft messy crest/small mohawk, sky-blue polo, jeans, yellow high sneakers, square glasses, silver laptop)' },
  sparkle_ale:    { file: '_ref_ale.webp',         label: 'Sparkle Ale (7-month-old baby boy, LIGHT BROWN hair with a small baby crest/mini mohawk just like his dad Mallow — NOT blond, white mandarin-collar shirt, mini jeans, tiny red high sneakers)' },
};

// Style reference image (file path relative to repo root). If present, viene
// allegata a ogni generazione di scena come riferimento di art-style globale.
// Per ora: page_7 di missione_4 (stile target richiesto dal product owner).
export const STYLE_REFERENCE_IMAGE = 'assets/episodes/missione_4/page_7.webp';

// Episodio precedente da usare come "coherence reference": tutte le sue
// immagini vengono allegate ad ogni prompt di scena per mantenere la
// coerenza visiva dei personaggi (volti, capelli, outfit) tra un episodio
// e il successivo. Path relativi alla repo root.
// Vengono incluse automaticamente in ordine alfabetico tutte le pagine
// dell'episodio indicato; lo style reference esplicito sopra viene
// piazzato per primo (e deduplicato) per fungere da "style anchor".
export const COHERENCE_REFERENCE_EPISODE = 'assets/episodes/missione_4';

/**
 * Costruisce il prompt finale per una scena.
 * @param {string} scenePrompt  Prompt scena dallo STORYBOARD.md.
 * @param {string[]} characterIds  Es. ['favilla','sparkle_ale'].
 * @returns {string}
 */
export function buildScenePrompt(scenePrompt, characterIds) {
  const present = (characterIds || [])
    .filter((id) => CHARACTER_REFS[id])
    .map((id) => `- ${CHARACTER_REFS[id].label}`);

  const charBlock = present.length
    ? `CHARACTERS IN THIS SCENE (must match the attached reference sheets):\n${present.join('\n')}`
    : 'CHARACTERS IN THIS SCENE: none (background / environment only).';

  return [STYLE_LOCK, '', `SCENE:\n${scenePrompt.trim()}`, '', charBlock, '', SAFETY_BLOCK].join('\n');
}
