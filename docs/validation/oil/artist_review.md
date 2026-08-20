# Oil artist review

## OIL-001 — first look at oil v0.1

- **Recorded:** 2026-08-20, `docs/validation/sessions/2026-08-20t02-56-06-oil.json`
- **Profile / paper:** `material.oil.diagnostic.v0.1` on Cold Press
- **Settings:** Draw, load `0.21`, pressure `0.55` (slider — no stylus), speed `0.80`
- **Measurements:** deposited `1681.43`, tallest point `2.248`, marked area `25.47%`,
  relocated `21348.22`, surface water `0`, suspended pigment `0`,
  conservation error `5.15e-7%`
- **Rating:** Recognizable
- **Decision:** Recalibrate

**Artist's words:**

> The brush shoves paint around and whether low pigment load or high pigment
> load, it shoves paint off of the surface and leaves a clean streak behind.
> Not typical oil behavior.

This is the correct verdict and it identified a real defect, not a tuning
preference. The saved mark shows thin ropey ridges with bare paper between
them and a fan of clean streaks — the brush was scraping the sheet.

### Cause

Two faults, both in the displacement path:

1. **The push was applied per contact sample, not per distance travelled.**
   Measured on a single pass: each cell received 8–10 pushes, each removing
   14.8% of its material, so **only ~20% of the film survived one stroke**. The
   sample count follows from an internal step size, so the same gesture drawn
   with denser sampling scraped harder. That breaks the rate-independence the
   brush specification requires.

2. **Nothing stopped the brush reaching bare paper.** Real paint adheres to the
   substrate: a bristle rides over a thinned film rather than lifting the last
   of it. The model had no such limit.

### Fix

`DEPO-003 detachment_threshold` — a property oil already declared and which
nothing consumed — now sets a **retained film**: material below that thickness
adheres to the sheet and cannot be pushed. Displacement is also scaled by the
share of a footprint crossing each contact represents, so total displacement
over a given travel no longer depends on sampling density.

Measured after the fix, same gesture and settings:

| Passes | Deposited | Relocated | Bare cells on the stroke centre-line | Film thickness |
| --- | --- | --- | --- | --- |
| 1 | 69.4 | 0.1 | **0 of 95** | 0.160 |
| 2 | 131.0 | 4.3 | **0 of 95** | 0.296 |
| 3 | 186.9 | 15.7 | **0 of 95** | 0.417 |
| 6 | 332.5 | 91.0 | **0 of 95** | 0.718 |

The streak is closed and layers now build instead of being scraped away.

### Still open after this fix

- **The artist has not re-reviewed.** The numbers say the streak is gone; only
  a look can say whether it now reads as oil.
- **Residual rate dependence remains**, and it predates this work: the deposit
  loop includes both endpoints, so one long segment and twenty-four short ones
  covering the same line deposit `69.4` versus `83.5` — about 20% more paint
  for the same gesture. This affects watercolor and charcoal too, and changing
  it would move already-approved charcoal results, so it needs its own work
  rather than a quiet fix here.
- Pressure was a flat `0.55` throughout; the threshold between light and heavy
  cannot be felt without a stylus or deliberate slider changes between strokes.

## Known stand-ins to stay sceptical of

- Yield stress `0.34`, viscosity `0.82`, packing `0.78`, particle density
  `0.62`, detachment threshold `0.28` — all normalized guesses, none measured.
- Relief shading is a height-gradient shade in one fixed light direction. It is
  a diagnostic, not a lighting model.
- One flat earth tone; there is no spectral colour in the bench, so glazing and
  mixing cannot be judged at all.
- Brush size still responds to the brush-water control, which means nothing for
  oil. Harmless but wrong; it should be relabelled when the applicator work
  lands.
