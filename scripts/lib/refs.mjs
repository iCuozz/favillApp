// Prompt per generare le 4 character sheet di riferimento.
// Si generano UNA volta sola (o quando vuoi cambiare un look stagionale).
// Output: scripts/_refs/_ref_*.webp

const SHEET_STYLE = `
Character reference sheet, single character on plain light beige background,
three full-body views side by side: front view, 3/4 side view, back view.
Cute cartoon illustration, friendly all-ages animated comic style,
chibi-friendly proportions, soft cel-shading, flat warm colors, clean line art,
no background details, no text, no letters, no logos, no watermark.
Model sheet for animation reference. Square 1:1 composition.
`.trim();

export const REFERENCE_SHEETS = [
  {
    id: 'favilla',
    file: '_ref_favilla.webp',
    prompt: `${SHEET_STYLE}

CHARACTER: A 30-year-old blonde woman, soft loose ponytail, warm friendly face,
light makeup, wearing a buttoned white shirt, knee-length black pencil skirt,
black low heels, holding a black quilted Chanel-style handbag with gold chain.
This is "Favilla" in her elegant Saturday-night look (used for Mission #5).`,
  },
  {
    id: 'favilla_blaze',
    file: '_ref_favilla_blaze.webp',
    prompt: `${SHEET_STYLE.replace('three full-body views side by side: front view, 3/4 side view, back view.',
      'three full-body views: front hero pose, 3/4 dynamic hero pose, back view with cape flowing.')}

CHARACTER: Same blonde woman as the Favilla sheet, now in HERO mode "Favilla Blaze":
white buttoned shirt glowing from within with soft violet inner light,
black pencil skirt transformed into a flowing violet hero cape,
golden flowing hair like a mane, the black quilted handbag floating beside her
in a glowing violet aura, soft magical sparkles around her.`,
  },
  {
    id: 'mallow_bellow',
    file: '_ref_mallow.webp',
    prompt: `${SHEET_STYLE}

CHARACTER: A 30-year-old geek dad, light brown hair styled in a soft messy crest /
small mohawk on top (short on the sides, taller in the middle), square black glasses,
warm goofy smile, wearing a sky-blue short-sleeve polo shirt, straight blue jeans,
high yellow Converse-style sneakers, holding a small silver 13-inch laptop under his arm.
This is "Mallow Bellow", Favilla's husband.`,
  },
  {
    id: 'sparkle_ale',
    file: '_ref_ale.webp',
    prompt: `${SHEET_STYLE}

CHARACTER: A 7-month-old baby boy, chubby cheeks, big sparkling brown eyes,
LIGHT BROWN HAIR styled in a small soft baby crest / tiny mohawk on top of the head
(exactly like his dad Mallow Bellow — same hair color, same crest shape but baby-sized),
happy grin showing two tiny teeth,
wearing a white mandarin-collar (Korean collar) baby shirt with small buttons,
soft mini blue jeans, tiny high red Converse-style sneakers.
He is sitting / standing in cartoon model-sheet poses (NOT in a high chair, this is a reference sheet).
This is "Sparkle Ale", the 7-month-old son. IMPORTANT: NOT blond — light brown hair with crest like dad.`,
  },
];
