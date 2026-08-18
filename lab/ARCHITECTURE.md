# Diagnostic shared-solver architecture

The diagnostic lab now uses one shared state and contact system for watercolor and charcoal. Medium names select a property profile; they do not select separate painting engines.

## Shared state

Each substrate cell stores:

- mobile carrier;
- mobile pigment;
- deposited pigment;
- carrier absorbed by the substrate;
- deterministic surface tooth.

The lab exposes pigment load, brush water, and initial paper dampness separately. A zero-pigment, high-water gesture is therefore clean water using the same contact transaction rather than a separate bloom tool.

## Canonical property inputs

The profiles in `shared-solver.js` use canonical IDs from `PROPERTY_REGISTRY.yaml`:

- `COMP-001` carrier fraction;
- `COMP-003` pigment fraction;
- `STATE-001` material phase;
- `TRAN-001` diffusion coefficient;
- `TRAN-002` permeability;
- `DEPO-001` transfer efficiency;
- `SUBI-001` surface roughness;
- `SUBI-003` porosity;
- `EVOL-001` evaporation flux;
- `EVOL-003` settling velocity.

Profiles are validated before drawing. Their current values are explicitly labeled `stand-in`; they are artist-calibrated diagnostic values, not measured production constants.

## Named model correspondence

- contact uses `MODEL-DEPO-001`;
- carrier dispersion uses `MODEL-TRAN-001` and `MODEL-TRAN-003`;
- porous uptake approximates `MODEL-TRAN-002`;
- evaporation uses `MODEL-EVOL-001`;
- pigment settling is a diagnostic approximation associated with `MODEL-PART-001`.

Each saved review records the material profile, named models, state measurements, and pigment-conservation error beside the artist verdict.

## Current limits

This is a small CPU grid intended to expose behavior for review. It is not the production Rust/GPU solver. Spectral color, granulation, brush reservoirs, measured paper profiles, and artist-accepted clean-water blooms remain future work. Any visible conclusion still requires artist approval.
