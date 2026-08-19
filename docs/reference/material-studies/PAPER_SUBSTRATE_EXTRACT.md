# Archived paper substrate extract

**Source:** `lib/models/paper.dart`, `lib/core/paper/paper_texture.dart`, and `lib/core/rendering/paper_renderer.dart` on the preserved `archive/legacy-main` branch (the same commit as `origin/main` at the 2026-08-18 recovery checkpoint).

The archive contains four named paper presets. It does **not** contain a separately named charcoal/pastel paper. `Rough` is the strongest preserved tooth candidate for charcoal or pastel artist review.

| Archived preset | Tooth | Absorbency | Sizing | Capacity | Dry-brush breakup | Seed | Grain scale | Color |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Plain White | 0.00 | 0.00 | 1.00 | 0.00 | 0.00 | 0 | 1.00 | `#FFFFFF` |
| Hot Press | 0.15 | 0.30 | 0.80 | 0.40 | 0.15 | 101 | 2.00 | `#FCFAF7` |
| Cold Press | 0.50 | 0.50 | 0.60 | 0.50 | 0.50 | 42 | 1.00 | `#FAF8F5` |
| Rough | 0.85 | 0.60 | 0.50 | 0.70 | 0.80 | 7 | 0.60 | `#F5F0E8` |

The archived texture generator used deterministic multi-scale noise for a height map and a separate capacity map. Height affected dry-brush contact and granulation; capacity affected water holding and irregular wet boundaries. These ownership boundaries remain useful evidence.

## vNext diagnostic mapping

- Archived tooth maps to canonical `SUBI-001` surface roughness.
- Archived capacity maps provisionally to `SUBI-003` porosity/holding capacity in the small lab.
- Archived absorbency and sizing jointly seed `TRAN-002` permeability. Cold Press is normalized to the already reviewed lab uptake rate; the other papers retain the archived relative ordering.
- Seed, grain scale, dry-brush breakup, and color remain traceable archive metadata.

The mapped values are labeled `archive-seed`. They are neither physical measurements nor final production constants. Artist comparison is mandatory, and later measured paper profiles may replace them without changing the shared material architecture.

## v0.2 grain-scale correction

The first JavaScript mapping multiplied sampling frequency by the archived `noiseScale`. That inverted the archived implementation, which divides its coordinates by `noiseScale`, and made Rough paper look like severely enlarged terrain. Direct artist feedback described the ridges and valleys as much larger than in the previous app and too zoomed-in to judge well.

v0.2 restores the inverse relationship and raises the diagnostic sampling density so Rough has many small tooth changes across the canvas. The physical tooth amplitude, absorbency, sizing, capacity, seed, color, and material behavior are unchanged. Automated checks now require at least 25 midline tooth crossings across the 300-cell diagnostic field and require Rough to have more than twice the crossing count of Hot Press. Visible paper scale still requires artist approval.
