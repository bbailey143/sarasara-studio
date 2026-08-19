# Diagnostic shared-solver architecture

The diagnostic lab now uses one shared state and contact system for watercolor and charcoal. Medium names select a property profile; they do not select separate painting engines.

## Shared state

Each substrate cell stores:

- mobile carrier;
- mobile pigment;
- deposited pigment;
- carrier held as paper saturation, separately from mobile surface water;
- deterministic surface tooth.

The lab exposes pigment load, brush water, and initial paper dampness separately. A zero-pigment, high-water gesture is therefore clean water using the same contact transaction rather than a separate bloom tool.

The pigment-load control represents pigment available at the applicator contact. Its mapping to deposited mass is state-aware: a suspension and a dry powder use the same contact model but different available-mass scales. This keeps watercolor concentration adjustable without changing carrier delivery or altering the already reviewed charcoal profile.

Watercolor contact is continuous across moisture levels. Brush moisture and existing paper moisture combine into one contact-wetness value. At its dry end, surface tooth and pressure determine which cells receive directly deposited pigment; as moisture increases, the same contact progressively becomes continuous and transfers more pigment into the mobile suspension. There is no named dry-brush mode or hidden carrier at zero brush water.

The v0.6 damp interval follows relationships recovered from the archived watercolor reference. The artist-facing brush-water control maps nonlinearly to delivered surface carrier, while `STATE-003`-like paper saturation remains a separate slower store. Paper-held water supports only partial mobility. At lower surface-water levels, `SUBI-001` tooth restricts connected carrier flow and mechanically retains part of the pigment; abundant surface water progressively overwhelms that resistance and recovers the previously reviewed full-wet transport. The archive's exact constants are evidence, not copied production truth.

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
- `EVOL-003` settling velocity;
- `REAC-001` rewetting sensitivity;
- `REAC-002` dissolution/release fraction;
- `REAC-003` redispersion coefficient;
- `REAC-004` reactivation threshold.

Profiles are validated before drawing. Their current values are explicitly labeled `stand-in`; they are artist-calibrated diagnostic values, not measured production constants.

## Named model correspondence

- contact uses `MODEL-DEPO-001`;
- carrier dispersion uses `MODEL-TRAN-001` and `MODEL-TRAN-003`;
- porous uptake approximates `MODEL-TRAN-002`;
- evaporation uses `MODEL-EVOL-001`;
- pigment settling is a time-scaled diagnostic approximation associated with `MODEL-PART-001`;
- clean-water release uses `MODEL-REAC-001` and returns deposited pigment to the mobile state without adding pigment mass.

Water movement is computed first. Pigment then follows that water flux according to the local pigment-to-water ratio, with only a small separate dispersion term. This keeps visible spreading tied to carrier movement instead of making pigment expand on its own.

Each saved review records the material profile, named models, state measurements, and pigment-conservation error beside the artist verdict.

## Current limits

This is a small CPU grid intended to expose behavior for review. It is not the production Rust/GPU solver. Spectral color, granulation, brush reservoirs, measured paper profiles, and artist-accepted clean-water blooms remain future work. The v0.3 values deliberately make transport easier to observe, but they remain stand-ins. Any visible conclusion still requires artist approval.
