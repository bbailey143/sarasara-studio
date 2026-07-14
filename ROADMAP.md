# Roadmap

Status tracker for Sarasara Studio. Update this after every milestone —
what's done, what's active, what's next. For the stable design reference,
see [ARCHITECTURE.md](ARCHITECTURE.md).

## Binding implementation specifications

The implementation specifications in [`specs/`](specs/) are mandatory parts
of this roadmap, not optional research or future enhancements:

- [`specs/watercolor-engine-spec.md`](specs/watercolor-engine-spec.md) is the
  implementation contract for the watercolor Fluid, Pigment, Texture, Brush
  handoff, and Canvas State work.
- [`specs/oil-engine-spec.md`](specs/oil-engine-spec.md) is the implementation
  contract for oil Rheology, mechanical pigment transport, the loaded-brush
  reservoir, height-field paint, and Lighting work.
- [`specs/brush-engine-spec.md`](specs/brush-engine-spec.md) is the binding
  implementation contract for the shared, medium-agnostic Brush engine. Its
  physical brush definition, input normalization, deformation/contact math,
  bristle clusters, reservoir conservation, `BrushContactSample`, transfer
  receipts, medium adapters, and validation requirements must all be built.
  It is not a research note, optional fidelity layer, or future upgrade.
- Where an older roadmap item, placeholder, or architectural note conflicts
  with any implementation-ready spec, the specs control. Update
  `ARCHITECTURE.md` and affected code documentation during that phase so the
  project does not retain two contradictory designs.
- A phase governed by a spec cannot be marked complete until its required
  data formats, stable interfaces, pass ordering, precision rules, and
  definition-of-done validation tests are implemented and pass.
- Any deliberate departure from a stable interface named at the end of a spec
  must be documented in the spec and `ARCHITECTURE.md` before implementation.

These requirements are non-negotiable acceptance criteria for the plan.

This is a fresh rewrite, not a resume of a prior project. Every phase
below starts unchecked, even though an earlier implementation of this same
app design (`archive/brush-concept-state` in the `brush-concept` repo)
completed Phases 0–3 and left useful lessons — see each phase's notes for
what was known to work there.

## Phase 0 — Foundation

- [x] Project structure (`models/`, `core/`, `ui/`) scaffolded.
- [x] `InputSample`, `Stroke` models.
- [x] `CanvasController` (`ChangeNotifier`-based) wired to a
      `CustomPainter` canvas.
- [x] Pointer capture, undo/redo, eraser, color picker, size slider.
- [ ] Verify: draw a stroke, undo it, redo it, erase part of it — all
      visually correct with no crashes.

## Phase 1 — Brush Engine

**Critical path — incomplete until the whole brush specification works.**
Implement [`specs/brush-engine-spec.md`](specs/brush-engine-spec.md) as the one
shared Brush engine used by every medium. A physical brush such as a Sable
Round #5 must retain the same construction and contact behavior when loaded
with watercolor or oil; only the medium's response may change. None of the
requirements below are research, optional polish, or deferred ideation.

- [x] `Brush` model + presets (round, mop, detail, flat, bristle, filbert).
- [x] `BrushPhysicsEngine`: pressure→footprint, rotation, bent Bezier
      skeleton, friction kinking, stress/splay, deterministic cluster layout,
      and controlled splitting are implemented in the shared physics layer.
- [x] Replace the single pressure-reactive ribbon with the specification's
      analytic footprint and persistent `16–64` bristle-cluster baseline.
      `StrokeRenderer` consumes contact paths and contains no duplicate
      deformation equations.
- [x] Implement device-safe pressure calibration, tilt/azimuth handling,
      time-aware filtering, equal-distance resampling, and deterministic
      replay from brush spec sections 3 and 5.
- [ ] Finish physical mm/view calibration. Timed stationary dwell samples are
      implemented and moving contact samples are event-rate independent.
- [x] Implement compression, damped bend and directional lag, splay, family
      geometry, deterministic splitting, contact pressure conservation, and
      local bristle velocity from brush spec sections 4, 6, and 7.
- [x] Add split/rejoin hysteresis and live Texture-engine height sampling to
      the cluster contact solver.
- [ ] Finish the conserved tip/belly reservoir. The 8-band extensive state,
      bounded offers, accepted receipts, depletion, medium-family safety, and
      rinse reset are implemented; Phase 2 must connect real palette spectra
      and canvas pickup so dirty-brush color is conserved end-to-end.
- [x] Implement the stable `BrushContactSample` contract, deterministic
      cluster/contact fields equivalent to (`W`, `D`, `Π`, `U`), sequential
      reservoir receipts, bounded contact work, and deterministic variation.
- [ ] Move brush-local contact rasterization from the verified CPU/Canvas
      baseline to the specification's shipping GPU texture path without
      changing the contact contract.
- [x] Implement the watercolor and oil medium-adapter contracts in brush spec
      section
      10. Brushes must provide contact and transfer opportunity only:
      watercolor owns flow/blooms/granulation, while oil owns yield,
      mechanical transport, relief, and lighting. No brush asset or preset may
      contain a baked watercolor edge, paper grain, bloom, oil ridge, or other
      prepainted medium effect.
- [ ] Implement every automated validation in brush spec section 15,
      including physical-size stability across zoom, input-rate independence,
      pressure safety, point-to-belly response, lag, tilt, splay, splitting,
      determinism, depletion, dirty-brush conservation, dwell bounds, and the
      same-brush/different-medium identity tests.
      **Current verification:** 15 focused brush tests plus the app-mount test
      pass; direct analysis reports no issues. Remaining tests are the physical
      zoom/device replay and final GPU-path checks.
- [x] **Artist stylus approval recorded July 11, 2026.** The user approved the
      Phase 1 physical brush feel after testing pressure/shape, directional
      flat-bristle behavior, large strokes, accumulated strokes, lag, and the
      final performance fixes.
- [ ] Complete the cross-phase section 16 scenes that require later engines:
      one brush/two fully simulated media, real spectral loaded-to-dry and
      dirty-brush passages, and the final target-iPad texture comparison.
- **Pass/fail:** Phase 1 is complete only when every required part of
  `brush-engine-spec.md` is implemented, all section 15 checks pass, and the
  section 16 artist-facing scenes pass on the target iPad and stylus. Phase
  1's brush-only stylus feel is approved; its remaining GPU, calibration, and
  cross-phase material gates stay open. A
  working placeholder ribbon, compile-only success, or a convincing baked
  stamp does not count as completion.

## Phase 2 — Pigment Mixing

**Goal:** paint-like color mixing — blue+yellow reads as green, not gray;
white shifts hue/boosts luminosity rather than just washing out.

- [x] `Pigment` model (opacity, staining, granulation, density,
      tint strength) + starter palette.
- [x] `PaintMixture`/`PigmentPortion` — pigment-identity carrier instead
      of a flat color.
- [x] `PigmentMixer.mixMany`'s aggregation (dedup by pigment identity) —
      real.
- [x] Replace the HSV placeholder with the shared 8-band, two-constant
      spectral Kubelka-Munk pigment model defined in
      `specs/watercolor-engine-spec.md` sections 3 and 6. This decision is no
      longer open: the same palette LUT, spectral storage, and KM conversion
      must be reused by watercolor and oil.
- [x] Add the 48-pigment palette LUT and float32 spectral packing/accumulation
      required by the watercolor spec; palette size must not increase
      per-pixel canvas storage.
- [x] `CanvasPigmentLayer` receives compatibility stroke deposits and performs
      spectral mixing/staining-aware lift, but it is not authoritative for
      watercolor/oil interaction or pickup. Those come from the active medium
      fields so there is only one physical source of truth.
- [x] Remove the old proximity-based `_simulatePigmentExchange` path. Dirty
      brush behavior now comes only from real bristle contact with the active
      medium field. Watercolor and oil return the exact pigment they remove in
      the shared reservoir receipt, and `rinseBrush()` restores the selected
      paint.
- [x] Remove HSV/CIELUV and Fick-diffusion helpers from the active pigment
      architecture. Oil diffusion remains zero; watercolor transport belongs
      to its specified Phase 4 simulation.
- [x] **Automated verification authored:** blue+yellow→green, white tint
      luminosity, fixed 48-row LUT packing, palette-size-independent eight-band
      storage, staining-aware lift, contact-only pickup conservation, dirty
      state, and rinse reset. The current revision still requires the pending
      SDK-enabled test run recorded under Phase 4 before it may be called green.
- **Pass/fail:** blue+yellow → green (fail = gray/muddy/black).
  Color+white → smooth lighten with possible hue shift (fail = flat,
  chalky fade). A brush crossing wet paint should visibly carry some of
  that color forward until rinsed.

## Phase 3 — Paper Surface

**Goal:** paper as an active material, not a background image.

- [x] `Paper` model + presets (Hot Press, Cold Press, Rough).
- [x] `PerlinNoise` (fBm + domain warp, anti-tiling) — real, closed-form.
- [x] `PaperTexture.generate()` — procedural height + capacity maps,
      real.
- [x] `PaperTexture.shouldSkipBristle` (dry-brush breakup) — real, wired
      into `StrokeRenderer`.
- [x] `GranulationHelper.granulationBias` — real, wired into
      `StrokeRenderer`.
- [x] `PaperRenderer` — cached visible tooth texture, real.
- **Pass/fail:** repeated strokes shouldn't reveal obvious texture
  tiling. A dry-brush stroke on Rough paper should show broken skips
  aligned with the paper tooth. A granulating pigment should settle more
  heavily into valleys than a smooth-staining one.

## Phase 4 — Water Flow & Drying

**Fluid recovery active (corrected 2026-07-12).** Artist review rejected the
wet-map + pigment-diffusion result as wet-looking marker strokes rather than
moving watercolor. Phase 4 again follows the binding
[`specs/watercolor-engine-spec.md`](specs/watercolor-engine-spec.md). The
diffusion build is a temporary fallback only; it cannot satisfy Phase 4 and
must not overlap the real Fluid transport. See
[`WATERCOLOR-FLUID-RECOVERY.md`](WATERCOLOR-FLUID-RECOVERY.md).

- [x] Implement velocity advection, water-height force, viscosity, divergence,
      pressure projection, free-surface residual flow, and wet boundaries on
      the CPU reference path. Fluid-specific divergence tests pass.
- [x] Transport suspended pigment conservatively and surface water with the
      solved velocity; diffusion provides only small-scale dispersion, never
      primary motion.
- [x] Automated proof: brush momentum moves pigment directionally while load
      remains conserved, and fallback mode does not execute the pressure solve.
- [x] Add an experimental canvas-tilt gravity control (amount + direction).
      Automated proof confirms a wet spectral wash travels downhill; artist
      review will show whether the live result exposes convincing bulk flow.
- [x] Fix live simulation startup: fresh water now forces the first step before
      `isDry` is consulted, and the derived wet mask is written to the current
      ping-pong buffer. Previously both bugs could leave every stroke static.
- [x] Add `Show wet areas`, a cyan diagnostic of the exact mobility mask used
      by wet mixing and lift, rather than pigment visibility or raw water.
- [x] Stop runaway water creation with conservative donor-cell transport and
      one-touch containment tests.
- [x] First bloom-shape correction after artist review: retain a bounded
      mechanically caught pigment fraction at brush contact, reduce the radial
      edge shove and repeated re-lift, and make capillary fronts prefer
      connected paper valleys. Tests require both an outer drying boundary and
      pigment remaining in the bloom center.
- [x] Second interaction correction after artist review: reduce capillary
      reach and radial drop impulse, retain at least half of the control
      center pigment in the clean-drop bloom test, and slow passive re-lift so
      a wet center is opened rather than erased.
- [x] A stationary held stylus now uses the brush reservoir's elapsed-time
      transfer offer and accepted receipt instead of adding a tuned full stamp
      every 17 ms. A zero accepted receipt deposits exactly zero pigment and
      carrier; an empty brush can still mechanically push an existing wash.
- [x] A new coloured drop now impact-lifts the older deposited pigment beneath
      it before adding its own pigment. Automated proof requires the older
      pigment to move outward while retaining a substantial center deposit.
- [x] Preserve the artist-approved `3.0×` pigment strength in the fixed
      receipt-to-grid conversion after artist review found the wash too pale.
      It remains independent of carrier volume and cannot change fluid levels.
- [x] Correct pressure-dependent paint composition after artist review exposed
      the previous response as inverted. Light contact uses pigment `P^0.65`
      and carrier water `P^2.0`, producing a colour-dense, water-poor mark;
      bristle push uses its own `P^1.4` coupling so a feather touch cannot fling
      a puddle. Firm pressure expresses much more water and stronger motion.
- [x] Preserve stylus pressure across multi-bristle contact. The Brush engine
      divides one touch into force shares whose sum is the original pressure;
      the medium recombines those shares once. A broad brush therefore neither
      becomes artificially firm nor artificially weak merely because it has
      more bristle clusters.
- [x] Distinguish wet overlap from damp working time and dry glazing at Phase A.
      One per-cell mobility value is derived from surface water plus slower
      paper saturation. Perfectly wet contact keeps almost all incoming pigment
      mobile, strongly reopens the recent active deposit, and immediately
      exchanges both colours across the connected wash; damp contact does this
      partially, while a dry under-layer is not lifted.
- [x] Treat all bristle clusters in one sampled brush touch as simultaneous.
      Their pigment, carrier, and motion accumulate before the shared wash is
      changed; old pigment is reopened once and local wet union runs once over
      the actual coloured-overlap region. Reversing sibling-bristle order must
      not change the result, and broad brushes no longer repeat the union pass
      per hair.
- [x] Replace one-sided wetness-weighted dispersion with symmetric neighbour
      exchange. Every spectral and pigment-property quantity removed from one
      wet cell is added to the other, including across a damp/wet boundary; the
      Phase 4 regression suite checks all eight `K/S` bands and property sums.
- [x] Correct the live wet-time scale. After artist review found even the
      minimum drying alongside the moving brush, the Water panel now maps
      surface evaporation exponentially from `0.000002..0.0012` per 30 Hz
      step. The lower half is deliberately expanded for long working time
      rather than wasting its travel on several nearly identical fast values.
      Paper-held moisture dries at `0.22×` that rate, uses `wetThr=.045`, and
      retains up to `.60` damp
      mobility after the surface shine fades. Faster tail drying starts only
      after paper mobility is already zero. A regression carries real blue
      pigment through the eight-second colour-picker pause reproduced in
      `TestingArtifacts/watercolor-1.gif`, then requires yellow to re-open it.
- [x] Correct the yellow-over-blue crossing from that GIF. A fully wet contact,
      or accepted coloured carrier re-wetting a still-active damp cell, now
      reopens 90–94% of the older unprotected deposit before adding the new
      pigment. Conservative seam exchange is limited to the actual coloured
      overlap plus a small connected margin, avoiding full broad-brush sweeps.
      The required result is one subtractive green wash with the earlier blue
      ridge dissolved—not a green patch over a blue line. Clean-water lift
      remains capped at 46% so bloom centers do not hollow out.
- [x] Correct Flutter's raw-image transparency handoff. Watercolor and oil keep
      straight pigment RGB internally, then premultiply a disposable RGBA copy
      immediately before `PixelFormat.rgba8888` decoding. Supplying full RGB
      with low alpha had made thin washes contribute too much light, which read
      as pale/additive colour and produced bright fringes.
- [x] Add persistent dry-substrate spectral state (`Kdry/Sdry/PropsDry`) to
      checkpoints and settle/lift. A `0.15 s` dry hold with separate off/on
      thresholds prevents a one-frame moisture dip from locking the wash.
      Once the hold completes, drying force-settles the final mobile fraction
      and freezes the substrate before `isDry` may become true. Direct or
      neighbouring clean water cannot silently re-lift that protected layer.
- [x] Make drying visibly animate, not merely change hidden state. The live
      composite now follows the shared wetness value every frame: wet pigment
      is deeper and more optically continuous, then lightens through spectral
      dryback and reveals slightly more paper as it becomes matte. The stroke
      footprint and pigment quantity do not change merely to fake dryness.
- [x] Implement contact-only watercolor dirty-brush pickup. The watercolor
      field removes bounded surface water, suspended pigment, and a smaller
      staining-resistant share of still-active deposit beneath the bristles;
      protected dry pigment is excluded. The exact removed `K/S`, pigment,
      granulation, staining, and carrier totals return to the shared brush
      reservoir and colour following contacts. Replay cannot pick up twice.
- [x] Enable the rinse tool from real reservoir pickup for both watercolor and
      oil. Choosing a paint or rinsing restores a clean reservoir; merely being
      near another stroke never dirties the brush.
- [ ] Implement ordered dry-glaze compositing: preserve a dry spectral
      substrate plus an active glaze layer (or a mathematically equivalent
      ordered finite-thickness KM result). The current single deposited field
      protects dry pigment from lift but cannot fully represent layer order;
      transparent layering is required before Phase 4 completion.
- [x] Apply canvas gravity after pressure projection rather than before it;
      this prevents the pressure solve from cancelling the downhill force.
      The tilt centroid test remains binding.
- [x] Replace the temporary dwell `depositScale` safety factor with
      receipt-derived, time-integrated watercolor transfer. The adapter now
      resolves the binding `P^0.65` pigment and `P^2.0` carrier releases into
      the same accepted receipt used by both the brush reservoir and live wash.
      Bristle-cluster radius also survives the shared handoff; watercolor no
      longer inflates every cluster into another whole-brush disc.
- [x] Make the accepted receipt the complete live material authority. Its own
      `K/S`, granulation, staining, pigment, and carrier values win inside the
      engine; accepted totals are normalized across footprint size. The Water
      panel changes carrier acceptance before the receipt is issued, while the
      engine applies only fixed `1200×` pigment and `875×` carrier unit
      conversions. Paper capacity is now sampled from the selected paper, and
      granulating pigment settles more strongly into its valleys.
- [x] Reject and remove the brute-force 320-cell CPU `Review` experiment after
      artist testing froze when two wet colours combined. Increasing 224 to
      320 doubled the area processed by Fluid and activated the most expensive
      contact-union work exactly when colour interaction needed review. The
      live app is restored to the safe 224-cell reference; the asynchronous
      stale-frame guard from that experiment is retained.
- [x] Stop accumulated wet strokes from making one ever-larger CPU work area.
      The 224-cell reference now marks 16-cell activity tiles, expands each by
      a one-tile safety halo, and skips dry tiles between separate marks during
      Fluid, pigment, water, edge, and settling passes. This preserves one
      shared watercolor field and cross-stroke mixing; it does not create a
      private simulation per stroke. A focused regression now asserts that
      distant wet marks no longer process the empty rectangle between them; it
      remains unconfirmed until the safe test run is available. Artist testing
      is still required to confirm usable lag after many large strokes.
- [x] Prevent CPU overload from becoming a self-sustaining UI freeze. The live
      medium clock now uses completion-scheduled one-shot updates instead of a
      repeating 33 ms timer: light work remains near 30 fps, while an expensive
      wet sheet receives a guaranteed 16 ms input/render gap before another
      update may begin. Simulation activity also retires sub-visible water,
      saturation, and velocity tails instead of keeping halo tiles alive. The
      Water panel exposes optional live update time, active-water percentage,
      and undo memory so further artist reports carry direct evidence.
- [ ] **Resolution is now an artist-validation gate, not optional polish.**
      Port the now-established activity-tile/halo behavior to the GPU/Metal path
      before further final tuning claims. The coarse CPU reference can verify
      conservation and engine connections, but cannot reliably expose the
      paper/brush/medium detail required for visual approval. Do not attempt
      another whole-sheet CPU resolution increase as a substitute.
- [ ] Re-run the focused Phase 4 Flutter suite after SDK execution is available.
      The new wet-union/finalization/receipt, visible-dryback, contact-pickup,
      protected-dry, conservation, and rinse-state tests are authored, but the
      2026-07-13 handoff could not execute them because the environment usage
      gate rejected Flutter's required SDK access; do not report this revision
      as test-confirmed until that run is green.
- [ ] Demonstrate and obtain artist approval for visible directional flow,
      irregular paper-guided branching, cross-stroke wet mixing, puddle
      redistribution, and momentum-carried pigment that cannot be reproduced
      by symmetric blur. Artist review specifically rejected hollow circular
      "Cheerio" blooms, evacuated centers, isolated overlapping strokes, and
      unusable live lag; those are now explicit failure conditions.

- [x] **Seamless watercolor wiring (not a mode).** Every stroke feeds one wet
      surface with spectral pigment, edge accumulation, and drying. The prior
      diffusion-only visual approval is withdrawn pending review of the restored
      Fluid path.
- [x] Phase 4 behavior scenes are authored (`test/watercolor_engine_test.dart`): wet-into-wet bleed,
      subtractive mixing (blue+yellow→green), edge darkening, bloom/backrun,
      dry-out & stability, containment. Plus the end-to-end
      `watercolor_integration_test.dart` and live `watercolor_live_test.dart`
      (paint → visible wash, transparent where untouched), and the stricter
      `watercolor_phase4_interaction_test.dart` adds a real Fluid second stroke,
      an eight-second blue-then-yellow working-window check, an explicit wet
      yellow crossing that checks the whole crossed stripe (not one pixel) and
      must dissolve the deposited blue ridge into subtractive green,
      wet/damp/dry union, sibling-order/radius/receipt conservation, dry-hold
      finalization, paper-valley granulation, and protected-rewet scenes. The
      current revision remains unconfirmed until the unchecked focused-suite
      item above is run successfully. `rgba_pixels_test.dart` locks the required
      premultiplied Flutter image boundary without changing internal colour math.
- [x] Live on-canvas display: ~30fps ticker and one transparent shared-wash
      composite over paper (no separate active/completed stroke colour layer),
      plus a collapsible `Water` panel (Flow/Wetness/Edge/Dry rate → params
      live). Undo/redo restore exact checkpoints; contact replay is fallback.
- [x] Per-stroke wet-state undo/redo checkpoints restore exact water,
      saturation, velocity, suspended/deposited spectra, and pigment-property
      state without replaying every earlier stroke. After artist testing found
      a repeatable freeze around stroke six regardless of colour, the live
      history was corrected from roughly 13 MB of whole-sheet copies per stroke
      to exact occupied-16-cell-tile checkpoints. Blank paper is no longer
      retained in every undo entry. Compact restore and memory regressions are
      authored; artist confirmation and a safe test run remain pending.
- [ ] Make simulation time invariant to delayed UI callbacks using bounded
      fixed substeps from real elapsed time. The dry hold is now expressed in
      seconds, and the completion-scheduled CPU driver prevents timer backlog,
      but it remains calibrated to nominal 30 Hz; a lag spike must not change
      the physical drying result in the shipping implementation.
- [ ] **Remaining for phase completion:** artist approval of this wet-union
      correction, ordered finite-thickness dry glazing, elapsed-time invariance,
      active-region tiling, and the GPU/Metal backend.
- **Pass/fail:** paint reads as moving wet paint on paper — flows, bleeds, mixes on the
  canvas, darkens at edges, and dries — not as dry markers; blue over wet yellow
  reads green; a clean brush is never contaminated by nearby paint. **The
  earlier diffusion-only visual acceptance is withdrawn. Phase 4 completes
  only after the restored Fluid path passes artist review, ordered glazing and
  elapsed-time behavior are complete, and tiling/GPU requirements are met.**

## Phase 5 — Oil Painting Engine

**CPU reference built (2026-07-13); awaiting artist review.** Implemented to
`specs/oil-engine-spec.md` in `core/oil/` as a separate physical medium beside
the wash (a live `Water | Oil` switch, one shared physical brush). Reuses the
shared pigment/KM contract; no watercolor code was retuned.

- [x] Implement the oil texture model: float32 surface height/medium,
      staggered flux, optional structure field, shared spectral paint fields,
      paint properties, canvas tooth, and lit color output.
- [x] Implement bidirectional brush deposit/pickup and the persistent loaded
      brush reservoir through the shared contact/receipt contract in
      `specs/brush-engine-spec.md`, so picked-up paint changes later marks
      without creating an oil-specific duplicate brush. The oil engine builds
      the **authoritative receipt** from what the canvas actually exchanged
      (spectra included), and the controller applies it to the one shared
      reservoir — dirty-brush color is conserved end-to-end.
- [x] Implement hard yield-gated Herschel-Bulkley rheology with conservative
      staggered flux, nonnegative height, CFL-safe substeps, and no pigment
      diffusion.
- [x] Transport pigment mechanically with brush drag and paint flux. The CPU
      reference uses conservative donor-cell transport for *both* the flux and
      the brush-drag pass (deliberate departure from the spec's §6 BFECC
      preference, documented in the spec and ARCHITECTURE.md); the GPU port is
      the planned home of MacCormack/BFECC drag crispness.
- [x] Add height-field lighting, oil sheen, canvas-tooth drybrush behavior,
      and mandatory finite-thickness KM glazing over the substrate.
- [x] Full live-state undo/checkpoints: per-stroke snapshots of the whole wet
      oil state, coexisting with watercolor checkpoints (null-aligned lists;
      a stroke only checkpoints the medium it touched).
- [x] Implement all validation tests in oil spec section 13: impasto hold,
      slump-and-stop, marble-not-bloom, dirty brush, wet-on-wet mechanical
      blending, broken-color drybrush, and volume conservation
      (`test/oil_engine_test.dart`), plus controller integration
      (`test/oil_integration_test.dart`) and render-to-PNG visual harnesses
      (`test/zz_oil.dart`, `test/zz_oil_live.dart`).
- [x] Live wiring: `Water | Oil` medium switch (switching rinses the reservoir
      into the new family), collapsible Oil panel (Body, Thinner, Load,
      Pickup, Gloss, Light angle), shared ~30fps ticker that no-ops once the
      paint sets (yield gate = zero active faces), lit transparent composite
      drawn above the wash.
- [ ] **Remaining for phase completion:** artist stylus review of the oil
      feel (deposit rates, drag strength, gloss are eye-tuned defaults),
      activity-based tiling, the documented simulation/display resolution
      split for normals, and the GPU/Metal backend.
- **Pass/fail:** all oil spec section 13 tests pass; held relief remains stable,
  colors stop mixing when mechanical motion stops, and total paint volume only
  changes through brush deposit or pickup. **Section 13 automated tests pass
  today; the phase closes after artist review plus tiling/GPU work.**

## Phase 6 — Studios & Navigation

**Not started.**

- [ ] Brush Studio, Paper Studio: full parameter controls + live preview
      + save/duplicate/favorite, built on the existing preset pattern in
      `models/brush.dart` / `models/paper.dart`.
- [ ] Pigment Studio: start as a library view of the starter palette;
      defer the full custom-pigment editor.
- [ ] Main-canvas navigation into Studios — pattern undecided (see
      ARCHITECTURE.md "Open Decisions").

## Phase 7 — Performance & Polish

**Ongoing discipline, not a deferred pass.** Revisit after every phase
above, not just at the end:

- [ ] Profile long painting sessions, not just cold start — watch for
      frame time creeping up during a stroke, not just after it.
- [ ] Quality-setting fallbacks for low-end devices (fewer bristles, lower
      watercolor/oil simulation resolution and iteration counts) once
      Phases 1, 4, and 5 have something to scale down. Fallbacks must preserve
      each spec's required physical behavior and precision constraints.
- [ ] Re-evaluate `CustomPainter`/Impeller shader migration only if
      profiling actually shows the CPU path is the bottleneck — not
      preemptively.
