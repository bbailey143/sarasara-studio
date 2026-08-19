# Watercolor calibration notes

Calibration is subordinate to the reference behaviors and artist review. Do not tune a number merely because it improves a single screenshot.

| Parameter or relationship | Evidence source | Current status | Next action |
| --- | --- | --- | --- |
| Carrier/pigment transfer ratio | Reference observation + controlled contact | Unmeasured | Establish a small-load mass ledger. |
| Damp-paper spread | Paper-specific observation | Unmeasured | Compare at least two substrate pore/absorbency profiles. |
| Settling contrast | Particle size/density evidence | Seed only | Record matched-population settling runs. |
| Drying-edge timing | Controlled temperature/humidity scene | Seed only | Record time series; do not make one universal dry time. |
| Wet crossing and subtractive mixture | Artist review | Pending prototype | Judge color and boundary disappearance together. |
| Bloom center retention | Artist review + mass conservation | Pending prototype | Track total mass and center share separately. |
| Failure envelope | Artist review | Pending prototype | Include puddling, cauliflower blooms, overworking, and drybrush. |
| Diagnostic drying cue | Artist review 2026-08-18 | Rejected | Drying became dark and opaque like acrylic; replace with lighter transparent drying and restrained rim concentration. |

Every accepted calibration note should record material recipe, substrate, environment, brush/load, input gesture, measured output, and artist verdict.

## Artist calibration history

### 2026-08-18 — Watercolor diagnostic pass

- Artist rating: **Unconvincing**
- Decision: **Recalibrate**
- Accepted behavior to preserve: pressure response.
- Rejected behavior: drying darkened and became opaque, reading as acrylic rather than watercolor.
- Insufficient behavior: pigment movement toward the rim was too slight to perceive.
- Required correction: lighten the wash during drying, retain transparency, strengthen wet outward pigment transport, and keep rim concentration modest.

### 2026-08-18 — Shared-solver visibility adjustment

- Artist finding: the watercolor was too light to observe transport reliably.
- Adjustment: increase diagnostic pigment visibility while retaining a transparent ceiling.
- Physics impact: none; carrier and pigment masses, transport, absorption, settling, and evaporation are unchanged.
- Validation status: artist review required to confirm that movement is now readable without making the wash feel opaque.

### 2026-08-18 — Transport separation

- Artist finding: even at maximum diagnostic visibility, post-stroke pigment movement was too slight and visually flat.
- Architectural correction: separate pigment load, brush water, and initial paper dampness.
- Transport correction: pigment is carried conservatively by water flux; a small separate dispersion term remains explicit.
- New test: pigment load at zero applies clean water without inventing pigment.
- Validation status: artist review required for wet-on-dry, wet-on-damp, and clean-water disturbance.

### 2026-08-18 — Separated-control artist review

- Artist rating: **Unconvincing**
- Decision: **Recalibrate**
- Observed at low pigment and brush-water settings on dry paper: the dry mark was invisible even at maximum diagnostic visibility.
- Wet-on-damp response: still insufficiently mobile.
- Clean-water disturbance: no convincing displacement or bloom.
- Required correction: substantially increase and validate carrier-flow magnitude and pigment coupling before asking for another realism approval.

### 2026-08-18 — Watercolor diagnostic v0.3 physics pass

- Material profile: `material.watercolor.diagnostic.v0.3`.
- Carrier correction: increase the stand-in transport coefficient and neighbor-to-neighbor water exchange so damp-paper spreading becomes observable during a short review.
- Pigment correction: couple mobile pigment more tightly to water flux and reduce independent pigment diffusion.
- Settling correction: apply settling over elapsed time instead of removing a large fraction every frame; retain a smaller water-gradient contribution for drying-edge formation.
- Reactivation correction: sufficiently wet clean-water contact releases a conservative fraction of deposited pigment back into the mobile state using `REAC-001` through `REAC-004` and `MODEL-REAC-001`.
- Added observation: the lab reports pigment-covered area separately from wet area, so carrier movement cannot be mistaken for pigment movement.
- Automated evidence: water expands the pigment region, clean water adds no pigment, reactivation increases mobile pigment, and pigment conservation remains within one percent.
- Validation status: **artist review required**. These checks show that the mechanisms operate; they do not establish that the speed, amount, edge character, or feel is convincing.

### 2026-08-18 — Watercolor diagnostic v0.3 artist review (`WC-LAB-1787095264270`)

- Artist rating: **Recognizable**.
- Artist observation: “Lots of really good fluid action.”
- Accepted behavior to preserve: the carrier movement is recognizable enough for this diagnostic stage.
- Remaining concern: pigment behavior is now the weak point.
- Review conditions: pigment load `1.00`, brush water `1.00`, paper dampness `0.25`, pressure `0.55`, speed `1.00`, diagnostic visibility `9.80`.
- Recorded result: pigment covered `45.84%` of the grid after drying; pigment conservation error was below `0.001%`.
- Decision field in the exported review: **Pending**.
- Gate interpretation: provisional artist approval for fluid action only. Do not claim final watercolor acceptance, and do not substantially retune carrier movement while addressing pigment unless a later artist comparison rejects it.
- Next focused question: identify whether the pigment problem is primarily color/visibility, suspended movement, edge accumulation, settling pattern, or dried appearance before changing its physical parameters.

### 2026-08-18 — Watercolor diagnostic v0.4 pigment-load correction

- Artist diagnosis: the wash is too pale because the brush deposits far too little pigment.
- Correction: increase actual pigment available during wet-suspension contact by approximately four times at the reviewed pressure; do not increase the diagnostic visibility multiplier to disguise the shortage.
- Preserved behavior: carrier delivery, transport, paper uptake, evaporation, settling timing, and reactivation parameters are unchanged from v0.3.
- Architectural basis: this is the `applicator_load` input to the shared contact/transfer model, not a watercolor-only visual effect. Dry-powder delivery retains its prior scale.
- Automated guardrail: changing pigment load changes pigment mass proportionally while matched gestures deliver identical carrier mass.
- Validation status: **artist review required** for believable concentration, transparency, motion, and dried appearance. The v0.3 fluid-action approval remains provisional and should be rechecked for accidental visual regression.

### 2026-08-18 — Dry-brush review and v0.5 contact correction (`WC-LAB-1787097983799`)

- Artist rating: **Recognizable**; decision: **Recalibrate**.
- Review conditions: pigment load `1.00`, brush water `0.00`, paper dampness `0.00`, pressure `0.55`, speed `1.00`, diagnostic visibility `12.00`.
- Rejected behavior: those settings failed to produce a convincing dry-brush mark with tooth-catching and broken deposition.
- Root cause: the contact calculation added hidden carrier at zero brush water and treated all watercolor pigment as mobile suspension.
- Correction: zero water now means zero delivered carrier. Brush moisture and existing paper moisture continuously blend tooth-controlled direct deposition into mobile wet transfer.
- Pressure consequence: greater pressure progressively reaches more paper valleys; low and moderate pressure leave more broken contact.
- Automated guardrails: dry contact adds no carrier, deposits pigment directly, covers less paper than a wet wash, gains mobility continuously with moisture, and deposits more material under greater pressure.
- Validation status: **artist review required** across at least dry `0.00`, damp `0.35`, and wet `1.00` brush-water settings. Preserve the previously approved full-wet fluid action.
