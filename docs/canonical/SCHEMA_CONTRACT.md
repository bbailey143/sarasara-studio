# Canonical schema contract

This is the bridge between the language-neutral vocabulary and future code. It does not choose Rust, Dart, GPU, or a user-interface framework. It defines what every implementation must preserve.

## One material description

Every material is a document with these parts:

```yaml
id: material.watercolor.test
version: 0.1.0
components: []
state: {}
applicability: {}
provenance: []
```

- `id` is stable and human-readable.
- `version` changes when meaning or units change.
- `components` identifies the physical participants (for example pigment, carrier, and binder).
- `state` contains values from `PROPERTY_REGISTRY.yaml`; unknown properties are rejected rather than silently ignored.
- `applicability` says which phases and participants the values apply to.
- `provenance` records where a value came from and whether it is measured, estimated, or a temporary stand-in.

## Required guarantees

1. Every property uses its registry ID and canonical unit.
2. Values are checked against the registry domain before a simulation starts.
3. Missing values are reported as missing; they are never replaced by an unexplained default.
4. A model may read only the properties listed in `MODEL_REGISTRY.yaml`.
5. Conservation-sensitive models must expose a measurable before/after balance.
6. Time, distance, mass, and amount-of-substance use one explicit unit system at the boundary.
7. A visual-facing result must retain a trace back to the model and input properties that produced it.

## Validation record

Each run produces a small record:

```yaml
run_id: run-2026-08-18-001
material_id: material.watercolor.test
models: [MODEL-TRAN-002, MODEL-EVOL-001]
inputs: {}
physics_results: []
artist_review:
  required: true
  status: pending
  reviewer: null
  notes: null
```

`artist_review.required` is true whenever a result changes a visible or tactile behavior: spreading, edge formation, drag, skipping, opacity, dust, drying, layering, or failure behavior. A physics pass cannot mark such a result accepted by itself.

## Rejection rules

The implementation must stop before drawing when:

- a property ID is unknown;
- a value has no unit or falls outside its declared domain;
- a model consumes an undeclared property;
- a conservation check fails without being marked as an intentional approximation;
- an artist-required result has no review record.

The implementation may continue with an explicitly labeled `stand-in` only in an experimental run. Stand-ins cannot graduate a medium to canonical status.
