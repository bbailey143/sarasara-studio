# Charcoal calibration notes

Charcoal calibration must preserve the difference between the source tool, detached particles, substrate capture, and later smudging/lifting. A darker mark is not automatically a larger mass deposit.

| Parameter or relationship | Evidence source | Current status | Next action |
| --- | --- | --- | --- |
| Tooth capture versus pressure | Matched gestures on smooth and toothy substrates | Artist accepted for Pastel Paper v0.2 diagnostic scope | Preserve the relationship during later changes. |
| Coarse/fine particle breakup | Shared fracture ledger plus artist comparison | Automated relationship verified; artist pending | Judge whether v0.5 crumbs and dust resemble brittle charcoal breakup. |
| Dusting versus main deposition | Controlled loading, pressure, and speed scenes | Mass bounded and automated; artist pending | Judge travel, amount, irregularity, and settling in the lab. |
| Smudge relocation | Automated source/destination ledger plus artist gesture review | v0.4 artist accepted for smudge motion on Plain White and Rough Watercolor Paper | Preserve the accepted motion on sample-guided Pastel Paper. |
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

### 2026-08-18 — Rough paper appeared zoomed-in; v0.2 scale correction

- Direct artist feedback: the paper ridges and valleys were much too large compared with the previous application and were difficult to judge.
- Limited pass: charcoal smudged up over the valleys as expected, so the contact relationship passed in principle.
- Cause: the JavaScript port multiplied frequency by archived `noiseScale`; the archived generator divided coordinates by it. Rough therefore became the broadest terrain instead of the finer-sampled tooth.
- Correction: substrate profiles advance to v0.2 and use inverse grain scale with a higher diagnostic sampling density. Tooth amplitude and all charcoal material/smudge parameters remain unchanged.
- Automated guard: Rough must show at least 25 midline tooth crossings over the 300-cell field and more than twice the Hot Press crossing count; all height-band, uptake, smudge, and conservation checks must still pass.
- Artist status: **re-review required** for corrected paper scale and naturalness.

### 2026-08-18 — CH-LAB-1787107972495 paper/material verdict split

- Artist verdict on charcoal v0.4 smudging: **Good / Accept for the existing smudge-motion scope**.
- Conditions: Rough v0.2, smudge, pressure `1.00`, speed `1.00`, pigment area `26.00%`, deposited pigment `2992.55`, relocated pigment `5991.20`, conservation error `0.00032%`.
- Separate paper verdict: **reject Rough as the charcoal evaluation sheet**. Its relief remained ugly and too dramatic; it originated as a watercolor preset and is better retained for that purpose.
- Architecture decision: do not tune the watercolor Rough profile until it serves charcoal. Add an independent experimental **Fine-Tooth Drawing Paper** substrate with smaller, shallower, more frequent grain and leave the shared material/contact system unchanged.
- Automated evidence on Fine-Tooth: its peak-to-valley range is lower than Rough Watercolor Paper; its grain changes direction more frequently; light contact favors raised fibers; firmer contact increases deposition in valleys; smudge conservation and settling checks still pass.
- Artist status: **required**. Those checks establish the intended relationships, not whether the sheet looks like drawing paper or makes charcoal feel right.

### 2026-08-18 — Artist-supplied Pastel White and Light Cream references

- The artist supplied two 5100 × 5100 pastel-paper samples after the generic Fine-Tooth v0.1 checkpoint.
- Visual reading: both show quiet, dense, irregular fibers with shallow apparent relief and none of the large rounded terrain seen in Rough Watercolor Paper.
- Measured appearance: Pastel White sampled mean RGB `238.10 / 237.95 / 237.01`, luminance spread `8.81`; Pastel Light Cream sampled mean RGB `238.08 / 234.95 / 223.03`, luminance spread `10.30`.
- Implementation response: replace the unreviewed generic Fine-Tooth selector with sibling **Pastel Paper — White** and **Pastel Paper — Light Cream** profiles. Both share identical physical state and deterministic fiber tooth. Only base color and subtle visible-fiber contrast differ.
- Architecture status: the samples calibrate an independent substrate pattern; they do not create charcoal-only contact equations. A photograph supplies appearance evidence, not measured height or friction.
- Automated evidence: pastel relief is much shallower than Rough Watercolor Paper, grain is more frequent, both colors have identical tooth, light contact favors raised fibers, firm contact reaches more shallow gaps, and smudge/conservation checks still pass.
- Artist status: **required** for visible scale, contact feel, pressure progression, and whether either ground supports believable charcoal gesture.

### 2026-08-18 — CH-LAB-1787110275815 Pastel White acceptance

- Artist verdict: **Convincing / Accept** for Pastel White appearance and low-pressure smudging.
- Conditions: charcoal v0.4, Pastel Paper — White v0.2, smudge, pressure `0.26`, speed `1.00`, visibility `1.00`.
- Saved state: pigment area `14.83%`, deposited pigment `2008.50`, relocated pigment `445.39`, conservation error `0.00012%`.
- Artist response: “Pastel paper is gold!”
- Accepted relationship: the sample-guided fine fibrous surface and existing loose-particle smudge behavior work together convincingly at low pressure.
- Scope limit: this record does not compare Draw contact at light and firm pressure, so CH-P-01 and CH-P-02 remain artist-pending. Light Cream remains unreviewed.

### 2026-08-18 — Direct artist clarification closes Pastel Paper draw tests

- The artist clarified that all prescribed Pastel Paper tests were completed; only one representative iteration was exported.
- Accepted: Pastel White light Draw at pressure `0.25`, matched firm Draw at `0.75`, matched Light Cream comparison, and fibrous-paper smudging.
- CH-P-01 tooth/fiber capture and CH-P-02 pressure progression advance to **artist accepted for the Pastel Paper v0.2 diagnostic scope**.
- White and Light Cream are accepted as physical twins whose ground tone differs without changing charcoal behavior.
- Evidence boundary: only the smudge iteration has a saved JSON/image/measurement record. The matched Draw and color-twin approval is a direct artist statement and must not be misrepresented as separately exported trials.
- Next calibration target: CH-P-03 / CH-P-04 coarse/fine fracture and bounded dusting with a conserved particle source; do not add decorative random flecks.

### 2026-08-18 — Charcoal v0.5 fracture and bounded dusting checkpoint

- The shared solver now keeps settled, loose, coarse-fragment, fine-dust, off-canvas, offered-source, and remaining-source quantities separately.
- During Draw, every fragment is split from pigment actually transferred out of the applicator offer. During later smudge contact, fragments are split from existing deposited or loose pigment. Neither path adds material to the pigment ledger.
- The trigger uses shared phase, pigment fraction, fracture toughness (`TRIB-003`), abrasion resistance (`TRIB-004`), particle population (`PART-001`), packing (`DEPO-004`), pressure, speed, and substrate tooth through `IM-008`; it does not test a medium name.
- Current fracture, abrasion, particle-size share, density, shape, travel, and settling values are normalized unmeasured stand-ins. They are calibration knobs, not scientific constants.
- Automated evidence: greater matched loading/pressure/speed creates more coarse and fine material; fine dust travels farther; coarse fragments settle sooner; both populations settle after contact; blank contact and a profile without a brittle particulate source create zero particles; identical commands reproduce exactly; total pigment error stays below 1% including off-canvas loss.
- Artist status: **required and pending**. The artist must decide whether the result reads as brittle crumbs and dust physically shed by the stroke, whether fine dust travels too far or too evenly, and whether any marks look like decorative spray.

### 2026-08-18 — CH-LAB-1787112551932 and v0.5.1 friction response

- Artist verdict on v0.5: **Good / Recalibrate**.
- Reviewed action: strong smudge on Pastel Paper — White at pressure `0.85`, speed `1.60`, visibility `1.00`.
- Artist diagnosis: the result was too light and wispy and felt as though it had almost zero friction.
- Saved state: pigment area `33.27%`, deposited `3241.69`, coarse created `144.29`, fine dust created `235.42`, relocated `3033.75`, off-canvas loss `0.000044`, conservation error `0.00114%`.
- Evidence boundary: the mass ledger passed, but the visible travel and density failed artist calibration. Because the saved action was Smudge, this review does not independently complete the prescribed Draw comparison.
- v0.5.1 response: reduce fine-dust launch speed and lateral spread, increase the influence of shared kinetic friction and substrate roughness on fine-dust energy loss, and settle fine dust somewhat sooner. Do not alter the accepted loose-ridge smudge path or create a named charcoal branch.
- New automated guard: increasing `TRIB-002` alone must shorten fine-dust travel while coarse fragments still travel less and settle faster than fine dust; all conservation and determinism checks remain required.
- Artist status: **retest required**. The intended result should remain visibly dusty, but denser, more surface-bound, and less like a pale airborne veil.
