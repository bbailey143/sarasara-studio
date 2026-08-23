# Sarasara Studio

A natural-media painting app. **iPad primary, mobile-first.**

Paint that behaves like paint — oil that holds a ridge and shoves under the
brush, watercolour that blooms and leaves a dark rim as it dries, charcoal that
catches the tooth and crumbles — on paper and canvas that are a little different
every sheet, with brushes you build yourself.

> **Working on this — human or AI? Read [`docs/GUIDEPOST.md`](docs/GUIDEPOST.md) first.**
> It is short, and it is the difference between building the app and building
> another lab.

## The idea

One engine. No named media inside it.

A medium is not a mode — it is a **recipe** of physical properties over a shared
vocabulary. Oil is a set of numbers. So is watercolour. Change the numbers far
enough and the same solver gives you a different material, because the
difference between oil and water really is a difference of degree.

The same holds one level down. A **brush** is an arrangement of hairs, so
"filbert" is a recipe too. A **surface** is a height field plus how it drinks and
how it looks, so "linen" is a recipe as well — and its height field can come from
a generator or from a photograph of your own canvas.

Three recipe spaces — *stuff*, *hairs*, *surface*. The engine reads all three and
knows the name of none.
→ [`ADR-0005`](docs/decisions/ADR-0005-THREE-RECIPE-SPACES.md)

## Layout

```
app/            the product — React, react-aria, Tailwind, mobile-first
  src/engine/   THE SEAM: the only place that knows how the engine works
engine/
  reference/    the JavaScript solver — the behavioural baseline
  gpu/          WGSL, and the harvested GLSL it comes from
  tests/        243 assertions: what "correct" means
docs/
  GUIDEPOST.md  read first
  decisions/    what was decided, and why
  validation/   the artist's marks, his words, recorded sessions
  canonical/    the property vocabulary
  harvest/      what came from where
```

## Running it

```bash
npm install
```

```bash
npm run lab
```

```bash
npm test
```

`npm test` runs the 243 assertions against the reference engine. It is the
acceptance suite the GPU engine will have to pass, so it never gets to be
"mostly passing".

## Where it stands

Nineteen of forty-nine behaviours are artist-approved. Oil holds its shape,
slumps when overloaded, gets shoved as a mass and never bleeds. Charcoal catches
the tooth, breaks, dusts and smudges. The brush engine holds its true size, knows
how it is held, opens with pressure, and lays paint by distance travelled rather
than by how fast the pen happens to report.

Two marks are red and waiting — the reservoir, and feathering. Watercolour has no
approved behaviour yet.

The board is [`docs/validation/board.json`](docs/validation/board.json). Only the
artist sets `approved`.
