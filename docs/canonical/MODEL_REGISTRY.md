# Equation and Model Registry v0.1

The property registry says what exists. The interaction matrix says who meets. This registry says which equation or constitutive model relates the inputs under stated assumptions.

A model is not automatically truth. It is a named hypothesis with a domain, failure modes, and validation obligations. The machine-readable source is [`MODEL_REGISTRY.yaml`](MODEL_REGISTRY.yaml).

## Model lifecycle

```text
MODEL HYPOTHESIS
      ↓
PHYSICS VALIDATION
      ↓
REFERENCE OBSERVATION VALIDATION
      ↓
ARTIST-EYE VALIDATION (when perceptually relevant)
      ↓
ACCEPT / RECALIBRATE / REVISE MODEL
```

## Artist-eye trigger rule

Artist validation is mandatory whenever a scientific conclusion predicts a perceptual or gestural consequence, including:

- how far a wash spreads;
- whether wetness feels continuous or mode-switched;
- whether pigment appears to settle, pool, stain, or dry back;
- whether pressure or speed changes loading, drag, or run-out naturally;
- whether charcoal catches tooth, skips valleys, dusts, smudges, lifts, or burnishes;
- whether color depth, opacity, scattering, or relief reads correctly;
- whether a failure mode feels like a believable material accident.

Purely internal conclusions with no artist-visible consequence still need physics validation, but they do not need an artist rating until they influence an observable behavior.

## Starter model families

| Model ID | Model | Main use | Artist-eye consequence |
| --- | --- | --- | --- |
| `MODEL-RHEO-001` | Newtonian viscosity | Simple fluid response | Spread, drag, and pressure feel |
| `MODEL-RHEO-002` | Power-law response | Shear thinning/thickening | Speed and pressure response |
| `MODEL-RHEO-003` | Herschel–Bulkley | Yield-gated paste/soft solid | Hold, slump, drag, and impasto |
| `MODEL-TRIB-001` | Coulomb friction | Contact resistance | Catch, drag, and smudge |
| `MODEL-TRAN-001` | Fickian diffusion | Microscopic dispersion | Softening or bleeding of visible mixtures |
| `MODEL-TRAN-002` | Lucas–Washburn capillary penetration | Porous substrate uptake | Absorption and spread |
| `MODEL-TRAN-003` | Conservative advection-diffusion | Mobile material transport | Wet union, smear, and mass-conserving movement |
| `MODEL-PART-001` | Stokes settling | Small-particle settling | Granulation and edge settling |
| `MODEL-DEPO-001` | Contact exchange | Applicator/material transfer | Loading, depletion, pressure, and run-out |
| `MODEL-EVOL-001` | Evaporation boundary flux | Drying and working time | Dryback, puddling, and edge formation |
| `MODEL-OPT-001` | Kubelka–Munk diffuse layer | Spectral appearance | Color depth, transparency, and scattering |
| `MODEL-REAC-001` | Reactivation release | Rewetting/lifting | Blooms, lifting, and overworking |

## Model selection rules

- Use the simplest model that reproduces the reference behavior without a special-case medium hack.
- Record when a model is a temporary approximation, not a measured law.
- Do not select a model because it is convenient to implement if it contradicts artist-observed material behavior.
- If physics checks pass but artist review fails, recalibrate first; if the failure is systematic, revise the model.
- A model cannot graduate solely because its equation is familiar or its numerical residual is small.
