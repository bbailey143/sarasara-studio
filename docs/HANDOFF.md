# Sarasara vNext relay handoff

This file is the project baton. Any AI model taking over this repository must read this file before planning or changing anything.

# PART A — Permanent relay protocol

## A1. Source of truth

Use the repository in this order:

1. This handoff for the current state and exact next action.
2. `docs/canonical/` for the shared physical vocabulary and contracts.
3. `docs/validation/` for scientific tests and artist decisions.
4. `lab/ARCHITECTURE.md` for how the diagnostic prototype maps onto the canonical model.
5. `docs/reference/` for archived evidence. Reference material may inform a model, but it is not automatically current truth.
6. Conversation history and model memory only as leads to verify against the repository.

If two documents conflict, do not silently choose one. Record the conflict here and repair the stale document as part of the smallest relevant task.

## A2. Non-negotiable project rules

- Begin with one abstract material state and derive named media from shared properties and interactions.
- A medium name may select a profile. It may not select a private engine, hidden effect, or named-medium shortcut.
- Keep substrate, carrier/fluid, pigment or particles, and applicator distinct but interacting.
- Preserve useful archived research as evidence; do not copy old constants as production truth without validation.
- Watercolor and charcoal are deliberately opposite tests of whether the architecture is genuinely shared.
- No medium graduates from experimental to canonical without schema, behavioral/physics, and artist validation for the stated scope.
- Whenever a scientific change creates something an artist can see or feel, artist review is mandatory before acceptance.
- Do not describe stand-in diagnostic values as measured production constants.
- Explain work to the user in artist-friendly language before technical language.

## A3. Evidence and acceptance

Keep these claims separate:

- **Code verified:** automated checks passed.
- **Physics observed:** a named test produced recorded measurements.
- **Artist accepted:** a saved review identifies the build, settings, rating, decision, and remaining faults.
- **Production ready:** not currently claimed anywhere in this repository.

An exported review JSON is evidence of what the artist saw and decided. It is not, by itself, proof that the equations are scientifically correct.

Use `Accept`, `Recalibrate`, `Revise model`, or `Blocked` exactly as defined in `docs/validation/README.md`. Acceptance is always limited to a written scope.

## A4. How to update this baton

At every meaningful checkpoint, and before switching models:

1. Read all of Part A and the existing Part B.
2. Verify the test and Git state; do not repeat an old claim from memory.
3. Rewrite Part B so it describes the current repository, including corrections and unresolved contradictions.
4. Make `NEXT ACTION` small enough to begin cold. Name exact files, the observable outcome, the verification command, and what each result means.
5. Record half-finished work under `IN FLIGHT`. Never hide it behind a clean summary.
6. Commit the baton with the work it describes and push it when repository authorization/network access permits.

The user should be able to start another AI with one sentence:

> Read `docs/HANDOFF.md` and keep going.

## A5. Safety against plausible but wrong conclusions

- Reproduce a reported behavior before diagnosing it.
- Check that diagnostic visibility controls do not alter the simulation.
- Prefer matched artist comparisons: change one physical input while holding the others constant.
- Say “unknown” when evidence cannot distinguish two causes.
- If a later review corrects an earlier interpretation, preserve the correction in the history instead of erasing it.
- Do not solve a failed shared interaction with a watercolor-only or charcoal-only flag.

# PART B — Current baton

## Last updated / by

- **Date:** 2026-08-19
- **By:** Claude (Opus 5)
- **Repository:** `https://github.com/bbailey143/sarasara-studio.git`
- **Local branch:** `vnext-bootstrap`
- **Archived application:** Git branch `archive/legacy-main`

## Build and repository state

- This foundation has no package install or production build yet. The lab is dependency-free HTML and JavaScript.
- Verified command: `node lab/shared-solver.test.js`
- Verified result on 2026-08-19 after the shared deposited layer and oil v0.1: `shared solver checks passed`, including all earlier relationships plus regime selection by property, yield-gated slumping and holding, yield-gated brush displacement, derived relief height, a body refusing carrier water, zero oil pigment diffusion, oil determinism, conservation, and a bit-for-bit regression proving watercolor and charcoal are untouched by the new pass.
- The new checks were mutation-tested on 2026-08-19: removing the yield gate, letting a body write carrier water, dropping packing from relief height, breaking slump conservation, and selecting the regime by material name were each deliberately introduced and each was caught by a named assertion.
- Verified result on 2026-08-19 after the artist pressure-calibration change: `shared solver checks passed`, including all earlier relationships plus default identity, monotonic curve interpolation, fixed endpoints, serializable calibration, directional checks for paper texture, particle breakup, smear, and speed influences, conservation below 1%, and no named-medium calibration branch.
- Verified command: `git diff --check`
- Verified result on 2026-08-19 after the pressure-calibration implementation: passed with no whitespace errors.
- Verified the inline lab script parses and all 57 HTML IDs are unique. Live browser QA passed at `1440 × 1000` and `375 × 812`: the panel sits to the right of the drawing surface on desktop and stacks below it on mobile without horizontal overflow. Clicking **Soft** changed the interior curve values from `0.33 / 0.67` to `0.48 / 0.80`; **Reset all** restored `0.33 / 0.67`. This verifies the instrument, not the material feel.
- The baton was introduced in local commit `f1be021` (`docs: add durable AI handoff baton`).
- The original nine-commit checkpoint was published through `bcc0e6b` on `origin/vnext-bootstrap`.
- Archived AI guidance was restored exactly as root `CLAUDE.md` in commit `9c48cc6`.
- The user explicitly authorized publishing every current `vnext-bootstrap` commit to `https://github.com/bbailey143/sarasara-studio.git` during this cleanup checkpoint.
- Fine-Tooth implementation and review history were published in commit `40f19f1` (`feat: add fine-tooth charcoal paper`).
- Sample-guided Pastel White/Cream profiles were published in commit `00dff73` (`feat: calibrate pastel paper from artist samples`).
- Pastel White artist acceptance was published in commit `e80f8d9` (`docs: accept pastel white charcoal smudge`).
- Complete Pastel Paper approval and CH-P-03/04 handoff were published in commit `c2cd9c7` (`docs: accept complete pastel paper pass`).
- Always verify publication with `git status --short --branch`; a clean published checkpoint shows no `ahead` count.

## Current objective

Prove that one shared, property-driven material architecture can describe and produce recognizable watercolor and charcoal without named-medium engines or hidden special cases. The current browser lab is a diagnostic instrument for that proof, not the production painting application.

The validation-status reconciliation is complete. Gate 2 and Gate 3 are explicitly partial and remain open. The artist supplied a loose, grainy charcoal target divided into **Stamp / 1 Layer / Multi-Layer / Smudge**, then requested direct control over the linked pressure relationships instead of model-by-model retuning. The lab now provides an artist-editable pressure curve plus paper-texture, particle-breakup, smear, and speed influences. The four-part target still requires artist review before narrower fracture or lift work resumes.

## What exists now

### Canonical foundation

- `docs/canonical/PROPERTY_REGISTRY.yaml` — shared physical properties.
- `docs/canonical/MODEL_REGISTRY.yaml` — shared model families.
- `docs/canonical/INTERACTION_MATRIX.yaml` — which families interact.
- `docs/canonical/SCHEMA_CONTRACT.md` — rules for valid profiles and evidence.
- `docs/canonical/TORTURE_TESTS.md` and `.yaml` — watercolor/charcoal architecture challenge.
- Schema Gate 1 is recorded as passing for v0.1: both media fit the vocabulary without private named-medium properties.

### Diagnostic lab

- Open `lab/diagnostic-lab.html` directly in a browser; no server or install is required.
- `lab/shared-solver.js` contains one solver used by both profiles.
- `lab/ARCHITECTURE.md` maps the solver to canonical properties and named models.
- The solver begins from an abstract material state. `watercolor` and `charcoal` are profile selectors, not separate engines.
- Current profiles are `material.watercolor.diagnostic.v0.6.1` and `material.charcoal.diagnostic.v0.6`. Watercolor v0.6.1 preserves the artist-reviewed v0.6 drawing constants and adds only stand-in friction/packing inputs for the shared smudge action; smudge itself is not artist-accepted for watercolor. Charcoal v0.6 preserves the v0.5.2 pressure-anchoring relationship and adds granular dry capture plus separated settled/loose/coarse/fine optical density.
- Paper is now a separate participant selected independently from material. The lab offers archive-seeded Plain White, Hot Press, Cold Press, and Rough Watercolor Paper plus reference-derived experimental Pastel Paper — White and Light Cream; saved reviews record the selected substrate ID, name, and provenance.
- The commercial 5100 × 5100 samples are not copied into the repository. Their measured base color, low contrast, and visible fiber scale guide the procedural profiles; physical height/friction remain stand-ins. White and Cream share exactly the same physical tooth, so color cannot alter charcoal behavior.
- The archive contains no separately named charcoal/pastel paper. Charcoal now selects Pastel Paper — White by default. This UI default does not change material physics or create a named-medium engine branch.
- `docs/reference/material-studies/PAPER_SUBSTRATE_EXTRACT.md` records the exact archived paper values and the provisional canonical mapping.
- `docs/reference/material-studies/LOOSE_GRAIN_CHARCOAL_TARGET.md` preserves the artist's four-part visible target; the temporary screenshot is not shipped.
- Saved reviews include the mark image, settings, profile/model information, measurements, rating, notes, and decision so historical comparisons can be made.
- Pressure and speed remain available under the collapsed Gesture diagnostics because they are test inputs, not primary material controls.
- The **Pressure behavior** card beside the canvas transforms hand/stylus pressure through a monotonic four-point curve. Linear, Soft, Firm, and Reset presets are available; two interior responses can be dragged or changed with accessible sliders. Four `0–2` influence controls tune paper-tooth reach, particle breakup, smear/anchoring, and gesture-speed effects. The current calibration persists locally and is saved in review JSON/history.
- Diagnostic visibility changes display strength only; the automated test verifies it does not change physical state.

### Shared relationships currently represented

- Applicator contact transfers available material according to pressure, speed, moisture, and substrate tooth.
- Intrinsic paper roughness, porosity/capacity, permeability, texture seed/scale, and color come from the selected substrate rather than from the watercolor or charcoal material profile.
- Surface carrier, paper-held saturation, mobile pigment, and deposited pigment are separate state values.
- Paper dampness initializes paper-held saturation rather than a surface puddle.
- Pigment follows carrier movement and can settle/deposit; visibility is separate from physical quantity.
- Dry watercolor contact deposits pigment through tooth with no hidden water or dry-brush mode.
- Clean water uses the same contact transaction and may reactivate pigment without inventing pigment mass.
- Charcoal deposits dry particles with no carrier through the same shared contact/state framework.
- Dry particle transfer is spatially incomplete: pressure, local tooth, `PART-002` density, and `PART-003` shape govern granular capture; uncaptured offered mass remains on the tool. Repeated layers darken by accumulating real deposited mass in the same grain structure.
- The dry preview maps settled, loose, coarse, and fine populations to different optical density so fine/loose material can remain a lighter veil. This observation mapping does not change the conserved state.
- A shared **Smudge existing material** action lifts deposited pigment into a short-lived loose state using friction, packing, pressure, speed, and substrate roughness. Loose particles retain gesture-direction momentum, coast briefly after contact, lose energy, and settle without calling the deposition path or branching on a medium name.
- Above the shared high-load compaction threshold, smudging immediately anchors a bounded share of relocated material into the contacted paper trail using pressure, friction, packing, roughness, and local tooth. The remainder still moves as loose/coarse/fine material. The cumulative **Pressed into paper** reading and saved JSON field `pressure_anchored_pigment` expose this relationship.
- Shared fracture contact can split transferred or already deposited/loose material into coarse fragments and fine dust only when the property profile defines a brittle particulate source. Coarse pieces travel less and settle faster; fine dust travels farther and settles slower; off-canvas mass is recorded.
- The dry-material ledger now exposes offered source, material remaining on the tool, settled, loose, coarse, fine, and lost/off-canvas pigment. The artist-facing history and exported JSON retain these quantities with the mark and verdict.

## Artist decisions and important corrections

### Watercolor

- Latest accepted review: `WC-LAB-1787100187504`.
- Profile/build: `material.watercolor.diagnostic.v0.6`.
- Rating: **Good**.
- Decision: **Accept for the initial diagnostic scope**.
- Reviewed settings: pigment load `1.00`, brush water `0.30`, paper dampness `0.24`, pressure `0.55`, speed `1.00`, diagnostic visibility `3.80`.
- Saved final measurements: wet area `15.89%`, pigment area `21.40%`, pigment conservation error below `0.001%`.
- Artist conclusion: not close to final realism, but a substantially improved and semi-convincing initial watercolor.
- The critical accepted relationship was reconnecting substrate → fluid/carrier → pigment → brush/applicator.
- Scope of acceptance: the shared diagnostic wiring and recognizable initial behavior only.

Important correction history:

- The artist initially described moderate-water swelling as more dramatic than a matched retest showed, but the underlying problem remained: no setting produced a dark, semi-wet, stroke-shaped mark.
- Archived evidence showed that mobile surface water must remain distinct from paper saturation, with paper capacity, friction/tooth, slower paper-held mobility, and pigment retention.
- v0.6 restored those relationships without copying the archived constants as final truth. The artist then accepted the limited diagnostic scope.

Still open for watercolor:

- natural brush shape and a finite reservoir with believable run-out;
- spectral/measured pigment appearance and mixing;
- wet crossings, layering, and glazing;
- artist-accepted clean-water blooms;
- multiple measured paper profiles;
- granulation, edge behavior, dryback, and believable failure ranges;
- production calibration and a production Rust/GPU implementation.

### Charcoal

- Correction history: `CH-LAB-1787103913509` rated v0.3 **Good / Recalibrate** because the displaced material stopped like putty.
- `CH-LAB-1787105475421` rated the v0.4 motion **Good / Accept for the smudge-motion scope**, while withholding final charcoal approval pending better paper.
- `CH-LAB-1787107111788` rated a Plain White smudge **Convincing / Accept** and described it as “so much fun to use.” Minor desired improvement: believable small particle flicks.
- Latest review: `CH-LAB-1787159371656`, charcoal v0.5.1 on Pastel White v0.2. Rating **Recognizable**; decision **Recalibrate strong-pressure smudging**.
- Latest settings: smudge, pressure `0.85`, speed `1.60`, diagnostic visibility `6.40`. Measurements: pigment area `20.56%`, deposited pigment `1919.76`, coarse created `116.64`, fine created `190.31`, cumulative relocated pigment `3323.37`, conservation error `0.00066%`.
- Artist conclusion: the strong pass pushed material around without leaving the darker rubbed smear that real pressure should force into paper. This does not revoke the accepted moderate result; it identifies the missing strong-pressure transition.
- New artist target after that review: loose, grainy charcoal with an irregular first contact, paper showing within one layer, gradual darkening across multiple layers, and a lighter directional smudge that preserves darker source structure. The artist expects to supply a separate flatter/heavier charcoal target later.
- Correction: fixing the inverted archived grain scale was necessary but did not make Rough suitable for charcoal. Do not keep tuning that wet-media paper toward dry-media needs.
- Generic Fine-Tooth v0.1 was superseded before artist review. Sample-guided Pastel White/Cream v0.2 use identical fibrous tooth with different ground colors. Automated relationships pass. `CH-LAB-1787110275815` artist-accepted Pastel White appearance and low-pressure smudging as Convincing; direct follow-up confirms all prescribed light/firm Draw and Light Cream comparisons were also performed and approved.
- CH-P-01 and CH-P-02 are artist-accepted for Pastel Paper v0.2's diagnostic scope. CH-P-03 and CH-P-04 have automated relationship evidence plus limited artist acceptance for v0.5.1 moderate smudging; the matched light-versus-strong Draw comparison remains open. CH-P-05's moderate behavior is accepted, while strong-pressure anchoring remains artist-pending. CH-P-08 now has partial automated grain/layer evidence in v0.6. Lift and burnishing/rejection remain unbuilt.
- Every visible charcoal conclusion requires artist review, with saved marks and settings.

## Reconciled validation status

- Gate 1 remains **pass**: both media fit the canonical vocabulary without private named-medium properties.
- Gate 2 is **partial and open**: several watercolor relationships, Hot Press/Rough uptake contrast, dry-charcoal tooth bands, pressure-driven valley reach, conservative smudge relocation/anchoring, bounded coarse/fine breakup, and v0.6 grain/layer buildup are automated, while lift, burnish, and other scenes remain unrun.
- Gate 3 is **partial, mandatory, and open**: watercolor v0.6 is artist-accepted only for its initial shared-interaction scope; charcoal smudge motion and v0.5.1 moderate-smudge breakup/drag are accepted only for their stated scopes; neither medium has final acceptance.
- `docs/validation/watercolor/physics_tests.md` and `docs/validation/charcoal/physics_tests.md` now distinguish `automated_relationship_verified`, `artist_accepted_limited_scope`, `partial_not_isolated`, and `not_run` test by test.

## NEXT ACTION — start here

Draw with **Oil** in `lab/diagnostic-lab.html` and record the first artist review of a third material. Oil v0.1 has code evidence only; nothing about how it looks has been judged.

1. Choose **Oil**, any paper, and **Draw material**.
2. Make one firm stroke. It should leave a raised body with a lit and a shadowed side, not a flat tone.
3. Stroke across the first mark. Paint should be shoved along and pile up ahead, not smear thin.
4. Try a light stroke and a heavy one over existing paint. Below the yield stress nothing should move at all; the change should arrive as a threshold, not a fade.
5. Watch a thick mound for a few seconds. It should hold. If it relaxes into a pool, the yield stress is too low.
6. Confirm no soft edges anywhere. Oil must not bleed, spread, or halo.
7. Save one rating and decision. Name any failure by its `OL-P-` id from `docs/validation/oil/physics_tests.md`.

**Why this action:** the automated checks prove the layer holds below yield, slumps above it, displaces under the brush, conserves mass, and leaves watercolor and charcoal bit-for-bit unchanged. None of that says whether it reads as paint.

**Success condition:** oil is recognizable as a body of paint — it holds marks, moves as a mass, takes light on its relief, and never bleeds. “Indistinguishable from oil” is not required for v0.1.

**Deferred at the artist’s request:** the charcoal Stamp / 1 Layer / Multi-Layer / Smudge comparison. Every charcoal mark and decision already recorded still stands. It is worth resuming after burnishing (`CH-P-07`) is built on the new shared layer, so the grain and the burnish can be judged in one sitting.

## IN FLIGHT

- Nothing in code. The shared deposited layer and oil v0.1 are implemented, mutation-tested, and committed. The first oil look is artist work, not an implementation task.

## Recently completed

- Added the shared deposited layer with derived `DEPO-005` relief height and yield-gated motion, plus oil v0.1 assembled entirely from existing canonical properties. Regime is selected by physical properties (`body` / `granular` / `flowing`), never by material name. In the matched three-recipe scene the same gesture yields deposited 3.043 / suspended 22.003 / water 62.050 for watercolor, 10.486 / 0 / 0 for charcoal, and 42.841 / 0 / 0 for oil, all at 0.000000% conservation error. A mound at or below the yield stress keeps 100% of its peak and moves exactly zero mass; at 8x yield it keeps 31.7%, at 40x it keeps 19.5%. Brush displacement is 0% at pressures 0.20 and 0.34 against a yield stress of 0.34, then 8.8% at 0.50, 38.9% at 0.75, and 60.0% at 1.00. Watercolor and charcoal deposited arrays are bit-for-bit identical across the new pass. `[1 RUN ONLY]`
- Recorded ADR-0002, the third-material vocabulary test. Twelve of thirteen required oil behaviors resolve to existing canonical properties; no new property family was introduced. The single gap, how tall deposited material stands, is derivable from mass, packing, and particle density and was therefore added as a derived property inside an existing family. The finding that matters is that the new shared layer is what charcoal burnishing (`CH-P-07`) and watercolor finite-thickness glazing were already blocked on.
- Added `docs/BUILD_MAP.html`, a visual orientation sheet kept current with the build. Only the pin, the board marks, and the next action change at a checkpoint. A board mark turns green only on artist review.
- Added the artist-controlled **Pressure behavior** card to the right of the desktop drawing surface, with a live input/output dot, draggable and keyboard-accessible curve controls, Linear/Soft/Firm/Reset presets, four shared influence controls, local persistence, and review JSON/history capture. Default calibration reproduces the previously tested behavior. Browser QA passed at `1440 × 1000` and `375 × 812`; Soft produced `0.48 / 0.80` and Reset restored `0.33 / 0.67`. `[1 RUN ONLY]`
- Recorded the artist's loose, grainy charcoal reference as `docs/reference/material-studies/LOOSE_GRAIN_CHARCOAL_TARGET.md`, preserving the labeled Stamp / 1 Layer / Multi-Layer / Smudge relationships without treating the screenshot as measured science.
- Added charcoal v0.6 property-driven granular transfer and population-specific optical density. In the matched load-`0.70`, pressure-`0.55`, speed-`0.80` scene, one pass marks `33.20%` of the checked corridor and leaves `66.80%` as paper/gaps. Three passes retain the same footprint, increase deposited mass from `4.41292` to `13.23877`, and lower mean corridor RGB from `232.02` to `222.72`; conservation remains below `0.000001%`. `[1 RUN ONLY]`
- Imported `CH-LAB-1787159371656`: charcoal v0.5.1, Pastel White, strong smudge at pressure `0.85` / speed `1.60`, rated **Recognizable / Recalibrate** because the contact swept material without leaving a pressed smear. Saved pigment area `20.56%`, deposited `1919.76`, coarse created `116.64`, fine created `190.31`, offered source `4352.52`, source remaining `2432.75`, relocated `3323.37`, conservation error `0.00066%`. `[1 RUN ONLY]`
- Added v0.5.2 shared high-load pressure anchoring plus a cumulative `pressure_anchored_pigment` ledger and **Pressed into paper** lab reading. In the matched test, pressure `0.55` anchors exactly `0`; pressure `0.85` anchors `0.06547` of `0.37697` relocated units (`17.37%`), leaves `0.29237` loose, raises clean-trail deposited mass from `0` to `0.04165`, and keeps conservation error at `0.00000112%`. `[1 RUN ONLY]`
- Imported `CH-LAB-1787158644333`: charcoal v0.5.1, Pastel White, moderate smudge at pressure `0.55` / speed `1.00`, rated **Convincing / Accept**. Saved pigment area `13.94%`, deposited `801.65`, coarse created `29.87`, fine created `48.73`, offered source `1819.08`, source remaining `1017.42`, relocated `1759.55`, effectively zero off-canvas loss, conservation error `0.00141%`. This accepts moderate-smudge breakup/drag only; it does not prove the separate strong-smudge or matched Draw scenes. `[1 RUN ONLY]`
- Imported `CH-LAB-1787112551932`: charcoal v0.5, Pastel White, strong smudge at pressure `0.85` / speed `1.60`, rated **Good / Recalibrate** because it was too light, wispy, and nearly frictionless. Saved pigment area `33.27%`, deposited `3241.69`, coarse created `144.29`, fine created `235.42`, relocated `3033.75`, conservation error `0.00114%`.
- Added v0.5.1 shared recalibration: reduced fine-particle forward/side launch, increased fine-particle energy loss from kinetic friction and substrate roughness, and increased settling without changing the accepted base loose-ridge smudge path or adding a named-medium branch.
- Added a matched regression that higher `TRIB-002` alone shortens fine-dust travel. In the checked 1-second scene, fine travel was `3.053` cells at friction `0.15`, `2.436` at profile friction `0.58`, and `2.144` at friction `0.85`; at profile friction, `63.81%` of fine dust versus `7.33%` of coarse fragments remained detached, with conservation error below `0.000001%`. `[1 RUN ONLY]`

- Implemented CH-P-03 / CH-P-04 as shared coarse-fragment and fine-dust populations sourced only from transferred or existing surface mass; no decorative particle source and no named-medium branch.
- Added offered-source, remaining-tool, settled, loose, coarse, fine, and off-canvas readings to the ledger; the lab exposes the artist-relevant readings and saves them in JSON/history.
- Added matched automated checks for load alone, pressure alone, speed alone, coarse-near/fine-far travel, different settling rates, blank/profile-without-source zero creation, determinism, source closure, off-canvas accounting, and total conservation below 1%.
- In the checked high scene, created particle mass was `1.27168` versus `0.00341` in the low scene; after `0.75 s`, the coarse centroid was `45.53` and fine centroid `49.48`, with `15.20%` coarse versus `84.48%` fine mass still detached; conservation error was `0.0000006%`. `[1 RUN ONLY]`
- Added explicit artist instructions distinguishing physically shed crumbs/dust from an even spray, glitter, or decorative speckles. At that checkpoint, CH-P-03/04 remained artist-pending.

- Reorganized the diagnostic controls into Brush, Paper, View, and collapsible Gesture groups while preserving simulation hooks.
- Added visible minimum, current, and maximum values to sliders and corrected narrow-screen layout.
- Increased watercolor pigment delivery without coupling pigment load to carrier delivery.
- Added continuous dry watercolor contact governed by tooth, pressure, and moisture rather than a dry-brush mode.
- Restored distinct paper saturation, surface carrier, tooth resistance, porous uptake, and damp-contact pigment retention from the architectural lessons in the archive.
- Added automated guards for conservation, clean water, dry contact, pressure response, paper dampness, carrier uptake, damp-versus-wet spread, pigment-load independence, reactivation, and dry charcoal deposition.
- Recorded limited artist acceptance of watercolor v0.6 and confirmed the implementation still follows the shared abstract-medium architecture.
- Restored the archived `OLDEYTIMEYCLAUDE.md` content exactly as root `CLAUDE.md`; it supplies Claude-specific caution, simplicity, surgical-change, and verification guidance alongside this model-neutral baton.
- Reconciled every formal watercolor and charcoal behavioral row with current evidence. Gate 2 and Gate 3 now say **partial and open** rather than incorrectly implying that no prototype or artist review exists.
- Implemented CH-P-05 as shared conservative surface-contact relocation. Automated checks verify source loss, destination gain, stronger matched movement under firm pressure, unchanged initial pigment, zero pigment on a blank smudge, and total conservation error below 1%.
- Added Draw/Smudge controls, action-specific artist instructions, a relocated-pigment reading, and saved action/interaction history to the diagnostic lab.
- Imported `CH-LAB-1787103913509`: charcoal v0.3 was rated **Good / Recalibrate** because its dense push stopped like putty instead of carrying a loose ridge forward.
- Added a shared loose surface-particle state with velocity, friction/roughness energy loss, and resettling. Automated checks verify ridge creation, continued forward motion after contact ends, loose-mass decay, deposited-mass recovery, blank-paper behavior, and conservation below 1%.
- Added a **Loose / moving pigment** reading and explicit artist checks for ridge motion, energy loss, and settling. The charcoal profile is now v0.4 and requires a new artist review.
- Imported `CH-LAB-1787105475421`: charcoal v0.4 was rated **Good / Accept for smudge motion**, with final approval explicitly withheld pending better paper.
- Recovered the archive's exact Plain White, Hot Press, Cold Press, and Rough paper seeds. Confirmed there is no separately named charcoal/pastel preset in the preserved branch.
- Split paper properties out of the material profiles. The lab now saves substrate identity/provenance independently and uses deterministic multi-scale height texture plus paper-specific uptake and color.
- Added automated checks for flat Plain paper, meaningful Rough height range, light peak capture, pressure-driven valley capture, Rough-versus-Hot-Press carrier uptake, and all existing conservation/smudge relationships.
- Imported `CH-LAB-1787107111788`: a pressure-`0.96` Plain White smudge was rated **Convincing / Accept** with conservation error `0.00070%`. This strengthens CH-P-05 but does not complete CH-P-01/CH-P-02.
- Recorded the artist's requested “little random bits” under future CH-P-03/CH-P-04 fracture/dusting rather than implementing arbitrary speckles.
- Recorded the direct Rough-paper feedback: charcoal movement over valleys passed in principle, while the enlarged paper scale required recalibration.
- Corrected the inverted archived `noiseScale` mapping in substrate v0.2. Rough now has 39 midline tooth crossings in the checked 300-cell field versus 13 for Hot Press, rather than a few oversized terrain features. Existing physics/conservation checks still pass.
- Imported `CH-LAB-1787107972495`: charcoal v0.4 smudge was **Good / Accept for motion**, while Rough v0.2 was rejected as the charcoal paper. Recorded pigment area `26.00%`, deposited `2992.55`, relocated `5991.20`, conservation error `0.00032%`.
- Renamed the preserved Rough profile **Rough Watercolor Paper** and added independent **Fine-Tooth Drawing Paper v0.1** as an explicitly experimental stand-in. Charcoal selects Fine-Tooth by default without changing shared contact physics.
- Added automated checks that Fine-Tooth relief is lower than Rough Watercolor Paper, grain is more frequent, light pressure favors peaks, firm pressure reaches valleys, and smudge/conservation behavior remains intact.
- Superseded unreviewed Fine-Tooth v0.1 with sample-guided Pastel White and Light Cream v0.2 profiles. Sampled RGB/luminance evidence is recorded in `docs/reference/material-studies/PASTEL_PAPER_SAMPLES.md`; source JPEGs are not shipped.
- White/Cream share identical physical tooth. On the 300 × 130 diagnostic field, Pastel relief range is `0.15663` with `105` midline crossings versus Rough's `1.0` range and `39` crossings. Automated pressure, smudge, blank-paper, and conservation checks pass. `[1 RUN ONLY]`
- Imported `CH-LAB-1787110275815`: Pastel White v0.2 low-pressure (`0.26`) smudge was rated **Convincing / Accept** with the note “Pastel paper is gold!” Pigment area was `14.83%`, deposited pigment `2008.50`, relocated pigment `445.39`, and conservation error `0.00012%`. This accepts appearance/smudge scope, not CH-P-01/02 Draw pressure. `[1 RUN ONLY]`
- Direct artist correction: all prescribed Pastel White light/firm Draw, Light Cream parity, and smudge tests were completed and approved; only one representative iteration was exported. CH-P-01 and CH-P-02 now have artist acceptance for Pastel Paper v0.2's diagnostic scope. Do not invent missing JSON records.

## Blocked and open questions

- Pastel White/Light Cream appearance, light/firm Draw contact, and smudge behavior are artist-accepted for the v0.2 diagnostic scope. Only the representative smudge has exported JSON evidence; the broader approval is a direct artist statement.
- The photographs provide color and visible-pattern evidence, not surface-height or friction measurements. Those values remain diagnostic stand-ins and may require recalibration.
- The archive paper numbers are application presets, not scientific measurements. Their canonical `TRAN-002` mapping is explicitly a normalized diagnostic stand-in.
- CH-P-03/04 v0.5 received a Good / Recalibrate verdict for nearly frictionless strong-smudge dust. v0.5.1 moderate-smudge breakup/drag is Convincing / Accept; the prescribed light-versus-strong Draw comparison remains artist-pending.
- CH-P-05 strong pressure failed in `CH-LAB-1787159371656` because it swept material without a pressed smear. The anchoring relationship introduced in v0.5.2 is carried into v0.6; its 17.37% matched result is code evidence only and remains part of the combined v0.6 artist review.
- Charcoal v0.6's `33.20%` checked coverage and layer-darkening measurements are code evidence only. Whether the grain is too sparse, too light, too regular, or otherwise unlike the supplied target is unknown until artist review.
- Browser layout and control operation are verified, but whether any chosen curve/influence combination feels like the supplied loose-charcoal target remains unknown until the artist draws and saves a review.
- The lab has no production brush reservoir, spectral color, measured papers, physically measured fracture constants/particle sizes, lift/burnish system, or production renderer.
- Rust is the intended production direction, but production implementation must wait until the shared foundation survives the stated validation scope.

## Do NOT

- Do not make a new watercolor-specific or charcoal-specific engine.
- Do not add flags such as `watercolorMode`, `charcoalMode`, `dryBrushMode`, or `bloomEffect` to make a test pass.
- Do not confuse stronger diagnostic visibility with more physical pigment.
- Do not solve the missing strong-pressure smear by increasing display gain; `CH-LAB-1787159371656` already used `6.40×`, and visibility cannot change deposited mass.
- Do not rejoin paper dampness and mobile surface water; that caused weak, swollen moderate-water marks.
- Do not replace the accepted substrate → carrier → pigment → applicator relationship with a visual stamp or texture shortcut.
- Do not claim final watercolor acceptance. The accepted review is deliberately limited.
- Do not mark a formal physics row passed merely because the solver contains a related equation.
- Do not satisfy the requested particle flicks with decorative randomness; they must come from conserved fracture/dusting state.
- Do not fake the loose-grain target with an overlaid texture, spray brush, or post-process speckles. Skipped contact must remain on the tool ledger, and layer darkening must come from accumulated mass.
- Do not tune Rough Watercolor Paper until it serves charcoal. Keep wet-media and dry-media papers as independent substrate profiles.
- Do not begin a production Rust/GPU engine before the validation-status reconciliation and the agreed v0.1 gates are complete.
