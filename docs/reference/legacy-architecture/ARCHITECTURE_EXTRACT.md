# Legacy architecture extract

**Source:** [`ARCHITECTURE.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/ARCHITECTURE.md) in the preserved archive.
**Classification:** accepted boundary evidence, rewritten for vNext.

## What the old architecture got right

The archive separates several responsibilities that must stay separate in vNext:

- **Brush:** position, speed, pressure, tilt, deformation, bristle contact, and reservoir opportunity.
- **Medium adapter:** translates an applicator contact into a medium-specific material event.
- **Pigment and optics:** pigment identity, spectral absorption/scattering, and color appearance.
- **Texture/substrate:** paper or canvas height, capacity, fiber, weave, and surface response.
- **Fluid or rheology:** mobile water flow for watercolor, yield-gated paste flow for oil.
- **Lighting:** relief normals and appearance of raised oil paint.
- **Canvas state:** persistent fields, composition, checkpoints, and undo/redo.

The useful abstraction is ownership. A central controller may coordinate these systems, but it should not quietly become the permanent home for every brush, pigment, paper, and medium rule.

## What changes in vNext

The old document is Flutter-specific and implementation-oriented. vNext keeps the physical boundaries but records them as language-neutral contracts. The canonical registry is the authority for the physical meaning; Rust, GPU APIs, or a future interface are downstream choices.

The archive also contains active implementation specifications. They remain valuable references, but their exact field names, texture formats, and pass counts are not canonical properties. Those details belong in a future computational design once the physical vocabulary and model registry are stable.

## Canonical links

| Boundary | Registry families |
| --- | --- |
| Material composition and state | `COMP`, `STATE` |
| Flow, paste, and contact mechanics | `RHEO`, `TRIB`, `TRAN`, `DEPO` |
| Particulate behavior | `PART` |
| Surface and wetting | `INTF`, `SUBI` |
| Drying and reactivation | `EVOL`, `REAC` |
| Appearance | `OPT` |

The full source remains in the archive so this extract can stay short, readable, and safe to evolve.
