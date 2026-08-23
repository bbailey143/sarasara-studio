# Increment 12 Stabilization Handoff

**Updated:** 2026-07-20  
**Branch:** `feat/native-core-increment-12`  
**Status:** **ROUTE BLOCKED pending stabilization**  
**Current step:** Step 3A complete: safe consecutive passes fused  
**Next step:** shared-runtime extraction before the former Step 3B

This is the authoritative short handoff for the live Windows Vulkan route.
Read it before continuing Increment 12 or starting Increment 13. The binding
painting behavior remains `specs/watercolor-engine-spec.md`; this file records
the current implementation and stability facts rather than replacing it.

## Goal, acceptance, route, blockers

**Goal:** make the existing 224-cell Increment-12 A/B route measurable and
stable before changing physics, raising resolution, or giving the GPU permanent
ownership of the painting.

**Acceptance for stabilization:** a prolonged native-mode session can sustain
70–100% wet coverage and active canvas tilt without a crash, visible painting
glitch, steadily growing memory use, leaked native cores, or an unexplained
picture backlog. Physical-display switching was explicitly removed from scope
by the artist on 2026-07-20; that concern was waived, not fixed.

**Implementation route:** retain the current Dart field and Vulkan parity path
while gathering evidence. Stabilization must not silently redefine the later
native-owned, active-tile, 512-cell target.

**Blockers known now:** the optimized stepping-stone still averages 214.08 ms
per stressed frame; a prior long session crashed at roughly 70% wet coverage
with tilt, though automated stress has not reproduced it; six separate binding
watercolor-behavior test failures remain.

## Artist evidence already collected

The Increment-12 artist test has happened. GPU mode caused significant painting
response lag, moving the app window to another physical display caused
glitching/lag, and a long
high-coverage session eventually crashed after canvas tilt was used. There was
no diagnostic capture from that run because the prior panel did not separate
native work. The short 64-cell automated parity scene still passes, but it does
not reproduce long duration, physical-display changes, 224-cell load, or broad
wet coverage.

## Code truth before Step 3

- `WatercolorNativeCore.stepFluid` is a Dart-side chain of ten pass calls, not
  one uninterrupted native/GPU frame.
- Vulkan is submitted and synchronously waited on ten times per native frame.
- Most passes copy their own inputs to Vulkan and results back to the native CPU
  field between passes.
- Increment 7 suspended-pigment transport computes its boundary/transport plan
  on the CPU, allocates temporary arrays, then runs the 19-channel gather on the
  GPU. Edge accumulation has a second CPU-built plan.
- `WatercolorEngine._nativeStep` additionally copies all live fields from Dart
  to native before the pass chain and copies them all back afterwards.
- Deposit, undo/history, paper policy, activity tiles, and final composition
  remain Dart-owned. The native path does not yet own active tiles or halos.

This is why the roadmap now calls Increment 12 a hybrid parity stepping-stone,
not a finished all-GPU frame.

## Step 1 implementation: measurements now available

Open **Water → Studio diagnostics → Performance details**. In native mode it
now reports:

- App-to-native and native-to-app wall time and bytes for the outer full-field
  handoff.
- Wall time for each of the ten stages: velocity, height force, viscosity,
  pressure plus tilt, pigment transport, surface water, wet mixing, paper plus
  drying, edge accumulation, and settle plus lift.
- Vulkan buffer upload/download wall time and bytes across the ten stages.
- Vulkan queue-submit plus fence-wait wall time and submit count. This is a CPU
  observation of how long the app blocks; it is not a hardware timestamp query.
- CPU time for the Increment-7 pigment plan and edge-accumulation plan.
- Temporary CPU plan bytes allocated during that frame.
- Main wash pixel-building and asynchronous image-decode time.
- Actual wet-field percentage after native download. The separately labelled
  `CPU tile estimate` is not authoritative in native mode because GPU tiling has
  not been implemented.
- Tilt amount/direction, total tick/picture counts, queued and discarded picture
  requests, current picture generation, and whether a picture is in flight.
- Whole-process resident memory and the peak observed during the current
  `CanvasController` lifetime. This includes Flutter and the rest of the app;
  it is intended for growth trends, not exact GPU-memory attribution.
- Native cores created, disposed, and currently live. After leaving a painting
  screen, `live` must return to its prior value once that controller is disposed.
- First-use native-core creation and static paper upload time.

The native diagnostic ABI was version 2 for the Step-1 capture. Step 3 adds two
fused GPU entry points and advances the ABI to version 3. The counters observe work only;
they do not alter pass order, thresholds, shaders, or painting output.

## Verification for Step 1

Verified on the real Windows Vulkan route with `gpuAvailable() == true`:

- `flutter analyze`: clean.
- `test/native/wc_bridge_smoke_test.dart`: ABI v2 and create/dispose lifecycle
  counts pass.
- `test/watercolor_native_live_toggle_test.dart`: all ten timing records,
  transfer bytes, ten GPU submits, plan scratch bytes, and visual parity pass.
- Complete non-image regression rerun: 116 passed / the same six known behavior
  failures; all native CPU/Vulkan checks passed with `gpuDiag=0`.
- `flutter build windows --debug`: succeeded with the ABI-v2 native library.
- Sample from the final automated 64-cell scene only: app upload 0.534 ms, ten
  passes 14.771 ms, app download 0.920 ms, GPU submit/wait 4.317 ms; composite mean
  byte difference 0.0001831, worst byte 1/255. Do not treat this small synthetic
  sample as the 224-cell artist-performance result.

These are the pre-optimization Step-1 verification facts. Current ABI and
submission counts are recorded in Step 3 below.

The wider non-visual suite remains **116 passed / 6 failed**. Those behavior
failures predate this observation-only diagnostic work and cover wet pickup,
wet-union mobility, bloom-center retention, and complete drying. Native parity
being green does not make the wider painting baseline green.

## Step 2 result: lag reproduced; crash not reproduced headlessly

The explicit harness is
`test/native/stress/increment12_native_stress.dart`. It is intentionally not
named `_test.dart`, so it does not make ordinary regression runs take minutes.
It requires the real Windows Vulkan route (`gpuAvailable() == true`,
`gpuDiag == 0`) and writes one flushed JSON record per frame to
`build/diagnostics/increment12-stress-latest.jsonl`.

The primary run used a 224-cell field, 300 frames, 75% requested wet coverage,
active diagonal tilt, a fresh composite every frame, and eight additional
create/run/dispose cycles. Actual wet coverage expanded from 77.3% to 93.8%.
It completed without a crash or non-finite field value. Nine native cores were
created, nine were disposed, and the live-core count returned to its starting
value.

The lag is decisively reproduced. Whole-frame time averaged **256.39 ms**
(p95 274.33 ms, maximum 313.83 ms), or at most about 3.9 simulation frames per
second before Flutter input and painting work. Average costs were:

- 11.49 ms for the Dart-to-native full-field copy.
- 197.36 ms for the ten-pass native chain.
- 16.01 ms for the native-to-Dart full-field copy.
- Within the chain: 3.02 ms uploading Vulkan buffers, 61.31 ms submitting and
  waiting, and **130.35 ms downloading Vulkan results**.
- 30.23 ms building the wash picture pixels and 0.43 ms decoding the image.

The four largest pass wall times were settle plus lift (90.82 ms), pigment
transport (38.60 ms), wet mixing (26.02 ms), and edge accumulation (23.32 ms).
These are not pure shader timings: the current pass-by-pass architecture makes
each wall time include its own transfers and synchronous wait.

A controlled second 300-frame run built a picture only on its first frame. It
also passed and averaged 244.72 ms (p95 270.72 ms). Removing repeated picture
creation therefore recovered only 11.67 ms, about 4.6%; it did not remove the
core lag. Process memory in the primary run rose from 222.16 MB to 264.38 MB
and peaked at 296.74 MB after lifecycle exercises. In the comparison it rose
from 210.55 MB to 261.07 MB and peaked at 274.04 MB. This short-run resident
memory trend is evidence to keep watching, not yet proof of a leak: native-core
live counts returned to baseline, and the test runner plus its JSON evidence
allocation are included in the process total.

The automated engine boundary therefore did **not** reproduce the artist's
crash. The remaining untested trigger was the complete Flutter window/display
path while the live app moved between physical monitors. On 2026-07-20 the
artist explicitly removed monitor switching from scope and authorized forward
progress. This is a **waiver, not a fix**: do not report that the display issue
was reproduced, diagnosed, or resolved.

Exact commands and the durable numerical summary are recorded in
`INCREMENT-12-STRESS-EVIDENCE.md`.

## Step 3A result: fewer round trips, same paint

Two safe consecutive groups now remain on Vulkan between their component
passes:

- Suspended-pigment transport → surface-water transport → wet mixing.
- Edge accumulation → settle/lift/finalize.

The conceptual ten-pass order is unchanged. The live route now crosses seven
Dart/native pass-group boundaries and performs seven Vulkan submissions rather
than ten. The CPU-authored suspended and drying-edge plans remain unchanged.
Native ABI version 3 exposes the two fused entry points.

The same 224-cell, 300-frame, 77.3–93.8% wet, tilted stress scene improved from
**256.39 ms to 214.08 ms average whole-frame time** (16.5%). P95 improved from
274.33 ms to 232.41 ms. The ten-pass native work fell from 197.36 ms to
154.31 ms; pass-level Vulkan downloads fell from 130.35 ms to 93.07 ms and
download volume fell from about 24.88 MB to 17.61 MB per frame. Submit/wait
time fell from 61.31 ms to 56.22 ms.

The optimized stress run again completed all 300 frames with zero non-finite
checks. Nine native cores were created and nine disposed; the live count
returned to baseline. The complete native test folder plus the live-toggle
parity test passed (27 tests), with `gpuDiag=0`, full-step worst float difference
2.3842e-7, and composite mean byte difference 0.0001831 (worst 1/255).
Full-project analysis is clean. The full regression suite remains exactly
**116 passed / the same six known failures**, with no new failure. The Windows
debug application builds successfully with the ABI-v3 native library.

A direct GPU-to-Dart final-return experiment was also measured. It averaged
214.31 ms, effectively identical to 214.08 ms, and merely moved time between
diagnostic columns. That experiment was discarded; do not recreate it as an
assumed optimization without new evidence.

This is a real improvement, but about 4.7 simulation frames per second is still
not acceptable for painting. Small additional pass fusions cannot remove the
remaining full-field round trip. The next meaningful performance boundary is
native-owned live state with deposits and composition routed without returning
the entire field every tick.

## Working-tree boundary

Pre-existing artist/UI work remains uncommitted in:

- `lib/app.dart`
- `lib/ui/painting_screen.dart`
- `lib/ui/toolbar/main_toolbar.dart`
- `.claude/settings.local.json`

The GPU toggle and the new on-screen diagnostic panel share
`painting_screen.dart` with those edits. Any future commit must inspect and
stage that file deliberately; do not sweep unrelated visual work into a native
stabilization commit.

## Next: shared runtime, then native-owned live state

The measured Step 3B goal remains valid, but the permanent boundary must not be
another watercolor-owned monolith. First follow
`specs/shared-engine-architecture-spec.md`: establish the shared component,
field-set, scheduler, canvas-layer, surface, and checkpoint contracts and wrap
the current watercolor path without changing its behavior. Then end the outer
Dart/native full-field upload and download, keep the selected material's live
fields native across frames, and add neutral deposit/composite boundaries.

The current `wc_*` ABI is a proven migration prototype, not the final shared
runtime API. Do not raise resolution, add external-texture display, or begin
other backends in the same slice. The six binding watercolor failures remain a
separate release gate.
