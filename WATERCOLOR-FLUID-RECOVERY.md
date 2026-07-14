# Watercolor Fluid Recovery and Model Handoff

**Decision date:** 2026-07-12  
**Authority:** `specs/watercolor-engine-spec.md` is binding again.  
**Reason:** artist review found the wet-map + diffusion build behaved like
wet markers rather than water carrying pigment.

## 1. Single-owner rule

There is one active watercolor transport model at a time:

- `fluid`: velocity advection → forces → viscosity → divergence → pressure →
  projection → velocity-carried water/pigment.
- `diffusionFallback`: historical wet-map diffusion used only while diagnosing
  or comparing migration output.

They may share pigment optics, paper fields, brush contacts, checkpoints, and
compositing. They may **not** both move pigment in the same frame. This prevents
double spreading and makes regressions attributable to one model.

## 2. Stable interfaces during recovery

- Brush continues emitting `BrushContactSample` and transfer receipts.
- `WatercolorEngine.depositContact` remains the Phase-A entry.
- `WatercolorField` remains the persistent Float32 state container.
- Spectral `K/S`, granulation/staining sums, and composite pixels remain stable.
  The checkpoint schema was expanded with `Kdry/Sdry/PropsDry`; deposited
  properties now use RGBA as `(load, granWt, stainWt, dryClock)`. Any running
  app must be fully restarted after this field-stride change rather than
  hot-reloaded.
- Fluid recovery changes the passes operating on those fields, not brush or
  pigment identity.

## 3. Recovery stages

1. **CPU truth model — implemented:** restore velocity self-advection, height forces,
   viscosity, divergence, Jacobi pressure, projection, water advection, and
   suspended-pigment advection.
2. **Visible acceptance — automated mechanics pass, artist review pending:** directional impulse must move both water and pigment;
   a pooled wash must redistribute coherently; projected velocity must have
   substantially lower divergence; stationary wet pigment must not spread as
   an ever-growing symmetric blur.
   Canvas tilt is available as a diagnostic: a wet wash must visibly travel in
   the chosen downhill direction, and the automated centroid test passes.
   The Water panel also exposes `Show wet areas`; cyan is the exact mobility
   mask `M` used by mixing and lift, not an estimate from pigment or raw water.
   Gravity is applied after pressure projection; the earlier pre-projection
   placement allowed the solver to cancel canvas tilt.
3. **Paper coupling:** capillary saturation, evaporation, settling, lift,
   granulation, and edge darkening operate after fluid transport. Live water
   capacity now comes from the selected paper; granulating pigment settles
   preferentially into its valleys. The CPU correction conservatively favours
   connected paper valleys and retains a
   bounded mechanically caught pigment fraction at contact, preventing a
   backrun from hollowing every stroke into a uniform ring.
4. **Performance:** the 224-cell CPU reference now uses 16-cell activity tiles
   with one-tile halos and skips the dry gaps between long-lived wet strokes
   throughout the ordered simulation. This is one shared field, not per-stroke
   paint, so wet marks can still unite. Metal/GPU must preserve the same pass
   order and fields. A 320-cell whole-sheet CPU review mode was tried and then
   removed after wet two-colour mixing froze the app. The safe 224-cell/8-
   pressure-iteration reference is restored. It can verify mechanics but is
   too coarse for final artist judgment, making the tiled GPU path the next
   required fidelity step rather than future polish.
   A second, independent stroke-count freeze was traced to undo history: every
   watercolor stroke retained about 13 MB of full-sheet wet fields, including
   blank paper. Live undo now stores exact occupied 16×16 tiles instead. This
   preserves wet-state undo and removes the per-stroke full-sheet memory climb;
   artist confirmation and execution of its regression are still pending.
   After that memory correction did not change the artist-observed freeze, the
   main-thread clock was identified as another threshold: a 33 ms periodic
   timer could request the next costly Fluid step immediately once work itself
   exceeded the interval. The live clock is now completion-scheduled with a
   guaranteed UI gap under load. Sub-visible numerical water/saturation and
   velocity tails are also retired so they cannot keep distant halo tiles
   active. `Show performance` reports update milliseconds, active percentage,
   and undo memory for the next handoff.
5. **Fallback removal:** remove `diffusionFallback` only after CPU/GPU parity
   and artist approval.

## 4. Handoff checklist

Any model or agent continuing this work must record:

- active transport mode and the exact pass order;
- parameters changed and the visual/mechanical reason;
- automated tests run and artist-visible checks still outstanding;
- which fields/interfaces changed;
- whether fallback code remains and how overlap is prevented;
- the next smallest unfinished stage.

Status updates belong in `ROADMAP.md`; durable ownership belongs in
`ARCHITECTURE.md`; equations and pass contracts belong in the binding spec.

## 5. Definition of recovered fluid

Recovery is not complete because edges look soft. It is complete when water
has a coherent velocity field, pressure projection reduces divergence,
momentum transports pigment directionally, height differences redistribute a
wash, wet boundaries contain motion, and the artist approves the result as
watercolor rather than wet marker rendering.

Explicit artist-visible failures are: circular hollow "Cheerio" blooms,
complete center evacuation, smooth fronts that ignore paper grain, overlapping
wet strokes behaving as isolated paintings, runaway growth, or interaction lag
that prevents painting. Automated coverage now includes water conservation,
single-touch containment, paper-valley branching, retained bloom-center
pigment, wet-into-wet bleed, and drying-edge formation; visual approval remains
the authority for whether their combined appearance is convincing.

## 6. Previous interaction correction (2026-07-12)

- Capillary transfer and radial drop impulse were reduced after artist review
  reported excessive spread.
- The mechanically caught fraction was increased and passive equilibrium
  re-lift reduced. Clean-drop tests now require at least 50% of the undropped
  center deposit to remain.
- Clean and coloured incoming drops impact-lift only the older deposited layer
  before adding their own pigment. A dedicated test requires an older wet
  stroke to bloom outward under a new coloured drop without a hollow center.
- Connected wet strokes share all fields; a bridge test requires both spectral
  pigments to enter the same intervening cells.
- Stationary dwell deposition was temporarily scaled to `0.001` per 17 ms tick.
  This workaround was removed by the 2026-07-13 receipt-authoritative handoff
  below; it must not be restored.
- Live spectral pigment strength retains the approved `3.0×` calibration after
  the wash read too pale. It is now folded into the fixed receipt-to-grid
  pigment conversion; carrier water is unchanged.
  The integration suite compares two concentrations and requires identical
  deposited water, preventing colour tuning from silently changing fluid flow.
- Pressure composition was corrected after artist review found the previous
  response inverted. Pigment uses `0.16·P^0.65`, carrier water uses
  `0.18·P^2.0`, and bristle-to-wash motion uses `P^1.4`. Tests require a light
  touch to have a higher pigment/water ratio and gentler push than a firm press.
- Splat reads substrate wetness before adding water. Wet overlap reopens older
  pigment and suppresses immediate settling so both strokes share the
  suspended wash; dry overlap does not lift the substrate. Protected spectral
  substrate state now persists in `Kdry/Sdry/PropsDry` and checkpoints, so it
  remains fixed through later simulation frames. Ordered finite-thickness
  dry-glaze compositing remains required; the current composite does not yet
  render true layer order.

## 7. Wet-union correction (2026-07-13)

Artist review found that structural field sharing was not enough: later wet
strokes still retained their own silhouette and read as a layer. The following
changes are now the active handoff state:

- One mobility function `M` is derived per cell from surface water and slower
  paper saturation. Surface water can reach full mobility; saturation alone now
  retains up to `.60` damp mobility with `wetThr=.045`. Splat, dispersion,
  settle/lift, and the visible wet mask use that same answer.
- Following artist review of `Recording Water-2.mp4`, live evaporation now maps
  exponentially to `0.000002..0.0012` per 30 Hz step. The rejected
  `0.0005..0.0035` range could still dry a thin bristle mark alongside the
  moving brush. The expanded lower half now provides long working time while
  retaining an intentional fast-dry upper end. Paper saturation dries at
  `0.22×` the surface rate, keeping a normal wash workable through the
  eight-second colour change captured in
  `TestingArtifacts/watercolor-1.gif`. The three-times-faster tail drain begins
  only after both surface shine and paper mobility are already zero.
- Perfectly wet coloured contact, or enough accepted carrier landing on a
  still-active damp cell, keeps fresh pigment almost entirely suspended and
  reopens 90–94% of the recent active deposit before the new colour is added.
  The old and new spectra therefore occupy one suspended mixture instead of a
  green patch appearing over an intact blue ridge. Protected `Dry` pigment is
  excluded, and the transfer does not remove pigment from the center cell.
  Clean-water impact remains capped at 46% so blooms keep the previously
  approved retained center rather than reverting to hollow rings.
  Staining resistance increases as mobility falls rather than locking a fresh
  wet stain in place.
- All bristle clusters in one sampled brush touch first accumulate into reused
  contact buffers. They see one pre-contact wash, cannot lift/freeze sibling
  bristles, and trigger local union once—not once per cluster. Contact performs
  up to five conservative exchange passes only over cells where new colour
  actually meets active old pigment, plus a three-cell connected margin;
  ongoing
  microscopic dispersion is now symmetric face-pair exchange weighted by
  `sqrt(Ma·Mb)`. It cannot create or erase spectra at a damp/wet boundary.
  Fluid remains the only owner of bulk movement.
- Below `M=.01`, a per-cell clock advances; above `M=.03`, it resets. After a
  continuous `0.15 s` dry hold, all remaining suspended pigment settles and
  the complete deposited cell is copied to `Kdry/Sdry/PropsDry`. `isDry` also
  waits for raw water, saturation, suspended load, and unprotected deposit, so
  a later neighbouring trickle cannot exploit a prematurely stopped cell.
- Live pigment and carrier amounts now come from the adapter's accepted,
  elapsed-time receipt. Pigment uses `P^0.65`, carrier uses `P^2.0`, and brush
  push remains `P^1.4`. A zero receipt cannot paint; an empty brush may still
  move an existing wash. The Water-panel Wetness level changes carrier
  acceptance before that receipt is issued. Receipt spectra/properties are
  authoritative, and the engine applies only fixed `1200×` pigment and `875×`
  carrier unit conversions; footprint radius cannot multiply those totals.
- Multi-bristle pressure is conserved as force shares. The Brush engine divides
  one stylus pressure among sibling clusters and watercolor sums those shares
  once. Bristle count can therefore make the footprint richer without making
  the same hand pressure artificially stronger or weaker.
- `MediumFootprintCluster` now preserves the physical bristle-cluster radius.
  Watercolor no longer rasterizes every cluster as another whole-brush disc,
  reducing stamp silhouettes and unnecessary large-brush work.
- If a new composite is requested while image decoding is busy, one latest
  request is retained. The screen should no longer remain on a stale pre-mix
  frame simply because a decode overlapped the next simulation tick.
- Flutter's `PixelFormat.rgba8888` decoder requires premultiplied bytes. The
  simulation still exposes straight-alpha colour for tests, but disposable
  watercolor image and wet-overlay buffers are now premultiplied immediately
  before decoding. The old straight-byte handoff over-contributed RGB at low
  alpha, making transparent pigment look pale/additive and producing bright
  fringes. Oil uses the same corrected shared boundary.
- Drying now has a visible optical animation tied to the same mobility `M` used
  by physics and `Show wet areas`. As water leaves, spectral scattering rises
  continuously and coverage eases slightly, changing a deep wet wash into a
  lighter matte passage without changing pigment mass or stroke geometry.
- Watercolor dirty-brush pickup now occurs before the outgoing contact lands.
  It reads only the true bristle footprint, removes bounded carrier plus
  suspended/active pigment from the shared field, excludes protected `Dry`,
  and returns exact spectra and properties in the accepted receipt. That
  receipt colours following contacts and enables rinse. Oil's existing pickup
  now drives the same rinse state. Replay offers zero pickup to prevent a
  second removal.

New binding regressions live in
`test/watercolor_phase4_interaction_test.dart`: wet/damp/dry contact ordering,
an active-Fluid second colour joining an existing wet wash, an eight-second
blue-then-yellow working-window check, a wet yellow crossing that checks the
whole crossed stripe, must reopen at least 88% of its deposited blue ridge, and
must composite subtractively green, immediate
two-colour sharing outside the new footprint, all-band/property conservation
across a damp/wet boundary, dry-hold hysteresis/finalization, paper-valley
granulation, and direct plus adjacent-water protection of the dry substrate.
Receipt spectrum authority, cluster-order independence, radius-invariant
totals, visible wet-to-dry optical change, contact-only pickup conservation,
and rinse-state wiring are covered by the integration/brush suites.
`test/watercolor_fluid_test.dart` also contains the new activity-mask check:
two distant wet marks must process far fewer cells than their enclosing
rectangle. It is authored but not yet execution-confirmed.

**Artist-test restart rule:** use a full app restart before judging this
correction. Hot reload can preserve the already-created watercolor engine and
its older mobility/drying parameters, which would reproduce the blue-ridge
failure even though the source has changed.

**Verification state at this handoff:** these new tests were authored and
reviewed, but were not executable in the 2026-07-13 session because the
environment usage gate rejected Flutter's required access to its SDK outside
the workspace; the standalone Dart SDK commands also hung against the existing
SDK/analyzer processes and were stopped. The focused pre-correction suite had
25 passing tests, but that result does **not** verify this correction. The next
model's first safe verification action is:

`flutter test test/rgba_pixels_test.dart test/watercolor_phase4_interaction_test.dart test/watercolor_fluid_test.dart test/watercolor_engine_test.dart test/watercolor_integration_test.dart test/watercolor_live_test.dart test/watercolor_checkpoint_test.dart`

Still open and not to be reported as Phase 4 completion: artist visual approval,
artist confirmation that activity masking plus compact history fixes
many-stroke lag, ordered
finite-thickness dry glazing, elapsed-time-invariant fixed substeps, shipping
GPU tile storage/dispatch, and the Metal/GPU backend.
