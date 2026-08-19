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
- Verified result on 2026-08-18 after CH-P-05 implementation: `shared solver checks passed`, including source/destination, pressure response, blank-paper, and conservation assertions.
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

The validation-status reconciliation is complete. Gate 2 and Gate 3 are explicitly partial and remain open. CH-P-05 now has a conservative shared smudge implementation and automated mass-ledger proof. The next phase is mandatory artist validation of that visible behavior.

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
- Current profiles are `material.watercolor.diagnostic.v0.6.1` and `material.charcoal.diagnostic.v0.3`. Watercolor v0.6.1 preserves the artist-reviewed v0.6 drawing constants and adds only stand-in friction/packing inputs for the shared smudge action; smudge itself is not artist-accepted for watercolor.
- Saved reviews include the mark image, settings, profile/model information, measurements, rating, notes, and decision so historical comparisons can be made.
- Pressure and speed remain available under the collapsed Gesture diagnostics because they are test inputs, not primary material controls.
- Diagnostic visibility changes display strength only; the automated test verifies it does not change physical state.

### Shared relationships currently represented

- Applicator contact transfers available material according to pressure, speed, moisture, and substrate tooth.
- Surface carrier, paper-held saturation, mobile pigment, and deposited pigment are separate state values.
- Paper dampness initializes paper-held saturation rather than a surface puddle.
- Pigment follows carrier movement and can settle/deposit; visibility is separate from physical quantity.
- Dry watercolor contact deposits pigment through tooth with no hidden water or dry-brush mode.
- Clean water uses the same contact transaction and may reactivate pigment without inventing pigment mass.
- Charcoal deposits dry particles with no carrier through the same shared contact/state framework.
- A shared **Smudge existing material** action relocates deposited pigment using friction, packing, pressure, speed, and substrate roughness without calling the deposition path or branching on a medium name.

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

- The lab has a shared-profile charcoal prototype and automated conservation/carrier guardrails.
- Formal charcoal validation records remain incomplete. Do not infer acceptance from the existence of earlier exported reviews unless their contents are imported and recorded in `docs/validation/charcoal/`.
- Still required: artist acceptance of smudge feel, tooth capture by height band, pressure progression into valleys, coarse/fine fracture populations, bounded dusting, lift, burnishing/rejection, and a continuous failure range.
- Every visible charcoal conclusion requires artist review, with saved marks and settings.

## Reconciled validation status

- Gate 1 remains **pass**: both media fit the canonical vocabulary without private named-medium properties.
- Gate 2 is **partial and open**: several watercolor relationships, the dry-charcoal baseline, and CH-P-05 conservative smudge relocation are automated, while many numbered scenes remain unrun.
- Gate 3 is **partial, mandatory, and open**: watercolor v0.6 is artist-accepted only for its initial shared-interaction scope; no canonical charcoal acceptance exists.
- `docs/validation/watercolor/physics_tests.md` and `docs/validation/charcoal/physics_tests.md` now distinguish `automated_relationship_verified`, `artist_accepted_limited_scope`, `partial_not_isolated`, and `not_run` test by test.

## NEXT ACTION — start here

Complete the **CH-P-05 artist validation** in `lab/diagnostic-lab.html`.

1. Refresh the lab, choose **Charcoal** and **Draw material**, and clear the surface.
2. Make two similar dense charcoal marks at pigment load `1.00`, speed `0.80`, and pressure about `0.70`.
3. Choose **Smudge existing material** without clearing. Drag once from the first dark mark into clean paper at pressure `0.25`; drag once from the second mark at pressure `0.75`. Keep speed `0.80`.
4. On an untouched blank area, make a smudge gesture. It must remain blank.
5. Judge:
   - does each source lighten while a softer trail gains charcoal;
   - does firm pressure move more existing charcoal than light pressure;
   - does the trail feel dusty, soft, and dragged rather than freshly painted, oily, or digitally blurred;
   - do repeated passes relocate material progressively rather than creating darkness;
   - does **Relocated by contact** increase while **Conservation error** remains near zero.
6. Add notes, choose a rating and decision, then **Save review record**. Send the exported `CH-LAB-*.json` to the next model.
7. The next model must import the review into `docs/validation/charcoal/artist_review.md` and `calibration_notes.md` before changing status.

**Success condition:** the saved review recognizes the effect as existing charcoal being pushed and softened. Automated conservation alone is not acceptance.

**Outcome rule:** `Accept` advances to CH-P-01/CH-P-02 tooth and pressure height-band measurements. `Recalibrate` adjusts the shared `TRIB-002` / `DEPO-004` contact response and repeats the same matched gestures. `Revise model` means the visible failure is systematic; do not add a charcoal-only shortcut.

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

## Blocked and open questions

- Charcoal artist evidence may exist in exported JSON files outside the repository, but it has not been established as canonical in the present docs.
- CH-P-05 artist feel is pending. The automated ledger cannot determine whether the smudge looks dusty, oily, too weak, too strong, or digitally blurred.
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
