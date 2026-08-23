# Sarasara Studio Architecture

## The permanent shape of the app

Sarasara Studio has one shared painting engine. Watercolor, oil, acrylic,
pastel, ink, and future materials are descriptions assembled from reusable
physical capabilities—not separate apps and not separate copies of the engine.

```text
Surface → Brush → Contact/Exchange → Material Response → Motion
        → Pigment → Setting/Drying → Optics → Canvas Layer
```

The binding contract is
[`specs/shared-engine-architecture-spec.md`](specs/shared-engine-architecture-spec.md).
Machine-readable material descriptions obey
[`specs/material-profile.schema.json`](specs/material-profile.schema.json), and
working examples live in [`assets/materials/`](assets/materials/).

## Document authority

When guidance conflicts, use this order:

1. `specs/shared-engine-architecture-spec.md` — ownership and shared pipeline.
2. `specs/brush-engine-spec.md` — the shared physical tool and reservoir.
3. `specs/watercolor-engine-spec.md` and `specs/oil-engine-spec.md` — required
   behavior of those material recipes.
4. This file — current code map and architectural decisions.
5. `ROADMAP.md` — sequence and status.
6. Increment handoffs/evidence — temporary implementation facts only.

A lower document cannot redefine a higher one. Completed work that conflicts
with the shared contract becomes migration input, not permanent architecture.

## Shared ownership

| Domain | Owns | Must not own |
|---|---|---|
| Surface | paper/canvas height, tooth, capacity, fiber/weave samples | watercolor absorption or oil yield rules |
| Brush | stylus input, physical tool, bristles, footprint, reservoir opportunity | bloom, ridge, drying, or pigment transport |
| Materials | JSON profiles, component selection, compatible modifiers | executable code inside JSON |
| Physics runtime | field registry, clock, ordered passes, active tiles/halos, conservation, GPU dispatch | a preference for one medium |
| Pigment | palette, spectral K/S, extensive properties | brush geometry or a medium clock |
| Canvas State | persistent layers/fields, ordered composition, checkpoints, undo/redo | medium-specific physical laws |
| UI/controller | artist controls, input routing, presentation | simulation pass logic or history formats |

Material profiles use one signed `consistency` scale:

- `-10` = softest deformable solid; `-1` = hardest deformable solid.
- `+1` = thinnest flowing material; `+10` = stiffest flowing material.
- `0` is reserved and invalid.

This gives artists one understandable “body” control while preserving the
important distinction between something that flows and something that smears
as a solid. Water solubility, solvent affinity, thinning agents, painting
media, working time, and reusable component choices are separate properties.

## Current code truth — July 20, 2026

The architecture has **not** been lost, but it is only partly realized.

Already healthy and reusable:

- `lib/core/brush/` contains the shared contact, dynamics, reservoir, and
  medium-adapter boundary.
- `lib/core/paper/` contains shared surface data and procedural texture.
- `lib/core/pigment/` contains shared spectral color and palette foundations.
- `lib/core/materials/material_profile.dart` validates the new shared material
  descriptions.

Architecture debt to extract safely:

- `WatercolorSimulation` currently bundles flow, pigment movement, paper
  response, drying, and some composition in one large class.
- `WatercolorField` and `OilField` each own their own storage and snapshot
  shapes instead of using a shared field/layer/history system.
- `WatercolorEngine` and `OilEngine` each orchestrate their own material
  pipeline.
- `CanvasController` coordinates separate deposit, tick, composite, and history
  paths for watercolor and oil.
- The native C ABI and field are named and packed around `wc_*`; they are a
  proven watercolor GPU prototype, not the permanent shared runtime boundary.

Those facts are honest migration debt, not permission to discard working
behavior. Existing Dart simulations remain the behavior oracles while their
responsibilities move behind shared interfaces.

## Runtime and GPU decision

Expensive physical simulation runs in a portable native core through Dart FFI:
Metal on Apple platforms and Vulkan/Direct3D elsewhere. Flutter remains the UI
shell. A Flutter fragment shader may perform final color composition, but it is
not the multi-pass physics engine.

The permanent native runtime owns live fields across frames, deposits, ordered
component execution, active tiles and halos, composition, and checkpoints.
Real GPU availability must be reported honestly: on the Windows Vulkan route,
`gpuAvailable() == true` and `gpuDiag == 0` are required. Parity against Dart
proves numerical fidelity; it does not prove useful frame time or visual feel.

## State and presentation

`CanvasController` is currently the app's reactive coordinator. High-frequency
painting updates repaint the canvas without rebuilding the whole interface;
low-frequency tool and material choices rebuild the relevant controls. As the
shared runtime is extracted, the controller should shrink to input routing,
selection, and presentation coordination.

The canvas remains artist-forward. Diagnostics are available but tucked away.
Brush, Paper, Pigment, and Material Studios will edit reusable definitions and
preview them without placing engineering controls in the main painting view.

## Non-negotiable rules

- One physical brush definition works with every compatible material.
- JSON selects registered behavior; it never carries executable code.
- New media reuse existing components first and add a new reusable component
  only for genuinely new physics.
- Shared modules never import watercolor or oil modules.
- Oil pigment never diffuses merely because watercolor pigment does.
- Paper appearance stays separate from transparent paint layers.
- The same accepted transfer receipt updates brush and canvas, preserving mass.
- Simulation time comes from one elapsed-time scheduler, not UI callback speed.
- History and composition belong to shared Canvas State.
- Active tiles and halos must become real native/GPU work before that milestone
  is claimed complete.
- Current artist-visible behavior is preserved during extraction with tests and
  compatibility adapters; no all-at-once rewrite.

## Active documentation

- [`README.md`](README.md) — project entry point.
- [`ROADMAP.md`](ROADMAP.md) — current status and ordered next work.
- [`specs/shared-engine-architecture-spec.md`](specs/shared-engine-architecture-spec.md) — binding shared system.
- [`specs/material-profile.schema.json`](specs/material-profile.schema.json) — material file contract.
- [`specs/brush-engine-spec.md`](specs/brush-engine-spec.md) — shared brush behavior.
- [`specs/watercolor-engine-spec.md`](specs/watercolor-engine-spec.md) — watercolor behavior recipe.
- [`specs/oil-engine-spec.md`](specs/oil-engine-spec.md) — oil behavior recipe.
- [`INCREMENT-12-STABILIZATION-HANDOFF.md`](INCREMENT-12-STABILIZATION-HANDOFF.md) — temporary native-route handoff.
- [`INCREMENT-12-STRESS-EVIDENCE.md`](INCREMENT-12-STRESS-EVIDENCE.md) — measured evidence for that route.

Superseded one-increment handoffs are deleted after their durable facts are
absorbed into the active roadmap or evidence files.
