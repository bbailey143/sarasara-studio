/**
 * The board: one row per behaviour that has to be judged.
 *
 * It has three kinds of subject, and keeping them apart matters.
 *
 *   THE PAINT   — what oil, watercolour or charcoal does. Per material.
 *   THE ENGINE  — what the brush machinery does for every brush: real size,
 *                 orientation, the belly, feathering, bending, running out.
 *                 One shared set. Approving "hair bends" on a filbert is a
 *                 statement about the engine, not about that filbert.
 *   THIS BRUSH  — whether this particular head is any good. Does it read as
 *                 the tool it claims to be, does its belly feel right, would
 *                 you reach for it again.
 *
 * The engine rows used to be keyed per brush, which meant there was no pass-off
 * for the thing actually being built — only for individual brushes. That was
 * wrong and the artist caught it.
 *
 * Live state is in docs/validation/board.json and is written by the artist
 * through the studio, never by a test run. Automated checks reach 'checked' and
 * stop there. Only the artist sets 'approved'.
 */

export const MARKS = {
  approved: { label: 'You approved it', short: 'Approved', tone: 'approved' },
  checked: { label: 'Machine says yes — your eye pending', short: 'Machine-checked', tone: 'checked' },
  partial: { label: 'Half there, tangled with other things', short: 'Partial', tone: 'partial' },
  recalibrate: { label: 'You checked it — it needs recalibrating', short: 'Recalibrate', tone: 'recalibrate' },
  none: { label: 'Not built', short: 'Not built', tone: 'none' },
};

/*
 * Worst to best. 'recalibrate' sits above 'not built' because a thing that is
 * built and wrong is further along than a thing that does not exist, and below
 * 'partial' because partial is half right rather than actively off.
 *
 * It is the only mark that asks a question back: choosing it opens a box for
 * the reason, which rides along with the next saved session rather than being
 * submitted separately.
 */
export const MARK_ORDER = ['none', 'recalibrate', 'partial', 'checked', 'approved'];

export const BOARD_ROWS = {
  watercolor: [
    { id: 'WC-01', name: 'Damp-paper spread', hint: 'a wash on a damp sheet', seed: 'partial' },
    { id: 'WC-02', name: 'Water and pigment stay separate', hint: 'the thing you were most right about', seed: 'checked' },
    { id: 'WC-03', name: 'Settling & granulation', hint: 'heavy pigment sinking into grain', seed: 'none' },
    { id: 'WC-04', name: 'Drying edge', hint: 'the dark rim as a wash dries', seed: 'partial' },
    { id: 'WC-05', name: 'Wet crossing', hint: 'blue into wet yellow — needs real colour', seed: 'none' },
    { id: 'WC-06', name: 'Clean-water bloom', hint: 'a drop pushing pigment outward', seed: 'partial' },
    { id: 'WC-07', name: 'Paper makes a difference', hint: 'hot press vs rough', seed: 'checked' },
    { id: 'WC-08', name: 'Failure range', hint: 'where it goes wrong, believably', seed: 'none' },
  ],
  charcoal: [
    { id: 'CH-01', name: 'Catches the tooth', hint: 'peaks take it before valleys', seed: 'approved' },
    { id: 'CH-02', name: 'Press harder, reach deeper', hint: 'not a stamp scaled up', seed: 'approved' },
    { id: 'CH-03', name: 'It breaks', hint: 'crumbs and dust, from real mass', seed: 'approved' },
    { id: 'CH-04', name: 'It dusts', hint: 'crumbs fall near, dust travels', seed: 'approved' },
    { id: 'CH-05', name: 'It smudges', hint: '"so much fun to use" — your words', seed: 'approved' },
    { id: 'CH-06', name: 'It lifts', hint: 'kneaded eraser, taking it back off', seed: 'none' },
    { id: 'CH-07', name: 'It burnishes', hint: 'rubbed slick, stops taking more', seed: 'none' },
    { id: 'CH-08', name: 'Failure range', hint: 'loose grain across load and speed', seed: 'partial' },
  ],
  oil: [
    { id: 'OL-01', name: 'Holds its shape', hint: 'a ridge stays a ridge', seed: 'approved' },
    { id: 'OL-02', name: 'Slumps when overloaded', hint: 'pile it too high and it gives', seed: 'checked' },
    { id: 'OL-03', name: 'The brush shoves it', hint: 'press hard enough, it moves as a mass', seed: 'approved' },
    { id: 'OL-04', name: 'It stands up', hint: 'real thickness off the sheet', seed: 'checked' },
    { id: 'OL-05', name: 'Never wets the sheet', hint: 'refuses water even when offered', seed: 'approved' },
    { id: 'OL-06', name: 'Never bleeds', hint: 'pigment goes where you put it', seed: 'approved' },
    { id: 'OL-12', name: 'Drags colour out', hint: 'a near-empty brush pulls paint onto bare canvas', seed: 'approved' },
    { id: 'OL-09', name: 'Takes light', hint: 'relief shading exists — unjudged', seed: 'partial' },
    { id: 'OL-07', name: 'Picks colour up into another', hint: 'a dirty brush; needs a rinse and a second colour', seed: 'none' },
    { id: 'OL-08', name: 'Dries', hint: 'sets over days and stops taking rework', seed: 'none' },
    { id: 'OL-10', name: 'Scrapes back', hint: 'wiping paint off with a blade or rag', seed: 'none' },
  ],
};

/**
 * The brush machinery. One set, shared by every brush that uses it.
 *
 * `needs` names what a tool must have before a row can be judged at all. The
 * disc has almost none of it — it is sized in cells, it is round, it has no
 * belly, no hair and no reservoir — which is exactly what makes it the frozen
 * reference. Judging the engine through the disc marks down the engine for the
 * disc's deliberate emptiness, and that happened on 2026-08-21.
 */
export const ENGINE_ROWS = [
  { id: 'BR-01', name: 'Holds its true size', hint: 'a 12 mm brush marks 12 mm, at any resolution', seed: 'checked', needs: 'size' },
  { id: 'BR-02', name: 'Knows how it is held', hint: 'edge stroke and broad stroke differ', seed: 'checked', needs: 'shape' },
  { id: 'BR-03', name: 'Opens with pressure', hint: 'tip only, then the belly comes down', seed: 'checked', needs: 'belly' },
  { id: 'BR-04', name: 'Feathers its edge', hint: 'a head of hair, not a cookie cutter', seed: 'checked', needs: null },
  { id: 'BR-05', name: 'Runs out of paint', hint: 'a reservoir that empties, and a dip that fills it', seed: 'checked', needs: 'reservoir' },
  { id: 'BR-06', name: 'Bends and lags', hint: 'the head trails the hand and rounds a corner off', seed: 'checked', needs: 'hair' },
  { id: 'BR-09', name: 'Lays paint by distance', hint: 'the same gesture lays the same paint however finely drawn', seed: 'checked', needs: null },
  { id: 'BR-07', name: 'Splays and splits', hint: 'press hard and the hairs separate', seed: 'none', needs: 'hair' },
  { id: 'BR-08', name: 'Springs back', hint: 'lift off and it recovers its shape', seed: 'none', needs: 'hair' },
];

/** What the tool in your hand can actually show. */
export const CANNOT_SHOW = {
  size: 'sized in cells, not millimetres',
  shape: 'round — it marks the same in every direction',
  belly: 'no belly to open',
  reservoir: 'bottomless by design',
  hair: 'no hair to bend',
};

/** Whether one particular head is any good. Per brush. */
export const BRUSH_ROWS = {
  disc: [
    { id: 'BX-00', name: 'Deliberately plain', hint: 'the frozen reference footprint, sized in cells, no hair', seed: 'approved' },
  ],
  filbert: [
    { id: 'BX-01', name: 'Reads as a filbert', hint: 'rounded, broad face, soft corners', seed: 'none' },
    { id: 'BX-02', name: 'Its belly feels right', hint: 'how it opens from tip to full head', seed: 'none' },
    { id: 'BX-03', name: 'Its hair feels right', hint: 'how far it trails and how it takes a corner', seed: 'none' },
    { id: 'BX-04', name: 'Worth keeping', hint: 'you would reach for it again', seed: 'none' },
  ],
};

BRUSH_ROWS.flat = [
  { id: 'BX-01', name: 'Reads as a flat', hint: 'square face, hard corners, a true edge', seed: 'none' },
  ...BRUSH_ROWS.filbert.slice(1).map((row) => ({ ...row })),
];

BRUSH_ROWS.custom = BRUSH_ROWS.filbert.map((row) =>
  row.id === 'BX-01'
    ? { ...row, name: 'Reads as what you drew', hint: 'the shape does what the drawing promised' }
    : { ...row },
);

export const seedBoard = () => {
  const board = { updatedAt: null, rows: {}, engine: {}, brushes: {} };
  for (const [material, rows] of Object.entries(BOARD_ROWS)) {
    board.rows[material] = {};
    for (const row of rows) board.rows[material][row.id] = { mark: row.seed, note: '', decidedAt: null };
  }
  for (const row of ENGINE_ROWS) board.engine[row.id] = { mark: row.seed, note: '', decidedAt: null };
  for (const [brush, rows] of Object.entries(BRUSH_ROWS)) {
    board.brushes[brush] = {};
    for (const row of rows) board.brushes[brush][row.id] = { mark: row.seed, note: '', decidedAt: null };
  }
  return board;
};
