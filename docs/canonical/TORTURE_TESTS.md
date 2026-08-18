# Watercolor + charcoal torture tests v0.1

These are the two deliberately different materials used to challenge the canonical vocabulary. Watercolor tests mobile carrier, wetting, porous paper, evaporation, suspended particles, and optical mixing. Charcoal tests brittle solids, friction, fracture, particle detachment, anchoring, smearing, lifting, and compression.

The machine-readable cases live in [`TORTURE_TESTS.yaml`](TORTURE_TESTS.yaml). They are a contract for the future reference laboratory, not a claim that the painting engine already passes them.

## Three validation gates

### Gate 1 — Schema torture test

**PASS for v0.1.** Every required phenomenon maps to existing canonical IDs. Neither case needs a private `specialWatercolorThing`, `charcoalMode`, or equivalent medium-only family. The full mapping is in [`TORTURE_TESTS.yaml`](TORTURE_TESTS.yaml).

### Gate 2 — Behavioral prototype test

**PENDING.** Once the minimal diagnostic solver exists, it must reproduce observable phenomena such as damp-paper spread, pigment/carrier separation, drying edges, tooth capture, valley skipping, pressure-dependent deposition, and particle relocation. These tests belong in the dedicated [`docs/validation/`](../validation/) lab plans; they are not product artwork tests.

### Gate 3 — Artist reality test

**MANDATORY and PENDING.** A practicing artist must recognize the intended medium without being told what is being simulated. The review must cover pressure, speed, loading, run-out, layering, substrate response, irregularity, continuous wetness or brittleness, expressive gestures, and believable failure. “Indistinguishable” is not required for v0.1; “recognizable without prompting” is the minimum.

The validation records live in:

- [`docs/validation/watercolor/`](../validation/watercolor/)
- [`docs/validation/charcoal/`](../validation/charcoal/)

No medium graduates from experimental to canonical without passing both the physics gate and the artist gate.

## How to read the statuses

| Status | Meaning |
| --- | --- |
| `schema_covered` | Existing canonical properties express the phenomenon directly enough to begin a reference test. |
| `calibration_required` | The concepts are present, but ranges, equations, or pairwise values still need evidence. |
| `artist_review_required` | The observable behavior must be judged visually and interactively; code checks alone are insufficient. |

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
