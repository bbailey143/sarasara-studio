# Watercolor reference behaviors

These are the phenomena a human should be able to recognize before the simulation is called watercolor. They describe observations, not implementation tricks.

| Behavior | Expected observation | Canonical causes |
| --- | --- | --- |
| Spread into damp paper | A fresh wash travels farther through an already damp region than across a dry one. | `TRAN-003`, `SUBI-002`, `SUBI-003`, `STATE-003` |
| Pigment settles differently from carrier | Water can move or evaporate while heavier or more settling-prone pigment remains behind. | `PART-001`, `PART-002`, `EVOL-003`, `RHEO-001` |
| Drying edge | Pigment gathers or changes optical density at a receding wet boundary. | `EVOL-001`, `STATE-003`, `DEPO-004`, `OPT-001`, `OPT-002` |
| Wet-into-wet mixing | A crossing of two active colors becomes one subtractive mixture, not two intact stamps. | `TRAN-004`, `DEPO-001`, `OPT-001`, `OPT-002` |
| Bloom/backrun | A clean-water event pushes or reopens nearby pigment without creating a hollow, artificial ring every time. | `REAC-001`, `TRAN-003`, `STATE-003` |
| Loading and depletion | The brush starts loaded, releases material through contact, and runs down in a continuous way. | `COMP-001`, `DEPO-001`, `DEPO-002`, future applicator contract |
| Substrate character | Smooth and toothy/porous papers produce meaningfully different edges and uptake. | `SUBI-001`, `SUBI-002`, `SUBI-003`, `INTF-002` |
| Believable failure | Puddling, cauliflower blooms, overworking, muddy mixing, and dryback can occur as consequences rather than mode switches. | `EVOL`, `REAC`, `TRAN`, `DEPO`, `OPT` |

The artist should be able to recognize the material from these behaviors without being told which medium the prototype represents.
