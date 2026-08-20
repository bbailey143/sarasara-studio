# Sarasara diagnostic studio

The bench where materials are tested by eye. Three columns: controls on the
left, the sheet in the middle and nothing else, measurements and approvals on
the right.

## Run it

```
npm install     # once
npm run lab
```

It opens at `http://localhost:5173`. The server is not optional decoration —
it is what lets a saved review land in the repository instead of in a browser
cache.

Verify the engine at any time with:

```
npm test        # node lab/shared-solver.test.js
```

## What it writes

| Path | Written when | Holds |
| --- | --- | --- |
| `docs/validation/sessions/*.json` | you press **Save this mark** | settings, profile and paper identity, every measurement, your rating and words, the board at that moment, and a PNG of the mark |
| `docs/validation/board.json` | you set any board mark | the live status of every behaviour, per material |

Both are plain JSON in the repository, so whoever picks the work up next —
including an AI — reads your actual results rather than a retyped summary.

If the server is not running the studio still paints, but a banner says
**offline · not recording** and nothing is written. That is deliberate: a
review that was not saved should never look like one that was.

## The rule the board encodes

A mark is a claim about what a **person has seen**.

- `none` — not built.
- `partial` — exists, but tangled with other things.
- `checked` — an automated check agrees. This is the ceiling for anything a
  test can establish.
- `approved` — **only the artist sets this.** No test run, no measurement, and
  no amount of green numbers may advance a row to approved.

## Architecture

```
studio/src/engine/index.js   <-- THE SEAM. The only file that knows how the
                                 engine is implemented.
studio/src/App.jsx               layout, painting, recording
studio/src/components/           React Aria controls, styled with Tailwind
studio/src/data/board.js         board rows and their seeded statuses
vite.config.mjs                  dev server + the API that writes to the repo
```

Three rules keep this extendable as papers, brushes and more materials arrive:

1. **Nothing above the seam imports the solver.** The UI talks to the object
   returned by `createEngine()` and nothing else. When the engine is rebuilt in
   another language, only `engine/index.js` changes.
2. **The UI never infers what a material is.** It asks the engine for the
   regime (`flowing` / `granular` / `body`) and lets that drive what is shown —
   which is why the water controls disappear for oil and charcoal instead of
   sitting there doing nothing. No panel branches on a material name.
3. **Display is never physics.** View strength changes what you see and never
   what is there. Anything that alters state belongs in a profile, not a
   control.

## Not built yet

Paper editor, brush editor, side-by-side comparison of two saved marks, and
replay of a recorded session. The panels are laid out so these arrive as new
sections rather than a rewrite.

The previous single-file bench is still at `lab/diagnostic-lab.html`. It is
superseded and will be removed once this one has been used in anger; until
then it stays as a fallback. `lab/shared-solver.js` is **not** superseded — it
is the engine, and both the studio and the test suite load it.
