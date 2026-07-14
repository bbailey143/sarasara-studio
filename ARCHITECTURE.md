# Architecture

## Overview

Sarasara Studio is a natural-media painting app built in Flutter. Its shared
physical brushes can carry distinct media—including watercolor and oil—while
pigment, surface, fluid/rheology, and lighting behavior remain in their proper
domains. This document is the stable architectural map. For what's built vs.
pending, see [ROADMAP.md](ROADMAP.md).

## Binding implementation specifications and precedence

The following specifications are the foundation of this architecture and are
**absolutely critical to the product**:

- [`specs/brush-engine-spec.md`](specs/brush-engine-spec.md) defines the one
  shared, medium-agnostic Brush engine: physical brush construction, safe
  stylus input, deformable bristle clusters, contact fields, reservoir
  conservation, transfer receipts, and medium adapters.
- [`specs/watercolor-engine-spec.md`](specs/watercolor-engine-spec.md) defines
  watercolor's Fluid, Pigment, Texture, and Canvas State fields and ordered GPU
  simulation passes.
- [`specs/oil-engine-spec.md`](specs/oil-engine-spec.md) defines oil's
  viscoplastic Rheology, mechanical pigment transport, height field, brush
  exchange, glazing, and Lighting pipeline.

These are binding implementation contracts—not research, future ideation,
optional fidelity, or reference material. All specified components, stable
interfaces, precision rules, pass ordering, conservation requirements, and
validation tests must be implemented and working.

**Precedence rule:** if this file, existing source code, a placeholder, an
older design decision, or completed work conflicts with a specification, the
specification wins. The conflicting architecture and code must be changed or
replaced; prior effort is not a reason to keep an incompatible path. When a
spec-driven replacement lands, update this architecture and remove the stale
alternative so the project never retains two competing systems.

The three specifications are one connected contract. The Brush engine emits
medium-agnostic contact and accepted-transfer bookkeeping; watercolor and oil
consume that shared contract while retaining completely different material
physics. None of the engines may absorb another engine's responsibilities for
convenience.

## Domain Separation

The engine keeps tool, material, surface, simulation, lighting, and persistent
canvas state in independent domains, coordinated but not owned by a central
controller:

- **Brush** (`models/brush.dart`, `core/rendering/brush_physics_engine.dart`)
  owns physical tool construction, normalized input, bend/splay/split/contact,
  bristle-local velocity, reservoir capacity/state, and transfer opportunity.
  It emits `BrushContactSample`; it does not own watercolor or oil results.
- **Medium adapters** translate `BrushContactSample` and accepted transfer
  receipts into the active medium's Phase A fields. They are the only bridge
  between shared brush physics and medium-specific material state.
- **Pigment** (`models/pigment.dart`, `core/pigment/`) owns the shared 8-band
  spectral `K/S` palette, extensive pigment-property sums, Kubelka-Munk mixing,
  and medium-appropriate pigment transport. It does not own brush shape.
- **Texture / Surface** (`models/paper.dart`, `core/paper/`) owns static paper
  or canvas height, absorbency/capacity, fiber, and weave fields. A brush may
  sample surface height for contact; watercolor and oil decide how material
  responds to that surface.
- **Fluid** owns watercolor velocity, pressure, incompressible flow, water,
  capillary saturation, evaporation, and wet boundaries.
- **Rheology** owns oil height-field yield, Herschel-Bulkley flux, mechanical
  transport, thixotropy, and volume conservation. Oil pigment diffusion is
  always zero.
- **Lighting** owns oil height-field normals, illumination, sheen, and the
  final lit oil result. It does not modify paint physics.
- **Canvas State** owns persistent simulation textures, composited color,
  activity tiles, checkpoints, and undo/redo snapshots appropriate to each
  medium.
- **`CanvasController`** coordinates these systems. It should not become
  the permanent home for brush, pigment, or paper rules — when a rule
  clearly belongs to one domain, it moves into that domain.

## Module Map

| File | Responsibility | Depends on |
|---|---|---|
| `models/brush.dart`, `paper.dart`, `pigment.dart` | Pure data + presets | nothing |
| `core/canvas/input_sample.dart` | One pointer/stylus sample | nothing |
| `core/canvas/stroke.dart` | One full stroke (samples + brush/paint snapshot) | `models/brush`, `core/pigment/paint_mixture` |
| `core/canvas/canvas_controller.dart` | Central state hub: strokes, undo/redo, active tool settings | almost everything below it |
| `core/paper/perlin_noise.dart` | 2D gradient noise (fBm, domain warp) | nothing |
| `core/paper/paper_texture.dart` | Procedural height/capacity grid + bilinear lookup + dry-brush decision | `perlin_noise` |
| `core/paper/granulation_helper.dart` | Pigment-settling bias from paper height | nothing (pure function) |
| `core/pigment/paint_mixture.dart` | "Paint recipe" value type (pigment portions + display color) | `models/pigment` |
| `core/pigment/pigment_mixer.dart` | Mixes paint recipes into one | `paint_mixture` |
| `core/pigment/spectral_color.dart` | Shared eight-band Kubelka-Munk reflectance and display conversion | nothing |
| `core/pigment/pigment_palette_lut.dart` | Fixed 48-row RGBA32F palette packing shared by watercolor and oil | `models/pigment` |
| `core/pigment/canvas_pigment_layer.dart` | Legacy compatibility grid; not authoritative for watercolor/oil mixing or brush pickup | `pigment_mixer` |
| `core/rendering/brush_physics_engine.dart` | Brush footprint deformation (pressure, rotation, stress/split) | `models/brush` |
| `core/rendering/stroke_renderer.dart` | **Current placeholder renderer.** Must be replaced/refactored into brush contact rasterization plus the active medium adapter and simulation/composite pipeline. | `brush_physics_engine`, active medium |
| `core/rendering/paper_renderer.dart` | Caches the visible paper texture as a `ui.Image` | `paper_texture` |
| `core/rendering/rgba_pixels.dart` | Straight-alpha simulation pixels → Flutter-required premultiplied RGBA8 handoff | `dart:typed_data` |
| `core/watercolor/watercolor_field.dart` | Persistent watercolor sim fields (spec §3) as float32 buffers at sim resolution, with ping-pong pairs, diagnostic full snapshots, and exact occupied-tile live-history checkpoints | nothing |
| `core/watercolor/watercolor_params.dart` | Watercolor simulation constants (spec §9) | nothing |
| `core/watercolor/watercolor_simulation.dart` | Per-frame watercolor pipeline plus contact-only field pickup and mobility-driven visible dryback | `watercolor_field`, `spectral_color` |
| `core/watercolor/watercolor_engine.dart` | Facade: resolves bidirectional watercolor receipts, maps brush contact into Phase-A splats, ticks, and composites | `watercolor_simulation`, `medium_adapter`, `brush_reservoir` |
| `core/oil/oil_field.dart` | Persistent oil sim fields (oil spec §3): float32 height/binder/structure, staggered fluxes, 8-band spectral sums, props, whole-state snapshots | nothing |
| `core/oil/oil_params.dart` | Oil constants (oil spec §11 names) + HB yield/mobility helpers | nothing |
| `core/oil/oil_simulation.dart` | Per-frame oil pipeline (oil spec §7: A exchange/drag → B yield-gated flux → D thixotropy → F lit composite); zero pigment diffusion | `oil_field`, `spectral_color` |
| `core/oil/oil_engine.dart` | Facade: brush contacts → stamps/drags, **authoritative** transfer receipts (dirty brush end-to-end), tick, lit composite | `oil_simulation`, `medium_adapter`, `brush_reservoir` |
| `ui/painting_screen.dart` | Pointer input → controller; `CustomPainter` compositing | `canvas_controller`, both renderers |
| `ui/toolbar/main_toolbar.dart`, `color_picker_dialog.dart` | Presentational only | models (+ each other) |

The module map above describes today's files where noted. It does not freeze
legacy classes as permanent architecture. Spec implementation should introduce
clear Brush Input/Contact, Medium Adapter, Fluid, Rheology, Pigment GPU,
Lighting, and Canvas State modules rather than forcing those responsibilities
into `StrokeRenderer` or `CanvasController`.

## Reactive State Model

`CanvasController extends ChangeNotifier` is the **only** reactive
primitive in the app.

- **High-frequency** updates (every pointer move) call `notifyListeners()`
  and are consumed only by `CustomPaint`'s `repaint: controller` inside a
  `RepaintBoundary` — this never triggers a widget rebuild.
- **Low-frequency** updates (brush/pigment/paper selection, undo/redo,
  clear) flow through toolbar callbacks into `setState()` in
  `PaintingScreen`, which cheaply rebuilds just the toolbar.

`CanvasController` owns brush/pigment/paper selection directly via public
getters/setters — the UI layer reads and writes those properties rather
than keeping a shadow copy of "current tool state" in local `State`.

## The Studio System

The main canvas stays focused on painting. Deep material customization —
building a custom brush, paper, or pigment from scratch — belongs in
separate **Studios** (Brush Studio, Paper Studio, and eventually a Pigment
Studio) reachable from the canvas but not crowding it.

A Studio is a workspace, not a settings panel: create from a preset,
duplicate before editing, save named custom materials, live-preview
changes, mark favorites. The main canvas offers simple selection and quick
controls; the Studio offers deeper shaping.

**Undecided:** whether a Studio opens full-screen, as a modal, or as a
side panel. This isn't scaffolded yet — see ROADMAP.md Phase 6.

## Performance Rules

These are architectural constraints, not later tuning notes:

- 60fps → <17ms/frame is a **ceiling** covering everything (input, canvas
  draw, toolbar, color mixing) — not a target hit only under ideal
  conditions.
- Precompute static brush variation and palette/spectral constants where the
  specs permit it. Never replace required physical behavior with a lookup that
  changes the result—for example, a Fick diffusion lookup cannot substitute
  for watercolor transport and must never be applied to oil.
- Brush input and low-count cluster dynamics run on CPU; brush-local contact
  fields and medium Phase A transfer run on GPU as specified. Reservoir
  receipts remain strictly ordered even when canvas work is batched.
- Watercolor and oil simulation must be **localized** to active tiles, use the
  spec-required simulation/display resolution split, halos, precision, and
  checkpoints, and avoid full-canvas simulation when no material is active.
- Every expensive visual feature needs a cheap fallback (fewer bristles,
  wider stamp spacing, lower wet-sim resolution, simpler paper).
- Small contact bounds must stay cheap, but the required brush-contact and
  medium texture passes are GPU architecture, not optional high-quality mode.
  Quality fallbacks may reduce cluster counts or simulation resolution only
  within the specifications' physical and precision requirements.

## Known Architectural Decisions

These record useful implementation boundaries. They are subordinate to the
binding specifications above; any conflict must be resolved in favor of the
specifications.

1. **`BrushPhysicsEngine.computeDeformation` owns rotation.** It takes a
   `rotationAngle` parameter and is meant to be the single place that
   turns brush-local steady-state offsets into world-space deformed
   offsets (rotate → contact-scale → stress → split). `StrokeRenderer`
   must consume its output — it must never recompute stress/split math
   inline itself. In the prior implementation, `StrokeRenderer.render()`
   reused `BrushPhysicsEngine.contactScaleForPressure()` and
   `applyFrictionKinking()` correctly, but reimplemented the stress/split
   formulas (`phi`, `rho = tan(...)`, split axis/shift) inline instead of
   calling `computeDeformation()`, which already implemented the same
   logic — `computeDeformation()` was exercised only by unit tests, never
   by production rendering. The mismatch existed because the engine
   version operated on unrotated offsets while the renderer needed
   rotated ones; giving the engine a `rotationAngle` parameter removes
   that excuse.
2. **Legacy pigment helpers were removed.** `PigmentDiffusionLut` and CIELUV
   blending are no longer in the active tree. Shared spectral KM owns mixing;
   oil never diffuses pigment, and watercolor uses its specified transport
   pipeline.
3. **Water state arrives with the specified Fluid engine.** Do not revive the
   old unused `PaperWetnessLayer` design. Phase 4 implements the watercolor
   spec's `Water` and `Saturation` textures, wet mask, capillary flow, and
   evaporation as one connected system.
4. **No speculative `utils/` file.** A `math_utils.dart` grab-bag
   (smoothing, remap, Catmull-Rom) existed previously but was unimported
   by anything else in the codebase — superseded by spring-damped math
   living directly where it's used. Reusable math helpers get added here
   only once something real calls them.
5. **Final rendering reads authoritative simulation state.** The current
   `StrokeRenderer`-only picture and disconnected `CanvasPigmentLayer` are
   placeholders, not a permanent boundary. Watercolor composites its
   suspended/deposited spectral textures; oil composites and lights its live
   height/spectral state. Pickup and dirty-brush exchange use the same
   authoritative state through medium adapters and transfer receipts.
6. **One brush, multiple media.** Never create separate watercolor/oil copies
   of a physical brush. Brush construction and contact stay shared; each
   medium resolves its own transfer and post-contact physics.

## Watercolor Engine (Phase 4)

`core/watercolor/` is the watercolor medium. It keeps the shared spectral
Kubelka-Munk colour + 48-pigment palette and implements the binding Fluid
pipeline in `specs/watercolor-engine-spec.md`. The wet-map + diffusion build in
`WATERCOLOR-REDESIGN.md` is a temporary historical fallback after artist
review found it read as wet markers. It must not replace or double-run with
velocity-carried pigment. Migration ownership and handoff rules live in
`WATERCOLOR-FLUID-RECOVERY.md`.

**Corrected direction.** Bleeding, edge darkening, and subtractive colour are
necessary but insufficient without coherent water movement. The Fluid engine
owns velocity, forces, viscosity, projection, and transport; small diffusion
may soften microscopic dispersion but cannot be the primary movement model.

**The model** (`WatercolorSimulation.step`, one wet surface, CPU float32):
1. **Fluid velocity** — self-advection, shallow-water height force, viscosity,
   divergence, Jacobi pressure, and partial free-surface projection;
2. **Conservative pigment transport** — projected brush/water velocity moves
   suspended `K/S` and property sums by donor-cell flux; wet-boundary distance
   supplies local capillary direction toward each mark's own drying edge;
3. **Surface-water transport** — velocity advects water before capillary paper
   spread, soaking, evaporation, and wet-mask update;
4. **Microscopic dispersion** — a deliberately secondary, bounded diffusion
   pass softens wet-into-wet mixing without owning bulk movement;
5. **Drying-rim accumulation** — a conservative donor transfer concentrates
   mobile pigment toward the local wet boundary;
6. **Settle/lift/finalize** — pigment remains suspended while fully wet, settles as the
   film dries, and clean-water impact re-suspends and pushes pigment into a
   backrun; granulating pigment settles preferentially into paper valleys, and
   a held dry transition protects the completed substrate;
7. **Fallback isolation** — `diffusionFallback` uses the historical path and
   never runs the pressure/Fluid passes in the same frame.

**Bloom and paper invariants.** Phase-A contact divides pigment into a mobile
fraction and a bounded mechanically caught fraction governed by staining,
granulation, and the local paper valley. Fluid and capillary passes may move or
re-lift the mobile fraction, but must not evacuate every trace from the contact
center. Capillary exchange is conservative and weighted by connected paper
valleys, so advancing fronts become irregular and branch with the paper rather
than expanding as perfect circles. All contacts write into the same water,
velocity, saturation, suspended-pigment, and deposited-pigment fields;
per-stroke private wet simulations are forbidden.

An incoming drop first reopens older *active* deposited pigment beneath it,
then adds its own caught/mobile fractions. At full wetness, a coloured crossing
returns 90–94% of that unprotected deposit to the shared suspended mixture so
the earlier ridge dissolves. Clean water remains capped at 46%, preserving the
retained center required for a bloom rather than reviving the hollow/Cheerio
failure. The protected `Dry` subset is never included. Neither lift removes
pigment from its cell; only Fluid or conservative exchange transports it.
Microscopic pigment dispersion may cross a connected wet boundary without
increasing capillary water spread; pigment mixing and water expansion remain
separate controls.

**Interim CPU budget.** The live reference remains one shared 224-cell field
with 8 pressure iterations, one viscosity pass, and two microscopic-dispersion
passes. It now divides CPU work into 16-cell activity tiles with a one-tile
halo. Every field is still shared across the whole sheet, so touching wet marks
interact normally; the mask only skips genuinely dry tiles between separate
marks. A 320-cell whole-sheet experiment was
removed after it froze during wet two-colour union: the area cost doubled and
the interaction hotspot crossed the usable CPU limit. This establishes a hard
architecture boundary. Higher-resolution artist review must come from active
tiles/halos plus the binding 512² GPU/Metal target, not another brute-force CPU
increase. The 224 reference remains useful for conservation and connection
checks but is not sufficient evidence of final visual fidelity. The CPU mask
is an immediate accumulated-lag safeguard, not a replacement for the Metal
backend or measured artist performance approval.

**Canvas tilt diagnostic.** `WatercolorParams.gravityX/Y` adds a constant
downhill acceleration only in wet cells. The Water panel exposes amount and
direction. This is real transport, not a display transform, and exists both as
an artist control and as a diagnostic for whether bulk flow is visible. Gravity
must be applied after pressure projection; applying it before projection lets
the solver cancel the uniform downhill force and makes tilt appear inert.

**Live-start invariant.** A fresh splat is active even before its derived wet
mask exists. `isDry` therefore checks raw surface water, paper saturation,
suspended pigment, and unprotected deposited pigment—not `M` alone—and
`_water` writes the new mask after ping-pong ownership swaps.
`Show wet areas` composites the exact mobility mask `M`, making workable
wetness visible independently of pigment or raw, sub-threshold moisture.

**Visible dryback.** The same `M` drives the wash composite continuously. Wet
pigment is darker and fully optically connected. As `M` falls, effective
particle scattering increases by up to 26 percent and alpha eases from full
wet coverage to 86 percent of that coverage, producing a lighter, matte dry
passage that reveals more of the separately rendered paper. This changes only
optics; it does not move pigment, alter the stroke footprint, or bake paper
texture into the wash. The live ticker keeps requesting these frames until the
raw-state `isDry` contract is satisfied.

The CPU simulations expose straight-alpha RGBA for readable colour tests.
Before those bytes enter Flutter's `PixelFormat.rgba8888` decoder, Canvas State
uses `premultiplyRgba8888` on the disposable image buffer. Passing straight RGB
to that premultiplied API is forbidden: low-alpha pigment otherwise contributes
near-full light and makes thin washes look additive or white-edged. The same
shared handoff is used by watercolor, its wet-area overlay, and oil.

Colour is spectral KM throughout (unchanged). Regression scenes are authored
across the watercolor test files for wet union, Fluid transport, subtractive
mixing, edge darkening, bloom, dry-out/stability, containment, receipt
authority, and paper coupling. The explicit artist scene from
`TestingArtifacts/watercolor-1.gif` is now binding: after an eight-second colour
change, a still-workable blue ridge crossed by yellow must become one green wash
and lose the old blue boundary. The 2026-07-13 revision is not yet
test-confirmed because the Flutter SDK execution gate prevented the focused
run. A visual harness (render-to-PNG frames) is the primary tuning tool—the
model is judged by eye, not only by numbers.

**One canvas source and contact-only dirty brush.** Mixing happens in the one
shared watercolor field; no stroke owns a private colour layer and the legacy
proximity grid (`_simulatePigmentExchange`) remains deleted. A brush can become
dirty only when its real bristle footprint contacts mobile paint. Before the
new deposit lands, watercolor may remove bounded surface carrier, suspended
pigment, and a smaller staining-resistant share of active `Dep-Dry`. It never
removes protected `Dry`. The medium returns the exact removed carrier, pigment,
eight-band `K/S`, granulation, and staining in the accepted receipt. Applying
that receipt changes the shared medium-agnostic reservoir, so later contacts
carry the picked colour until the artist rinses or loads a clean selected paint.
Replay uses stored reservoir snapshots and disables pickup, preventing a
rebuild from removing the same canvas material twice.

**Receipt-authoritative deposit.** The watercolor adapter resolves the
reservoir's elapsed-time offer into separate accepted pigment `P^0.65` and
carrier `P^2.0` quantities. The Water-panel Wetness control changes carrier
acceptance at this point, before the receipt exists. `WatercolorEngine` then
uses the receipt's own spectral/property sums and converts physical brush units
to CPU-grid units with fixed `1200×` pigment and `875×` carrier calibration.
The same receipt removes
material from the one shared brush reservoir and supplies the live wash, so a
zero receipt cannot create pigment or water and stationary dwell needs no
special repeat-stamp scale. Light pressure is colour-dense and water-poor;
firm pressure releases much more carrier. Bristle-to-wash motion remains a
separate `P^1.4` coupling, allowing even an empty brush to push existing wet
paint without inventing material.

The medium-neutral footprint carries each physical cluster's radius. Live
watercolor splats that local radius (with a small simulation-cell safety floor)
instead of drawing one whole-brush disc for every cluster. Synthetic engine
tests that omit radius retain the whole-brush fallback. Cluster shares still
sum the accepted contact quantity once, regardless of footprint radius, and
pressure is not reapplied inside the raster footprint. All sibling clusters
are accumulated into reusable contact buffers before the wash changes; they
therefore see one pre-contact state, cannot lift/freeze one another, and run
wet union once for the whole brush sample. The artist-approved stronger colour
is preserved in the fixed pigment conversion; `pigmentConcentration`,
`carrierGain`, and `waterRatio` now belong only to explicit synthetic scenes.

One physical contact's normalized stylus force is divided among its sibling
clusters. Those force shares sum back to the original pressure exactly once at
the medium boundary. Averaging the shares would make a many-bristled brush
artificially weak; copying the whole pressure onto every sibling would make it
artificially strong. Brush shape therefore cannot change the artist's pressure.

This is the engine-separation boundary: the Brush engine knows tool geometry,
hairs, pressure, motion, and reservoir opportunity but no bloom or watercolor
rule. Watercolor consumes only the stable contact/receipt contract and knows no
Sable, Flat, or Mop preset identity. The adapter and controller coordinate the
handoff; neither engine may reach through that boundary to special-case the
other. Oil must consume the same brush contact contract with its own transfer
and material laws.

**Wet union, damp working time, and dry glaze.** Every cell derives one mobility
value from surface water and slower paper saturation:

`surface = smoothstep(.35·wetThr, 1.5·wetThr, h)`

`paper = smoothstep(.20·wetThr, 1.1·wetThr, s)`

`M = 1 - (1 - surface)·(1 - .60·paper)`

All contact, dispersion, settling, lift, and wet-mask decisions use this same
`M`; no stroke owns a private wet flag. During coloured contact, accepted
carrier derives `Mcontact = M + (1-M)·freshWater` for active `Dep-Dry` pigment
only; protected `Dry` can never be reopened by this shortcut. At `Mcontact≈1`,
the crossing reopens 90–94% of recent unprotected deposit, fresh catch approaches
only microscopic grain trapping, and a bounded local face exchange removes the
new-stroke seam. That exchange runs only over actual coloured overlap plus a
three-cell margin, not an entire broad-brush box. Damp paper (up to `M≈.60`
from saturation alone) mixes partially. The current `wetThr=.045` and
`paperDryFactor=.22` preserve that interval through an ordinary colour change.
The live Dry-rate control uses an exponential `0.000002..0.0012` surface
evaporation range per 30 Hz step, so its lower half represents genuinely long
working time while the upper end still permits intentional fast drying. A
faster residual drain begins only after mobility
is already zero. Below
`wetOff=.01`, a per-cell clock advances; above `wetOn=.03`, it resets. Only
after a continuous `0.15 s` dry hold is the last suspended fraction
force-settled and the complete
deposited state copied to `Kdry/Sdry/PropsDry`. Later brush or capillary water may
move only `Dep - Dry`, so it cannot resurrect a finished layer.

Deposited properties occupy one RGBA record: `(load, granWt, stainWt,
dryClock)`. Granulation and staining weights move with pigment during both
settling and re-lift, so a granulator does not lose its paper behavior after
one wet/dry exchange.

Microscopic dispersion uses symmetric conservative face flux with
`coupling=sqrt(Ma·Mb)`: every `K/S`, load, granulation, or staining amount
removed from cell A is added to B. This specifically replaces the old
one-sided variable-wetness Laplacian, which could manufacture or erase pigment
at a damp/wet join. Bulk movement still belongs to Fluid; this local exchange
is contact union, not a second motion engine.

The selected paper's real capacity map limits local soaking, while tooth height
biases capillary connections, immediate grain catch, and granulation settling.
The current composite still sums total deposited spectra, so binding completion
additionally requires ordered finite-thickness layer-over-substrate optics.
Likewise, the CPU driver still advances at a calibrated fixed 30 Hz; the hold
is measured using that fixed step, but real-time substepping remains required
so UI lag cannot alter drying history.

**Live wiring (`CanvasController` + `PaintingScreen`) — seamless, not a mode.**
Watercolor is always active. Every brush contact feeds `WatercolorEngine`
(`_depositWatercolor`, using the accepted carrier and spectral receipt); a
completion-scheduled clock calls `tickWatercolor` near 30 fps (steps only while
wet or freshly painted, recomposites on change, and retains one latest-frame
request while image decode is busy). It schedules the next update only after
the current Fluid/Oil work returns and guarantees at least a 16 ms UI gap once
work exceeds half a nominal frame. This prevents repeating-timer catch-up from
starving stylus input; it is a responsiveness guard, not the still-required
elapsed-time-invariant substep system. For watercolor the painter draws only the **transparent shared wash**
over the paper—there is no completed- or active-stroke colour layer above it.
A collapsible `Water` panel maps Flow,
Wetness, Edge, Dry rate, Canvas tilt, and Tilt direction to live parameters via
mutable `WatercolorSimulation.params`. Undo/redo restore exact stroke-boundary
wet-state checkpoints; replay remains only as a compatibility fallback. Live
watercolor history stores complete field data only for occupied 16×16 tiles.
This retains exact wet undo while avoiding the former roughly 13 MB full-sheet
copy before every stroke—the cause identified for the repeatable six-stroke
memory/garbage-collection freeze. Full snapshots remain an engine diagnostic,
not the live history format.
The Water panel's optional performance readout reports the last complete update
time, actual active simulation fraction, and retained undo memory. These are
diagnostics only and do not alter medium behavior.

**Still open:** artist visual approval of the restored Fluid feel—including
non-circular branching blooms, retained center pigment, and visibly shared wet
interaction between overlapping strokes—plus ordered dry-glaze optics,
real-time substepping, shipping GPU tile storage/dispatch, the GPU/Metal
backend, and contact-based dirty-brush pickup.

## Oil Engine (Phase 5)

`core/oil/` is the oil medium — the CPU reference of
`specs/oil-engine-spec.md`. It reuses the shared spectral Kubelka-Munk colour
and 48-pigment palette unchanged and implements what oil does differently:
viscoplastic transport, a dynamic height field, a bidirectionally loaded
brush, and height-field lighting. The two governing facts (spec §1): **flow is
gated by yield stress** (`τ = ρ·g·h·|∇H|` against Herschel-Bulkley
`τ_y + K·γ̇ⁿ`; sub-yield paint holds — impasto), and **pigment never
diffuses** — colour moves only where paint is mechanically transported. There
is no diffusion term anywhere in `core/oil/`.

**Modules.** `oil_field.dart` (spec §3 texture set as float32 buffers: height,
binder volume, thixotropic structure, staggered face fluxes, 8-band `K`/`S`
sums, extensive props, plus whole-state snapshots), `oil_params.dart` (spec
§11 names), `oil_simulation.dart` (the pipeline), `oil_engine.dart` (facade:
brush contacts → stamps/drags, authoritative receipts, tick, lit composite).

**The pipeline** (spec §7): **A1** bidirectional exchange per contact —
pickup first (drag-gated, so the lifted spectrum is the *older* paint → dirty
brush), then deposit toward the pressure-weighted equilibrium film
`max(0, film·fill − h)`, which makes a held press saturate instead of pumping
volume (oil needs no dwell scaling); **A2** brush drag, the primary mixer;
**B** substepped yield-gated Herschel-Bulkley face flux with a hard sub-yield
branch (never smoothed — that is what freezes relief) and every material field
riding the identical donor fractions; **D** thixotropic structure recovery;
**F** finite-thickness Kubelka-Munk over the substrate (mandatory for glazing
to read) then height-field normals with diffuse + oil specular, drybrush
tooth-mask alpha, and straight-alpha simulation RGBA. The shared rendering
handoff premultiplies only the disposable copy sent to Flutter.

**Documented deviation from the spec's §6 advection preference.** The spec
prefers BFECC/MacCormack for pigment in the brush-drag pass to keep marbling
crisp; this CPU reference uses conservative donor-cell/upwind transport for
*all* extensive fields in both the drag and flux passes. Rationale: strict
volume/pigment conservation (spec §8's own requirement), guaranteed
no-colour-where-no-paint, and co-transport so pigment can never separate from
its carrying paint. Crispness cost is bounded because sub-yield paint does not
move at all. The GPU port is the planned home of MacCormack drag. This
departure is also noted in the spec file per the precedence rules.

**Brush exchange is receipt-authoritative.** `OilEngine.depositContact`
performs the real exchange against canvas state and returns the
`TransferReceipt` (volumes *and* spectra, bounded by the brush's offer);
`CanvasController` applies it to the one shared `BrushReservoir`. Picked-up
colour therefore tints every later mark until rinsed — dirty brush conserved
end-to-end, with no oil-specific brush copy. Live contacts normalize total
contact pressure once (the same double-application lesson watercolor learned);
per-cluster shares shape the footprint, the stylus pressure drives the
drybrush gate. That gate rides the *local* tooth peak under the footprint, so
smooth paper is contacted at any pressure while rough canvas breaks a light
pass into peak-only deposits.

**Media coexistence, one brush.** `ActiveMedium` (controller) selects where
the next contact goes; both simulations persist and composite together (wash
below, oil above). Switching media rinses the reservoir into the new
`MediumFamily` (the reservoir guards against silent cross-medium mixing).
Undo/redo keeps one (possibly null) checkpoint per medium per stroke —
null-aligned lists mean a stroke restores only the medium it touched. The Oil
panel maps Body → yield+consistency, Thinner → deposited binder fraction
(never diffusion), Load → equilibrium film, Pickup → smear/dirty-brush lift,
Gloss → specular, Light angle → raking azimuth.

**Interim CPU budget.** 192-cell live grid, 3 rheology substeps per frame,
donor-bounded fluxes (≤ a fifth of the donor per substep), full step skipped
once every face is sub-yield (`isSettled`, an imperceptibility threshold —
the Bingham excess factor decays asymptotically, so bitwise stillness is the
wrong test). These are interactive-reference numbers, not a replacement for
activity tiling, the display-resolution normal split (spec §10), or the GPU
backend.

**Validation.** `test/oil_engine_test.dart` implements all seven spec §13
mechanisms (impasto hold under raking light, slump-then-stop, marble-not-bloom
with bitwise rest stability, dirty brush, wet-on-wet interface blending with
zero outward creep, drybrush broken colour, volume conservation) plus
checkpoint/composite/receipt-bound tests; `test/oil_integration_test.dart`
covers the controller wiring; `test/zz_oil.dart` and `test/zz_oil_live.dart`
are the render-to-PNG harnesses this engine was tuned with — judged by eye,
like watercolor.

**Still open:** artist stylus review of the feel (deposit/drag/gloss defaults
are eye-tuned), activity tiling, display-resolution normals, GPU/Metal
backend, and an oil scrape/wipe tool (the eraser currently no-ops in oil).

## Open Decisions

- **Studio navigation pattern** — full-screen, modal, or side panel.
- **State management** — `ChangeNotifier` is sufficient today (single
  screen, no cross-screen state sharing). Revisit if/when Studios (Phase
  6) need state shared across screens.

Pigment mixing is **not open**: the three binding specifications require one
shared 8-band, two-constant spectral Kubelka-Munk model and palette contract.
