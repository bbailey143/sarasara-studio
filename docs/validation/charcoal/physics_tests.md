# Charcoal behavioral prototype tests

The lab should show particles, contact load, surface height/tooth, deposited amount, and optical result separately.

| ID | Test | Observable check | Result |
| --- | --- | --- | --- |
| CH-P-01 | Tooth capture | Light contact deposits on raised substrate regions before valleys. | `automated_relationship_verified` — on sample-guided Pastel Paper, matched light contact has greater average deposited mass on raised fibers than in the shallow gaps. Artist review is pending. |
| CH-P-02 | Pressure progression | Increasing pressure progressively increases valley contact rather than scaling a fixed stamp. | `automated_relationship_verified` — matched firm contact increases average deposited mass in the Pastel Paper gap band relative to light contact. Artist pressure progression is pending. |
| CH-P-03 | Fracture population | A brittle source creates distinct coarse and fine particle populations under loading. | `not_run` — the solver has no distinct coarse/fine particle ledger. |
| CH-P-04 | Dusting | Fine particles detach and settle outside the main contact in a bounded way. | `not_run` — no detached-dust population or bounded dust scene exists. |
| CH-P-05 | Smudge transport | Sliding contact relocates deposited particles; it does not create new pigment from nowhere. | `artist_accepted_limited_scope` — shared contact reduces source-region pigment, increases destination-region pigment, creates a transient loose ridge that continues briefly in the gesture direction and then settles, moves more under firm than light matched pressure, leaves `initialPigment` unchanged, creates nothing on blank paper, and keeps total pigment error below 1%. `CH-LAB-1787105475421` rated v0.4 Good / Accept, `CH-LAB-1787107111788` rated a high-pressure Plain White smudge Convincing / Accept, `CH-LAB-1787107972495` rated the motion Good / Accept while separately rejecting Rough as charcoal paper, and `CH-LAB-1787110275815` rated a pressure-`0.26` Pastel White smudge Convincing / Accept with the note “Pastel paper is gold!” Final charcoal approval remains open. |
| CH-P-06 | Lift | A later lifting gesture removes a bounded portion governed by adhesion, cohesion, and contact. | `not_run` — no lifting contact or removed-particle ledger exists. |
| CH-P-07 | Burnish | Repeated compression changes packing/optics and eventually reduces fresh capture. | `not_run` — no packing/history state or fresh-capture comparison exists. |
| CH-P-08 | Failure range | Broken deposition and dusting vary continuously with load, speed, tooth, and history. | `not_run` — no continuous failure-envelope scene or canonical artist record exists. |

The prototype must keep a mass ledger for detached, deposited, lifted, and remaining particles.

## Verified baseline outside the numbered gates

The automated lab verifies that the charcoal profile deposits dry pigment, deposits no liquid carrier, and keeps pigment conservation error below 1%. CH-P-01 and CH-P-02 now isolate fiber capture and pressure-driven gap reach on sample-guided Pastel Paper. CH-P-05 checks conservative relocation, post-contact momentum, and settling, and its v0.4 motion has limited artist acceptance. Artist Pastel Paper/pressure review plus CH-P-03, CH-P-04, and CH-P-06 through CH-P-08 remain open. No final charcoal-medium acceptance is recorded.
