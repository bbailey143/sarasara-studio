# ADR-0005 — Stuff, hairs, surface: three recipe spaces, no names

**Date:** 2026-08-22
**Status:** accepted

## The artist's question

> If the current theory behind the mediums is true — that we can build an entire
> library of mediums based on one large set of definitions that don't represent
> any single medium, but when combined in certain recipes creates accurate
> simulation, then the same should be true of brushes and substrates, right?

Yes, and it is already half true. But the answer is different for each of the
three, and the differences are the interesting part.

## Where it already holds

**Surfaces are already recipes.** Every paper and canvas is the same set of
fields with different numbers — tooth, absorbency, sizing, capacity, breakup,
colour, fibre contrast, thread spacing. Hot press and rough linen differ in
degree, not in kind.

With one cheat: a `pattern` field reading `woven`, `fibrous` or plain, which is
a *type switch* rather than a property. It is the one place a surface tells the
engine what kind of thing it is instead of what it is like.

**Brushes are about eighty per cent there.** A drawn brush is an outline plus
softness, stiffness, width, capacity and release — all numbers. The disc is a
deliberate exception, frozen as the reference footprint.

## The decision

**Three recipe spaces. The engine reads all three and knows the name of none.**

| space | what it is | what a named thing is |
| --- | --- | --- |
| **stuff** | material properties over the canonical vocabulary | "Oil" is a set of numbers |
| **hairs** | a bundle of filaments — position, length, stiffness | "Filbert" is an arrangement |
| **surface** | a height field plus transport and optical properties | "Linen" is a generator and some numbers |

### Surface: a height field with a pluggable source

The height field can be produced by anything — a weave generator, a fibre
generator, or **a photograph of a real canvas**. The engine only ever sees the
field. That removes the `pattern` type switch, and it quietly builds the
image-fed surface tool the artist asked for months ago as the same mechanism
rather than a separate feature.

### Hairs: the primitive one level down

Today a brush is a *footprint* — an outline with a soft edge. That is why the
artist's feathering complaint could not be answered properly: a soft edge is a
gradient, and a gradient is not hair.

Make a brush a **bundle of filaments** and filbert, flat, fan, rigger and mop
stop being types. They become recipes for arranging the same primitive — which
is exactly the medium argument, applied one level down.

Three board rows fall out of that one change:

| row | as a footprint | as hairs |
| --- | --- | --- |
| `BR-04` feathers its edge | a smooth gradient — marked red by the artist | separate streaks, because there are separate hairs |
| `BR-07` splays and splits | unbuilt | press harder and the hairs move apart |
| `BR-08` springs back | unbuilt | each filament already carries stiffness |

Three problems answered by one change in what a brush *is*, rather than three
features. That is the sign the primitive is right.

It also makes the Brush Studio worth building as a premium tool. Shaping a real
bundle and watching the tufts fan is a thing worth paying for. Dragging nodes on
an outline is a diagram.

This does not contradict ADR-0003. The artist still *draws* the brush; the
drawing describes the bundle rather than the footprint.

## The limits, stated plainly

**1. Vocabulary outruns the solver, and it already has.** Of the 28 declared
properties, three are read by nothing at all: `COMP-002`, `COMP-004`,
`STATE-003`. Only three of twenty-eight, but it proves the failure mode is real
rather than theoretical — a property can be defined, documented and tuned while
nothing in the engine implements it, and nobody notices. **Every new axis needs
a test that fails when it stops mattering.**

**2. Geometry resists being a scalar.** "Filbert versus fan" cannot be reduced
to a value on a fixed axis list. This is precisely why hairs work: shape is not
reduced to numbers, it *emerges* from arranging many small things. The same
reason the medium vocabulary works at all — it describes stuff, not forms.

**3. Verification cost multiplies rather than adds.** Nineteen approved marks
took weeks. If brushes and surfaces each become property spaces, the space to be
judged grows by multiplication. That is only survivable if most of it is covered
by *relationships* — softer hair must cut a corner more than stiffer — with
individual judgement reserved for the few marks that carry real weight.

## The cost we are accepting

A hair bundle is hundreds of primitives per contact. That is free on the GPU and
**not free in JavaScript**, which is the reference implementation that keeps the
GPU honest.

This is workable because the tests run on small sheets, but it means the
reference engine becomes slow and precious — a thing that proves correctness
rather than a thing anyone paints with. That is a real change in what the
reference is for, and it is accepted deliberately rather than discovered later.
