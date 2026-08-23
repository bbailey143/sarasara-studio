# Watercolor Redesign — Historical Fallback Record

**Status: temporary fallback, not the target architecture (corrected
2026-07-12).** Stages A and B produced visible bleeding and passed their
behavior tests, but artist review found that the result still reads as wet
markers because diffusion is not fluid transport. The binding
`specs/watercolor-engine-spec.md` Fluid model is restored. This document is
kept to explain the experiment and preserve useful tuning—not to authorize a
second competing watercolor engine. See `WATERCOLOR-FLUID-RECOVERY.md`.

**No-overlap rule:** when the real Fluid pipeline is active, this fallback's
pigment-diffusion transport must be disabled. Shared components—spectral KM,
paper fields, brush contacts, checkpoints, and composite—remain reused.

**Current handoff note (2026-07-13):** `TestingArtifacts/watercolor-1.gif`
supersedes the looser historical acceptance below. Its blue wash pauses for
about eight seconds while the colour picker is open, then yellow crosses it.
When `Show wet areas` says that blue is still workable, the crossing must become
one subtractive green wash and the earlier blue ridge must disappear. The active
Fluid correction now extends paper-held damp time and lets accepted coloured
carrier fully re-wet still-active damp pigment. It reopens 90–94% of that active
deposit before local conservative mixing, while protected dry glaze is excluded;
the Flutter raw-image boundary also premultiplies transparent RGBA instead of
letting thin colour over-contribute light. See the recovery document and
binding spec for the exact rules.

**Dirty-brush and drying continuation (2026-07-13):** Stage C contact pickup is
now active without restoring the rejected proximity system. Watercolor samples
only the true bristle footprint in the one wet field, returns the exact removed
material to the shared brush reservoir, excludes protected dry pigment, and
disables pickup during replay. The rinse control follows that real receipt for
both watercolor and oil. The composite also animates visible dryback from a
deeper wet passage to a lighter, more paper-revealing matte dry passage using
the same mobility value shown by `Show wet areas`. Artist review then required
a much longer working interval: the live Dry-rate control now uses the binding
exponential `0.000002..0.0012` range documented in the recovery record.
The attempted 320-cell whole-sheet CPU `Review` mode was removed after it froze
when two wet colours combined. The app is restored to the safe 224-cell
reference. That grid remains useful for mechanical checks but is too coarse for
final paper/brush/medium judgment; tiled GPU resolution is now a required
precondition for confident visual tuning, not optional future polish.
After artist testing found heavy lag after roughly five or six still-wet
strokes, the safe CPU reference gained 16-cell activity tiles with a one-tile
halo. Ordered Fluid and pigment passes now skip dry tiles between separate wet
marks while retaining one shared sheet, so this performance correction cannot
turn strokes back into isolated paintings. Its artist performance check remains
pending; the GPU path is still required for final resolution.
When the freeze remained at the same stroke count with either one colour or
two, the limiting factor was isolated from mixing: live undo was retaining a
roughly 13 MB full-sheet wet checkpoint before every watercolor stroke. It now
stores all fields only in occupied 16×16 tiles, keeping restore exact without
duplicating blank paper. This memory fix is separate from Fluid behavior and
therefore does not alter mixing, drying, pressure, or brush transfer.
Because compact history did not move the freeze point, the next independent
cause was corrected in the live clock. A repeating 33 ms timer could saturate
the main UI once one Fluid update exceeded its slot. Updates now schedule only
after the preceding work completes and leave a guaranteed input/render gap
under load. Microscopic water and velocity remnants are retired before activity
tiling, and an optional Water-panel performance readout makes the next artist
test measurable rather than inferential.

**How it was verified:** a render-to-PNG harness paints scripted strokes and
saves frames that get judged by eye (the fix for tuning blind), plus behavior
tests in `test/watercolor_engine_test.dart` and the live path in
`test/watercolor_live_test.dart`.

## 1. Why the current build feels wrong

Two honest root causes, not six separate bugs:

1. **Two color systems fighting.** An older pickup mechanic
   (`_simulatePigmentExchange`) stirs nearby deposited paint into the brush on
   every pointer move and fades the brush each step. The new water-wash then
   paints with that corrupted color. → clean brushes dirtying near other colors,
   whiteout on the second stroke, "mixing when it wants to."

2. **No real-time fluid behavior.** The incompressible fluid solver produces
   almost no visible motion at real frame rates (~0.03 cells/step), and paint
   dries in ~1–2 s. So a stroke is a **dry stamp**, not wet paint that bleeds,
   blooms, mixes, and flings. Headless tests hid this — they use idealized
   splats over hundreds of steps.

**Meta-cause:** I built the physics for *tests I could measure* instead of the
*look I need to see*, and I layered a new system onto a half-built old one.

## 2. What "good" looks like (acceptance, judged by eye)

1. Lay a stroke → soft wet edges, remains workable through an ordinary colour
   change, and darkens at its drying edge. `Show wet areas` must agree with the
   actual mixing decision.
2. Lay yellow across still-wet blue → **one green wash where they overlap**, a
   softened/lost earlier blue boundary, and contact may now carry a bounded
   amount of the real blue/green wash into later yellow marks until rinsed.
3. Drop water into a damp area → pigment pushes outward (bloom / backrun).
4. Fast stroke → a little pigment flings past the end.
5. Two separate strokes nearby → they do **not** contaminate each other or the
   brush unless their wet paint is physically touched by the bristles.
6. It reads as **wet paint on paper**, not markers.

## 3. Key realization

The watercolor *look* is driven mostly by **wet-into-wet bleeding**, **edge
darkening on drying**, and **subtractive color** — **not** by dramatic fluid
velocity. Real watercolor barely "flows" unless very wet. The full
Navier–Stokes solve was expensive and bought us none of the look. The missing
ingredient is **visible pigment bleeding through wet regions** plus **enough wet
time** to see it happen.

## 4. Proposed architecture — one surface, one color source

```
Brush physics (KEEP — approved feel)
      │  contact: position, pressure, footprint, velocity
      ▼
Deposit  → lays wet pigment (the picked color) + water into ONE wet surface,
           shaped by the footprint, with brush momentum as initial velocity
      ▼
Wet surface (the medium — the ONLY pigment store):
   • wetness spreads into damp paper and evaporates (multi-second wet window)
   • suspended pigment BLEEDS through wet regions  ← the visible watercolor look
   • pigment settles as it dries, darker at the drying edge
   • re-wetting lifts settled pigment → blooms
   • spectral Kubelka–Munk mixing throughout (KEEP — already correct)
      ▼
Composite → transparent pigment over paper (KEEP); wet reads darker, dry matte
```

**Color has one canvas source of truth.** Mixing happens **on the canvas** where
wet colors overlap. Loading a selected color begins clean; after that, the
brush may absorb bounded paint only through real contact with this same wet
surface and carry it forward until rinsed. Nearby paint never contaminates it.

**Fluid model:** replace the incompressible solver with a simpler, cheaper,
**art-directable wet-map + pigment-diffusion** model that targets the visible
behaviors directly (bleed, bloom, edge-darken, fling). The spec explicitly
allows simpler models; the full solve was overkill.

## 5. What's kept vs. replaced

| Keep (works / approved) | Replace / remove | Unify |
|---|---|---|
| Brush physics & feel | Incompressible fluid solve → wet-map + diffusion | One pigment surface (the wet sim) |
| Paper texture | Proximity brush-pickup color corruption | One color source (picked color; canvas mixes) |
| Spectral KM color + 48 palette | Deposit-scale hacks (`depositRate` gains) → first-class | |
| Transparent-overlay rendering | Old Phase-2 pigment grid as a second store | |

Brush **feel** is untouched — I only change what happens *after* the contact,
at the deposit boundary.

## 6. How I stop tuning blind (non-negotiable)

Build a **render-to-image harness**: paint a scripted test stroke, save PNG
frames at t = 0, 0.5s, 1s, 2s, and actually **look** at them (and share them
with you). Every tuning change gets judged by eye, not by a number. This is the
single biggest process fix.

## 7. Staged rollout — each stage is visible and judgeable

- **Stage A — Predictable, visible color.** One surface, one color source; kill
  the pickup corruption; deposits are clearly visible; canvas mixes where wet
  colors overlap. *You can paint clean, predictable, mixing watercolor.*
- **Stage B — The wet feel.** Wet-into-wet bleeding, multi-second wet time, edge
  darkening, blooms, end-of-stroke fling — all tuned by eye against Stage 2
  acceptance. *It stops feeling like markers.*
- **Stage C — Refinement.** Dirty-brush done right, granulation into paper,
  glazing over dry layers, performance (active-region tiling).

## 8. Historical decisions — now resolved

1. The one shared watercolor surface is binding. Proximity pickup stays
   removed; real bristle-contact pickup is now implemented against that surface.
2. The wet-map/diffusion replacement was rejected by artist review. The Fluid
   model in the binding watercolor spec is active; diffusion is secondary only.
3. The staged record remains useful history, but the current implementation
   follows `ROADMAP.md`, `ARCHITECTURE.md`, and the binding specs.
