# Legacy research catalog and Step 3 triage

**Source archive:** [`archive/legacy-main`](https://github.com/bbailey143/sarasara-studio/tree/archive/legacy-main)  
**Purpose:** turn the old Sarasara work into evidence for the canonical vocabulary without copying its implementation history into vNext.

## Reading labels

| Label | Meaning |
| --- | --- |
| **Accepted concept** | A physical idea worth carrying into the canonical vocabulary. It still needs a source or measurement before production calibration. |
| **Reference behavior** | A behavior observed in a test or artist review. It is valuable acceptance evidence, not automatically a physical constant. |
| **Historical rejection** | An approach the old work tried and artist review rejected. Keep it so the same mistake is not repeated. |
| **Implementation residue** | A class, buffer, tuning number, or framework choice. Preserve only when it helps explain provenance; never promote it to a canonical property. |

## Source inventory

| Legacy source | What it contributes | Triage result |
| --- | --- | --- |
| [`ARCHITECTURE.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/ARCHITECTURE.md) | Domain boundaries between Brush, Pigment, Texture, Fluid/Rheology, Lighting, and Canvas State. | Accepted boundary evidence; rewrite in language-neutral terms. |
| [`ROADMAP.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/ROADMAP.md) | What was attempted, what was accepted, and which checks remained open. | Status history only; not a property source. |
| [`specs/brush-engine-spec.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/specs/brush-engine-spec.md) | Applicator construction, contact topology, pressure, motion, reservoir, and transfer handoff. | Accepted contract concepts; implementation details remain legacy. |
| [`specs/watercolor-engine-spec.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/specs/watercolor-engine-spec.md) | Flow, water, suspended/deposited pigment, paper coupling, evaporation, settling, spectral optics. | Accepted candidate behavior and ownership; calibrations remain provisional. |
| [`specs/oil-engine-spec.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/specs/oil-engine-spec.md) | Yield-gated Herschel–Bulkley flow, mechanical pigment transport, impasto height, and lighting. | Accepted candidate model family; parameters require evidence. |
| [`WATERCOLOR-FLUID-RECOVERY.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/WATERCOLOR-FLUID-RECOVERY.md) | Detailed recovery notes, conservation checks, wet-union observations, and performance caveats. | Reference behavior plus historical decisions; never copy tuning numbers blindly. |
| [`WATERCOLOR-REDESIGN.md`](https://github.com/bbailey143/sarasara-studio/blob/archive/legacy-main/WATERCOLOR-REDESIGN.md) | Wet-map/diffusion experiment and the reason artist review rejected it as wet-looking markers. | Historical rejection; retain as a negative test. |
| `TestingArtifacts/` and recorded frames | Visual proof of washes, working time, mixing, and freezes. | Artist-validation evidence; inspect images separately from code tests. |

## Subject map

### Fluids and watercolour

The old work describes watercolor as a mobile suspension whose visible behavior depends on water, pigment, paper, and time. The canonical translation is:

| Legacy idea | Canonical home | Evidence status |
| --- | --- | --- |
| Carrier water amount | `COMP-001 carrier_mass_fraction`, `STATE-003 liquid_saturation` | Accepted concept |
| Velocity-carried wash | `TRAN-004 advection_velocity` plus a future fluid model reference | Accepted concept |
| Microscopic mixing | `TRAN-001 diffusion_coefficient` | Accepted concept, secondary only |
| Capillary paper movement | `TRAN-003 capillary_pressure`, `SUBI-002 pore_size_distribution`, `SUBI-003 porosity` | Accepted concept |
| Drying | `EVOL-001 evaporation_flux`, `STATE-003 liquid_saturation` | Accepted concept |
| Settling and granulation | `EVOL-003 settling_velocity`, `PART-001` through `PART-004`, `SUBI-001` and `SUBI-002` | Composite phenomenon, not one slider |
| Staining | `REAC-002 dissolution_release_fraction` and a future pigment/substrate affinity entry | Candidate gap |
| Spectral wash color | `OPT-001 spectral_absorption`, `OPT-002 spectral_scattering` | Accepted concept |

### Oil, paste, and heavy media

The old oil specification gives a useful contrast: paint can behave as a soft solid, remain still below yield, and mix through mechanical transport rather than diffusion.

| Legacy idea | Canonical home | Evidence status |
| --- | --- | --- |
| Yield stress | `RHEO-002 yield_stress` | Accepted concept |
| Herschel–Bulkley response | `RHEO-003 shear_rate_response` plus the future model registry | Accepted model family |
| Structural rest/build-up | `STATE-004 structural_state` | Accepted concept |
| Height/relief | `DEPO-004 deposited_packing_fraction` plus a future layer-height property | Candidate gap |
| Mechanical color transport | `TRAN-004 advection_velocity`, `DEPO-001 transfer_efficiency` | Accepted concept |
| Zero self-diffusion | `TRAN-001 diffusion_coefficient = 0` for oil policy | Accepted medium policy, not a new property |
| Raking-light appearance | `OPT-001`, `OPT-002`, `OPT-004 spectral_reflectance` | Accepted concept |

### Applicator and brush/load behavior

The brush specification’s most important lesson is that a brush is a tool, not a baked medium effect. Brush geometry, pressure, tilt, motion, contact, reservoir capacity, and transfer opportunity belong to an applicator contract. The active material decides what that contact does.

Relevant canonical links are `DEPO-001 transfer_efficiency`, `DEPO-002 deposited_mass_flux`, `DEPO-003 detachment_threshold`, `TRIB-001`/`TRIB-002` friction, and `SUBI-001 surface_roughness`. A future applicator registry should add physical brush construction properties without putting watercolor, oil, or paper appearance into a brush preset.

### Pigments and optics

The old architecture’s eight-band `K/S` representation and Kubelka–Munk mixing are valuable shared optical concepts. They belong in `OPT`, while particle density, size, shape, and flocculation belong in `PART`. A 48-row palette is an implementation choice, not a limit on the canonical vocabulary.

### Substrate and paper

Paper height/tooth, capacity, porosity, pore geometry, surface energy, and wetting are distinct ideas. The old code sometimes presented these through one paper preset; vNext keeps the physical concepts separate so a substrate recipe can later explain why a mark breaks, soaks, anchors, or blooms.

### Drying, cure, and reactivation

The old watercolor work provides reference windows for working time, dryback, settling, and rewetting. Those observations should become acceptance scenes and calibration records. They should not be hard-coded as universal seconds because they depend on temperature, humidity, airflow, layer thickness, substrate, and material composition.

## The “granulation” translation

The legacy artist label **Granulation** does not survive as a canonical property. In the old research it points to a combination of:

`PART-001` particle diameter distribution, `PART-002` particle density, `PART-004` flocculation tendency, `RHEO-001` carrier viscosity, `EVOL-003` settling velocity, `INTF-002` contact angle, `TRAN-003` capillary pressure, and `SUBI-001`/`SUBI-002` substrate geometry.

An artist macro may eventually adjust a recipe-level combination of those values. The registry must still keep the underlying causes visible.

## Gaps found during mining

These concepts appear in the archive but are intentionally not invented as ad-hoc Step 3 fields yet:

- pigment/substrate affinity and staining resistance;
- substrate absorbency or sorptivity as a directly measurable property;
- paint-layer height and relief stress;
- applicator construction and reservoir properties;
- named constitutive models and their calibration datasets.

They belong in the next registry revision or the separate model registry after their definitions and evidence are written. This is a useful result of mining: a missing concept is now visible and named, rather than being hidden inside a legacy slider.

## Migration rule

Reference material is copied or summarized only after its source, subject, status, and canonical destination are recorded. The archive remains the recovery source. vNext receives the explanation and evidence needed to make a future decision—not an unexamined second copy of the old application.
