# Charcoal calibration notes

Charcoal calibration must preserve the difference between the source tool, detached particles, substrate capture, and later smudging/lifting. A darker mark is not automatically a larger mass deposit.

| Parameter or relationship | Evidence source | Current status | Next action |
| --- | --- | --- | --- |
| Tooth capture versus pressure | Matched gestures on smooth and toothy substrates | Automated height-band relationship verified; artist pending | Compare Plain and Rough marks, then light and firm pressure on Rough. |
| Coarse/fine particle breakup | Material-specific particle evidence | Seed only | Measure or bound the size populations. |
| Dusting versus main deposition | Controlled loading and speed scene | Unmeasured | Track detached particle mass separately. |
| Smudge relocation | Automated source/destination ledger plus artist gesture review | v0.4 artist accepted for smudge motion; substrate scope remains open | Preserve the accepted motion while comparing it on better tooth/absorbency profiles. |
| Lift response | Adhesion/cohesion and artist review | Pending prototype | Test gentle lift, hard lift, and repeated lift. |
| Burnishing rejection | Repeated pressure scene | Pending prototype | Record packing, optical change, and fresh capture reduction. |
| Failure envelope | Artist review | Pending prototype | Include broken deposition, dusting, and over-burnished rejection. |

Each accepted calibration note should record material recipe, substrate, environment, brush/tool, input gesture, measured output, and artist verdict.

### 2026-08-18 — Charcoal v0.3 conservative smudge prototype

- Added **Draw material** and **Smudge existing material** as explicit contact actions.
- Smudge is implemented once in the shared solver; it does not branch on the charcoal profile name.
- Canonical inputs: `TRIB-002` kinetic friction, `DEPO-004` deposited packing, `SUBI-001` roughness, applied pressure, and tangential speed through `MODEL-TRIB-001` / `IM-009`.
- Automated evidence: source-region pigment decreases, destination-region pigment increases, matched firm pressure relocates more than light pressure, `initialPigment` is unchanged, blank-paper smudging creates zero pigment, and total pigment conservation error remains below 1%.
- Diagnostic record: saved reviews now include the contact action, named interaction, relocated amount, settings, image, artist rating, and decision.
- Validation status: **artist review required**. The equations and ledger do not establish whether the gesture feels dusty, soft, draggy, greasy, too weak, too strong, or digitally blurred.

### 2026-08-18 — CH-LAB-1787103913509 artist review and v0.4 response

- Artist verdict on v0.3: **Good / Recalibrate**.
- Recognizable part: the contact felt like it was pushing dense particles.
- Failed part: displaced material stopped immediately with the gesture, making it feel putty-like rather than like a loose ridge with residual movement.
- Model diagnosis: v0.3 transferred pigment directly from one settled cell to another. It had no transient loose-particle state in which displaced material could carry and lose momentum.
- v0.4 response: the shared solver now uses `MODEL-TRIB-001`, `MODEL-PART-001`, and `IM-009` to lift a bounded amount of settled pigment into a loose surface state, give it gesture-direction velocity, dissipate that velocity through friction and substrate roughness, and settle it back into the deposited state.
- Architecture status: this is a shared surface-particle relationship driven by canonical packing, friction, roughness, pressure, and speed—not a charcoal-only effect or named-medium branch.
- Automated evidence: a loose ridge is created, its center continues forward after contact ends, loose mass decreases as deposited mass increases, blank contact creates nothing, and total pigment error remains below 1%.
- Validation status: **artist review required** for v0.4. The automated result establishes motion and conservation, not whether the amount, timing, ridge shape, or feel is believable.

### 2026-08-18 — CH-LAB-1787105475421 limited artist acceptance

- Artist verdict on v0.4: **Good / Accept for the smudge-motion scope**.
- Accepted relationship: displaced pigment behaves like a loose particle ridge with brief residual motion and settling rather than a putty slab.
- Saved state: pressure `0.77`, speed `1.00`, pigment area `17.13%`, deposited pigment `1580.78`, cumulative relocated pigment `2521.69`, conservation error `0.00045%`.
- Explicit limit: the artist withheld final charcoal approval because the single placeholder substrate was poor.
- Next evidence: recover the archived paper definitions, keep them as separate substrate profiles, compare matched gestures on smooth and toothy sheets, and require artist approval before any paper becomes canonical.

### 2026-08-18 — Archived paper profiles integrated

- Archive finding: the preserved branch contains Plain White, Hot Press, Cold Press, and Rough presets. It contains no separately named charcoal/pastel paper; Rough is only the strongest tooth candidate.
- Separation correction: intrinsic roughness, porosity/capacity, permeability, texture seed/scale, and paper color now belong to an independently selected substrate profile rather than the charcoal or watercolor material profile.
- Automated evidence: Plain is flat; Rough has a meaningful peak/valley range; light charcoal deposits more per cell in the raised Rough band than the valley band; firm pressure increases valley-band deposit; matched Rough watercolor contact absorbs more carrier than Hot Press; conservation checks still pass.
- Artist status: **pending**. The equations cannot decide whether the procedural Rough sheet looks natural, feels appropriate for charcoal/pastel, or preserves the accepted smudge character.

### 2026-08-18 — CH-LAB-1787107111788 Plain White smudge review

- Artist verdict: **Convincing / Accept for this smudge/substrate scope**.
- Conditions: charcoal v0.4, Plain White, smudge, pressure `0.96`, speed `1.00`, visibility `1.00`.
- Artist response: the interaction was notably fun and convincing; the independent substrate refactor did not destroy the accepted particle motion on the flat control sheet.
- Desired improvement: occasional believable small particle flicks.
- Model placement: particle flicks belong to future CH-P-03 / CH-P-04 fracture and dusting with detached coarse/fine populations and conservation. Do not add a visual random-speck shortcut.
- Scope limit: this high-pressure Plain White smudge does not validate tooth capture or pressure-driven valley reach. Rough paper draw reviews remain required.
