# Validation gates

Sarasara has two sources of truth:

1. **Physics** tells us why a behavior should happen.
2. **Artists** tell us whether the behavior actually feels like the medium.

Neither source is sufficient alone. No medium graduates from experimental to canonical without passing all three gates:

```text
SCHEMA TORTURE TEST
        ↓
BEHAVIORAL PROTOTYPE TEST
        ↓
ARTIST VALIDATION
        ↓
ACCEPT / RECALIBRATE / REVISE MODEL
```

## The three gates

### 1. Schema torture test

Can the medium be described with the shared canonical properties? Are important behaviors missing? Does the description require a private medium-only escape hatch?

### 2. Behavioral prototype test

Once a minimal diagnostic solver exists, can it reproduce observable phenomena? This is not beautiful artwork. It is instrumentation: spreading, settling, drying, tooth capture, skipping, deposition, and particle relocation.

### 3. Artist reality test

Does a practicing artist recognize the medium without being told what is being simulated? The review covers pressure, speed, loading, depletion, layering, substrate response, irregularity, continuous wetness, expressive gestures, and believable failure.

“Indistinguishable” is not required for v0.1. The minimum useful result is **recognizable without prompting**, with a written note explaining what remains wrong.

## Review outcomes

- **Accept:** all required gates pass for the stated scope.
- **Recalibrate:** the vocabulary and model are appropriate, but measured ranges or response curves need adjustment.
- **Revise model:** the observed behavior is systematically wrong or requires a special-case property.
- **Blocked:** evidence, a working prototype, or artist access is missing. Blocked is not a pass.

Watercolor and charcoal each have their own reference behaviors, physics test plan, artist review sheet, and calibration notes in the sibling folders.
