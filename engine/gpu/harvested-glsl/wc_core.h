/* Sarasara Studio — native simulation core (C ABI).
 *
 * Increment 1 introduced the CPU-host watercolor `_bleed` pass; later
 * increments add GPU bleed and the ordered Phase-B fluid passes behind the
 * same stable surface, reached from Dart over FFI.
 * The Dart `WatercolorSimulation` remains the behavioral baseline; this core
 * must reproduce it bit-for-bit within float rounding. The GPU (Vulkan)
 * compute dispatch swaps in behind THIS SAME ABI — the `extern "C"` surface
 * below is the stable interface.
 *
 * Field layout mirrors `lib/core/watercolor/watercolor_field.dart` exactly:
 *   row-major, index(x,y) = y*size + x;
 *   ksus/ssus interleaved as [cell*WC_BANDS + band];
 *   propsSus interleaved as [cell*WC_SUS_PROPS + channel].
 */
#ifndef WC_CORE_H
#define WC_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define WC_EXPORT __declspec(dllexport)
#else
#define WC_EXPORT __attribute__((visibility("default")))
#endif

#define WC_ABI_VERSION 3
#define WC_BANDS 8      /* WatercolorField.bands */
#define WC_SUS_PROPS 3  /* WatercolorField.susProps (load, granWt, stainWt) */
#define WC_DEP_PROPS 4  /* WatercolorField.depProps (load, granWt, stainWt, dryClock) */
#define WC_DEP_DRY_CLOCK 3 /* WatercolorField.depDryClock index into propsDep */
#define WC_DIAG_VALUE_COUNT 9

/* Opaque persistent field handle. */
typedef struct WcField WcField;

/* Simulation constants that must match the Dart params bit-for-bit, so these
 * are doubles (Dart `WatercolorParams` fields are doubles). Grows as more
 * passes are ported. */
typedef struct WcParams {
  double bleed;        /* WatercolorParams.bleed */
  double wetThreshold; /* WatercolorParams.wetThreshold */
} WcParams;

WC_EXPORT int wc_abi_version(void);

WC_EXPORT WcField* wc_create(int size);
WC_EXPORT void wc_destroy(WcField* f);
WC_EXPORT int wc_size(const WcField* f);

/* Increment-12 stabilization diagnostics. Reset immediately before one live
 * native step, then read WC_DIAG_VALUE_COUNT uint64 values in this order:
 * GPU upload ns, GPU submit/wait ns, GPU download ns, suspended-plan CPU ns,
 * edge-plan CPU ns, GPU upload bytes, GPU download bytes, submit count, and
 * temporary CPU plan bytes. These are observations only; they do not alter
 * simulation behavior or scheduling. */
WC_EXPORT void wc_diag_reset(WcField* f);
WC_EXPORT void wc_diag_read(WcField* f, uint64_t* values, int count);

/* Upload the fields the bleed pass reads/writes. Lengths:
 *   waterH, saturation  : size*size
 *   ksus, ssus          : size*size*WC_BANDS
 *   propsSus            : size*size*WC_SUS_PROPS */
WC_EXPORT void wc_upload(WcField* f,
                         const float* waterH,
                         const float* saturation,
                         const float* ksus,
                         const float* ssus,
                         const float* propsSus);

/* Upload/download the persistent Phase-B velocity pair. Each array has
 * size*size floats in row-major order. */
WC_EXPORT void wc_upload_velocity(WcField* f,
                                  const float* velU,
                                  const float* velV);
WC_EXPORT void wc_download_velocity(WcField* f,
                                    float* velU,
                                    float* velV);

/* Binding B1 velocity self-advection. The CPU path mirrors Dart's bilinear
 * backtrace exactly; the GPU path matches within float32 rounding and falls
 * back to CPU if Vulkan is unavailable. */
WC_EXPORT void wc_advect_velocity(WcField* f);
WC_EXPORT void wc_advect_velocity_gpu(WcField* f);

/* Binding Phase-B shallow-water height force: velocity gains a nudge down the
 * (waterH + saturation) gradient, clamped to [-3, 3]. In-place velocity update.
 * The CPU path matches Dart exactly; the GPU path matches within float32
 * rounding and falls back to CPU when Vulkan is unavailable. */
WC_EXPORT void wc_height_force(WcField* f, double heightForce);
WC_EXPORT void wc_height_force_gpu(WcField* f, double heightForce);

/* Binding Phase-B viscosity: `iters` implicit-style Jacobi relaxation
 * iterations over the velocity pair. Same parity/fallback contract. */
WC_EXPORT void wc_viscosity(WcField* f, double viscosity, int iters);
WC_EXPORT void wc_viscosity_gpu(WcField* f, double viscosity, int iters);

/* Binding Phase-B pressure projection: divergence, `pressureIters` pressure
 * Jacobi iterations, then a partial free-surface projection with canvas tilt
 * (gravityX/gravityY) applied after projection. Updates the velocity pair.
 * Same parity/fallback contract. */
WC_EXPORT void wc_pressure_project(WcField* f, double heightForce,
                                   double gravityX, double gravityY,
                                   double wetThreshold, int pressureIters);
WC_EXPORT void wc_pressure_project_gpu(WcField* f, double heightForce,
                                       double gravityX, double gravityY,
                                       double wetThreshold, int pressureIters);

/* Binding Phase-B conservative surface-water transport: each cell keeps a
 * remainder and scatters a velocity-weighted share to its downwind neighbours
 * (boundary cells reflect the outgoing share back to themselves). Updates
 * waterH. Same parity/fallback contract. */
WC_EXPORT void wc_advect_surface_water(WcField* f);
WC_EXPORT void wc_advect_surface_water_gpu(WcField* f);

/* Read the surface-water field back out (length size*size). */
WC_EXPORT void wc_download_water(WcField* f, float* waterH);

/* Upload flat/per-cell paper inputs used by capillary spread and soaking. */
WC_EXPORT void wc_upload_paper(WcField* f, const float* paperHeight,
                               const float* paperCapacity);

/* Capillary surface-water spread followed by soak, evaporation, and mobility
 * recomputation. The CPU reference is bit-exact with Dart on flat paper; the
 * GPU entry point uses float-parity compute with CPU fallback. */
WC_EXPORT void wc_water(WcField* f, double wetSpread, double dry,
                        double paperDryFactor, double soak,
                        double wetThreshold);
WC_EXPORT void wc_water_gpu(WcField* f, double wetSpread, double dry,
                            double paperDryFactor, double soak,
                            double wetThreshold);

/* Read the paper saturation and mobility fields back out (size*size each). */
WC_EXPORT void wc_download_saturation(WcField* f, float* saturation);
WC_EXPORT void wc_download_mobility(WcField* f, float* waterM);

/* Upload the mobility mask (size*size), read by suspended-pigment transport. */
WC_EXPORT void wc_upload_mobility(WcField* f, const float* waterM);

/* Binding Phase-B conservative suspended-pigment transport: a drying-edge-
 * biased velocity carries the 8-band suspended K/S and property sums to downwind
 * neighbours, gated so pigment does not flow into dry cells. `edge` is
 * WatercolorParams.edge; `wetThreshold` is WatercolorParams.wetThreshold. Same
 * parity/fallback contract. */
WC_EXPORT void wc_advect_suspended(WcField* f, double edge, double wetThreshold);
WC_EXPORT void wc_advect_suspended_gpu(WcField* f, double edge,
                                       double wetThreshold);

/* GPU-only fused middle group used by the live full-step route: suspended
 * transport, surface-water transport, then wet mixing. It preserves pass
 * order while removing two submissions and the intermediate host round trips.
 * CPU fallback runs the same three public passes sequentially. */
WC_EXPORT void wc_transport_mix_gpu(WcField* f, double edge,
                                    double wetThreshold, double bleed,
                                    double scale, int iters);

/* Drying-edge (coffee-ring) pigment accumulation. A rim cell draws a bounded
 * fraction of the suspended pigment from its wettest immediate neighbour.
 * Conservative across all 19 suspended channels. Same parity/fallback
 * contract as the other native passes. */
WC_EXPORT void wc_edge_accumulate(WcField* f, double edge);
WC_EXPORT void wc_edge_accumulate_gpu(WcField* f, double edge);

/* Upload/download the deposited pigment layer (kdep/sdep: size*size*WC_BANDS;
 * propsDep: size*size*WC_DEP_PROPS) and the protected dry substrate (kDry/sDry:
 * size*size*WC_BANDS; propsDry: size*size*WC_DEP_PROPS). */
WC_EXPORT void wc_upload_deposited(WcField* f, const float* kdep,
                                   const float* sdep, const float* propsDep);
WC_EXPORT void wc_download_deposited(WcField* f, float* kdep, float* sdep,
                                     float* propsDep);
WC_EXPORT void wc_upload_dry(WcField* f, const float* kDry, const float* sDry,
                             const float* propsDry);
WC_EXPORT void wc_download_dry(WcField* f, float* kDry, float* sDry,
                               float* propsDry);

/* Settle / lift / finalize: suspended pigment settles into the deposited layer
 * as the film dries, wet pigment can be lifted back, and a cell held below
 * mobility for dryHoldSeconds freezes its deposit into the dry substrate.
 * Updates suspended + deposited + (on finalize) dry state and velocity.
 * Same parity/fallback contract. */
WC_EXPORT void wc_settle_lift(WcField* f, double settle, double lift,
                              double edge, double wetOff, double wetOn,
                              double dryHoldSeconds, double stepSeconds);
WC_EXPORT void wc_settle_lift_gpu(WcField* f, double settle, double lift,
                                  double edge, double wetOff, double wetOn,
                                  double dryHoldSeconds, double stepSeconds);

/* GPU-only fused tail used by the live full-step route. Edge accumulation is
 * dispatched first, followed by settle/lift after a shader-memory barrier.
 * This removes the intermediate suspended-pigment download/upload while
 * preserving the two passes' binding order. CPU fallback runs both passes
 * sequentially. */
WC_EXPORT void wc_edge_settle_lift_gpu(WcField* f, double edge, double settle,
                                       double lift, double wetOff, double wetOn,
                                       double dryHoldSeconds,
                                       double stepSeconds);

/* Run the wet-into-wet diffusion pass `iters` times on the CPU. Each iteration
 * is a copy -> symmetric face-flux -> swap, matching one Dart `_bleed(scale:)`
 * call over a fully-active grid. This is the bit-exact reference path. */
WC_EXPORT void wc_bleed(WcField* f, const WcParams* p, double scale, int iters);

/* 1 if a Vulkan compute device is available and the bleed pipeline is ready. */
WC_EXPORT int wc_gpu_available(void);

/* Diagnostic for GPU init. -2 = untried, -1 = built without Vulkan (CPU-only
 * library), 0 = initialised OK, 1 = instance, 2 = device pick, 3 = logical
 * device, 4 = pipeline failed. */
WC_EXPORT int wc_gpu_diag(void);

/* Same pass as wc_bleed, dispatched as GPU compute (Metal/Vulkan/D3D via the
 * platform loader). Matches the CPU/Dart result within float rounding, not
 * bit-for-bit. Falls back to the CPU path when no GPU is available. */
WC_EXPORT void wc_bleed_gpu(WcField* f, const WcParams* p, double scale,
                            int iters);

/* Read the suspended trio back out after simulation. Same lengths as upload. */
WC_EXPORT void wc_download(WcField* f,
                           float* ksus,
                           float* ssus,
                           float* propsSus);

#ifdef __cplusplus
}
#endif

#endif /* WC_CORE_H */
