# Oil behavioral prototype tests

Oil is the third-material vocabulary test recorded in
[`ADR-0002`](../../decisions/ADR-0002-OIL-VOCABULARY-TEST.md). It exists to
challenge the shared architecture at the one place watercolor and charcoal
never contest: **bulk motion**. Watercolor flows freely; charcoal does not move
until rubbed; oil holds its shape until pushed past a threshold.

Every value in `material.oil.diagnostic.v0.1` is an unmeasured normalized
stand-in. Nothing below is a claim that oil looks like oil.

| ID | Test | Observable check | Result |
| --- | --- | --- | --- |
| OL-P-01 | Holds its shape | A mound below the yield stress does not spread. | `automated_relationship_verified` — at 0.5× and 1.0× the yield stress a mound keeps 100% of its peak and moves exactly zero mass over 30 frames. |
| OL-P-02 | Slumps above yield | A mound above the yield stress spreads, and the excess governs how much. | `automated_relationship_verified` — at 8× yield the peak keeps 31.7%; at 40× it keeps 19.5%. A profile with a quarter of the yield stress slumps strictly more from the same mound. Mass drift stays below 4e-6. |
| OL-P-03 | The brush pushes a body | Contact above the yield stress relocates existing material along the stroke; contact below it does not. | `automated_relationship_verified` — at yield stress 0.34, pressures 0.20 and 0.34 displace exactly 0%; 0.50 displaces 8.8%, 0.75 displaces 38.9%, 1.00 displaces 60.0%. Displacement conserves mass to 3e-8. |
| OL-P-04 | It stands up | Relief height rises with deposited mass and follows packing and particle density. | `automated_relationship_verified` — `DEPO-005` equals deposited mass over packing × density to 1e-9, and more mass stands taller. Derived only; never authored in a profile. |
| OL-P-05 | No carrier wetting | A body never wets or soaks the sheet, even when carrier water is offered. | `automated_relationship_verified` — a 60-frame stroke drawn with brush water 0.6 leaves surface water and absorbed water at exactly 0. Carrier water offered directly at the contact is also refused. |
| OL-P-06 | Zero pigment diffusion | Oil pigment never enters the suspended state and never spreads on its own. | `automated_relationship_verified` — suspended pigment stays exactly 0 across a full stroke and 30 steps; `TRAN-001` is 0 in the profile. |
| OL-P-07 | Dirty brush | Painting into a wet layer picks material up onto the tool. | `not_run` — `DEPO-003` is present in the profile but no pickup path consumes it yet. |
| OL-P-08 | Cure | The layer sets over days and stops accepting rework. | `not_run` — no cure clock or `EVOL-002` state transition exists. |
| OL-P-09 | Relief reads as relief | Ridges and brush marks catch light believably. | `artist_review_required` — diagnostic relief shading exists and is code-verified only as a function of the height gradient. Whether it reads as paint is unknown until reviewed. |
| OL-P-10 | Scrape and wipe | A scraping gesture removes a bounded portion of the layer. | `not_run` — no removal gesture exists. |

## Shared-architecture regression

The new layer must be invisible to the materials that do not have a yield
stress. This is checked directly, not assumed:

- Watercolor and charcoal both report `flowLayer()` moving exactly `0`.
- After a full stroke, the deposited array of each is **bit-for-bit identical**
  before and after the shared layer pass.
- Both keep their existing regimes: watercolor `flowing`, charcoal `granular`.
- No method in the shared layer branches on a material name; this is asserted
  against the function source, matching the existing calibration check.

## Same gesture, three recipes, one path

A single stroke (pressure 0.70, load 1.00, brush water 0.45, speed 0.90) run
through the same code with only the recipe changed:

| Recipe | Regime | Deposited | Suspended | Surface water | Conservation error |
| --- | --- | --- | --- | --- | --- |
| watercolor | flowing | 3.043 | 22.003 | 62.050 | 0.000000% |
| charcoal | granular | 10.486 | 0.000 | 0.000 | 0.000000% |
| oil | body | 42.841 | 0.000 | 0.000 | 0.000000% |

Three materially different results, no medium-name branch anywhere in the path.

## Not yet evidence of anything visual

No artist has drawn with this. The stand-in yield stress, viscosity, packing,
density, transfer efficiency, relief shading, and colour are all unmeasured.
OL-P-09 is the gate that matters, and it is open.
