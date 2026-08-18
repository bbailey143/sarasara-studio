# Canonical property families v0.1

This is the filing system for Sarasara’s physical vocabulary. A property gets one stable home even when several systems use it. A family describes a kind of fact; it does not describe a software module or a named painting medium.

## The twelve families

The order is intentional: composition and state establish what exists; mechanics and particles describe how it behaves; interfaces, transport, and deposition describe contact and movement; substrate, evolution, and reactivation describe the receiving surface and time; optics describes what becomes visible.

| Order | Prefix | Family | Owns | Does not own |
| ---: | --- | --- | --- | --- |
| 1 | `COMP` | Composition | Material ingredients and proportions. | Current wetness, flow results, or display color. |
| 2 | `STATE` | Phase & State | Current phase, temperature, saturation, and internal structure. | The recipe’s fixed ingredients or a named medium’s UI label. |
| 3 | `RHEO` | Mechanical / Rheology | Deformation, viscosity, yield, elasticity, and constitutive response. | Contact friction, particle identity, or substrate geometry. |
| 4 | `TRIB` | Tribology / Wear / Fracture | Friction, rubbing, abrasion, cohesion failure, and fracture resistance. | Bulk flow or optical appearance. |
| 5 | `PART` | Particles | Size, density, shape, and collective particulate tendencies. | The carrier’s viscosity or the paper’s pores. |
| 6 | `INTF` | Interfacial Physics | Surface and interfacial tension, wetting, and boundary angles. | Bulk transport, drying rate, or a final deposited amount. |
| 7 | `TRAN` | Transport | Diffusion, advection, permeability, and capillary movement. | The decision to deposit material or the appearance of the result. |
| 8 | `DEPO` | Transfer / Deposition | Contact exchange, detachment, deposited flux, and layer packing. | The applicator’s construction or the receiving substrate’s intrinsic facts. |
| 9 | `SUBI` | Substrate Interaction | Tooth, pores, porosity, surface energy, and what the receiving surface accepts. | The paint recipe or the applicator’s force. |
| 10 | `EVOL` | Evolution / Drying / Cure | Evaporation, settling, curing, shrinkage, and time-dependent change. | A one-time contact result or optical display conversion. |
| 11 | `REAC` | Reactivation | Rewetting, release, redispersion, and mobilization of a settled layer. | Ordinary drying or an unconditional “undo drying” switch. |
| 12 | `OPT` | Optics | Wavelength-dependent absorption, scattering, refractive behavior, and reflectance. | Pigment recipe identity or physical transport. |

## Prefix and identifier rules

1. Every canonical property ID is `PREFIX-NNN`, with a three-digit number beginning at `001`.
2. Numbers are never reused. A deprecated property keeps its ID and receives `evidence.status: deprecated`.
3. Names are stable `snake_case`; display names may be painter-friendly and may change for clarity.
4. A property belongs to the family that answers the question in its definition, not the family that happens to consume it most often.
5. A property may reference another family in `dependencies`, but it must not duplicate that property under a new name.
6. A model output is marked `interaction_derived` or `derived`; it is not disguised as an intrinsic material constant.
7. A medium policy may select a value, model, or zero value for a canonical property. It may not invent a private family such as `WATER-...` or `CHARCOAL-...`.

## v0.1 coverage

The first registry contains four starter properties in each family, giving 48 entries total. That even distribution is a scaffolding decision, not a claim that every family is equally mature. The next additions should be driven by the watercolor and charcoal torture tests and by cited evidence, not by keeping the table visually balanced.

## Cross-family placement examples

### “Granulation”

Granulation is an artist-facing result assembled from `PART` particle distribution and density, `PART-004` flocculation tendency, `RHEO-001` carrier viscosity, `EVOL-003` settling velocity, `INTF-002` wetting, `TRAN-003` capillary pressure, and `SUBI` pore/tooth properties. It is not a thirteenth family or a single universal scalar.

### “Tooth”

Tooth belongs to `SUBI` when it means the receiving surface’s roughness or pore geometry. A brush’s tendency to catch on that tooth is an interaction using `TRIB` and `DEPO`; the brush does not own the paper property.

### “Wetness”

Wetness is a state and exchange result (`STATE`, `TRAN`, `EVOL`), not a recipe ingredient. A friendly “wetness” control may adjust a recipe or environment, but the canonical fields remain explicit.

### “Opacity”

Opacity is usually derived from absorption, scattering, thickness, and substrate reflectance. It belongs in an optical model or derived result, not as an arbitrary pigment slider.

## Family acceptance gate

Before adding a new family, the proposed concept must fail all existing placement tests: it cannot be filed honestly under composition, state, mechanics, particles, interfaces, transport, deposition, substrate, evolution, reactivation, or optics. A new prefix also needs at least one definition, one unit or representation rule, one dependency example, one reference behavior, and one reason the existing families cannot express it.

This gate protects the vocabulary from growing special cases whenever a new medium or UI idea arrives.
