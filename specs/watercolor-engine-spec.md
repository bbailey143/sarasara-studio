# Watercolor Simulation — Implementation Spec

> **Binding fluid model restored (2026-07-12).** The temporary wet-map +
> pigment-diffusion implementation did not provide convincing moving water and
> read as wet markers. This specification is again authoritative for the Fluid
> solve, velocity-carried pigment, water/paper exchange, precision, pass order,
> and validation. The diffusion build may remain only as an explicitly named
> fallback during migration; it must not replace or run on top of the Fluid
> passes. See [`WATERCOLOR-FLUID-RECOVERY.md`](../WATERCOLOR-FLUID-RECOVERY.md).

**For:** the Fluid / Pigment / Texture engine implementation sprint (Flutter · iPad · Metal)
**Status:** implementation contract; the Phase-4 CPU reference is in active correction. The newest wet-union changes have authored checks but do not yet have a confirmed completed test run; artist and GPU validation remain pending.
**Reference model:** Curtis, Anderson, Seims, Fleischer & Salesin, *Computer-Generated Watercolor* (SIGGRAPH 1997), adapted to an incompressible stable-fluids solver for GPU friendliness.

---

## 1. Purpose & scope

This describes a real-time, physically-motivated watercolor medium that reproduces the four behaviors that read as "real watercolor": **flow** (wet-into-wet spreading), **edge darkening** (pigment pooling at wet boundaries), **blooms / backruns** (water re-mobilizing settled pigment), and **subtractive mixing** (true pigment color, not RGB blend).

It maps onto the existing five-engine architecture as:

| Engine | Owns |
|---|---|
| **Brush** | Stamp geometry, pressure → the splat pass (§5, Phase A) |
| **Fluid** | Velocity, pressure, incompressible solve (Phase B) |
| **Pigment** | Suspended/deposited transport, deposit-lift, Kubelka-Munk (Phases D, F) |
| **Texture** | Selected-paper height/capacity field, capillary and granulation coupling (feeds E1/E3) |
| **Canvas State** | The persistent field textures + composited color; undo/checkpoint, tiling (§3, §7) |

The scope is the *medium simulation*, not brush-tip modeling or UI. The medium outputs one low-resolution **transparent wash** texture. Canvas State owns that texture and draws it over the separately owned, high-resolution paper rendering; the watercolor composite must not bake an opaque paper background into the wash.

---

## 2. Architecture overview

The simulation has a fixed order. The current Phase-4 CPU reference is authoritative for behavioral ordering while the GPU port is pending. The GPU version may combine or split kernels, but it must preserve the same read-before-write boundaries, conservation rules, and observable order. GPU fields that are read and written in one logical step use a **ping-pong** pair.

```text
per physical brush contact, before field mutation:
  A. RECEIPT/BATCH  accept one exact receipt → resolve every sibling cluster
                    → normalize totals over clipped footprints → one shared
                    pre-contact lift/catch → mutate once → local wet exchange

per current fixed CPU step, in this exact order:
  B. FLUID           velocity self-advection → height force → viscosity
                     → divergence → pressure → projection + tilt
  C. BULK TRANSPORT  conservative donor transport of suspended pigment
                     → conservative donor transport of surface water
  D. WET UNION       symmetric conservative microscopic exchange (N passes)
  E. WATER/PAPER     valley-coupled capillary spread → capacity-limited soak
                     → evaporation → recompute M
  F. EDGE ACCUMULATE conservative wetter-donor → drying-rim pigment transfer
  G. SETTLE/LIFT     granulation settling → active lift → dry-clock finalization

on a requested visible update:
  H. COMPOSITE       spectral KM → transparent wash texture → canvas over paper
```

This order is binding: edge accumulation reads the newly recomputed `M` from E, then settle/lift reads the edge-adjusted suspended fields. The historical diffusion fallback has a different internal transport path and is not the Phase-4 behavior contract. Pressure and viscosity are the iterated Fluid passes; D may also use a small authored iteration count for microscopic wet mingling.

---

## 3. Data model (textures)

All sim textures are at **sim resolution** `S×S` (see §7 for how that relates to the visible canvas). Use the smallest format that holds the range without banding.

| Texture | Channels | Format | Ping-pong | Contents |
|---|---|---|---|---|
| `Velocity` | RG | RG16F | yes | `u, v` in cells/step |
| `Pressure` | R | R16F | yes | pressure scratch (zeroed each frame) |
| `Divergence` | R | R16F | no | scratch |
| `Water` | RG | RG16F | yes | `h` (surface-water height/volume), `M` (shared mobility, soft 0..1) |
| `Saturation` | R | R16F | yes | `s` paper capillary saturation |
| `Ksus0,Ksus1` | RGBA×2 | **RGBA32F** | yes | suspended (mobile) **absorption** spectrum, 8 bands |
| `Ssus0,Ssus1` | RGBA×2 | **RGBA32F** | yes | suspended **scattering** spectrum, 8 bands |
| `Kdep0,Kdep1` | RGBA×2 | **RGBA32F** | yes | deposited (fixed) absorption spectrum, 8 bands |
| `Sdep0,Sdep1` | RGBA×2 | **RGBA32F** | yes | deposited scattering spectrum, 8 bands |
| `PropsSus` | RGBA | **RGBA32F** | yes | `(load_sus, granWt_sus, stainWt_sus, —)` |
| `PropsDep` | RGBA | **RGBA32F** | yes | `(load_dep, granWt_dep, stainWt_dep, dryClock)` |
| `Kdry0,Kdry1` | RGBA×2 | **RGBA32F** | no | protected dry-substrate absorption spectrum; subset of `Kdep*` |
| `Sdry0,Sdry1` | RGBA×2 | **RGBA32F** | no | protected dry-substrate scattering spectrum; subset of `Sdep*` |
| `PropsDry` | RGBA | **RGBA32F** | no | protected `(load_dry, granWt_dry, stainWt_dry, 0)`; subset of `PropsDep` |
| `Palette` | RGBA | RGBA32F (static) | no | 48-pigment LUT: per row, 8-band K, 8-band S, `γ`, `σ` |
| `Paper` | RGB | RGBA8 (static) | no | selected paper: R=height `τ`, G=absorbency/capacity `κ`, B=fiber/2nd octave |
| `Color` | RGBA | RGBA8 | no | transparent low-resolution wash output (Canvas State owns) |

**This is the spectral pigment model — it decouples storage from palette size.** The paper does not store *which* of the 48 pigments are present; it stores the optical result — the mixture's absorption `K` and scattering `S` as 8-band spectra. Laying down pigment *p* at concentration *c* just adds `c·K_p` and `c·S_p` into the running spectrum (§5, A1). The palette can be 48 or 480 pigments and per-pixel storage never changes: **15 float textures, fixed**, including the protected dry-substrate subset.

`PropsSus`/`PropsDep` carry what the spectra alone cannot: the mixture-average granulation and staining that drive deposit/lift. They are stored as *extensive weighted sums* (`granWt = Σ cₚγₚ`, `stainWt = Σ cₚσₚ`) beside total load, so load, granulation identity, and staining identity transport together. Recover an average only as `granWt/load` or `stainWt/load` when a behavior needs it. `PropsDep.a` is the cell's dry hold clock; it is state, not a pigment property. `PropsDry` protects the same three extensive pigment quantities after finalization and stores `0` in its clock channel.

**Deposited spectra do not advect** — deposited paint is fixed to the paper. Only the four suspended spectral textures + `PropsSus` move in the advect pass (5 targets). That keeps the advect pass within the 8-target MRT limit. `Kdry/Sdry/PropsDry` are persistent subsets of deposited state: ordinary lift may act only on `Dep - Dry`; the protected dry substrate remains fixed until an explicit future re-wetting/scrubbing rule releases it.

**Single-constant fallback:** if memory is tight, drop `Ssus*`/`Sdep*` (4 textures) and store only the K/S *ratio* spectrum per layer (~5 spectral textures total). You lose per-band scattering — i.e. some granulation-opacity fidelity — but keep correct spectral color. Recommended only if profiling demands it.

**Precision note that matters:** the deposited spectra (`Kdep*`, `Sdep*`) accumulate over hundreds of frames — use **float32**, not half-float, or thin glazes quantize and stair-step. `Velocity` and `Pressure` are fine at half-float.

**Memory:** at 512² sim resolution the 15 spectral/property RGBA32F textures total ≈ 60 MB (`512·512·16 B · 15`). Keep them and the transparent `Color` wash at sim resolution; Canvas State upscales the wash over its separately rendered paper (§7). This remains independent of whether the palette contains 48 or 480 pigments.

**Palette identity, deliberately not stored:** because the paper holds mixtures rather than pigment labels, there is no "erase only the ultramarine." That mirrors real paint — once mixed on the sheet it has no memory of the tubes. The two `Props` averages recover the behavioral differences that actually matter (staining vs granulating) without per-pigment storage.

---

## 4. Conventions

- **Grid space.** One texel = one cell. Current transport coefficients are calibrated per numerical cell-step, while `stepSeconds = 1/30 s` advances the real-time dry clock. A real elapsed-time accumulator remains required before shipping.
- **Neighbors.** `L,R,D,U` = `(i-1,j),(i+1,j),(i,j-1),(i,j+1)`. Sample with a `texel = 1/S` offset.
- **Boundaries.** Domain walls: zero normal velocity. Wet boundary: velocity and pigment transport exist only where `M > 0` — this is what keeps paint inside the wash instead of flooding the sheet.
- **Velocity self-advection sample.** The Fluid velocity scratch may use bilinear semi-Lagrangian back-tracing clamped to `[0.5, S-1.5]`. Suspended pigment and surface water in the binding Phase-4 path do **not** use semi-Lagrangian gathering; they use conservative donor transport (C/D1).

---

## 5. Contact and fixed-step pipeline

Each operation below names its inputs, outputs, and binding math. Pseudocode is GLSL-style where useful, but the current CPU reference's conservative scatter operations may require a reduction or equivalent flux formulation when ported to Metal. `X` is the current texel coordinate; `s(T)` means sample texture `T` at `X`.

### Phase A — Splat (Brush engine handoff)

**A1. Receipt-authoritative contact batch (binding).** One physical contact is
one transaction, even when its footprint contains many bristle clusters. Its
accepted `TransferReceipt` contains **extensive totals**, not per-cell density:

```text
carrierOut, pigmentOut,
KOut[8], SOut[8], granulationOut, stainingOut,
carrierIn, pigmentIn,
KIn[8], SIn[8], granulationIn, stainingIn
```

`KOut`, `SOut`, `granulationOut`, and `stainingOut` are the exact spectral and
property totals belonging to `pigmentOut`. They are the live source of color
and pigment identity; a parallel palette/color argument may exist only for
explicit synthetic tests and must never recolor a real receipt.

**A1a. Contact-only pickup (binding).** `carrierIn` in the adapter payload is
the brush reservoir's maximum available room, not a promise that paint exists.
Before adding the outgoing material, watercolor samples only the real bristle
footprint against the shared pre-contact field. A resting wet brush has bounded
capillary pickup; tangential drag increases coupling continuously. Pickup may
remove surface `h`, suspended pigment, and a smaller staining-resistant share
of active deposited `Dep-Dry`. It must never remove protected `Dry`, and no
nearby/proximity pigment store may substitute for the watercolor field.

The CPU reference uses a normalized local pickup kernel. Per contacted cell,
surface-water removal is capped at 38 percent of local `h` per contact;
suspended pigment removal is capped at 48 percent and is proportional to the
captured local water share and `M`; active deposited removal is capped at 16
percent, also multiplied by `M` and `(1-.75·stainAvg)`. Every removed `K/S`,
`load`, `granWt`, and `stainWt` quantity uses the same layer fraction. The final
receipt reports the exact removed totals using the inverse A1 unit conversions:

```text
carrierIn = removedWaterSim / C_carrier
pigmentIn = removedLoadSim  / C_pigment
KIn[b]    = removedKSim[b]  / C_pigment
SIn[b]    = removedSSim[b]  / C_pigment
```

Only this completed bidirectional receipt updates the brush reservoir. Picked
spectra therefore colour later contacts until rinse or an explicit clean load.
Checkpoint replay deposits each contact's stored reservoir spectrum with
pickup disabled, so rebuilding cannot remove field material a second time.

The CPU reference currently uses fixed unit conversions
`C_pigment = 1200` and `C_carrier = 875`:

```text
loadSim      = C_pigment · pigmentOut
KSim[b]      = C_pigment · KOut[b]
SSim[b]      = C_pigment · SOut[b]
granWtSim    = C_pigment · granulationOut
stainWtSim   = C_pigment · stainingOut
waterSim     = C_carrier · carrierOut
```

These are interim simulation-unit conversions, not artistic controls. They are
constant for a given reference grid and may not depend on UI strength,
pressure, footprint radius, clipped area, event count, callback rate, or dwell
stamp count. Pressure and elapsed contact time have already affected what the
adapter accepted into the receipt; applying them to material again is forbidden.

For sibling cluster `i`, use `shareᵢ = coverageᵢ·pressureᵢ / Σⱼ
(coverageⱼ·pressureⱼ)`. Preserve the cluster's own physical radius. Evaluate its
discrete kernel only over in-bounds cells, then normalize those surviving
weights so `Σₓ wᵢ(x)=1`, including at canvas edges. Pigment uses its normalized
contact kernel for load, `K/S`, `granWt`, and `stainWt`; carrier may use its own
slightly wider, separately normalized water kernel. Consequently, changing
radius or clipping either footprint changes spatial shape, not how much of its
accepted total appears.

Accumulate all sibling clusters into temporary contact buffers first. Only then
mutate `h`, `Ksus/Ssus/PropsSus`, and `Velocity` in one second pass that reads a
single pre-contact wash state. A sibling may not lift, dry, or recolor another
sibling from the same physical contact. Mechanical impulse remains a separate,
bounded geometry/velocity contribution and may still push an existing wash
when the material receipt is zero.
Wet-into-wet vs wet-on-dry is emergent from the shared pre-contact mobility `M`
defined in A3/E1; it is never stored per stroke. Splat samples `h` and `s`
directly with that same function, so newly added carrier cannot misreport the
substrate as previously wet. E1 remains the sole writer of the persistent `M`
texture.

**A2. Pressure-dependent composition (binding).** Brush pressure does not scale
water and pigment as one inseparable quantity. The watercolor adapter resolves
the brush's contact/reservoir opportunity into separate accepted carrier and
pigment amounts:

```text
pigmentResponse(P) ∝ P^γp      γp < 1   (starter: 0.65)
carrierResponse(P) ∝ P^γw      γw > 1   (starter: 2.0)
pushResponse(P)    ∝ P^γu      γu > 1   (starter: 1.4)
```

For one multi-cluster brush sample, the Brush engine distributes the normalized
stylus force as sibling `forceShareᵢ` values whose sum is `P`. Watercolor
reconstructs `P = clamp(Σ forceShareᵢ, 0, 1)` exactly once. Duplicating the
whole stylus pressure on every sibling invents force; averaging valid shares
loses force. Bristle count must do neither.

Therefore a light touch is pigment-rich, water-poor, gently coupled to fluid,
and more strongly records bristle/paper texture. Firm pressure expresses much
more carrier water and couples more bristle motion into the wash, producing
softer transport and faster mixing. All three responses remain bounded by the
brush transfer opportunity and the exact accepted receipt. A medium adapter
owns these watercolor meanings; the Brush engine remains medium-agnostic.

The accepted receipt is the sole live material authority: zero accepted
pigment/carrier deposits zero pigment/carrier, while a material-empty contact
may still impose bounded brush velocity on an existing wash. The batching,
radius preservation, normalization, and fixed-conversion rules in A1 are
mandatory parts of that conservation contract.

**A3. Wet union versus dry glaze (binding).** Derive one pre-contact mobility
value per cell. Surface water may be fully mobile; paper-held moisture provides
a slower, partial damp-working interval:

```text
surface = smoothstep(0.35·wetThr, 1.50·wetThr, h)
paper   = smoothstep(0.20·wetThr, 1.10·wetThr, s)
M       = 1 - (1 - surface)·(1 - dampMobility·paper)
dampMobility starter = 0.60
```

`M` is the one shared mobility answer used by contact union, microscopic
exchange, lift, drying-edge decisions, and the wet-area diagnostic. The current
reference uses `M` directly; there is no second per-stroke wetness value or
hidden `join` mask. Splat evaluates this equation from **pre-contact** `h,s`.
That `Mpre` remains authoritative for protected dry substrate. Accepted carrier
may raise a separate contact-time mobility only for active `Dep-Dry` pigment;
it can re-wet a damp wash but can never make protected `Dry` pigment pretend it
was still active. E1 writes persistent `Water.M` after water/paper evolution.

- At `M≈1`, re-suspend a substantial bounded share of the *active,
  unprotected* deposit, reduce incoming mechanical catch toward microscopic
  grain trapping, and place old plus new pigment in the same suspended fields.
  Staining must not immobilize pigment merely because its pigment identity is a
  stainer while the wash is perfectly wet; resistance grows as drying/fixation
  progresses.
- At damp `M`, interpolate both re-suspension and incoming catch continuously.
- At `M≈0` after the dry hold, do not lift protected deposited pigment. Preserve
  it as the optical substrate and apply the incoming wash as an ordered
  transparent spectral glaze.

The CPU reference's contact re-opening is binding because the 2026-07-13
yellow-over-blue capture showed that a lower lift left the earlier blue ridge
intact beneath a green patch. With pre-contact mobility `Mpre`, normalized
contact pressure `P`, accepted incoming carrier per cell `win`, and active
deposit staining average `stainAvg`:

```text
fresh     = smoothstep(0, wetThr, win)
Mcontact  = Mpre + (1-Mpre)·fresh
wetUnion  = smoothstep(.15, .75, Mcontact)
stainKeepColour = 1 - stainAvg·(1-Mcontact)·.85
stainKeepClean  = 1 - stainAvg·(1-Mpre)·.85
colouredLift = clamp(
    Mcontact·(.18 + .12·P)
  + wetUnion·(.72 + .02·P)
  0, .94)
cleanWaterLift = clamp(
    Mpre·(.20 + .22·P) + fresh·(.08 + .08·P),
  0, .46)
impactLift = incoming pigment > 0
    ? colouredLift·stainKeepColour
    : cleanWaterLift·stainKeepClean
```

At full wetness, or when accepted coloured carrier fully re-wets a still-active
damp cell, a coloured crossing re-opens at least 90% and at most 94% of the
active unprotected deposit. Incoming-pigment catch uses `Mcontact`, so a firm,
water-rich contact stays mobile while a light, water-poor contact records more
paper grain. The small remainder and microscopic wet catch retain paper-grain
evidence without preserving the old stroke boundary.
Clean water remains capped at 46% so a bloom opens the center without reviving
the hollow/Cheerio failure. Neither rule removes pigment from the cell: it
transfers active deposited state to suspended state before conservative local
exchange or Fluid transport.

Contact union and microscopic dispersion use symmetric, conservative face
exchange through connected mobile cells:

```text
coupling_ij = sqrt(Mi·Mj)
flux = q·coupling_ij·(Pi - Pj)·dt
Pi -= flux
Pj += flux
```

Apply the identical paired fraction to every suspended `K`, `S`, load,
granulation-weight, and staining-weight channel. A one-sided variable-wetness
Laplacian is forbidden because it creates or destroys pigment at damp/wet
joins. This exchange removes a contact seam and handles microscopic mingling;
Fluid alone still owns bulk movement.

For immediate contact-local union, the current CPU reference uses
`q=clamp(.08 + .14·Mcontact, 0, .22)` for two damp, three workable, or five
fully wet paired-exchange passes. Run these passes only inside the bounded
coloured-overlap region (plus a three-cell connected margin), once for all
sibling clusters. First marks and clean-water contacts do not pay this work.
The ordinary per-frame `bleed` pass remains separate and secondary.

Overlapping wet strokes form one connected wash; drawing a second independent
stroke image on top, or keeping per-stroke wet buffers, is forbidden.

True dry glazing requires a preserved dry substrate plus an active glaze layer,
or a mathematically equivalent finite-thickness KM layer-over-substrate
calculation. Collapsing all dry layers into one unordered deposited mixture is
not sufficient for Phase 4 completion.

### Phase B — Fluid solve (Fluid engine)

Incompressible stable-fluids with a shallow-water height force. This is the recommended v1: robust, standard, and matches the prototype. (True shallow water is a fidelity upgrade — see §12.)

**B1. Advect velocity** (self-advection)
- **In:** `Velocity` → **Out:** `Velocity'`
```glsl
vec2 vel = s(Velocity);
vec2 back = X - dt * vel * texel;
vec2 velNew = bilinear(Velocity, back);
```

**B2. Apply forces** (water plus paper-saturation height gradient)
- **In:** `Velocity`, `Water`, `Saturation` → **Out:** `Velocity'`
```glsl
vec2 gradHS = 0.5 * vec2((hR+sR) - (hL+sL), (hU+sU) - (hD+sD));
vel -= heightForce * gradHS;   // current cell-step calibration
```

**B3. Viscosity diffuse** — Jacobi, `viscIters` iterations (2–4 is plenty), ping-pong
- **In:** `Velocity` → **Out:** `Velocity'`
```glsl
// implicit-style Jacobi; stable for any nu
vel = (velC + nu*(velL+velR+velD+velU)) / (1.0 + 4.0*nu);
```

**B4. Divergence**
- **In:** `Velocity` → **Out:** `Divergence`
```glsl
div = 0.5 * ((uR - uL) + (vU - vD));
```

**B5. Pressure solve** — Jacobi, `pressureIters` iterations (**20–40**), ping-pong. Zero `Pressure` before the loop.
- **In:** `Pressure`, `Divergence` → **Out:** `Pressure'`
```glsl
p = (pL + pR + pD + pU - div) * 0.25;
```

**B6. Partial projection, free-surface residual, tilt, and boundaries.** The
current CPU reference removes most divergence (`projectionStrength = 0.68`),
then restores a bounded fraction of the legitimate free-surface height flow.
Canvas tilt is deliberately added **after** projection so a constant downhill
force is not projected away.

- **In:** `Velocity`, `Pressure`, `Water`, `Saturation`, tilt controls → **Out:** `Velocity'`
```glsl
vec2 projected = vel - 0.68 * 0.5 * vec2(pR-pL, pU-pD);
vec2 gradHS = 0.5 * vec2((hR+sR)-(hL+sL), (hU+sU)-(hD+sD));

float theta = tiltDirectionTurns * 2.0 * PI;   // 0=right, .25=down
vec2 gravity = 0.24 * tiltAmount * vec2(cos(theta), sin(theta));
vel = clamp(projected - 0.28*heightForce*gradHS + gravity,
            vec2(-3.0), vec2(3.0)) * 0.985;

if (atWall || h+s <= 0.35*wetThr) vel = vec2(0.0);
```

This tilt equation is the current 30 Hz CPU interim, not the final
elapsed-time-invariant force integration. It must be rescaled with real
substep duration when the accumulator lands, and equal wall time at different
callback rates must produce near-equal downhill displacement.

### Phase C / D — Conservative bulk transport and wet union

**D1. Conservative donor transport (binding).** Suspended pigment is scattered
from each donor cell into at most one x-neighbor, one y-neighbor, and itself.
It is **not** semi-Lagrangian back-traced: gather advection can silently change
pigment totals at wet/dry boundaries. A gentle nearest-dry-boundary bias is
added to pigment velocity before the donor fractions are calculated.

```text
vPig = Velocity - normalize(∇boundaryDistance) · (0.025·edge)
fx = clamp(abs(vPig.x)·0.42, 0, 0.42)
fy = clamp(abs(vPig.y)·0.42, 0, 0.42)
if fx+fy > 0.78: scale both so fx+fy = 0.78
reject a destination outside the connected wet region

Qout[self] += Qdonor · (1-fx-fy)
Qout[xDst] += Qdonor · fx
Qout[yDst] += Qdonor · fy
```

Apply the exact same donor fractions to all suspended `K`, `S`, `load`,
`granWt`, and `stainWt` channels. Initialize outputs to zero and add every donor
contribution before swapping buffers; deposited fields never move. This is a
strict extensive-quantity conservation rule, not merely a visual preference.
The GPU port must implement an equivalent conservative scatter/reduction.

Surface `h` then uses the same donor pattern with raw `Velocity` (no pigment
edge bias), the same `0.42` per-axis cap, and the same `0.78` total cap. Thus
bulk surface water is conservative before capillary spread and evaporation.

**D2. Microscopic wet union.** After bulk donor transport, connected mobile
faces exchange suspended pigment symmetrically using A3's
`sqrt(Mi·Mj)` coupling. The current Fluid path uses
`rate = min(0.24, 0.55·bleed)` for `bleedIters` passes (default 2). Every face
subtracts from one cell exactly what it adds to the other for all spectral and
property channels. This softens contact seams; it does not replace Fluid as the
source of bulk motion.

### Phase E — Selected paper, edge accumulation, settle/lift, and dry lock

**E1. Valley-coupled capillary spread and capacity-limited soak.** Both `τ`
(height) and `κ` (capacity) come from the artist's currently selected paper,
sampled on the simulation grid. For each right/down face, spread surface water
as an equal-and-opposite pair:

```text
valleyA = 1 - τA
valleyB = 1 - τB
connection = clamp(valleyA·valleyB, 0, 1)^2
conductance = 0.12 + 0.88·connection
moved = (hA-hB) · wetSpread · 0.20 · conductance
hA -= moved
hB += moved
```

The nonzero `0.12` floor allows ordinary paper to communicate; connected
valleys carry much more water and create irregular grain-following fronts.
After spread, each cell absorbs only what its paper has room to hold:

```text
room   = max(0, κ-s)
absorb = min(h·soak, room)
h = max(0, h - absorb - dry)
tail = (h<=ε and s<=.20·wetThr) ? 3 : 1
s = max(0, s + absorb - dry·paperDryFactor·tail)
M = 1 - (1-smoothstep(.35·wetThr,1.50·wetThr,h))
      ·(1-.60·smoothstep(.20·wetThr,1.10·wetThr,s))
```

This is the current CPU reference: paper saturation is local held water, while
surface water performs the conservative neighbor spread. A future two-layer
capillary model may add saturation transport, but it may not bypass selected
paper capacity or valley coupling. The `tail` multiplier begins only after
paper mobility is already zero; it ends invisible residual work without
shortening the artist's damp mixing window.

**E2. Drying-edge accumulation.** This pass runs *after* E1 recomputes `M` and
*before* settling. For a drying-rim target with `0.04 < M < 0.92`, choose its
adjacent neighbor with the greatest `M`. If `ΔM > 0.02`, transfer
`frac = clamp(edge·0.035·ΔM, 0, 0.08)` from that wetter donor to the target.
Subtract and add the identical amount for all suspended `K`, `S`, `load`,
`granWt`, and `stainWt` channels. This is conservative edge concentration, not
a color-darkening filter and not permission to clear the wash center.

**E3. Granulation settle, active lift, and dry finalization.** Compute scalar
fractions once and apply each fraction coherently to every `K/S` band plus
`load`, `granWt`, and `stainWt`. Use only pre-update values on the right-hand
side. Protected `Dry` quantities are excluded from ordinary lift.

```text
valley   = 1-τ
granAvg  = PropsSus.granWt / max(PropsSus.load, 1e-4)
granBias = clamp(1 + granAvg·(valley-.5), .65, 1.35)
settleFrac = settle·(1-M)·granBias·(1 + edge·length(∇M))

activeLoad  = max(0, PropsDep.load    - PropsDry.load)
activeGran  = max(0, PropsDep.granWt  - PropsDry.granWt)
activeStain = max(0, PropsDep.stainWt - PropsDry.stainWt)
stainAvg = activeStain / max(activeLoad, 1e-4)
stainKeep = 1 - stainAvg·(1-M)·.85
liftFrac = lift·M·.10·stainKeep
```

The valley term makes high-granulation mixtures settle more readily in the
selected paper's low areas. `granWt` must transfer into deposited state and
back out on lift just like `load` and `stainWt`; consuming or dropping it during
settling destroys pigment identity.

`PropsDep.dryClock` is channel A in the binding
`(load, granWt, stainWt, dryClock)` layout. The CPU reference advances it with
the fixed interim `stepSeconds = 1/30 s`:

```text
if no suspended load and no unprotected deposit: dryClock = 0
else if M <= wetOff (.01): dryClock += 1/30 s
else if M >= wetOn  (.03): dryClock = 0
else: dryClock = max(0, dryClock - 1/30 s)

dryLocked = dryClock >= dryHoldSeconds (.15 s)
```

At `dryLocked`, force `settleFrac=1` and `liftFrac=0`, settle every remaining
suspended spectral/property quantity, copy complete deposited `K/S/load/
granWt/stainWt` into `Dry`, write `PropsDry.dryClock=0`, and zero local velocity.
Finalization happens at the actual dry transition, never lazily on a later
brush contact. Direct or neighboring capillary water may then mobilize only a
future active layer, not the protected dry substrate.

The live ticker may stop only when **raw state**, not merely `M`, satisfies:

```text
Σh <= 1e-6
Σs <= 1e-6
ΣPropsSus.load <= 1e-6
Σmax(PropsDep.load-PropsDry.load, 0) <= 1e-6
```

This is the binding `isDry` meaning: no surface water, no paper saturation, no
suspended pigment, and no unprotected deposit awaiting finalization. The fixed
30 Hz stepping is explicitly interim; shipping Phase 4 still requires a real
elapsed-time accumulator and near-equal results under 30 Hz, 60 Hz, and
jittered callbacks.

### Phase F — Composite (Pigment engine → Canvas State)

**F1. Spectral Kubelka-Munk → transparent wash RGBA.** Reconstruct the mixture spectra (deposited + suspended, so wet paint shows), compute per-band reflectance, then collapse 8 bands to RGB with precomputed color-matching weights. See §6.
- **In:** deposited set, suspended set, `PropsSus`, `PropsDep`, `Water.M` → **Out:** transparent `Color` wash
```glsl
vec3 XYZ = vec3(0.0);
for (int b = 0; b < 8; b++) {
    float K = Kdep[b] + Ksus[b];
    float dry = 1.0 - clamp(M, 0.0, 1.0);
    float S = (Sdep[b] + Ssus[b]) * (1.0 + 0.26*dry) + 1e-4;
    float ks   = K / S;
    float Rinf = 1.0 + ks - sqrt(ks*ks + 2.0*ks);   // KM reflectance, band b
    XYZ += Rinf * cieXYZ[b];                          // precomputed D65·CMF weight
}
vec3 rgb = max(XYZ2SRGB * XYZ, 0.0);                  // linear pigment reflectance
float thick   = PropsDep.load + PropsSus.load;
float wet = clamp(M, 0.0, 1.0);
float alpha = (1.0 - exp(-thick * 3.2)) * (.86 + .14*wet);
rgb *= 1.0 - 0.10*wet;                               // wet reads deeper
Color = vec4(linearToSRGB(rgb), alpha);               // transparent where no pigment
```
This is continuous visible dryback, not a last-frame style swap. Increased
particle scattering as water leaves lightens the pigment, while the modest
alpha reduction reveals more separately rendered paper and reads matte. It may
not change pigment mass, expand/contract the footprint, or bake paper texture
into `Color`. The ticker must continue compositing while raw-state `isDry` is
false so the artist sees the transition animate.
`cieXYZ[b]` and `XYZ2SRGB` are constants computed once on the CPU (§6). The band loop unrolls to 8 iterations — cheap. F1 must not mix in paper color or paper grain. Canvas State first renders the selected paper at its own resolution, then upscales and alpha-composites this low-resolution wash over it. The current safe CPU reference uses a `224×224` wash; the paper renderer remains separately owned and higher resolution.

The CPU `compositeToRgba` buffer is straight alpha so its pigment RGB remains
readable in behavior tests. Flutter's raw `PixelFormat.rgba8888` boundary is
premultiplied: immediately before decoding a disposable image buffer, replace
each stored channel with `round(channel·alpha/255)`. Passing the straight bytes
directly is forbidden because a thin, low-alpha wash would contribute near-full
RGB light and visually imitate additive/pale mixing. The wet diagnostic and oil
image use the same shared handoff. A future shader path must declare and obey
its render-target blend convention rather than applying this conversion twice.

---

## 6. Spectral Kubelka-Munk color model

Subtractive mixing is the one place naive alpha blending is visibly wrong (blue + yellow must give green, not a muddy average). We use **two-constant KM over 8 spectral bands** rather than per-RGB-channel. Spectral is what makes mixes reliably correct instead of "mostly" correct, and — crucially — it's what makes the 48-pigment palette free: the canvas stores the *mixture spectrum*, never the pigment list (§3).

**Why spectral is required here, not just nicer.** Paint advects and mixes every frame. Spectral `K`/`S` blend *linearly*, so they interpolate cleanly when a stroke smears across pixels holding different mixtures. A per-pigment slot list can't be bilinearly interpolated across such pixels. For a flowing medium, spectral is the representation that stays physically coherent under transport.

**Bands.** 8 bands spanning 380–730 nm (~44 nm each), centers ≈ 400, 444, 488, 532, 576, 620, 664, 708 nm. 8 is the sweet spot; 6 is a viable trim, 16 the fidelity ceiling (rarely worth it).

**Mixing.** For a mixture, `K[b] = Σ cₚ Kₚ[b]`, `S[b] = Σ cₚ Sₚ[b]` — which is exactly the running sum the canvas already stores. Per-band reflectance `R∞[b] = 1 + K/S − √((K/S)² + 2K/S)`.

**Spectrum → RGB** (the collapse in F1). Precompute on CPU, once:
- For each band `b`, `cieXYZ[b] = D65(λ_b) · [x̄,ȳ,z̄](λ_b) · Δλ`, then normalize so a unit reflector (`R∞[b]=1 ∀b`) maps to the white point.
- `XYZ2SRGB` = the standard 3×3 XYZ→linear-sRGB matrix; apply sRGB gamma after.

Then `XYZ = Σ_b R∞[b]·cieXYZ[b]`, `rgb = XYZ2SRGB · XYZ`. Both are just constants in the shader.

**The 48-pigment palette (`Palette` LUT).** Each pigment is one row: 8-band `K`, 8-band `S`, plus scalars `γ` (granulation) and `σ` (staining). Store as a static RGBA32F texture — 48 rows × 5 texels (4 texels = 16 spectral values, 1 texel = `γ,σ`). Live painting uses the palette when pigment enters the brush reservoir; the adapter then returns the accepted extensive `KOut/SOut/granulationOut/stainingOut` totals. A1 consumes those receipt totals and does not look up or substitute a palette row. Direct palette lookup in A1 is reserved for an explicitly synthetic scene.

**Authoring a pigment.** Measure (or eyeball from a swatch) the pigment's masstone reflectance across the 8 bands → gives `K/S` per band. Fit `S` magnitude from how a thin glaze reads over white (transparent stainers: low `S`; opaque/granulating: high `S`). Set `γ` high for granulators, `σ` high for stainers. For a starter 48, seed from a standard watercolor set (e.g. a Winsor/Daniel Smith reference) — their masstone/undertone data is published and converts directly.

**Finite-thickness layer order (binding for Phase 4).** F1's current unordered
`R∞` mixture converted to transparent wash alpha is an interim preview only. Exact KM
layer-over-substrate reflectance must use active-layer thickness (`load`) and
the preserved ordered dry substrate. `yellow → dry → blue` and
`blue → dry → yellow` must be allowed to produce different results; collapsing
them into one unordered `K/S` sum is not sufficient.

---

## 7. Resolution & tiling strategy (iPad)

The sim does **not** need to run at canvas resolution. Perception of flow is low-frequency. The selected paper still supplies simulation-scale height/capacity, while its visible tooth and color are rendered separately at higher resolution beneath the transparent wash.

**Current and required:**
- **CPU activity scheduling now:** the shared 224×224 reference marks 16-cell
  activity tiles and expands each by a one-tile halo. Ordered Fluid, pigment,
  water, edge, and settling passes skip dry tiles between separate wet marks.
  This is scheduling only: every stroke still reads and writes the same sheet
  fields and may mix whenever wet regions meet.
- **CPU reference now:** one `224×224` full-sheet simulation and matching transparent `Color` wash. A `320×320` whole-sheet experiment was removed after wet two-colour contact union froze the app; its roughly doubled area cost is not an acceptable review path. The CPU reference verifies behavior/conservation but is too coarse for final artist approval.
- **Shipping target:** 512×512 for a full-sheet wash; 256×256 may be adequate for smaller work. Keep all 15 spectral/property fields and `Color` at simulation resolution. This bounds spectral memory to ~60 MB regardless of canvas size.
- **Dirty-region tiling (CPU scheduling present; GPU storage/dispatch still required):** the CPU mask activates from raw `h`, `s`, velocity, suspended load, or unprotected deposited load; `M==0` alone is insufficient because finalization may still be pending. The shipping implementation partitions GPU storage/dispatch into tiles (for example 256²) under the same rule. Higher-resolution visual tuning must use this tiled GPU path rather than increasing the full-sheet CPU field again.
- **Halo:** overlap tiles by ~4 cells so advection/pressure don't see hard seams; blend in the halo.
- **CPU activity zero:** numerical `h`/`s` below `1e-6` and velocity below `1e-5` are physically invisible and must retire before activity marking. They must not keep a halo tile scheduled indefinitely. Shipping GPU thresholds must be validated against visible wetness and conservation scenes rather than relying on exact floating-point zero.

**Undo / checkpoint (Canvas State contract):** a dry snapshot includes `Kdep*`, `Sdep*`, `PropsDep` plus `Kdry*`, `Sdry*`, `PropsDry` (10 textures, ~40 MB at 512² before compression). Velocity, water, and suspended paint are transient in the shipping contract: on dry restore, zero them and the sheet is simply "dry." Snapshot at stroke boundaries, not per frame; per-tile dirty tracking tells which tiles changed, so incremental snapshots copy only those. The CPU live history now implements this rule with exact occupied-16×16-tile checkpoints, including transient wet fields and the dry-substrate subset. It must not return to full-sheet per-stroke copies: at 224² those consumed roughly 13 MB each and caused a repeatable freeze after only several strokes.

**Perf target (not yet measured on the current Phase-4 build):** profile a 512² active Metal tile at 60 fps. Pressure Jacobi is expected to dominate; reduce its iteration count only against measured incompressibility and visual tests, not by assumption.

**UI scheduling safety:** the CPU reference must never use a repeating timer that can catch up continuously when one simulation update exceeds its interval. The next update is scheduled only after the current one returns; under load the UI receives at least a 16 ms input/render gap. This guard may slow reference-time animation and therefore does not replace the binding elapsed-time accumulator or the Metal performance target.

---

## 8. Numerical stability & precision

- **Velocity self-advection:** semi-Lagrangian bilinear back-tracing is allowed for `Velocity` only. Suspended pigment and surface water use the conservative donor limits in D1; do not replace them with semi-Lagrangian gathering.
- **Conservative donor bounds:** per-axis moved fraction is at most `0.42`, total moved fraction at most `0.78`; symmetric microscopic face exchange is capped at `0.24`. These bounds keep the explicit extensive-quantity passes non-negative.
- **Pressure:** Jacobi is GPU-parallel but converges slowly; 20–40 iters is the real-time sweet spot. If flow looks "springy" or compressible, add iterations before touching anything else. Multigrid or red-black Gauss-Seidel is the upgrade path (§12).
- **Precision:** the deposited spectra (`Kdep*`, `Sdep*`) and `PropsSus`/`PropsDep` **must** be float32 (accumulation). Velocity/pressure half-float is fine. Watch half-float on `Saturation` if `beta` is small — underflow can stall capillary flow; if so, promote to float32.
- **Clamp everything** non-negative after deposit/lift and after evaporation. A single negative `K` or `S` will poison the KM `sqrt` and throw a NaN across the band loop.
- **Zero pressure** at the start of each frame's B5 loop, or old pressure biases the solve.

---

## 9. Parameter reference

| Symbol | Name | Current CPU / binding value | Notes |
|---|---|---|---|
| `stepSeconds` | fixed CPU substep | `1/30 s` interim | shipping driver must accumulate real elapsed time and bound catch-up work |
| `nu` | viscosity | `0.055` default | inverse of "flow" slider |
| `pressureIters` | pressure Jacobi | `8` interim | shipping GPU profile may require 20–40; validate rather than assume |
| `viscIters` | viscosity Jacobi | `1` interim | shipping GPU target remains 2–4 if profiling supports it |
| `bleed`,`bleedIters` | microscopic union | `0.22`, `2` defaults | Fluid path applies `0.55·bleed`, capped at `.24` |
| `edge` | boundary bias / rim transfer | `2.2` default; UI `0.8–3.4` | affects D1 bias, E2 accumulation, and drying-edge settle |
| `settle` | deposit rate | `0.06` | ↑ = paint settles faster |
| `lift` | active lift rate | `0.035` | protected `Dry` is excluded |
| `γₚ` | granulation | 0.0–0.6 | **palette entry**, per pigment; feeds `granAvg` in E3 |
| `σₚ` | staining | 0.2–0.9 | **palette entry**, per pigment; high = resists active lift in E3 |
| `wetSpread` | valley-coupled capillary rate | `0.22` default | E1 multiplies by `.20·conductance` |
| `dry` | per-step surface evaporation | `0.0025` synthetic default; live UI exponential `0.000002–0.0012` | lower slider half reserves long working time; convert to elapsed-time rate before shipping |
| `paperDryFactor` | paper/surface drying ratio | `0.22` | surface shine may fade while paper remains workable through a normal colour change |
| `wetThr` | mobility scale | `0.045` | shared by the exact A3/E1 `M` equation |
| `dampMobility` | paper-only mobility | `0.60` | real damp-working interval after surface shine |
| `wetOff`,`wetOn` | dry hysteresis | `.01`, `.03` | exact current thresholds; `wetOn > wetOff` |
| `dryHoldSeconds` | lock delay | `.15 s` | prevents threshold flicker before finalization |
| `tiltForce` | downhill acceleration | `.24·tiltAmount` | current 30 Hz interim, applied after projection |
| `C_pigment`,`C_carrier` | receipt unit conversion | `1200`, `875` | fixed; never depend on UI, pressure, footprint, or event count |
| `BANDS` | spectral bands | 8 | 6 = trim, 16 = max fidelity |
| `PALETTE_N` | palette size | 48 | free to raise; per-pixel cost is fixed |

---

## 10. Flutter / iPad implementation path

Flutter has no first-class compute-shader API, so the multi-pass structure is the crux of the port. Three options, in order of increasing effort and payoff:

**Option A — `ui.FragmentShader` ping-pong (fastest to prototype).**
Compile each pass's GLSL via `impellerc` to a `FragmentProgram`; render each pass into a `ui.Image` with a `PictureRecorder`, feed that image as a sampler uniform to the next pass. *Works, but* every pass costs a picture-record + rasterize, and the 20–40-iteration pressure loop makes that overhead the bottleneck. Viable for a proof-of-life at low `pressureIters`; not the shipping path.

**Option B — `flutter_gpu` (the intended path).**
Impeller's low-level API exposes textures, render passes, and custom shaders — exactly this pipeline without the picture overhead. It's the natural home for this sim. Caveat: it's still early/experimental; budget time for API churn. If it's stable enough at sprint time, this is the best effort-to-payoff.

**Option C — native Metal + external texture (the shipping path).**
Implement the whole pipeline as Metal compute/fragment shaders in a native render loop; register the output `MTLTexture` as a Flutter **external texture** and composite it with the `Texture` widget. Flutter owns UI; Metal owns the sim. Most plumbing, best performance and control, and it's how a production iPad paint engine would ship. The kernels in §5 port almost line-for-line to `.metal`.

**Recommendation for the sprint:** validate correctness with **Option A** at 256² / 20 pressure iters (proves the pipeline and the KM math on-device), then build the real engine on **Option C**, keeping **B** on the radar if `flutter_gpu` has matured. Structure the shader source so A and C share the same GLSL/MSL kernels — the pipeline order and I/O contracts in §5 are the stable interface.

---

## 11. Validation tests (definition of done)

Each proves a specific mechanism, not just "looks wet." This is a required
definition of done, **not** a claim that every item has passed. The newest
Phase-4 wet-union checks have been authored but do not yet have a confirmed
completed run; ordered dry glazing, elapsed-time invariance, GPU tiling, and
artist approval remain open.

1. **Edge darkening** — single wet stroke on dry paper dries with a visibly darker rim. (D1 bias + E2 accumulation.)
2. **Bloom / backrun** — flood-wet a region, drop pigment, then drop clean water at the center after 1–2 s: pigment ring pushes outward. (E1 re-wet → E3 lift.)
3. **Subtractive wet mixing** — cross still-workable blue with yellow. At the
   crossing, the old active ridge loses at least 88% of its deposited load,
   both spectra occupy the same suspended cells, and the composite reads green
   rather than two alpha-blended marks. Confirm palette-size independence:
   painting from 48 pigments costs the same per pixel as 3. (§6.)
4. **Granulation** — high-`γₚ` pigment in a wet wash settles into the selected paper's valleys; low-`γₚ` stays smoother. (`E3 × (1-Paper.R)`.) Confirm granulation weight survives settle and lift.
5. **Containment** — a wash does not leak past its connected wet boundary while flowing internally. (D1 destination gate.)
6. **Dry-tile deactivation** — a wash stops consuming GPU a few seconds after the last stroke. (§7 tiling.)
7. **Pressure composition** — a light contact has a higher pigment/water ratio
   and lower fluid impulse than a firm contact while retaining visible colour.
8. **Wet union / dry glaze** — overlapping wet colours enter a shared mobile
   wash; the same overlap after complete drying leaves the substrate fixed and
   produces an ordered transparent glaze.
9. **Wet/damp/dry matrix** — repeat the same crossing with `M>0.85`, damp
   `0.15<M<0.65`, and after dry lock. Shared two-colour mobility must order
   `wet > damp > dry≈0`, while every `K/S` band and property sum is conserved.
10. **Touching-front union** — two differently coloured wet fronts exchange
    both pigments symmetrically once face-connected; the same scene with a dry
    gap does not mix. A trace threshold alone is insufficient: each colour must
    enter the other's former region by a meaningful bounded ratio.
11. **Drop inside a wet wash** — both old and new pigment move beyond the drop
    footprint, pigment remains at the center, and no persistent circular/top
    stamp silhouette remains.
12. **Dry finalization and rewet protection** — once the engine reports dry,
    suspended load is negligible and every deposited spectral/property channel
    is frozen. Direct clean water and water arriving only from a neighbour must
    not lift that protected substrate.
13. **Receipt and clipped-footprint conservation** — a zero accepted receipt
    creates no material. The same nonzero receipt, applied with different
    cluster radii or partly outside the canvas, produces the same total carrier,
    load, every `K/S` band, `granWt`, and `stainWt` immediately after contact.
    Sibling-cluster order must not change the result.
14. **Paper coupling** — with equal initial water, selected papers with different
    capacity retain different bounded `s`; connected valleys carry more
    capillary flow than peaks, and no face transfer creates water.
15. **Tilt and real time** — positive tilt produces bounded downhill motion in
    the selected direction. Equal wall time at 30 Hz, 60 Hz, and jittered
    callbacks gives near-equal displacement, wetness, drying state, pigment
    totals, and mixing score after the elapsed-time accumulator is implemented.
16. **Artist colour-change pause** — at the default Water-panel dry setting, a
    normally wet stroke retains `M>0.45` through an eight-second pause before a
    second colour arrives. With `Show wet areas` enabled, the visible diagnostic
    and the mixing decision must agree. The first pigment must remain outside
    protected `Dry`, and a water-bearing second colour must reopen at least 88%
    of its deposited ridge across the whole crossed stripe, not only one center
    cell. This locks the failure reproduced in `TestingArtifacts/watercolor-1.gif`.
17. **Flutter alpha handoff** — a straight RGBA pixel `(200,100,50,128)` becomes
    premultiplied `(100,50,25,128)` before `PixelFormat.rgba8888` decoding;
    fully opaque colour is unchanged and zero-alpha RGB is cleared. The
    simulation's pre-handoff straight buffer remains unchanged for colour tests.

---

## 12. Known simplifications & fidelity upgrades

- **Incompressible vs true shallow water.** v1 uses projection + a height-gradient force. Full shallow water (evolving `h` with `∇·(h u)`) gives more convincing puddling and drying fronts — upgrade the Fluid engine later without touching Pigment.
- **Thick-layer vs finite-thickness KM (required and still open).** F1 currently turns one unordered `R∞` mixture into a transparent wash alpha that Canvas State draws over paper. Exact ordered KM layer-over-substrate reflectance (using `load` as thickness and preserved dry-layer order) is a **required Phase 4 upgrade** for convincing transparent glazing, not optional polish (§6 and A3). Phase 4 is not complete until this is implemented and the order test passes.
- **8 bands vs more.** 8 spectral bands is the chosen default; 16 is the fidelity ceiling and rarely worth the doubled spectral memory.
- **Jacobi pressure.** Fine for real-time; multigrid is the upgrade if you push sim resolution past ~768².
- **Single water layer.** Curtis separates a thin capillary layer from the surface water; we fold both into `h + s`. Splitting them improves very-wet puddle behavior.

---

*Interfaces to hold stable during the port: the texture list in §3, the pass order and per-pass I/O in §5, and the parameter names in §9. Everything else is free to change.*
