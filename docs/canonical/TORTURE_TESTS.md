# Watercolor + charcoal torture tests v0.1

These are the two deliberately different materials used to challenge the canonical vocabulary. Watercolor tests mobile carrier, wetting, porous paper, evaporation, suspended particles, and optical mixing. Charcoal tests brittle solids, friction, fracture, particle detachment, anchoring, smearing, lifting, and compression.

The machine-readable cases live in [`TORTURE_TESTS.yaml`](TORTURE_TESTS.yaml). They are a contract for the diagnostic laboratory, not a claim that the current prototype or a future painting engine already passes them.

## Three validation gates

### Gate 1 — Schema torture test

**PASS for v0.1.** Every required phenomenon maps to existing canonical IDs. Neither case needs a private `specialWatercolorThing`, `charcoalMode`, or equivalent medium-only family. The full mapping is in [`TORTURE_TESTS.yaml`](TORTURE_TESTS.yaml).

### Gate 2 — Behavioral prototype test

**PARTIAL; GATE REMAINS OPEN.** The minimal shared solver now verifies several relationships automatically: separate watercolor carrier and pigment state, conservative pigment transport, porous uptake, moisture-dependent contact, clean-water reactivation, dry charcoal deposition without carrier, and conservative smudge relocation of existing deposited pigment. It does not yet isolate every required phenomenon. In particular, spectral wet crossings, clean-water bloom geometry, multiple paper recipes, charcoal tooth/pressure progression, fracture, dust, lifting, burnishing, and both media's failure ranges remain open. The test-by-test evidence is recorded in [`docs/validation/`](../validation/).

### Gate 3 — Artist reality test

**MANDATORY and PARTIAL; GATE REMAINS OPEN.** Watercolor diagnostic v0.6 received a **Good / Accept for this scope** artist decision for the shared substrate → carrier → pigment → applicator relationship. Charcoal v0.4 smudge motion received **Good / Accept for that limited scope** in `CH-LAB-1787105475421`, with final approval explicitly withheld pending better substrate review. Neither decision approves complete medium realism, multiple papers, failure ranges, or the remaining numbered scenes. A practicing artist must still recognize each intended medium without prompting across the required pressure, speed, loading, run-out, layering, substrate, irregularity, expressive, and failure behaviors. “Indistinguishable” is not required for v0.1.

The validation records live in:

- [`docs/validation/watercolor/`](../validation/watercolor/)
- [`docs/validation/charcoal/`](../validation/charcoal/)

No medium graduates from experimental to canonical without passing both the physics gate and the artist gate.

## How to read the statuses

The machine-readable case mappings use these evidence labels:

| Status | Meaning |
| --- | --- |
| `schema_covered` | Existing canonical properties express the phenomenon directly enough to begin a reference test. |
| `calibration_required` | The concepts are present, but ranges, equations, or pairwise values still need evidence. |
| `artist_review_required` | The observable behavior must be judged visually and interactively; code checks alone are insufficient. |

The behavioral test tables use these result labels:

| Result | Meaning |
| --- | --- |
| `automated_relationship_verified` | A repeatable code check directly verifies the named relationship, but artist feel may still be open. |
| `artist_accepted_limited_scope` | A saved artist review accepts a precisely written subset, not the entire medium. |
| `partial_not_isolated` | A related mechanism or observation exists, but the full test has not been separated from confounding variables. |
| `not_run` | The lab lacks the required scene, measurement, or canonical artist record. |

## Watercolor acceptance scenes

1. Place a wet blue wash on a porous sheet and confirm carrier, suspended pigment, and paper state remain distinguishable.
2. Cross still-wet blue with yellow. The overlap should become one subtractive mixture, not two opaque stamps.
3. Add a clean-water drop to a damp mark. It should push pigment outward without erasing the center.
4. Let the wash dry. Edge accumulation, settling, and optical dryback should be visible without changing the total pigment into a new color source.
5. Rewet the settled area. Only the material allowed by the reactivation conditions should move.

## Charcoal acceptance scenes

1. Draw lightly on smooth and toothy substrates. Particle capture and breakup should differ because the substrates differ.
2. Increase pressure until detachment and compression change. A heavier mark must not simply scale a pre-painted texture stamp.
3. Drag across an existing mark. Smearing should transport particles through contact and friction.
4. Repeat pressure over the same area. Burnishing should change packing and appearance without inventing extra pigment.
5. Lift or erase part of a mark. Removal should be governed by contact, adhesion, cohesion, and particle population.

## Failure rule

If either material requires a new medium-specific property to pass, stop and repair the family placement or add a genuinely general property with a definition, unit/representation, dependencies, evidence source, and reference behavior. Do not patch the failure with a named-medium flag.
