/**
 * The board: one row per behaviour a material has to show.
 *
 * `seed` is the status recorded in each material folder under docs/validation/ at the
 * time the studio was built. Live state is held in docs/validation/board.json
 * and is written by the artist through the studio, never by a test run.
 *
 * A mark is a claim about what a person has SEEN. Automated checks can reach
 * 'checked' and stop there. Only the artist sets 'approved'.
 */

export const MARKS = {
  approved: { label: 'You approved it', short: 'Approved', tone: 'approved' },
  checked: { label: 'Machine says yes — your eye pending', short: 'Machine-checked', tone: 'checked' },
  partial: { label: 'Half there, tangled with other things', short: 'Partial', tone: 'partial' },
  none: { label: 'Not built', short: 'Not built', tone: 'none' },
};

export const MARK_ORDER = ['none', 'partial', 'checked', 'approved'];

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
    { id: 'OL-01', name: 'Holds its shape', hint: 'a ridge stays a ridge', seed: 'checked' },
    { id: 'OL-02', name: 'Slumps when overloaded', hint: 'pile it too high and it gives', seed: 'checked' },
    { id: 'OL-03', name: 'The brush shoves it', hint: 'press hard enough, it moves as a mass', seed: 'checked' },
    { id: 'OL-04', name: 'It stands up', hint: 'real thickness off the sheet', seed: 'checked' },
    { id: 'OL-05', name: 'Never wets the sheet', hint: 'refuses water even when offered', seed: 'checked' },
    { id: 'OL-06', name: 'Never bleeds', hint: 'pigment goes where you put it', seed: 'checked' },
    { id: 'OL-12', name: 'Drags colour out', hint: 'a near-empty brush pulls paint onto bare canvas', seed: 'checked' },
    { id: 'OL-09', name: 'Takes light', hint: 'relief shading exists — unjudged', seed: 'partial' },
    { id: 'OL-07', name: 'Picks colour up into another', hint: 'a dirty brush; needs a rinse and a second colour', seed: 'none' },
    { id: 'OL-08', name: 'Dries', hint: 'sets over days and stops taking rework', seed: 'none' },
    { id: 'OL-10', name: 'Scrapes back', hint: 'wiping paint off with a blade or rag', seed: 'none' },
  ],
};

export const seedBoard = () => {
  const board = { updatedAt: null, rows: {} };
  for (const [material, rows] of Object.entries(BOARD_ROWS)) {
    board.rows[material] = {};
    for (const row of rows) board.rows[material][row.id] = { mark: row.seed, note: '', decidedAt: null };
  }
  return board;
};
