# Foundation scope

## In scope now

- A canonical, machine-readable vocabulary for material, applicator, substrate, and environment properties.
- Units, allowed ranges, relationships, provenance, and model ownership for each property.
- Reference equations, validation cases, and interaction maps.
- Careful curation of useful legacy research into `docs/reference/`.

## Explicitly out of scope now

- A replacement painting engine.
- Rendering or GPU implementation.
- Product interface design.
- Medium-specific engines or special-case flags.
- Choosing implementation details because the old project used them.

## Direction of travel

The canonical specification is portable. It must describe the same physical idea regardless of the eventual implementation. Rust is the intended production direction, but this specification does not depend on Rust or any other language.
