# Oil and paste rheology extract

**Source:** [`specs/oil-engine-spec.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/specs/oil-engine-spec.md)  
**Classification:** accepted model-family evidence; calibration remains open.

## Two defining contrasts

The old oil specification makes two useful distinctions from watercolor:

1. Oil is viscoplastic: below a yield stress it holds a soft-solid shape; above yield it flows according to a shear-dependent law.
2. Oil pigment does not self-diffuse. Mixing happens through brush drag, folding, and other mechanical transport.

These are policies over shared canonical properties, not a separate property universe. `RHEO-002 yield_stress`, `RHEO-003 shear_rate_response`, `STATE-004 structural_state`, and `TRAN-001 diffusion_coefficient` can express them.

## Canonical translation

| Legacy model idea | Registry destination |
| --- | --- |
| Herschel–Bulkley response | `RHEO-003 shear_rate_response` plus a future model registry entry |
| Yield gate | `RHEO-002 yield_stress` |
| Rest/build thixotropy | `STATE-004 structural_state` |
| Mechanical drag and smear | `TRAN-004 advection_velocity`, `DEPO-001 transfer_efficiency` |
| Impasto and layer relief | Candidate future `DEPO` height property |
| Raking-light appearance | `OPT-001`, `OPT-002`, `OPT-004` |

## Guardrail retained

Setting oil diffusion to zero is a medium policy for this model family. It must not be turned into a universal rule that prevents another material from having molecular diffusion. The model registry will later hold the named constitutive and transport choices.
