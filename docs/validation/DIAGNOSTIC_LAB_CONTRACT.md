# Diagnostic lab contract

The first working prototype should be a small diagnostic lab, not a polished painting app. Its purpose is to make one physical claim visible, adjustable, and reviewable.

## Required panels

1. **Material setup** — choose watercolor or charcoal, paper, load, pressure, speed, and wetness.
2. **Observation canvas** — show the simulated mark and a simple reference target beside it.
3. **Measurements** — show only useful readings: deposited amount, spread distance, edge contrast, valley contact, and conservation error.
4. **Review card** — record the artist rating, notes, and whether the result is accepted, recalibrated, or rejected.

## First experiments

### Watercolor

- damp paper spread;
- pigment/carrier separation;
- drying edge formation;
- one failure case: puddling or cauliflower bloom.

### Charcoal

- tooth capture;
- valley skipping;
- pressure-driven deposition;
- one failure case: dusting or broken deposition.

## Artist approval is a required step

For every experiment, the lab must present the physics conclusion in plain language, then require an artist review when that conclusion affects perception. For example:

> “Increasing pressure increased valley contact by 18%.”

The artist must answer whether the change feels like real charcoal before the result can be marked accepted. A numeric pass with an artist rejection is `recalibrate`, not `pass`.

## Minimum acceptance record

```yaml
experiment_id: WC-DRY-001
physics_status: pass
artist_status: pending
artist_rating: null
artist_notes: null
decision: pending
```

The lab is ready for implementation only when it can save this record alongside the run inputs and model names.
