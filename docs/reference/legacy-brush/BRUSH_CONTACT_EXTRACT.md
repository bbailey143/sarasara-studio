# Applicator and brush-contact extract

**Source:** [`specs/brush-engine-spec.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/specs/brush-engine-spec.md)  
**Classification:** accepted contract concept; implementation details remain historical.

## Central lesson

A brush is a tool, not a watercolor or oil effect. The same physical brush can carry different media. Its hair bundle, point, belly, spring, splay, lag, contact, capacity, and reservoir are one applicator definition. The medium adapter decides what material response follows.

## Contact sequence

```text
stylus / motion
    -> normalized pressure and tilt
    -> brush deformation and contact topology
    -> medium-agnostic contact sample
    -> medium transfer decision
    -> material transport and substrate response
```

The brush should not directly write water, pigment, paper saturation, oil height, or lighting fields. This keeps `DEPO-001 transfer_efficiency` and `DEPO-003 detachment_threshold` as interaction results instead of hidden brush constants.

## Vocabulary mined into vNext

| Brush idea | Canonical destination or follow-up |
| --- | --- |
| Pressure and normal load | `TRIB`/`DEPO` interaction inputs |
| Tangential motion and speed | `TRAN-004 advection_velocity`, future applicator contract |
| Surface drag | `TRIB-001 static_friction_coefficient`, `TRIB-002 kinetic_friction_coefficient` |
| Contact area/topology | `DEPO-001 transfer_efficiency`, `DEPO-002 deposited_mass_flux` |
| Reservoir capacity and accepted receipt | future applicator/material exchange contract |
| Paper tooth sampled at contact | `SUBI-001 surface_roughness` |

## Guardrail retained

No brush preset may contain a baked watercolor edge, paper grain, oil ridge, bloom, granulation, or other medium result. A footprint describes contact; material behavior belongs to the material/substrate system.
