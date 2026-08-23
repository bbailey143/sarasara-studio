# ADR-0006 — WebGPU in the browser, and the shell before the engine

**Date:** 2026-08-22
**Status:** accepted

## Why this branch exists

The artist, on the branch this one replaces:

> I'm not super excited about how this build has gone. [...] I've decided
> against continuing the lab because it feels very very separate from what the
> final product is supposed to be. And, in fact, I think that has been loss to
> all the branches.

He was right, and the cause is worth stating so it is not repeated: **the lab
had a specification and the product did not.** Every session, the thing with a
clear definition got better. The result was nineteen approved marks about how
paint behaves and not one line of the app.

He also believed Rust and wasm were already decided and that the mission had
drifted from them. Half of that is right. There is **no Rust anywhere, on any
branch** — it was discussed and never written. But the GPU work he remembered is
real: thirteen GLSL compute shaders in `feat/native-core-increment-*`
implementing a full incompressible fluid solve, behind a stable C ABI, with a
CPU reference the GPU had to match *"bit-for-bit within float rounding"*.

Two halves that had never met. The archive had a real engine and no way to prove
it was right. The branch being replaced had the proof and no real engine.

## Decisions

### The engine runs on the GPU, in the browser

WGSL compute, translated from `engine/gpu/harvested-glsl/`. Rust and wasm only
where CPU work genuinely remains.

Chosen over a native iPad build because it keeps the React and react-aria UI the
artist wants, keeps the edit-reload-paint-on-the-iPad loop that has been working
well over a tunnel, and gives one codebase for desktop and tablet. A native
build has a higher ceiling and remains open; nothing here forecloses it, because
everything above the seam is ignorant of what is below it.

Chosen over Rust-to-wasm-on-the-CPU because the numbers say wasm alone cannot
carry the load. Compiling buys perhaps two to four times. Watercolour at the
finest sheet needs more than that, and ADR-0004 measured why.

**Two things that must not be forgotten when this is built.**

*wasm is not the GPU.* It would not have touched a single one of the wastes
found in ADR-0004, because the problem was never that the arithmetic was slow.

*A GPU port only pays if the paint never comes back.* Simulating on the GPU and
reading the field to the CPU each frame to draw it gives up the entire gain and
can be slower than staying put. The physics and the picture must live in the
same place. That makes this a rebuild of both sides of the seam, not a port of
one side.

### The app shell is built first, with the engine behind the seam

The JavaScript reference engine goes behind `app/src/engine/index.js` while the
real UI is built against it. The GPU engine is swapped underneath later.

This is the reverse of the instinct to do the exciting part first, and it is
chosen deliberately: **the thing the artist is unhappiest about is that the UI
is not his UI.** Building the shell first fixes that first. The seam already
exists, is already proven — the disc, drawn brushes and a whole reservoir have
been swapped behind it without a panel noticing — and it is the mechanism that
makes this order safe.

### The lab is a panel inside the app

The readouts, the board and session recording live behind a toggle in the real
app, on the real canvas. Nothing is a separate world again.

This also matters for the previous decision: without somewhere to live, the 243
assertions and 19 approved marks decay into folklore. They are the acceptance
suite the GPU engine will have to pass. They are the only reason it will be
possible to know the rebuild did not break the paint.

### Mobile-first, iPad primary

Not a desktop app that resizes. Touch targets, no hover, panels as sheets rather
than columns, and Apple Pencil pressure and tilt as the *primary* input with
sliders as the fallback for when there is no stylus.

The frame budget is **8.3 ms**, not 16.7 ms — a 120 Hz screen. ADR-0004 bought
the room for that; it did not make it free.

The three-column desktop lab in `app/src/` is exactly the wrong shape for this
device, which is one more reason it becomes a panel rather than the shell.
