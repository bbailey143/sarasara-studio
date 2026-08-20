# ADR-0003: Brushes are drawn, not configured

**Status:** Direction set by the artist, 2026-08-20. Not yet designed or built.
**Follows:** [ADR-0002](ADR-0002-OIL-VOCABULARY-TEST.md)

## The artist's words

> The old way of building the brush was blind to me — I want to build brushes
> visually using vector SVG shapes and then customizing numbers of tufts. This
> will be bigger than "just adding a brush".

## What this rejects

The legacy build described a brush entirely in numbers: bristle counts, splay
coefficients, bend stiffness, cluster layout. That work was sound and the artist
approved how it *felt* in July. But the artist could never see what he was
making before he made a mark with it. A brush was a list of values that produced
a result, and the only way to know what a value did was to paint with it and
guess backwards.

That is the wrong way round for the person who has to use it.

## The direction

A brush is **drawn**, the way a brush maker shapes one:

- Its silhouette is a vector outline — round, flat, filbert, fan, rigger — drawn
  or edited directly rather than derived from parameters.
- Tufts are placed and counted visibly. How many, how grouped, how splayed is
  something you see, not something you type.
- The physical numbers the engine needs are **derived from the shape**, not
  authored alongside it. The drawing is the source; the numbers follow.

## Why this is bigger than adding a brush

1. **It changes what a brush *is* in the vocabulary.** Today the applicator is
   the least-developed of the five participants — the sheet, the recipe and the
   bench all have real contracts, and the hand is a disc. Giving it a drawn form
   means deciding how a shape becomes contact, and that is a contract, not a
   feature.

2. **It needs a second kind of studio.** The diagnostic bench answers "does this
   material behave?" A brush studio answers "what does this tool look like?" —
   a different tool with a canvas of its own, direct manipulation, and its own
   saved library. The three-column bench was built so panels could be added, but
   this is closer to a sibling than a panel.

3. **Every approved mark depends on it.** Ten behaviours across oil and charcoal
   are approved on how they look, and all of them were painted with a disc.
   Changing the tool changes all of them. This is the single most disruptive
   thing left on the road, which is a reason to do it deliberately, not a reason
   to avoid it.

4. **It reorders the road.** Real colour was the standing recommendation because
   it unblocks the most board rows. The artist has chosen the brush instead. Both
   are defensible; the brush is the one that changes how painting *feels*, and
   feel is what every green mark on the board is actually recording.

## Open questions, none answered yet

- Does the drawn outline drive contact directly, or does it produce the physical
  values the existing contact model already consumes?
- Are tufts individually simulated, or grouped into the bristle clusters the
  legacy engine used and the artist approved?
- What survives from the legacy brush engine, and what is genuinely replaced?
  Its feel was approved; its authoring was not.
- Where does a brush live — a file beside the material recipes, or its own kind
  of thing entirely?
- How is a brush reviewed? The board records material behaviours. A tool needs
  its own rows, or the material rows need to name the brush they were judged with.

## Consequences

- The brush moves ahead of real colour on the road.
- Nothing about it is designed yet. This ADR exists so the direction is not lost
  between sessions, not because a decision has been made about how to build it.
- When it lands, every existing green mark should be re-examined, since all of
  them were made with a disc.
