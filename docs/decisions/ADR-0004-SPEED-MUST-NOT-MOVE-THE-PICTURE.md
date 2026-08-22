# ADR-0004 — Speed must not move the picture

**Date:** 2026-08-22
**Status:** accepted

## What happened

The artist tried the lab on an iPad and it was unusable. His question was
whether the planned move to the GPU would fix it.

Measured first, on the *smallest* sheet, on a desktop:

| | blank sheet | 73% covered in paint |
| --- | --- | --- |
| physics | 9.4 ms | 9.8 ms |
| drawing it | 11.3 ms | 11.4 ms |

A blank sheet cost the same as a full one. That is not a machine short of
arithmetic — it is a machine redoing finished work. The frame budget is 16.7 ms
at 60 fps and 8.3 ms on the iPad's 120 Hz screen.

Three things were doing work that had no effect:

- The **paper** — colour, grain, fibre shading — was recomputed for every cell
  on every frame, including parsing the same paper colour out of the same
  string 106,400 times a frame. That one line was 5 of the 11 ms.
- The **water solve** ran on every material thin enough to flow, whether or not
  there was any water on the sheet. Oil never wets the sheet by design, so
  every oil painting ran a full fluid solve over a field of zeroes, forever.
- The **crumb and dust passes** blanked three whole grids and scanned every
  cell before discovering there were no crumbs and no dust. Oil and watercolour
  never make a particle.

And `reliefHeight()` — two property reads, two conversions and four clamps —
was called about 850,000 times a frame from the slump pass and three times per
pixel from the renderer, always with the same divisor.

## The decision

**A change made for speed must not move the picture, and that has to be
proved rather than asserted.**

Every change here is measured against the previous commit's renderer by
rendering the same scene with both and comparing every channel of every pixel
across four material-and-surface pairings. The bar is zero differing channels,
not "close enough".

That bar caught two things a review would not have:

- Caching the paper colour in a `Float32Array` lost enough precision to move
  the odd pixel by one. It is a `Float64Array` of the shade alone now — less
  memory, fewer reads, and exact.
- The wet sheen used to be blended on top of a value already rounded to a byte
  by being stored in the image. Keeping full precision through it is arguably
  more correct, but it is a *different picture*, and this was not the change in
  which to decide that. It stores and reads back, as it always did.

**Work is skipped only when it is provably work over nothing.** Each producer
of water or particles says so; each pass reports whether anything is left. The
gates are never guesses about whether a frame "looks idle".

**Every gate must be pinned by a test that fails when the gate sticks shut.**
Six deliberate breakages were tried. Two survived the first round — a sheet
declared dry while still wet, and paper mixed once and never re-mixed — and
both were survivable because every wet test in the suite was *comparative*.
Rough paper drinking more than hot press stays true even when both stop
drinking after one frame. The replacements are absolute: a wash must keep
soaking in after the brush has gone, and changing the paper must change what is
on screen.

## What it bought

| | before | after |
| --- | --- | --- |
| oil, standard sheet | 46 fps | **263 fps** |
| oil, finest sheet | 18 fps | **84 fps** |
| watercolour, standard | 55 fps | **97 fps** |
| watercolour, finest | 18 fps | **28 fps** |

## Confirmed on the device it was failing on

2026-08-22, the artist, on the iPad over a tunnel to the same dev server that
had been unusable an hour earlier:

> It tests exactly how you said it would.

Oil smooth, watercolour still dragging. That is the shape the desktop numbers
predicted, which matters for more than the frame rate: it means the diagnosis
was right. The iPad was never short of horsepower. It was doing the same
enormous amount of nothing the desktop was, on a smaller budget.

Evidence status: `artist_accepted_limited_scope`. One device, one session, not
a range of hardware.

## What this says about the GPU

Watercolour at the finest sheet is still 28 fps, and that is the honest number:
the fluid solve is real work over 239,400 cells and there is no waste left in
it to remove. That is the case for compiling it, and eventually for the GPU.

But two things follow from the above and should be written down before anyone
starts:

**wasm is not the GPU.** Compiling the solver buys maybe two to four times.
It would not have touched any of the waste found here, because the problem was
never that the arithmetic was slow.

**A GPU port only pays if the paint never comes back.** Simulating on the GPU
and reading the field back to the CPU each frame to draw it gives up the whole
gain and can be slower than staying put. The physics and the picture have to
live in the same place. That makes it a rebuild of both sides of the seam, not
a port of one side, and `studio/src/engine/index.js` exists precisely so the
panels above it never learn which side won.

Nothing here forecloses that. It buys the room to do it deliberately rather
than as an emergency.
