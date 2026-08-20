# ADR-0002: Oil as the third-material vocabulary test

**Status:** Accepted — vocabulary passes; one derived property and one shared state are required
**Date:** 2026-08-19
**Supersedes nothing. Extends:** [ADR-0001](ADR-0001-FOUNDATION-FIRST.md)

## Why this test exists

Watercolor and charcoal are deliberate opposites, but they are opposites in a way
that flatters the architecture. One flows and the other does not move at all, so
they never compete for the same bulk-motion machinery. They overlap almost
entirely at contact, transfer, and bookkeeping — the part nobody doubted was
shareable.

Oil sits between them. It neither flows freely nor sits still: it holds its shape
until pushed past a threshold, then moves as a body. It is therefore the first
material that can genuinely falsify the shared foundation.

**The falsification rule adopted here:** if a third material requires a new
*property family*, the canonical vocabulary has failed. New *values* are the
entire point. New *code*, added as a shared capability, is acceptable. A new
family is not.

## Method

Every behavior required of oil by the archived
`specs/oil-engine-spec.md` (preserved on the `feat/native-core-increment-12`
checkpoint) was mapped against `docs/canonical/PROPERTY_REGISTRY.yaml` v0.1.

## Result — the vocabulary holds

| Oil behavior | Canonical property | Verdict |
| --- | --- | --- |
| Holds shape until pushed | `RHEO-002` yield_stress | covered |
| Thick or thin body | `RHEO-001` dynamic_viscosity | covered |
| Loosens under the brush | `RHEO-003` shear_rate_response | covered |
| Holds a peak or ridge | `RHEO-004` elastic_modulus | covered |
| Pigment travels with the paste and never spreads alone | `TRAN-001` = 0, `TRAN-004` advection | covered |
| Thins with solvent, not water | `COMP-004` volatile_mass_fraction | covered |
| Dries by oxidation over days | `EVOL-002` cure_fraction | covered |
| Sinks slightly as it cures | `EVOL-004` shrinkage_strain | covered |
| Opaque covering | `OPT-002` spectral_scattering | covered |
| Gloss | `OPT-003` refractive_index | covered |
| Picks up the wet layer beneath | `DEPO-003` detachment_threshold | covered |
| Scrapes and wipes back | `TRIB-004` abrasion_resistance | covered |
| **Stands up off the sheet (relief)** | **none** | **gap** |

**No new property family is required.** Twelve of thirteen behaviors resolve to
existing canonical IDs. The vocabulary survives its first real challenge.

## The one gap, and why it is not a failure

Nothing in the registry says how tall deposited material stands. But height is
not an intrinsic property of a material — it is a state of the canvas, and it is
already implied by quantities the ledger tracks:

```text
relief height = deposited mass ÷ (DEPO-004 packing fraction × PART-002 particle density × area)
```

The registry explicitly permits this: `allowed_representations` includes
`derived`, and the rules require only that a derived value "name its inputs
instead of posing as an intrinsic material fact."

**Action:** add `DEPO-005 deposited_relief_height` as a `derived`,
`interaction_derived` property naming those three inputs. This is a bookkeeping
addition inside an existing family, not a new family.

## The real cost: one new shared state on the bench

The vocabulary passes. The *bench* does not, and this is the useful finding.

The shared solver currently carries six material states per cell: mobile carrier,
mobile pigment, deposited pigment, loose particles with velocity, coarse
fragments, and fine dust. Oil is none of these. It needs a **deposited layer that
has thickness and can itself move once pushed past its yield stress**.

That state must be added. The important question is whether it is oil-specific.
It is not:

- **Charcoal `CH-07` burnishing** — currently `not_run`, and unbuildable today,
  because it requires a deposited layer whose packing changes under repeated
  compression. That is the same state.
- **Watercolor finite-thickness glazing** — a known gap since the archived
  build. Ordered layers of real thickness. Same state.
- **Watercolor `WC-04` drying edge** — currently `partial_not_isolated`; a rim is
  a thickness variation, not a colour variation.

So oil did not ask for a private feature. It exposed a concept the bench was
always missing, which three behaviors on two other materials were already
blocked on.

**Action:** add a shared deposited-layer state with thickness and yield-gated
motion, available to every recipe, selected by property values rather than by
material name. A recipe whose `RHEO-002` is effectively unbounded simply never
moves that layer — which is exactly what charcoal and dry watercolor should do.

## Consequences

- The falsification test passes. The shared foundation is not disproven, and it
  has now been challenged by something that could have broken it.
- `DEPO-005` is added to the property registry as a derived property.
- The bench gains one shared state, not an oil path.
- Three previously blocked behaviors on watercolor and charcoal become
  reachable as a side effect.
- Charcoal's four-part artist review is deferred, not cancelled. Its current
  marks stand.
- This is a paper result. It is code evidence of nothing until the state is
  implemented, and artist evidence of nothing until oil is drawn with and judged.
