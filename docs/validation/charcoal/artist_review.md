# Charcoal artist review

**Reviewer:** ____________________
**Date:** ____________________
**Prototype/build:** ____________________
**Substrate/tooth:** ____________________
**Tool/load:** ____________________

## Recognition gate

Without being told the intended medium, does the reviewer identify this as charcoal from the behavior alone?

- [ ] Unconvincing
- [ ] Recognizable
- [ ] Good
- [ ] Convincing
- [ ] Indistinguishable in behavior

**Minimum v0.1:** Recognizable without prompting, with believable brittle, dusty, draggy, and broken behavior for the stated charcoal profile.

## Behavior ratings

| Behavior | Unconvincing | Recognizable | Good | Convincing | Notes |
| --- | --- | --- | --- | --- | --- |
| Pressure changes deposition naturally | [ ] | [ ] | [ ] | [ ] | |
| Speed changes drag and breakup plausibly | [ ] | [ ] | [ ] | [ ] | |
| Loading and run-out feel continuous | [ ] | [ ] | [ ] | [ ] | |
| Tooth catch and valley skipping feel right | [ ] | [ ] | [ ] | [ ] | |
| Dusting and broken deposition feel believable | [ ] | [ ] | [ ] | [ ] | |
| Smudging relocates existing particles | [ ] | [ ] | [ ] | [ ] | |
| Lifting responds like a real mark | [ ] | [ ] | [ ] | [ ] | |
| Burnishing changes future capture and appearance | [ ] | [ ] | [ ] | [ ] | |
| Accidents and irregularities feel believable | [ ] | [ ] | [ ] | [ ] | |

## Decision

- [ ] Accept for this scope
- [ ] Recalibrate
- [ ] Revise model
- [ ] Block pending better evidence or prototype

**What felt wrong first?**

______________________________________________________________________________

**Which expressive gesture failed?**

______________________________________________________________________________

**Which believable failure was missing or overdone?**

______________________________________________________________________________

## Recorded review — CH-LAB-1787103913509

- **Date:** 2026-08-18
- **Prototype/build:** `material.charcoal.diagnostic.v0.3`
- **Action:** Smudge existing material
- **Settings:** pressure `0.25`, speed `0.80`, pigment load `1.00`; the saved inactive brush-water and paper-dampness values were `0.75` and `0.25`.
- **Rating:** **Good**
- **Decision:** **Recalibrate**
- **Saved evidence:** pigment area `17.24%`, deposited pigment `5108.84`, cumulative relocated pigment `5567.64`, conservation error below `0.001%`.

The artist recognized the sense of pushing dense particles, but the movement also felt like putty because everything stopped as soon as the smudge gesture stopped. A believable pass should form a small loose ridge beneath and ahead of the contact, allow that ridge to retain a little forward movement after the hand lifts, then lose energy and settle. This review does **not** accept CH-P-05; it requires another artist pass on the recalibrated behavior.

## Recorded review — CH-LAB-1787105475421

- **Date:** 2026-08-18
- **Prototype/build:** `material.charcoal.diagnostic.v0.4`
- **Action:** Smudge existing material
- **Settings:** pressure `0.77`, speed `1.00`, diagnostic visibility `1.00`; the saved inactive pigment-load, brush-water, and paper-dampness values were `0.70`, `0.75`, and `0.25`.
- **Rating:** **Good**
- **Decision:** **Accept for the v0.4 smudge-motion scope**
- **Saved evidence:** pigment area `17.13%`, deposited pigment `1580.78`, loose pigment effectively settled at save time, cumulative relocated pigment `2521.69`, conservation error `0.00045%`.

The artist described the revised motion as “looking really good.” CH-P-05’s loose-ridge motion and settling are accepted for this diagnostic checkpoint. This is **not final charcoal approval**: the reviewer explicitly withheld that until the placeholder substrate is replaced and compared with better paper, pointing to the archived watercolor and charcoal/pastel-oriented paper work as useful evidence.

## Recorded review — CH-LAB-1787107111788

- **Date:** 2026-08-18
- **Material/build:** `material.charcoal.diagnostic.v0.4`
- **Substrate:** `substrate.paper.plain-white.archive-seed.v0.1` — Plain White
- **Action:** Smudge existing material
- **Settings:** pressure `0.96`, speed `1.00`, diagnostic visibility `1.00`; the saved inactive pigment-load, brush-water, and paper-dampness values were `0.70`, `0.75`, and `0.25`.
- **Rating:** **Convincing**
- **Decision:** **Accept for this smudge/substrate scope**
- **Saved evidence:** pigment area `31.00%`, deposited pigment `3922.91`, loose pigment effectively settled at save time, cumulative relocated pigment `6220.98`, conservation error `0.00070%`.

The artist reported that the smudge was “so much fun to use.” This strengthens CH-P-05’s limited artist acceptance and confirms that separating the paper profile did not break the accepted smudge motion on the flat control sheet. A desired minor improvement is believable small particle flicks. That belongs to CH-P-03 / CH-P-04 fracture and dusting, where detached particles must have a bounded physical source and mass ledger; it must not be added as arbitrary random decoration.

This record does not decide CH-P-01 or CH-P-02: Plain White is intentionally flat, the action was smudge rather than draw, and pressure was `0.96`. Rough-paper light/firm drawing comparisons are still required.

## Direct artist follow-up — Rough paper scale

- **Source:** Conversation follow-up after the archive-seeded paper comparison; no new exported JSON was supplied.
- **Behavioral verdict:** **Pass in principle** — charcoal smudged up and over valleys, which matched the expected physical behavior.
- **Paper verdict:** **Recalibrate** — ridges and valleys appeared severely zoomed-in and much larger than in the previous application, making the paper difficult to judge.

The v0.1 implementation had inverted the archived grain-scale direction. Substrate v0.2 corrects that mapping and makes the tooth substantially finer while leaving material and smudge physics unchanged. CH-P-01 / CH-P-02 artist approval remains pending until the corrected Rough paper is reviewed.

## Recorded review — CH-LAB-1787107972495

- **Date:** 2026-08-18
- **Material/build:** `material.charcoal.diagnostic.v0.4`
- **Substrate:** `substrate.paper.rough.archive-seed.v0.2` — now labeled **Rough Watercolor Paper**
- **Action:** Smudge existing material
- **Settings:** pressure `1.00`, speed `1.00`, diagnostic visibility `1.00`; the saved inactive pigment-load, brush-water, and paper-dampness values were `0.70`, `0.75`, and `0.25`.
- **Rating:** **Good**
- **Decision:** **Accept for the smudge-motion scope; reject this paper for charcoal evaluation**
- **Saved evidence:** pigment area `26.00%`, deposited pigment `2992.55`, loose pigment effectively settled at save time, cumulative relocated pigment `5991.20`, conservation error `0.00032%`.

The charcoal behavior remained good, so CH-P-05's limited acceptance stands. The artist again found the paper ugly and its peaks and valleys too dramatic, noting that this Rough preset was created for watercolor and was less exaggerated there. That is a substrate verdict, not a failure of charcoal smudging.

The archived Rough profile remains available for wet-media comparison and is no longer the charcoal recommendation. A generic **Fine-Tooth Drawing Paper v0.1** candidate was added as an immediate response, then superseded before artist review when the artist supplied Pastel White and Pastel Light Cream samples. Charcoal now defaults to sample-guided **Pastel Paper — White**, with **Pastel Paper — Light Cream** sharing exactly the same physical tooth. These candidates have passed automated relationship checks but require fresh artist review before CH-P-01 or CH-P-02 can graduate.

## Recorded review — CH-LAB-1787110275815

- **Date:** 2026-08-18
- **Material/build:** `material.charcoal.diagnostic.v0.4`
- **Substrate:** `substrate.paper.pastel-white.reference-derived.experimental.v0.2` — Pastel Paper — White
- **Action:** Smudge existing material
- **Settings:** pressure `0.26`, speed `1.00`, diagnostic visibility `1.00`; the saved inactive pigment-load, brush-water, and paper-dampness values were `0.70`, `0.75`, and `0.25`.
- **Rating:** **Convincing**
- **Decision:** **Accept for Pastel White appearance and low-pressure smudge scope**
- **Saved evidence:** pigment area `14.83%`, deposited pigment `2008.50`, loose pigment effectively settled at save time, cumulative relocated pigment `445.39`, conservation error `0.00012%`.
- **Artist note:** “Pastel paper is gold!”

This accepts the sample-guided Pastel White surface as an artist-convincing ground for the reviewed smudge and confirms that the already accepted loose-particle motion survives at low pressure on the new fibrous paper. It does **not** complete CH-P-01 or CH-P-02: the saved action was Smudge, not Draw, and there is no matched firm-pressure drawing record. Pastel Light Cream also remains unreviewed.

## Direct artist follow-up — complete Pastel Paper pass

- **Source:** Conversation follow-up after `CH-LAB-1787110275815`; no additional exported JSON was supplied.
- **Clarification:** The artist completed every prescribed comparison and exported only one representative iteration.
- **Reviewed scope:** Pastel White Draw at pressure `0.25`; matched Pastel White Draw at `0.75`; matched Pastel Light Cream comparison; dense-mark smudging on the fibrous paper.
- **Decision:** **Accept for the complete Pastel Paper v0.2 diagnostic scope.**

The artist approves the fine-fiber appearance, light-pressure peak/fiber capture, progressive firm-pressure reach into shallow gaps, White/Cream behavior parity, and preservation of the accepted smudge motion. The prior paragraph remains as the correct interpretation of the JSON by itself; this direct statement supplies the missing artist evidence and closes CH-P-01 and CH-P-02 for this experimental substrate scope.

This is not final charcoal-medium or production-paper approval. Coarse/fine fracture populations, bounded dusting, lift, burnishing, and failure-range behavior remain open.

## Pending artist gate — charcoal v0.5 fracture and bounded dusting

Use **Pastel Paper — White** and **Draw material**. First make a short comparison stroke at pigment load `0.35`, pressure `0.25`, speed `0.35`. Clear the surface, then make the same gesture at load `1.00`, pressure `0.85`, speed `1.60`.

Approve CH-P-03 / CH-P-04 only if all of these are true:

- coarse crumbs remain nearer the stroke and settle sooner than the finest dust;
- fine dust travels a little farther but still looks shed by the gesture;
- increasing load, pressure, or speed strengthens breakup continuously;
- particles are irregular consequences of contact, not an even spray, glitter, or decorative speckle layer;
- the main stroke still catches the accepted Pastel Paper fibers;
- after motion ends, the conservation reading remains below `1%`;
- a blank smudge creates no crumbs or dust.

Rate the visible result **Unconvincing**, **Recognizable**, **Good**, **Convincing**, or **Indistinguishable in behavior**, then choose **Accept**, **Recalibrate**, or **Revise model** and save the review JSON. Automated checks do not satisfy this artist gate.
