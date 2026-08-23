# Guidepost

**Read this before touching anything. It is short on purpose.**

---

## What this is

**Sarasara Studio** — a natural-media painting app. **iPad primary, mobile-first.**

It is an app. It is not a lab with an app attached. The diagnostic lab is a
panel *inside* the app, opening onto the same canvas you paint on.

Three previous branches drifted, and they drifted the same way: the lab had a
specification and the product did not, so the lab is what got built. Nineteen
approved marks about how paint behaves, and no app. If you find yourself
improving the measuring instrument instead of the thing being measured, stop.

---

## Decided. Do not re-open these without the artist saying so.

**1. One engine, three recipe spaces.** The engine reads *stuff*, *hairs*, and
*surface*. It never learns a name. "Oil", "Filbert" and "Linen" are recipes —
data — and a named thing is nothing but a set of numbers over a shared
vocabulary. → `decisions/ADR-0005`

**2. The seam.** `app/src/engine/index.js` is the only file that knows how the
engine is implemented. Everything above it talks to the interface and nothing
else. The UI never imports the solver. The UI never reads a property id to make
a decision — it asks the engine.

**3. The engine runs on the GPU, in the browser.** WGSL compute, translated
from the harvested GLSL in `engine/gpu/harvested-glsl/`. Rust and wasm only
where CPU work genuinely remains. → `decisions/ADR-0006`

**4. App shell first, engine behind the seam.** Build the real UI against the
JavaScript reference engine, then swap the GPU engine underneath. The seam
exists precisely so this is possible.

**5. The picture must not move for performance.** Prove it with a pixel diff
against the previous commit, not with an argument. Zero differing channels.
→ `decisions/ADR-0004`

**6. Brushes are drawn, not configured.** → `decisions/ADR-0003`

**7. Only the artist sets `approved`.** Automated checks reach `checked` and
stop there. Nothing you do can promote a mark.

---

## Forbidden

- **Branching on a name.** Not in the engine, not in the UI. No
  `if (material === 'oil')`. Ever.
- **A `kind` or `type` field that switches code paths.** One survives — the
  substrate `pattern` field (`woven` / `fibrous` / plain). Killing it is a
  standing task, not a precedent.
- **Adding a property nothing reads.** Three are already dead: `COMP-002`,
  `COMP-004`, `STATE-003`. A property with no solver behind it is a knob
  wired to nothing. Every new one needs a test that fails when it stops
  mattering.
- **Changing an approved behaviour quietly.** If your change moves a mark, say
  so on the board and in the review, in the artist's words, before you commit.
- **Building anything that lives outside the app.** That is how the last three
  branches went.

---

## Where the truth lives

| | |
| --- | --- |
| what correct means | `engine/tests/solver.test.js` — 243 assertions |
| what the artist accepted | `docs/validation/board.json` |
| why, in his own words | `docs/validation/*/artist_review.md` |
| the vocabulary | `docs/canonical/` |
| decisions and their reasoning | `docs/decisions/` |
| what came from where | `docs/harvest/HARVEST.md` |

---

## How to work here

**Measure before you claim.** Every performance number, every physics claim.
The iPad was assumed to need a GPU; measuring found a blank sheet cost the same
as a full one, and the fix was to stop redoing finished work.

**Render it and look.** The canvas weave was wrong four times and every single
failure was invisible in the measurements.

**Break your own tests on purpose.** Change the code so it is wrong, and check
the suite screams. A test that survives the mutation protects nothing. This has
found real gaps every time it has been run — including a whole family of tests
that compared two sheets against each other and stayed true when both stopped
moving.

**Check the instrument before the engine.** Two rounds of judgement were once
spent on a fine surface and a broken display.

**Talk like an artist.** He is a painter, not a programmer. Lead with what it
means for the painting. Keep the jargon in the code.

---

## What to build next, in order

1. **The app shell.** Mobile-first, iPad primary. Canvas, floating dark tool
   rail, docked properties, panels as sheets rather than desktop columns.
   Pencil pressure and tilt are the primary input; sliders are the fallback for
   when there is no stylus. The existing UI in `app/src/` is the old desktop
   lab — it becomes a panel, it is not the shell.
2. **Hairs.** A brush becomes a bundle of filaments rather than an outline with
   a soft edge. This is what unlocks `BR-04` feathering, `BR-07` splaying and
   `BR-08` springing back — three board rows from one change of primitive.
3. **The GPU engine.** WGSL from the harvested shaders, held to the same 243
   assertions, swapped in behind the seam.
4. **Surface as a height field with a pluggable source** — generator or
   photograph. Kills the `pattern` switch and gives the artist the image-fed
   canvas tool he asked for, as the same mechanism rather than a feature.

---

## Handing off

Leave `docs/HANDOFF.md` current: what you did, what you measured, what is
half-done, and the one thing you would do next. Assume the next model has none
of your context and will believe whatever the repository tells it.
