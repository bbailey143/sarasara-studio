# Sarasara Studio Roadmap

This file says where the app is now and what happens next. Architecture lives
in [`ARCHITECTURE.md`](ARCHITECTURE.md); binding ownership lives in
[`specs/shared-engine-architecture-spec.md`](specs/shared-engine-architecture-spec.md).

## Current position — July 20, 2026

Sarasara already has a strong shared brush, paper texture foundation, spectral
pigment model, CPU watercolor reference, CPU oil reference, and a verified
Windows Vulkan implementation of the major watercolor passes. The live Vulkan
stepping-stone remains too slow at broad wet coverage: the optimized stress
scene averaged 214.08 ms per frame. Six known watercolor behavior checks also
remain failing.

The newly identified architectural risk is real: medium behavior, scheduling,
field storage, composition, and history are bundled inside watercolor- and
oil-shaped classes. Continuing directly to a permanently native-owned
`wc_*` field would harden that shape. The shared-engine recovery below is now
the active work and comes before the old “Step 3B” implementation.

## Gate A — Shared architecture lock

- [x] Establish the shared pipeline and ownership contract.
- [x] Define the versioned JSON material schema.
- [x] Add validated example profiles for watercolor, oil, acrylic, and oil
      pastel, spanning flowing and deformable-solid regimes.
- [x] Add a Dart `MaterialProfile` parser and automated contract tests.
- [x] Make the shared specification higher authority than medium documents.
- [x] Identify current medium-owned orchestration as migration debt.
- [ ] Build the runtime component registry and modifier registry.
- [ ] Load selectable materials through profiles rather than a hard-coded
      `ActiveMedium` branch.

**Pass/fail:** a malformed profile is rejected; every active profile resolves
all required component slots; JSON cannot inject code; adding a profile does
not require another branch in `CanvasController`.

## Gate B — Shared CPU runtime extraction

Move orchestration without changing the proven watercolor or oil mathematics.

- [ ] Add shared `SurfaceSample`, semantic field-set, component, scheduler,
      canvas-layer, and checkpoint contracts.
- [ ] Wrap existing watercolor contact, fluid, pigment, paper, drying, and
      optics passes as registered components.
- [ ] Wrap existing oil exchange, rheology, pigment, setting, and lighting
      passes through the same contracts.
- [ ] Move the one simulation clock and pass ordering out of medium facades.
- [ ] Move tile/dirty-region and undo/redo ownership into shared Canvas State.
- [ ] Reduce `CanvasController` to selection, input routing, and presentation.

**Pass/fail:** the same saved brush and gesture still produce the current
watercolor and oil reference results, but both travel through one scheduler,
field/layer system, history system, pigment system, and surface contract.

## Gate C — Native-owned shared state (replaces old Step 3B)

- [ ] Introduce neutral native runtime boundaries for field sets, deposits,
      steps, composites, checkpoints, and disposal.
- [ ] Keep watercolor fields native across frames and end the outer whole-field
      upload/download on every tick.
- [ ] Route brush deposits and composition through the shared native boundary.
- [ ] Make active tiles and one-tile halos actual native/GPU work.
- [ ] Retain the Dart reference adapters for parity and behavior comparison.
- [ ] Migrate `wc_*` entry points behind the neutral boundary; remove them only
      when replacement parity and lifecycle checks pass.

**Pass/fail:** real Vulkan reports `gpuAvailable() == true` and `gpuDiag == 0`;
the live state stays native; high-coverage stress is stable and meaningfully
faster; active tiles/halos are measured GPU work; lifecycle counts return to
baseline.

## Gate D — Watercolor completion

- [ ] Resolve the six known behavior failures: pickup, wet-union mobility,
      bloom-center retention, and complete drying.
- [ ] Implement ordered finite-thickness dry glazing.
- [ ] Make results invariant to delayed UI callbacks using bounded elapsed-time
      substeps from the shared scheduler.
- [ ] Validate varied paper height/capacity through the shared surface contract.
- [ ] Obtain artist approval for moving water, wet interaction, blooms, retained
      centers, edge behavior, dryback, glazing, and responsive stylus feel.

Watercolor remains a demanding first customer of the shared engine, not the
engine itself.

## Gate E — Oil completion

- [x] CPU reference supports receipt-authoritative pickup/deposit, yield-gated
      viscoplastic flow, mechanical pigment transport, relief, lighting,
      drybrush, conservation checks, and live coexistence with watercolor.
- [ ] Run oil through the shared scheduler, fields, layers, history, surface,
      pigment, and native-runtime boundaries.
- [ ] Add native components for oil rheology and relief composition.
- [ ] Add activity tiling and the simulation/display resolution split.
- [ ] Complete artist stylus review and add scrape/wipe behavior.

Oil must remain physically different—especially zero pigment diffusion—while
sharing the app foundation.

## Gate F — Prove extensibility with a third medium

- [ ] Assemble acrylic from the shared brush, surface, spectral pigment,
      viscoplastic motion, layer, and optics components.
- [ ] Add only the missing polymer-coalescence setting component.
- [ ] Demonstrate modifiers: water, retarder, glazing liquid, and gel produce
      bounded changes without new controller branches.
- [ ] After acrylic, prototype the deformable-solid path with oil pastel to
      prove that negative consistency values do not allocate fluid fields.

**Pass/fail:** most of acrylic is configuration and reuse; its genuinely unique
setting behavior is one registered component available to future polymer media.

## Later product work

- Brush, Paper, Pigment, and Material Studios with preview, duplicate, save,
  favorite, and approachable controls.
- External-texture display after native-owned state is stable.
- Metal backend and target-iPad validation; Android and additional desktop
  backends.
- Long-session profiling and honest quality fallbacks.
- Artist-facing polish and responsive narrow layouts.

## Preserved completed foundations

- Shared physical brush contact, bristle clusters, pressure conservation,
  reservoir receipts, dirty-brush pickup, and rinse behavior.
- Procedural paper height/capacity/tooth and paper rendering.
- Shared 8-band spectral K/S pigment and fixed palette packing.
- Watercolor CPU reference with real fluid, transport, paper exchange, drying,
  edge, pickup, tile history, and diagnostics—subject to the open failures.
- Oil CPU reference with viscoplastic height flow, mechanical pigment movement,
  relief lighting, glazing, and conservation tests.
- Watercolor Vulkan increments 1–11, live toggle, detailed diagnostics, stress
  evidence, and safe pass fusion. The current hybrid is a parity/stability
  stepping-stone, not the shipping architecture.

## Verification discipline

Every milestone report separates:

1. implemented code and passing automated checks;
2. real GPU/backend evidence;
3. artist-visible or stylus approval;
4. known failures and environment blockers.

No parity result substitutes for visual approval. No CPU tile estimate is
reported as real GPU tiling. A blocked route stays labelled blocked rather than
quietly redefining its milestone.
