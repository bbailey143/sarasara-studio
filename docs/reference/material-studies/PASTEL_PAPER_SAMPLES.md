# Artist-supplied pastel paper samples

Two 5100 × 5100 JPEG samples supplied by the artist on 2026-08-18 guide the experimental dry-media paper profiles:

- `Pastel White.jpg`
- `Pastel Light Cream.jpg`

The commercial source images are **not copied into this repository**. They are visual calibration evidence, not redistributable application assets and not measurements of physical height.

## Sampled appearance

Pixels were sampled on a regular 25-pixel grid across each full image.

| Sample | Mean RGB | Luminance standard deviation | Artist-readable observation |
| --- | --- | ---: | --- |
| Pastel White | `238.10, 237.95, 237.01` | `8.81` | Neutral near-white base with very quiet, fine fibers. |
| Pastel Light Cream | `238.08, 234.95, 223.03` | `10.30` | The same fine fibrous character on a warmer cream base. |

The samples show many small, irregular fibers with low visual relief. They do not show the large rounded peaks and valleys seen in the rejected Rough watercolor-paper test.

## Diagnostic mapping

The lab maps the two samples to sibling substrates:

- **Pastel Paper — White**
- **Pastel Paper — Light Cream**

Both use the same deterministic fine-fiber pattern and the same provisional roughness, permeability, capacity, and contact behavior. Only base color and subtle visible-fiber contrast differ. This guarantees that changing paper color cannot secretly change charcoal deposition or smudging.

The sampled mean colors guide `paperColor`. The visible fiber density and low contrast guide the procedural appearance. `SUBI-001` physical roughness and all height/contact values remain explicit experimental stand-ins because a flat photograph cannot prove true surface height, friction, or particle capture.

## Acceptance boundary

Automated checks may establish that:

- the pastel profiles have much shallower relief than Rough Watercolor Paper;
- their grain changes more frequently;
- White and Light Cream have identical physical tooth;
- light contact favors raised fibers;
- firm contact reaches more shallow gaps;
- smudging remains conservative.

Artist review has established that the scale looks like pastel paper and that charcoal catches, skips, responds to pressure, and smudges believably for the v0.2 diagnostic scope. The artist also approved White/Cream behavior parity, clarifying that all prescribed tests were performed although only one representative JSON was exported. The profiles are still not canonical production papers because the photographs do not measure physical height, friction, or particle capture.
