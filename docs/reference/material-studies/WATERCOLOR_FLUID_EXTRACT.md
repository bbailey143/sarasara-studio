# Watercolor fluid and wet-paper extract

**Sources:** [`specs/watercolor-engine-spec.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/specs/watercolor-engine-spec.md), [`WATERCOLOR-FLUID-RECOVERY.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/WATERCOLOR-FLUID-RECOVERY.md), and [`WATERCOLOR-REDESIGN.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/WATERCOLOR-REDESIGN.md).  
**Classification:** accepted physical concepts plus explicit historical rejection.

## Accepted behavior

The archive consistently identifies the watercolor behaviors that matter to an artist:

- wet-into-wet movement;
- pigment carried by water rather than moved by an unrelated color blur;
- edge darkening as material gathers at a drying boundary;
- blooms/backruns when water re-mobilizes a partially settled layer;
- subtractive spectral mixing;
- capillary coupling to paper;
- settling, staining, drying, and later reactivation.

These map to `TRAN`, `SUBI`, `EVOL`, `REAC`, `PART`, and `OPT` in the canonical registry.

## Historical rejection

The old wet-map plus diffusion experiment passed some mechanical checks but artist review found that it looked like wet markers rather than moving watercolor. It is retained as a negative reference, not as a second engine. A future implementation may use diffusion as a bounded microscopic process, but it cannot become the primary bulk transport model when a fluid model is active.

## Evidence boundaries

The archive contains useful observations about working windows, color crossings, retained centers, wet masks, and dryback. Those are reference behaviors. Numbers such as simulation-unit conversion factors, dry-rate ranges, grid sizes, and pressure exponents are implementation-era calibration notes, not universal canonical values.

## Canonical translation

| Observed phenomenon | Registry link |
| --- | --- |
| Mobile carrier | `COMP-001`, `STATE-003` |
| Surface water and paper-held moisture | `STATE-003` |
| Bulk movement | `TRAN-004` |
| Microscopic dispersion | `TRAN-001` |
| Paper capillary action | `TRAN-003`, `SUBI-002`, `SUBI-003` |
| Drying | `EVOL-001` |
| Settling and granulation | `EVOL-003`, `PART-001`..`PART-004` |
| Rewetting and lifting | `REAC-001`, `REAC-002`, `REAC-003` |
| Spectral appearance | `OPT-001`, `OPT-002`, `OPT-004` |
