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

- **Date:** 2026-08-18
- **By:** Codex, GPT-5
- **Repository:** `https://github.com/bbailey143/sarasara-studio.git`
- **Local branch:** `vnext-bootstrap`
- **Archived application:** Git branch `archive/legacy-main`

## Build and repository state

- This foundation has no package install or production build yet. The lab is dependency-free HTML and JavaScript.
- Verified command: `node lab/shared-solver.test.js`
- Verified result on 2026-08-18 after archived-paper recovery: `shared solver checks passed`, including material/substrate separation, flat-versus-rough height variation, peak/valley capture, pressure-driven valley reach, Hot Press versus Rough uptake, smudge momentum/settling, blank-paper behavior, and conservation assertions.
- Verified command: `git diff --check`
- Verified result on 2026-08-18 during the GitHub cleanup checkpoint: passed with no whitespace errors.
- Verified the inline lab script parses, each required control ID occurs exactly once, and `smudgeSegment` contains no `watercolor` or `charcoal` branch. Live visual browser inspection remains pending as recorded below.
- The baton was introduced in local commit `f1be021` (`docs: add durable AI handoff baton`).
- The original nine-commit checkpoint was published through `bcc0e6b` on `origin/vnext-bootstrap`.
- Archived AI guidance was restored exactly as root `CLAUDE.md` in commit `9c48cc6`.
- The user explicitly authorized publishing every current `vnext-bootstrap` commit to `https://github.com/bbailey143/sarasara-studio.git` during this cleanup checkpoint.
- Always verify publication with `git status --short --branch`; a clean published checkpoint shows no `ahead` count.

## Current objective

Prove that one shared, property-driven material architecture can describe and produce recognizable watercolor and charcoal without named-medium engines or hidden special cases. The current browser lab is a diagnostic instrument for that proof, not the production painting application.

The validation-status reconciliation is complete. Gate 2 and Gate 3 are explicitly partial and remain open. Charcoal v0.4 smudge motion is now artist-accepted for that limited scope. The artist explicitly withheld final approval because the placeholder paper was poor, so the next phase is matched artist validation of the recovered independent paper profiles.

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
- Current profiles are `material.watercolor.diagnostic.v0.6.1` and `material.charcoal.diagnostic.v0.4`. Watercolor v0.6.1 preserves the artist-reviewed v0.6 drawing constants and adds only stand-in friction/packing inputs for the shared smudge action; smudge itself is not artist-accepted for watercolor. Charcoal v0.4 adds transient loose-particle momentum and settling without a named-medium engine branch.
- Paper is now a separate participant selected independently from material. The lab offers archive-seeded Plain White, Hot Press, Cold Press, and Rough profiles; saved reviews record the selected substrate ID, name, and provenance.
- The archive contains no separately named charcoal/pastel paper. `Rough` is the strongest preserved tooth candidate. Its use for charcoal/pastel remains an artist hypothesis, not an archived fact.
- `docs/reference/material-studies/PAPER_SUBSTRATE_EXTRACT.md` records the exact archived paper values and the provisional canonical mapping.
- Saved reviews include the mark image, settings, profile/model information, measurements, rating, notes, and decision so historical comparisons can be made.
- Pressure and speed remain available under the collapsed Gesture diagnostics because they are test inputs, not primary material controls.
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
- A shared **Smudge existing material** action lifts deposited pigment into a short-lived loose state using friction, packing, pressure, speed, and substrate roughness. Loose particles retain gesture-direction momentum, coast briefly after contact, lose energy, and settle without calling the deposition path or branching on a medium name.

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
- Latest review: `CH-LAB-1787105475421`, profile `material.charcoal.diagnostic.v0.4`.
- Rating: **Good**. Decision: **Accept for the smudge-motion scope**.
- Reviewed settings: pressure `0.77`, speed `1.00`, diagnostic visibility `1.00`; saved inactive load `0.70`, brush water `0.75`, and paper dampness `0.25`.
- Saved measurements: pigment area `17.13%`, deposited pigment `1580.78`, cumulative relocated pigment `2521.69`, conservation error `0.00045%`.
- Artist conclusion: the revised motion is “looking really good,” but final charcoal approval is withheld until it is tested on a better substrate.
- Still required: artist acceptance of paper tooth and pressure progression, coarse/fine fracture populations, bounded dusting, lift, burnishing/rejection, and a continuous failure range.
- Every visible charcoal conclusion requires artist review, with saved marks and settings.

## Reconciled validation status

- Gate 1 remains **pass**: both media fit the canonical vocabulary without private named-medium properties.
- Gate 2 is **partial and open**: several watercolor relationships, Hot Press/Rough uptake contrast, dry-charcoal tooth bands, pressure-driven valley reach, and CH-P-05 conservative smudge relocation are automated, while many numbered scenes remain unrun.
- Gate 3 is **partial, mandatory, and open**: watercolor v0.6 is artist-accepted only for its initial shared-interaction scope; charcoal v0.4 smudge motion is accepted only for that scope; neither medium has final acceptance.
- `docs/validation/watercolor/physics_tests.md` and `docs/validation/charcoal/physics_tests.md` now distinguish `automated_relationship_verified`, `artist_accepted_limited_scope`, `partial_not_isolated`, and `not_run` test by test.

## NEXT ACTION — start here

Complete the **CH-P-01 / CH-P-02 paper and pressure artist comparison** in `lab/diagnostic-lab.html`.

1. Refresh the lab, choose **Charcoal**, **Draw material**, and **Plain White**. Clear the surface.
2. Set pigment load `0.70`, speed `1.00`, pressure `0.25`, and diagnostic visibility `1.00`. Draw several steady strokes and save a rated review.
3. Change only the paper to **Rough**, clear, and repeat the same strokes. Judge whether peaks catch charcoal, valleys remain broken, and the paper looks/cooperates like a plausible drawing sheet rather than decorative noise. Save a second review.
4. Keep **Rough**, change only pressure to `0.75`, clear, and repeat. Judge whether greater pressure progressively reaches valleys while preserving paper character instead of merely scaling a dark stamp. Save a third review.
5. On Rough, make one dense mark at pressure about `0.70`, switch to **Smudge existing material**, and repeat the previously accepted push. Confirm the better tooth does not destroy the accepted loose-ridge motion.
6. Send the exported `CH-LAB-*.json` records. The next model must import them before changing CH-P-01 or CH-P-02 artist status.

**Success condition:** Rough is recognizably more toothy than Plain without looking like a pasted texture; light pressure favors peaks, firm pressure reaches more valleys continuously, and the accepted smudge motion survives.

**Outcome rule:** `Accept` advances to CH-P-03 / CH-P-04 fracture and dusting. `Recalibrate` adjusts only the independent substrate mapping/texture and repeats the matched papers. `Revise model` means the paper/contact relationship is systematically wrong; do not add a charcoal-only paper effect.

## IN FLIGHT

- Nothing. No simulation or documentation work is half-implemented.

## Recently completed

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

## Blocked and open questions

- Artist judgment of the recovered paper appearance and contact feel is pending. Automated height bands cannot determine whether Rough looks natural, feels appropriate for charcoal/pastel, or preserves expressive gesture.
- The archive paper numbers are application presets, not scientific measurements. Their canonical `TRAN-002` mapping is explicitly a normalized diagnostic stand-in.
- Live in-app browser inspection could not be completed in the implementation environment; page syntax, control structure, and solver behavior were checked, but the artist must refresh and inspect the actual lab.
- The lab has no production brush reservoir, spectral color, measured papers, full particle fracture/dust system, or production renderer.
- Rust is the intended production direction, but production implementation must wait until the shared foundation survives the stated validation scope.

## Do NOT

- Do not make a new watercolor-specific or charcoal-specific engine.
- Do not add flags such as `watercolorMode`, `charcoalMode`, `dryBrushMode`, or `bloomEffect` to make a test pass.
- Do not confuse stronger diagnostic visibility with more physical pigment.
- Do not rejoin paper dampness and mobile surface water; that caused weak, swollen moderate-water marks.
- Do not replace the accepted substrate → carrier → pigment → applicator relationship with a visual stamp or texture shortcut.
- Do not claim final watercolor acceptance. The accepted review is deliberately limited.
- Do not mark a formal physics row passed merely because the solver contains a related equation.
- Do not begin a production Rust/GPU engine before the validation-status reconciliation and the agreed v0.1 gates are complete.
