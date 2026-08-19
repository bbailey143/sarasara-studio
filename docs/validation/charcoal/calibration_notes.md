# Charcoal calibration notes

Charcoal calibration must preserve the difference between the source tool, detached particles, substrate capture, and later smudging/lifting. A darker mark is not automatically a larger mass deposit.

| Parameter or relationship | Evidence source | Current status | Next action |
| --- | --- | --- | --- |
| Tooth capture versus pressure | Matched gestures on smooth and toothy substrates | Unmeasured | Record deposited mass by surface height band. |
| Coarse/fine particle breakup | Material-specific particle evidence | Seed only | Measure or bound the size populations. |
| Dusting versus main deposition | Controlled loading and speed scene | Unmeasured | Track detached particle mass separately. |
| Smudge relocation | Automated source/destination ledger plus artist gesture review | Automated relationship verified; artist pending | Test whether the moved trail feels dusty and material-driven rather than freshly painted or digitally blurred. |
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
