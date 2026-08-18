# Artist-validation extract

**Sources:** [`ROADMAP.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/ROADMAP.md), [`WATERCOLOR-FLUID-RECOVERY.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/WATERCOLOR-FLUID-RECOVERY.md), and the archived `TestingArtifacts/` notes.
**Classification:** reference behavior and acceptance evidence, not physical constants.

## Behaviors worth carrying forward

- A watercolor wash should remain workable through an ordinary color change.
- Yellow crossing still-wet blue should read as one subtractive green wash, not two intact stamps.
- A clean-water drop should push wet pigment outward without hollowing the center.
- Separate wet marks should not contaminate one another unless material physically meets.
- A fast stroke may fling a bounded amount of material past its end.
- A charcoal-like brittle mark must support friction, detachment, smearing, lifting, and substrate anchoring.

## What the tests do not prove

Automated conservation, divergence, tile-count, or replay checks can tell us whether a reference computation obeys a rule. They do not prove that the result feels like paint on a real device. The archive repeatedly separates code verification from artist/device acceptance; vNext keeps that distinction explicit.

## Registry consequence

Every future canonical property should gain at least one reference behavior and one evidence source. A passing number without a visible acceptance scene is incomplete; a convincing scene without a named physical cause is also incomplete.
