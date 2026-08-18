# Canonical vocabulary

This folder holds the authoritative dictionary for Sarasara. Read [`PROPERTY_FAMILIES.md`](PROPERTY_FAMILIES.md) before adding a new property or prefix, then add the property itself to [`PROPERTY_REGISTRY.yaml`](PROPERTY_REGISTRY.yaml).

The first registry will assign stable identifiers across these families:

`COMP`, `STATE`, `RHEO`, `TRIB`, `PART`, `INTF`, `TRAN`, `DEPO`, `SUBI`, `EVOL`, `REAC`, and `OPT`.

Each entry will define its physical meaning, representation, canonical unit, valid domain, dependencies, applicability, solver consumers, artist-facing mappings, and provenance. A property is not a slider by default; artist controls may later map to several physical properties.

The two-material architecture check is documented in [`TORTURE_TESTS.md`](TORTURE_TESTS.md) and [`TORTURE_TESTS.yaml`](TORTURE_TESTS.yaml).

The cross-participant relationships are documented in [`INTERACTION_MATRIX.md`](INTERACTION_MATRIX.md) and [`INTERACTION_MATRIX.yaml`](INTERACTION_MATRIX.yaml).

The named equations and constitutive choices are documented in [`MODEL_REGISTRY.md`](MODEL_REGISTRY.md) and [`MODEL_REGISTRY.yaml`](MODEL_REGISTRY.yaml). Models with perceptual consequences require artist-eye validation.
