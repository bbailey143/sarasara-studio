# Interaction Matrix v0.1

The property registry tells us what a thing is. The interaction matrix tells us who it meets and what result comes from that meeting.

## The four participants

| Participant | Examples | Question |
| --- | --- | --- |
| **Material** | composition, phase, viscosity, particles, spectra | What is being moved or changed? |
| **Applicator** | pressure, speed, contact area, reservoir, direction | How is the material being contacted? |
| **Substrate** | tooth, pores, porosity, surface energy, existing layer | What receives, resists, absorbs, or anchors it? |
| **Environment** | temperature, humidity, airflow, gravity, illumination | What surrounds and influences the event? |

## The distinction that prevents duplicated properties

| Kind | Meaning | Example |
| --- | --- | --- |
| **Intrinsic** | A fact belonging to one participant. | Particle density |
| **State-dependent** | A fact that changes with condition or history. | Liquid saturation |
| **Pairwise** | A fact defined by two participants meeting. | Contact angle of a wash on paper |
| **Interaction-derived** | A result computed during an event. | Transfer efficiency |

An interaction-derived result must not be saved as though it were an intrinsic material setting. For example, “transfer efficiency = 0.72” is not a universal paint property; it is the result of material, applicator, substrate, and conditions meeting.

## Core relationships

```text
Transfer = F(Material, Applicator, Substrate, Environment)
Flow     = F(Material, Substrate, Gravity, Temperature)
Drying   = F(Material, Substrate, Temperature, Humidity, Airflow)
Wetting  = F(Material Surface, Substrate Surface, Condition)
Wear     = F(Material Resistance, Applicator Load, Substrate Tooth, Motion)
Smear    = F(Deposited Material, Friction, Load, Motion, Substrate)
```

The full machine-readable matrix is [`INTERACTION_MATRIX.yaml`](INTERACTION_MATRIX.yaml).

## Important rows

| Result | Material contributes | Applicator contributes | Substrate contributes | Environment contributes |
| --- | --- | --- | --- | --- |
| Transfer efficiency | composition, viscosity, yield, saturation | pressure, speed, contact area, duration | tooth, pores, wetting | temperature, humidity |
| Flow velocity | viscosity, yield, structure, saturation | initial contact only | pores, permeability, capillary geometry | gravity, temperature |
| Drying rate | volatile fraction, surface tension, liquid state | layer thickness | pores, porosity, surface energy | temperature, humidity, airflow |
| Settling velocity | particle size, density, shape, carrier viscosity | none after deposition | pores and saturation | gravity, temperature |
| Wear/fracture | toughness, elasticity, cohesion | load, speed, duration | roughness and pores | temperature and moisture |
| Mechanical anchoring | particle shape, detachment, packing | load and contact duration | tooth, pores, surface energy | temperature, humidity |
| Smudge transport | deposited particle population and packing | pressure, tangential speed, area | tooth and adhesion | — |
| Spectral appearance | absorption, scattering, refractive behavior | layer thickness and packing history | substrate reflectance and surface | illumination and temperature |

## Ownership rules

- The **material** does not own the result of touching paper.
- The **applicator** proposes contact; it does not decide how watercolor flows or charcoal anchors.
- The **substrate** contributes geometry and surface response; it does not own the material recipe.
- The **environment** changes rates and conditions; it does not become a hidden medium mode.
- A solver may consume values from every participant, but its output must keep provenance and classification.

## Matrix acceptance gate

Before adding a property, ask:

1. Is this an intrinsic fact, a state, a pairwise relationship, or a result?
2. Which participants does it depend on?
3. Does an existing property already express one of those inputs?
4. Can watercolor and charcoal use the same relationship with different values or models?
5. Can a future artist review observe the result directly?

If the answer is unclear, the property is not ready for the canonical registry.
