# Sarasara vNext

This repository is the foundation for Sarasara's next generation: a natural-media painting system grounded in a shared, physically meaningful vocabulary.

This branch deliberately contains no application, painting engine, rendering code, or product interface. The legacy Flutter project is preserved separately at `archive/legacy-main` for careful reference and migration work.

## Foundation rules

- Start with physical concepts, not named-media switches.
- Keep the canonical specification independent of any programming language or interface framework.
- Treat watercolor and charcoal as contrasting tests of whether the vocabulary is genuinely shared.
- Preserve legacy material as evidence; do not copy legacy implementation into this history by default.
- Record decisions and uncertainty clearly before implementation begins.

## Structure

- `docs/architecture/` — system boundaries and shared contracts.
- `docs/canonical/` — the canonical property and model vocabulary.
- `docs/decisions/` — durable architectural decisions.
- `docs/reference/` — curated legacy research and external references.

The first substantive deliverable is the Canonical Property Registry v0.1.
