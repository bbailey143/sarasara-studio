# Canonical vocabulary

This folder holds the authoritative dictionary for Sarasara. Read [`PROPERTY_FAMILIES.md`](PROPERTY_FAMILIES.md) before adding a new property or prefix, then add the property itself to [`PROPERTY_REGISTRY.yaml`](PROPERTY_REGISTRY.yaml).

The first registry will assign stable identifiers across these families:

`COMP`, `STATE`, `RHEO`, `TRIB`, `PART`, `INTF`, `TRAN`, `DEPO`, `SUBI`, `EVOL`, `REAC`, and `OPT`.

Each entry will define its physical meaning, representation, canonical unit, valid domain, dependencies, applicability, solver consumers, artist-facing mappings, and provenance. A property is not a slider by default; artist controls may later map to several physical properties.

The two-material architecture check is documented in [`TORTURE_TESTS.md`](TORTURE_TESTS.md) and [`TORTURE_TESTS.yaml`](TORTURE_TESTS.yaml).
