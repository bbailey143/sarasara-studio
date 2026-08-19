# Diagnostic shared-solver architecture

The diagnostic lab now uses one shared state and contact system for watercolor and charcoal. Medium names select a property profile; they do not select separate painting engines.

## Shared state

Each substrate cell stores:

- mobile carrier;
- mobile pigment;
- deposited pigment;
- loose surface pigment with short-lived velocity;
- coarse fragments with short travel and fast settling;
- fine dust with longer travel and slower settling;
- carrier held as paper saturation, separately from mobile surface water;
- deterministic surface tooth.

The solver also keeps a cumulative diagnostic count of pigment relocated by later contact. This is not additional pigment and is not included in material mass; it lets a saved review distinguish deposition from smudging.

The lab exposes pigment load, brush water, and initial paper dampness separately. A zero-pigment, high-water gesture is therefore clean water using the same contact transaction rather than a separate bloom tool.

The pigment-load control represents pigment available at the applicator contact. Its mapping to deposited mass is state-aware: a suspension and a dry powder use the same contact model but different available-mass scales. This keeps watercolor concentration adjustable without changing carrier delivery or altering the already reviewed charcoal profile.

Watercolor contact is continuous across moisture levels. Brush moisture and existing paper moisture combine into one contact-wetness value. At its dry end, surface tooth and pressure determine which cells receive directly deposited pigment; as moisture increases, the same contact progressively becomes continuous and transfers more pigment into the mobile suspension. There is no named dry-brush mode or hidden carrier at zero brush water.

The v0.6 damp interval follows relationships recovered from the archived watercolor reference. The artist-facing brush-water control maps nonlinearly to delivered surface carrier, while canonical `STATE-003` paper saturation remains a separate slower store. Paper-held water supports only partial mobility. At lower surface-water levels, `SUBI-001` tooth restricts connected carrier flow and mechanically retains part of the pigment; abundant surface water progressively overwhelms that resistance and recovers the previously reviewed full-wet transport. The archive's exact constants are evidence, not copied production truth.

The shared solver begins from a deliberately abstract material state, not from watercolor. Material profiles supply phase, composition, material transport, deposition, evolution, and reactivation values. A separate substrate profile supplies intrinsic paper roughness, porosity/capacity, permeability, procedural height metadata, and paper color. The same contact and state-update functions then derive behavior from both participants. A medium name is only a convenient profile selector in this lab; it is not permission to invoke a private medium engine or effect.

The paper selector preserves the archive's Plain White, Hot Press, Cold Press, and Rough Watercolor Paper seeds. The archive had no separately named charcoal/pastel sheet, and artist review rejected forcing its Rough watercolor preset into that role. The artist then supplied Pastel White and Pastel Light Cream visual samples. Charcoal now defaults to the sample-guided experimental **Pastel Paper — White**, with **Pastel Paper — Light Cream** as a color sibling. Both use identical fine, shallow, fibrous physical tooth; only their paper color and subtle visible-fiber contrast differ. The supplied commercial JPEGs are not shipped, and their appearance cannot prove physical height. The artist has accepted both papers' appearance, light/firm Draw response, color parity, and smudge behavior for the v0.2 diagnostic scope; they remain `reference-derived` stand-ins rather than measured production papers. Changing paper never changes the material profile or contact equations.

Smudging is a second action through that same shared contact system. It reads deposited material, kinetic friction, deposited packing, pressure, speed, and substrate roughness; then lifts a bounded fraction into a loose surface-particle state. Those loose particles retain short-lived directional momentum, coast after contact ends, lose energy through friction and roughness, and settle back into the deposited state. Above the shared high-load compaction threshold, a property-driven share of relocated material is immediately anchored into the contacted paper trail while the remainder can still move as loose, coarse, and fine populations. This is the deposited output already named by `IM-009`, not a charcoal mode or a new pigment source. Smudging never calls the applicator deposition path and never changes the initial-pigment ledger. The UI may request **Draw** or **Smudge**, but neither action branches on a named medium.

Fracture and dusting use the same shared contact ledger. A profile with a powder or brittle-solid phase and defined fracture/particle properties may split a bounded fraction of transferred material into coarse and fine populations. During Draw, that fraction comes from pigment actually transferred from the applicator offer; during later smudge contact, it comes from deposited or already loose material. Coarse pieces launch more slowly and settle sooner. Fine dust launches faster and settles more slowly. Material leaving the grid is recorded as off-canvas loss rather than silently deleted. A blank contact or a profile without a brittle particulate source creates no fragments. The current values are normalized stand-ins whose visible behavior requires artist approval.

Dry transfer is spatially incomplete rather than a filled footprint. Local tooth, normal pressure, `PART-002` particle density, and `PART-003` shape determine a bounded capture probability and captured amount. Material not captured remains in the applicator-source ledger. Repeating the same stroke therefore accumulates real deposited mass in the same granular structure instead of invoking a multi-layer visual effect. This relationship is shared and property-driven; it does not test the charcoal profile name.

The dry optical preview also distinguishes populations instead of converting their sum to one flat opacity. Deposited packing and particle density control the darkness of settled/coarse material, while loose and fine dust contribute a lighter veil. This changes only how conserved state is observed; it does not alter the pigment ledger. The artist must decide whether that separation resembles loose charcoal.

## Canonical property inputs

The profiles in `shared-solver.js` use canonical IDs from `PROPERTY_REGISTRY.yaml`:

- `COMP-001` carrier fraction;
- `COMP-003` pigment fraction;
- `STATE-001` material phase;
- `STATE-003` local liquid saturation;
- `TRAN-001` diffusion coefficient;
- `TRAN-002` permeability;
- `DEPO-001` transfer efficiency;
- `DEPO-004` deposited packing fraction;
- `SUBI-001` surface roughness;
- `SUBI-003` porosity;
- `TRIB-002` kinetic friction coefficient;
- `TRIB-003` fracture toughness;
- `TRIB-004` abrasion resistance;
- `PART-001` particle diameter population, represented here as coarse/fine shares;
- `PART-002` particle density stand-in;
- `PART-003` particle shape stand-in;
- `EVOL-001` evaporation flux;
- `EVOL-003` settling velocity;
- `REAC-001` rewetting sensitivity;
- `REAC-002` dissolution/release fraction;
- `REAC-003` redispersion coefficient;
- `REAC-004` reactivation threshold.

Profiles are validated before drawing. Their current values are explicitly labeled `stand-in`; they are artist-calibrated diagnostic values, not measured production constants.

## Named model correspondence

- contact uses `MODEL-DEPO-001`;
- carrier dispersion uses `MODEL-TRAN-001` and `MODEL-TRAN-003`;
- porous uptake approximates `MODEL-TRAN-002`;
- evaporation uses `MODEL-EVOL-001`;
- pigment settling is a time-scaled diagnostic approximation associated with `MODEL-PART-001`;
- clean-water release uses `MODEL-REAC-001` and returns deposited pigment to the mobile state without adding pigment mass.
- deposited-material smudging uses `MODEL-TRIB-001`, `MODEL-PART-001`, and interaction `IM-009`; it conservatively lifts, moves, and resettles existing surface pigment.
- fracture and dusting use `MODEL-TRIB-001`, `MODEL-PART-001`, and interaction `IM-008`; coarse/fine mass is removed from a real source before it can move or settle.

Water movement is computed first. Pigment then follows that water flux according to the local pigment-to-water ratio, with only a small separate dispersion term. This keeps visible spreading tied to carrier movement instead of making pigment expand on its own.

Each saved review records the material profile, named models, named interactions, selected contact action, state measurements, relocated-pigment count, and pigment-conservation error beside the artist verdict.

## Current limits

This is a small CPU grid intended to expose behavior for review. It is not the production Rust/GPU solver. Spectral color, brush reservoirs, measured paper profiles, and artist-accepted clean-water blooms remain future work. The watercolor v0.6.1 patch preserves the accepted v0.6 material constants while paper physics now comes from an independent selected substrate. Charcoal v0.5 added mass-bounded coarse/fine fracture and dusting to the already accepted v0.4 loose-particle smudge motion; v0.5.1 increased shared fine-particle drag and settling. v0.5.2 added the shared high-load anchoring relationship. Charcoal v0.6 now targets the artist's loose, grainy **Stamp / 1 Layer / Multi-Layer / Smudge** reference by adding incomplete granular capture and population-specific optical density. That entire visible target, including the carried-forward pressure smear, requires fresh artist review. Grain scale, optical density, fracture shares, pressure anchoring, and travel/settling remain unmeasured stand-ins.
