# Harvest — what came from where, and what was left behind

The `official` branch is not a fresh start. It is a merge of two efforts that
had never met: one that built a real GPU engine and could not prove it was
right, and one that built the proof and never got a real engine.

Git history is kept rather than orphaned, because the whole evidence discipline
rests on being able to trace where a number came from. "Starting over" here
means a clean structure and a stated mission, not discarding what was learnt.

---

## From the Flutter / Vulkan branches — `feat/native-core-increment-*`

Last touched 2026-08-19. Never contained a line of Rust; the GPU work is GLSL.

**`engine/gpu/harvested-glsl/` — thirteen compute shaders, verbatim.**

A complete incompressible fluid solve:

| shader | what it does |
| --- | --- |
| `wc_advect_velocity` | move the velocity field along itself |
| `wc_divergence` | where the field is compressing |
| `wc_pressure_jacobi` | solve for the pressure that cancels it |
| `wc_project` | subtract the pressure gradient — the field is now divergence free |

And the watercolour behaviour on top of it:

| shader | what it does |
| --- | --- |
| `wc_advect_surface_water` | water moves with the flow |
| `wc_advect_suspended` | pigment moves with the water |
| `wc_capillary`, `wc_soak` | the paper drinks |
| `wc_bleed` | pigment creeps into damp paper |
| `wc_edge_accumulate` | the dark rim as a wash dries |
| `wc_settle_lift` | pigment drops out and is picked back up — the largest of the thirteen |
| `wc_viscosity`, `wc_height_force` | thickness, and height driving flow |

Plus `wc_core.h` and `wc_internal.h` — a stable `extern "C"` ABI with the GPU
dispatch swapping in behind it, and a CPU reference the GPU had to reproduce
*"bit-for-bit within float rounding"*.

That last requirement is the same discipline ADR-0004 arrived at independently
on the JavaScript renderer eleven months later. Two efforts, same conclusion.
It is a good sign about both.

**`docs/harvest/`** — the architecture, roadmap, stabilisation handoff and
stress evidence from that work, plus the watercolour recovery and redesign notes
from `main`.

### Left behind, deliberately

- **77 Dart files** — the Flutter app. Superseded by the decision to run in the
  browser (ADR-0006).
- **Compiled SPIR-V** (`*_spv.inc`). Build output. The GLSL is the source, and
  it is being translated to WGSL anyway.
- **Test artefacts** — GIFs, video and frame contact sheets of the watercolour
  running. Still in `feat/native-core-increment-12` if a translated shader needs
  something to be compared against, which it will.

---

## From `vnext-bootstrap`

The branch this one replaces. Everything durable here is data, specification or
judgement — none of it is tied to a language or a platform.

| | |
| --- | --- |
| `engine/tests/solver.test.js` | **243 assertions** — what "correct" means, and the acceptance suite the GPU engine must pass |
| `engine/reference/solver.js` | the JavaScript reference solver — the behavioural baseline, not a thing to ship |
| `docs/canonical/` | the property vocabulary, interaction matrix, model registry, torture tests |
| `docs/validation/board.json` | **19 approved marks** of 49 rows |
| `docs/validation/*/artist_review.md` | the artist's judgements in his own words, including the corrections |
| `docs/validation/sessions/` | 10 recorded sessions with measurements and canvas images |
| `docs/decisions/` | ADR-0001 to 0006 |
| `docs/reference/` | legacy architecture, brush and UI studies, material and substrate research |
| tuned values | 3 materials, 8 surfaces, 3 brushes |

### Left behind, deliberately

- **`lab/diagnostic-lab.html`** — the pre-React standalone lab. Superseded twice.
- **The three-column desktop layout.** The React code moved to `app/` and still
  works, but it is the old lab, not the shell. It becomes a panel. Mobile-first
  is a rebuild, not a media query.

---

## What was never there

**Rust.** Not one file, on any branch, ever. It was discussed as the plan for
low-level GPU access and never started. Recorded here because the artist
believed it had been decided, and it had — as an intention, not as code.
