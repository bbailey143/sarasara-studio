/**
 * THE SEAM.
 *
 * This module is the only thing in the studio that knows how the painting
 * engine is implemented. Everything above it — every panel, control, readout,
 * and review — talks to the interface returned by `createEngine()` and nothing
 * else.
 *
 * Today that interface is backed by the JavaScript reference solver in
 * `lab/shared-solver.js`. When the engine moves to a compiled/wasm build, only
 * this file changes: `createEngine` stays async, every other method stays
 * synchronous, and no panel notices the swap.
 *
 * Rules for anyone extending this:
 *   - The UI must never import `shared-solver.js` directly.
 *   - The UI must never read a canonical property id out of a profile to make a
 *     decision. Ask the engine what a material is; do not infer it.
 *   - Nothing here may branch on a material name.
 */

import '../../../lab/shared-solver.js';

const lab = globalThis.window?.SarasaraLab;
if (!lab) throw new Error('The shared solver did not register. Check lab/shared-solver.js.');

const { SharedSolver, PROFILES, SUBSTRATES, BRUSHES } = lab;

/** Artist-facing names for things the profiles only know by id. */
const MATERIAL_LABELS = { watercolor: 'Watercolor', charcoal: 'Charcoal', oil: 'Oil' };

/** Which readouts are worth showing for a given physical regime. */
const REGIME_READOUTS = {
  flowing: [
    'pigment_area_fraction', 'wet_area_fraction', 'water', 'absorbed_water',
    'mobile_pigment', 'deposited_pigment', 'relocated_pigment', 'pigment_conservation_error',
  ],
  granular: [
    'pigment_area_fraction', 'deposited_pigment', 'loose_pigment', 'coarse_fragment_pigment',
    'fine_dust_pigment', 'source_remaining_pigment', 'pressure_anchored_pigment',
    'lost_off_canvas_pigment', 'relocated_pigment', 'pigment_conservation_error',
  ],
  body: [
    'pigment_area_fraction', 'deposited_pigment', 'relief_peak', 'relief_area_fraction',
    'carried_pigment', 'relocated_pigment', 'water', 'mobile_pigment', 'pigment_conservation_error',
  ],
};

/** Plain-language labels, so a panel never has to translate a canonical name. */
export const READOUT_LABELS = {
  pigment_area_fraction: ['Marked area', '%'],
  wet_area_fraction: ['Wet area', '%'],
  water: ['Surface water', ''],
  absorbed_water: ['Soaked into paper', ''],
  mobile_pigment: ['Pigment in suspension', ''],
  deposited_pigment: ['Pigment on the sheet', ''],
  loose_pigment: ['Loose on the surface', ''],
  coarse_fragment_pigment: ['Crumbs', ''],
  fine_dust_pigment: ['Dust', ''],
  source_remaining_pigment: ['Left on the tool', ''],
  pressure_anchored_pigment: ['Pressed into paper', ''],
  lost_off_canvas_pigment: ['Left the page', ''],
  carried_pigment: ['Held on the brush', ''],
  relocated_pigment: ['Pushed by contact (running total)', ''],
  relief_peak: ['Tallest point', ''],
  relief_area_fraction: ['Area standing up', '%'],
  pigment_conservation_error: ['Ledger error', '%'],
};

const PERCENT_KEYS = new Set(['pigment_area_fraction', 'wet_area_fraction', 'relief_area_fraction']);

export async function createEngine({ width, height, material, substrate }) {
  let solver = new SharedSolver(width, height, PROFILES[material], SUBSTRATES[substrate]);
  let materialId = material;
  let substrateId = substrate;
  let brushId = 'disc';

  const reliefStats = () => {
    let peak = 0;
    let standing = 0;
    for (let i = 0; i < solver.n; i++) {
      const h = solver.reliefHeight(i);
      if (h > 0) standing++;
      if (h > peak) peak = h;
    }
    return { relief_peak: peak, relief_area_fraction: standing / solver.n };
  };

  return {
    get materialId() { return materialId; },
    get substrateId() { return substrateId; },

    /** 'flowing' | 'granular' | 'body' — derived from properties, never a name. */
    regime() { return solver.regime(); },

    profile() {
      const p = PROFILES[materialId];
      return { id: p.id, version: p.version, provenance: p.provenance };
    },

    substrateInfo() {
      const s = SUBSTRATES[substrateId];
      return { id: s.id, name: s.name, version: s.version, provenance: s.provenance };
    },

    setMaterial(id) {
      if (!PROFILES[id]) throw new Error('Unknown material: ' + id);
      materialId = id;
      solver.setProfile(PROFILES[id]);
    },

    /** The tool. 'disc' is the plain footprint every earlier review used. */
    setBrush(id) {
      if (!BRUSHES[id]) throw new Error('Unknown brush: ' + id);
      brushId = id;
      solver.setBrush(id);
    },

    brushInfo() {
      const b = BRUSHES[brushId];
      return { id: b.id, key: brushId, name: b.name, version: b.version, kind: b.kind, widthMm: b.widthMm || null };
    },

    /** A brush being edited. Handed in whole each time so the engine rebakes. */
    /** Lift the brush off the sheet, so the next stroke starts where it is put. */
    liftBrush() { solver.liftBrush(); },

    setBrushDefinition(definition) {
      brushId = 'custom';
      solver.setBrush({
        id: 'brush.custom.drawn.v0',
        name: definition.name || 'Custom',
        version: '0',
        kind: 'shape',
        outline: definition.outline,
        belly: definition.belly,
        softness: definition.softness,
        stiffness: definition.stiffness,
        widthMm: definition.widthMm,
        provenance: [{ status: 'stand-in', note: 'Drawn by the artist in the brush editor. Geometry only.' }],
      });
    },

    /** The definition behind a registry brush, so the editor can start from it. */
    brushDefinition(id) {
      const b = BRUSHES[id] || BRUSHES.filbert;
      if (b.kind !== 'shape') return null;
      return {
        name: b.name,
        outline: b.outline.map((p) => [p[0], p[1]]),
        belly: b.belly.map((s) => ({ ...s })),
        softness: b.softness,
        stiffness: b.stiffness ?? .6,
        widthMm: b.widthMm,
      };
    },

    setSubstrate(id) {
      if (!SUBSTRATES[id]) throw new Error('Unknown substrate: ' + id);
      substrateId = id;
      solver.setSubstrate(SUBSTRATES[id]);
    },

    /** Take a new sheet off the pad. Sheet 0 is the reference sheet. */
    newSheet(seed) { return solver.newSheet(seed); },
    sheetId() { return solver.getSheet(); },

    setViewGain(value) { solver.setDisplayGain(value); },

    /** Off means one simulation cell per screen block: honest edges, visible pixels. */
    setSmoothing(enabled) { solver.setSmoothing(enabled); },

    clear(dampness = 0) { solver.clear(dampness); },

    /** One contact segment. `action` is 'draw' or 'smudge'. */
    stroke(action, a, b, view, opts) {
      if (action === 'smudge') {
        solver.smudgeSegment(a.x, a.y, b.x, b.y, view.width, view.height, opts.pressure, opts.speed);
      } else {
        solver.depositSegment(
          a.x, a.y, b.x, b.y, view.width, view.height,
          opts.pressure, opts.load, opts.water, opts.speed, opts.angle || 0,
        );
      }
    },

    step(dt) { solver.step(dt); },
    forceDry() { solver.dry(); },
    render(ctx, canvas) { solver.render(ctx, canvas); },

    /** Named numbers, already filtered to what this regime can meaningfully report. */
    readout() {
      const raw = { ...solver.metrics(), ...reliefStats() };
      const keys = REGIME_READOUTS[solver.regime()] || Object.keys(raw);
      return keys
        .filter((key) => raw[key] !== undefined)
        .map((key) => {
          const [label, unit] = READOUT_LABELS[key] || [key, ''];
          const value = PERCENT_KEYS.has(key) ? raw[key] * 100 : raw[key];
          return { key, label, unit: unit || (key === 'pigment_conservation_error' ? '%' : ''), value };
        });
    },

    /** Everything a saved session needs to be reproducible later. */
    snapshot() {
      const raw = { ...solver.metrics(), ...reliefStats() };
      return { regime: solver.regime(), measurements: raw };
    },
  };
}

export const listBrushes = () =>
  Object.keys(BRUSHES).map((id) => ({
    id,
    name: BRUSHES[id].widthMm ? `${BRUSHES[id].name} · ${BRUSHES[id].widthMm} mm` : BRUSHES[id].name,
    version: BRUSHES[id].version,
  }));

export const listMaterials = () =>
  Object.keys(PROFILES).map((id) => ({
    id,
    name: MATERIAL_LABELS[id] || id,
    version: PROFILES[id].version,
  }));

export const listSubstrates = () =>
  Object.keys(SUBSTRATES).map((id) => ({
    id,
    name: SUBSTRATES[id].name,
    version: SUBSTRATES[id].version,
  }));
