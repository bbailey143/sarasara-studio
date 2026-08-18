# Canonical Property Registry v0.1

This is Sarasara's first shared dictionary for the physical ideas the future painting system must be able to describe. It deliberately starts beneath familiar labels such as “granulation,” “body,” or “tooth.” Those labels can become friendly artist controls later, but they are not the underlying facts.

The companion file, [`PROPERTY_REGISTRY.yaml`](PROPERTY_REGISTRY.yaml), is the authoritative machine-readable source. This guide explains how to read and use it.

## What an entry means

Every entry has a stable ID, plain-language definition, symbol, mathematical shape, unit, believable range, dependencies, ownership, and a note about how it might appear to an artist. Its `evidence.status` is deliberately `seed` for now: the physical idea is established, while the exact values, equations, and calibration still need to be grounded in curated research and measurement.

The four scopes prevent duplicated or misleading variables:

| Scope | Meaning | Example |
| --- | --- | --- |
| `intrinsic` | Belongs to the described material or substrate. | Particle density |
| `state_dependent` | Changes as the material changes. | Dynamic viscosity |
| `pairwise` | Depends on two named things meeting. | Contact angle of a wash on a paper |
| `interaction_derived` | Computed from several inputs during an event. | Transfer efficiency |

## Registry families

| Prefix | Family | Starter entries |
| --- | --- | --- |
| `COMP` | Composition | Carrier, binder, pigment, and volatile fractions |
| `STATE` | Phase and state | Phase, temperature, saturation, structural state |
| `RHEO` | Mechanical and rheology | Viscosity, yield stress, shear response, elasticity |
| `TRIB` | Tribology, wear, fracture | Static and kinetic friction, toughness, abrasion |
| `PART` | Particles | Size distribution, density, shape, flocculation |
| `INTF` | Interfacial physics | Surface tension, advancing and receding angles |
| `TRAN` | Transport | Diffusion, permeability, capillarity, advection |
| `DEPO` | Transfer and deposition | Transfer efficiency, deposited flux, detachment, packing |
| `SUBI` | Substrate interaction | Roughness, pores, porosity, surface energy |
| `EVOL` | Evolution, drying, cure | Evaporation, curing, settling, shrinkage |
| `REAC` | Reactivation | Rewetting, dissolution, redispersion, threshold |
| `OPT` | Optics | Absorption, scattering, refractive index, reflectance |

## Important guardrails

- **No universal “granulation” setting.** Its visible effect may arise from particle size and density, flocculation, carrier viscosity, capillarity, pore geometry, and motion. The registry records those ingredients separately.
- **No medium-only escape hatches.** Watercolor, charcoal, oil, ink, and future materials choose applicable values and models from this vocabulary. They do not introduce `specialWatercolorThing` or `charcoalMode`.
- **No disguised output controls.** Transfer efficiency, capillary pressure, settling velocity, and reflectance are results of an interaction. They should remain readable diagnostics even if an artist macro influences their inputs.
- **Units come first.** A recipe may offer friendly terms such as “thick,” “wet,” or “grippy,” but saved data and solver contracts must use the canonical unit.

## What v0.1 can already describe

The starter set can express the core contrast needed for the next validation step:

- A watercolor wash: a low-viscosity mobile suspension with surface tension, wetting, capillary uptake, evaporation, settling, rewetting, and spectral optics.
- A charcoal mark: a brittle particulate source with friction, fracture, detachment, roughness, mechanical anchoring, smearing, lifting, and particulate optics.

That does not mean the models are finished. It means both materials can be described using one vocabulary instead of two parallel feature lists.

## Next use of this registry

The next step is to put every entry through watercolor and charcoal “torture tests.” Entries will then gain literature citations, model links, and calibrated ranges. New entries are allowed only when they name a genuinely missing physical concept, not when they merely reproduce an old slider or a convenient implementation detail.
