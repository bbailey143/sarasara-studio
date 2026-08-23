# Increment 12 Stress Evidence — 2026-07-20

This is the durable summary of stabilization Step 2's automated portion. Raw
per-frame JSON is generated under `build/diagnostics/` and is intentionally not
treated as permanent source documentation.

## Environment and command

- Windows real-Vulkan route: `gpuAvailable() == true`, `gpuDiag == 0`
- Field: 224 by 224 cells
- Requested wet coverage: 75%; observed coverage grew from 77.3% to 93.8%
- Tilt: `gravityX=0.18`, `gravityY=0.12`
- Harness: `test/native/stress/increment12_native_stress.dart`

Primary run:

```powershell
$env:SARA_STRESS_FRAMES='300'
$env:SARA_STRESS_COVERAGE='0.75'
$env:SARA_STRESS_LIFECYCLE_CYCLES='8'
$env:SARA_STRESS_COMPOSITE_EVERY='1'
D:\flutter\bin\flutter.bat test test\native\stress\increment12_native_stress.dart
```

Picture-isolation comparison:

```powershell
$env:SARA_STRESS_FRAMES='300'
$env:SARA_STRESS_COVERAGE='0.75'
$env:SARA_STRESS_LIFECYCLE_CYCLES='0'
$env:SARA_STRESS_COMPOSITE_EVERY='100000'
D:\flutter\bin\flutter.bat test test\native\stress\increment12_native_stress.dart
```

The large composite interval means only frame zero builds a picture.

## Results

| Measurement | Composite every frame | Composite on first frame |
|---|---:|---:|
| Result | pass | pass |
| Frames | 300 | 300 |
| Average whole frame | 256.39 ms | 244.72 ms |
| p95 whole frame | 274.33 ms | 270.72 ms |
| Maximum whole frame | 313.83 ms | 327.53 ms |
| Start resident memory | 222.16 MB | 210.55 MB |
| End resident memory | 264.38 MB | 261.07 MB |
| Peak resident memory | 296.74 MB | 274.04 MB |
| Non-finite checks | 0 of 31 | 0 of 31 |

Primary-run average breakdown:

| Boundary | Average |
|---|---:|
| Dart to native | 11.49 ms |
| Ten native passes | 197.36 ms |
| Native to Dart | 16.01 ms |
| Vulkan uploads within passes | 3.02 ms |
| Vulkan submit plus wait within passes | 61.31 ms |
| Vulkan downloads within passes | 130.35 ms |
| Composite pixel building | 30.23 ms |
| Composite image decode | 0.43 ms |

Largest primary-run pass wall times:

| Pass | Average |
|---|---:|
| Settle plus lift | 90.82 ms |
| Pigment transport | 38.60 ms |
| Wet mixing | 26.02 ms |
| Edge accumulation | 23.32 ms |

Nine native cores were created and nine disposed during the primary run; the
live count returned to baseline. No crash occurred. This proves the reported
lag at realistic load and narrows its main cost to repeated GPU downloads and
synchronous waits. It does not reproduce or clear the artist-reported crash
while moving the live Flutter window between physical displays.

Two initial comparison attempts stalled before the test began inside the Codex
sandbox and were discarded. The clean comparison above ran outside that
sandbox and is the only comparison result recorded here.

## Step 3A optimization result

The live Vulkan route now keeps two dependency-safe groups on the GPU:

- Suspended-pigment transport, surface-water transport, and wet mixing.
- Edge accumulation and settle/lift/finalize.

This preserves all ten conceptual passes and their order while reducing Vulkan
submissions from ten to seven. The CPU-authored suspended and edge plans are
unchanged. Native ABI version 3 exposes the fused groups.

The primary 300-frame command above was repeated with the same field, wet
coverage, tilt, per-frame composite, and eight lifecycle cycles:

| Measurement | Before fusion | Seven-submission route | Change |
|---|---:|---:|---:|
| Average whole frame | 256.39 ms | 214.08 ms | -16.5% |
| p95 whole frame | 274.33 ms | 232.41 ms | -15.3% |
| Maximum whole frame | 313.83 ms | 282.81 ms | -9.9% |
| Native pass/group chain | 197.36 ms | 154.31 ms | -21.8% |
| Vulkan upload time | 3.02 ms | 2.31 ms | -23.5% |
| Vulkan submit plus wait | 61.31 ms | 56.22 ms | -8.3% |
| Vulkan download time | 130.35 ms | 93.07 ms | -28.6% |
| Vulkan upload volume | 28.14 MB | 20.67 MB | -26.5% |
| Vulkan download volume | 24.88 MB | 17.61 MB | -29.2% |
| Vulkan submissions | 10 | 7 | -30.0% |

The optimized run observed 77.3–93.8% wet coverage, completed all 300 frames,
reported zero non-finite results in 31 full-field checks, and created/disposed
nine native cores with a live-count delta of zero. Resident memory began at
224.46 MB, ended at 247.95 MB, and peaked at 281.68 MB; this remains a trend to
watch rather than proof of a leak or a fix.

Focused verification after the optimization:

- Complete `test/native` folder plus the live-toggle parity test: 27 passed.
- Real Vulkan confirmed with `gpuDiag=0`.
- Full-step worst float difference versus Dart: `2.3841858e-7`.
- Composite mean byte difference: `0.0001831`; worst byte: `1/255`.
- Focused Dart analysis: no issues.
- Full-project analysis: no issues.
- Full regression suite: 116 passed / the same six known behavior failures.
- `flutter build windows --debug`: succeeded with the ABI-v3 native library.

A subsequent direct GPU-to-Dart final-return experiment averaged 214.31 ms.
It did not improve the whole frame; it only shifted roughly 64 ms from the
native-download measurement into the app-download measurement. That experiment
was removed. The retained seven-submission route is the measured result above.

The remaining 214.08 ms average is still unsuitable for painting. The next
meaningful performance boundary is native-owned live state, so the complete
field no longer travels from Dart to native and back on every simulation tick.
The implementation now passes first through the shared-runtime extraction in
`specs/shared-engine-architecture-spec.md`; the evidence here remains valid and
must be reproduced after that boundary exists.
