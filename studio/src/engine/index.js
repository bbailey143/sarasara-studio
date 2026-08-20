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

const { SharedSolver, PROFILES, SUBSTRATES } = lab;

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
    'relocated_pigment', 'water', 'mobile_pigment', 'pigment_conservation_error',
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

    setSubstrate(id) {
      if (!SUBSTRATES[id]) throw new Error('Unknown substrate: ' + id);
      substrateId = id;
      solver.setSubstrate(SUBSTRATES[id]);
    },

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
          opts.pressure, opts.load, opts.water, opts.speed,
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
