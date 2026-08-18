# ADR-0001: Foundation before implementation

**Status:** Accepted

## Decision

Sarasara vNext will establish canonical physical properties, interaction contracts, and reference models before building a new engine or interface.

## Why

The legacy project contains valuable research and experiments, but its implementation history should not dictate the new architecture. Defining the vocabulary first prevents one medium or one user-interface control from becoming a hidden universal assumption.

## Consequences

- Legacy implementation remains preserved on `archive/legacy-main`.
- New history begins with documentation rather than application code.
- Watercolor and charcoal will be used as contrasting validation cases for the vocabulary.
- Implementation decisions remain downstream of the physical specification.
