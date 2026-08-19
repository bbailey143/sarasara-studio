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
- Verified result on 2026-08-18 after the pastel samples were mapped: `shared solver checks passed`, including material/substrate separation, identical physical tooth for White/Cream, much lower Pastel relief than Rough Watercolor Paper, finer fiber frequency, peak/gap capture, pressure-driven gap reach, Hot Press versus Rough uptake, smudge momentum/settling, blank-paper behavior, and conservation assertions.
- Verified command: `git diff --check`
- Verified result on 2026-08-18 during the GitHub cleanup checkpoint: passed with no whitespace errors.
- Verified the inline lab script parses, each required control ID occurs exactly once, and `smudgeSegment` contains no `watercolor` or `charcoal` branch. Live visual browser inspection remains pending as recorded below.
- The baton was introduced in local commit `f1be021` (`docs: add durable AI handoff baton`).
- The original nine-commit checkpoint was published through `bcc0e6b` on `origin/vnext-bootstrap`.
- Archived AI guidance was restored exactly as root `CLAUDE.md` in commit `9c48cc6`.
- The user explicitly authorized publishing every current `vnext-bootstrap` commit to `https://github.com/bbailey143/sarasara-studio.git` during this cleanup checkpoint.
- Fine-Tooth implementation and review history were published in commit `40f19f1` (`feat: add fine-tooth charcoal paper`).
- Sample-guided Pastel White/Cream profiles were published in commit `00dff73` (`feat: calibrate pastel paper from artist samples`).
- Pastel White artist acceptance was published in commit `e80f8d9` (`docs: accept pastel white charcoal smudge`).
- Always verify publication with `git status --short --branch`; a clean published checkpoint shows no `ahead` count.

## Current objective

Prove that one shared, property-driven material architecture can describe and produce recognizable watercolor and charcoal without named-medium engines or hidden special cases. The current browser lab is a diagnostic instrument for that proof, not the production painting application.

The validation-status reconciliation is complete. Gate 2 and Gate 3 are explicitly partial and remain open. Charcoal v0.4 smudge motion, Pastel Paper fiber capture, and pressure-driven gap reach are artist-accepted for their stated diagnostic scopes. The artist clarified that every prescribed Pastel White/Light Cream test was performed and approved although only one representative JSON was exported. The next phase is CH-P-03 / CH-P-04 fracture and physically bounded dusting.

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
- Paper is now a separate participant selected independently from material. The lab offers archive-seeded Plain White, Hot Press, Cold Press, and Rough Watercolor Paper plus reference-derived experimental Pastel Paper — White and Light Cream; saved reviews record the selected substrate ID, name, and provenance.
- The commercial 5100 × 5100 samples are not copied into the repository. Their measured base color, low contrast, and visible fiber scale guide the procedural profiles; physical height/friction remain stand-ins. White and Cream share exactly the same physical tooth, so color cannot alter charcoal behavior.
- The archive contains no separately named charcoal/pastel paper. Charcoal now selects Pastel Paper — White by default. This UI default does not change material physics or create a named-medium engine branch.
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
- `CH-LAB-1787105475421` rated the v0.4 motion **Good / Accept for the smudge-motion scope**, while withholding final charcoal approval pending better paper.
- `CH-LAB-1787107111788` rated a Plain White smudge **Convincing / Accept** and described it as “so much fun to use.” Minor desired improvement: believable small particle flicks.
- Latest review: `CH-LAB-1787107972495`, charcoal v0.4 on Rough v0.2. Rating **Good**; decision split into **Accept for smudge motion / reject Rough for charcoal evaluation**.
- Latest settings: smudge, pressure `1.00`, speed `1.00`, diagnostic visibility `1.00`. Measurements: pigment area `26.00%`, deposited pigment `2992.55`, cumulative relocated pigment `5991.20`, conservation error `0.00032%`.
- Artist conclusion: charcoal movement still looked good, but the paper remained ugly and too dramatic; the artist correctly identified Rough as a watercolor-oriented preset.
- Correction: fixing the inverted archived grain scale was necessary but did not make Rough suitable for charcoal. Do not keep tuning that wet-media paper toward dry-media needs.
- Generic Fine-Tooth v0.1 was superseded before artist review. Sample-guided Pastel White/Cream v0.2 use identical fibrous tooth with different ground colors. Automated relationships pass. `CH-LAB-1787110275815` artist-accepted Pastel White appearance and low-pressure smudging as Convincing; direct follow-up confirms all prescribed light/firm Draw and Light Cream comparisons were also performed and approved.
- CH-P-01 and CH-P-02 are artist-accepted for Pastel Paper v0.2's diagnostic scope. Still required: coarse/fine fracture populations, bounded dusting, lift, burnishing/rejection, and a continuous failure range.
- Every visible charcoal conclusion requires artist review, with saved marks and settings.

## Reconciled validation status

- Gate 1 remains **pass**: both media fit the canonical vocabulary without private named-medium properties.
- Gate 2 is **partial and open**: several watercolor relationships, Hot Press/Rough uptake contrast, dry-charcoal tooth bands, pressure-driven valley reach, and CH-P-05 conservative smudge relocation are automated, while many numbered scenes remain unrun.
- Gate 3 is **partial, mandatory, and open**: watercolor v0.6 is artist-accepted only for its initial shared-interaction scope; charcoal v0.4 smudge motion is accepted only for that scope; neither medium has final acceptance.
- `docs/validation/watercolor/physics_tests.md` and `docs/validation/charcoal/physics_tests.md` now distinguish `automated_relationship_verified`, `artist_accepted_limited_scope`, `partial_not_isolated`, and `not_run` test by test.

## NEXT ACTION — start here

Build the smallest CH-P-03 / CH-P-04 **fracture and bounded dusting diagnostic** in `lab/shared-solver.js`, `lab/shared-solver.test.js`, and `lab/diagnostic-lab.html`. Do this before adding lift or burnish because the artist-requested small particle flicks need a conserved physical source rather than decorative randomness.

1. Extend the shared particle state with distinct coarse-fragment and fine-dust populations. Trigger fracture from shared properties—powder/solid phase, available source mass, pressure, tangential speed, packing/cohesion proxies, and substrate tooth—not from the word `charcoal`.
2. Every detached fragment must be removed from an existing source: applicator-available mass during Draw or deposited/loose mass during later contact. Track remaining, deposited, loose, coarse, fine-dust, settled, and lost/off-canvas mass so the total error stays below `1%`.
3. Coarse fragments should remain nearer the main contact and settle quickly. Fine dust may travel farther and settle more slowly. Neither population may appear on blank contact or when the profile lacks a brittle particulate source.
4. Add lab readings for **Coarse fragments** and **Fine dust**, include them in saved review JSON/history, and add artist instructions that distinguish believable brittle crumbs/dust from decorative speckles.
5. Add matched automated scenes: low versus high loading/pressure/speed; coarse-near versus fine-far distribution; post-contact settling; blank-contact zero creation; identical-command determinism; conservation below `1%`; and a check that the implementation contains no `watercolor`/`charcoal` named branch.
6. Run `node lab/shared-solver.test.js`, parse the inline lab script, verify required IDs occur once, run `git diff --check`, then return the new diagnostic for mandatory artist review. Do not mark CH-P-03 or CH-P-04 accepted from automation alone.

**Success condition:** the lab exposes two physically sourced particle populations whose amount and travel respond continuously to gesture/material/substrate inputs, settle plausibly, and remain mass-conservative without a named-medium shortcut.

**Outcome rule:** after code verification, artist review decides `Accept`, `Recalibrate`, or `Revise model`. Only artist acceptance advances to CH-P-06 lift.

## IN FLIGHT

- The direct artist clarification is being recorded locally. After commit/push, no implementation is in flight; CH-P-03 / CH-P-04 is the next new task.

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
- Small particle flicks require a physically bounded detached-particle population and mass ledger in CH-P-03/CH-P-04; no such state exists yet.
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
- Do not satisfy the requested particle flicks with decorative randomness; they must come from conserved fracture/dusting state.
- Do not tune Rough Watercolor Paper until it serves charcoal. Keep wet-media and dry-media papers as independent substrate profiles.
- Do not begin a production Rust/GPU engine before the validation-status reconciliation and the agreed v0.1 gates are complete.
