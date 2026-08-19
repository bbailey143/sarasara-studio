# Charcoal behavioral prototype tests

The lab should show particles, contact load, surface height/tooth, deposited amount, and optical result separately.

| ID | Test | Observable check | Result |
| --- | --- | --- | --- |
| CH-P-01 | Tooth capture | Light contact deposits on raised substrate regions before valleys. | `not_run` — the current charcoal baseline deposits through deterministic tooth, but no raised-versus-valley mass measurement or canonical artist record isolates this test. |
| CH-P-02 | Pressure progression | Increasing pressure progressively increases valley contact rather than scaling a fixed stamp. | `not_run` — a shared pressure relationship is checked for dry watercolor contact, not for matched charcoal height bands. |
| CH-P-03 | Fracture population | A brittle source creates distinct coarse and fine particle populations under loading. | `not_run` — the solver has no distinct coarse/fine particle ledger. |
| CH-P-04 | Dusting | Fine particles detach and settle outside the main contact in a bounded way. | `not_run` — no detached-dust population or bounded dust scene exists. |
| CH-P-05 | Smudge transport | Sliding contact relocates deposited particles; it does not create new pigment from nowhere. | `not_run` — the lab can draw but cannot yet perform a non-depositing relocation gesture. This is the next implementation target. |
| CH-P-06 | Lift | A later lifting gesture removes a bounded portion governed by adhesion, cohesion, and contact. | `not_run` — no lifting contact or removed-particle ledger exists. |
| CH-P-07 | Burnish | Repeated compression changes packing/optics and eventually reduces fresh capture. | `not_run` — no packing/history state or fresh-capture comparison exists. |
| CH-P-08 | Failure range | Broken deposition and dusting vary continuously with load, speed, tooth, and history. | `not_run` — no continuous failure-envelope scene or canonical artist record exists. |

The prototype must keep a mass ledger for detached, deposited, lifted, and remaining particles.

## Verified baseline outside the numbered gates

The automated lab check verifies only that the charcoal profile deposits dry pigment, deposits no liquid carrier, and keeps pigment conservation error below 1%. That baseline proves the shared solver can represent a carrier-free deposit; it does not pass CH-P-01 through CH-P-08. No canonical charcoal artist acceptance is recorded yet.
