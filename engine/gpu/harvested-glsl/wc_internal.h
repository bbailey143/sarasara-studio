/* Internal field layout shared between the CPU core (wc_core.c) and the GPU
 * backend (wc_vulkan.c). Not part of the public ABI. */
#ifndef WC_INTERNAL_H
#define WC_INTERNAL_H

#include "wc_core.h"

#include <stdint.h>

struct WcField {
  int size;
  int cells;
  float* velU;        float* velUScratch;   /* cells, Phase B velocity */
  float* velV;        float* velVScratch;   /* cells, Phase B velocity */
  float* pressure;    float* pressureScratch; /* cells, pressure Jacobi */
  float* divergence;  /* cells, velocity divergence */
  float* waterH;      float* waterHScratch;   /* cells, surface water (scatter) */
  float* saturation;  /* size*size, read-only during bleed */
  float* waterM;      /* cells, mobility mask (read-only; suspended zeroing) */
  float* paperHeight;   /* cells, capillary valley input (read-only) */
  float* paperCapacity; /* cells, saturation capacity input (read-only) */
  float* ksus;        float* ksusScratch;   /* cells*WC_BANDS */
  float* ssus;        float* ssusScratch;   /* cells*WC_BANDS */
  float* props;       float* propsScratch;  /* cells*WC_SUS_PROPS */
  float* kdep;        float* sdep;          /* cells*WC_BANDS, deposited pigment */
  float* propsDep;    /* cells*WC_DEP_PROPS (load, granWt, stainWt, dryClock) */
  float* kDry;        float* sDry;          /* cells*WC_BANDS, dry substrate */
  float* propsDry;    /* cells*WC_DEP_PROPS, protected dry props */
  uint64_t diagSuspendedPlanNs;
  uint64_t diagEdgePlanNs;
  uint64_t diagTemporaryBytes;
  void* gpu;          /* opaque per-field Vulkan resources; NULL until used */
};

uint64_t wc_diag_now_ns(void);

/* GPU backend (wc_vulkan.c). When built without Vulkan these are stubs that
 * report "unavailable" so the core transparently falls back to the CPU path. */

/* 1 if a Vulkan compute device + bleed pipeline initialised, else 0. */
int wc_vk_available(void);

/* Init diagnostic; see wc_gpu_diag in wc_core.h for the codes. */
int wc_vk_diag(void);
void wc_vk_diag_reset(void);
void wc_vk_diag_read(uint64_t* values, int count);

/* Run `iters` bleed iterations on the GPU. `bleedClamped` is the host-computed
 * clamp(params.bleed * scale, 0, 0.24); `wetThreshold` is params.wetThreshold.
 * On success the result is copied back into f->ksus / f->ssus / f->props. */
void wc_vk_bleed(struct WcField* f, double bleedClamped, double wetThreshold,
                 int iters);

/* Run the binding B1 velocity self-advection pass on the GPU. On success the
 * latest velocity is copied back into f->velU / f->velV. */
void wc_vk_advect_velocity(struct WcField* f);

/* Phase-B shallow-water height force on the GPU. Latest velocity copied back
 * into f->velU / f->velV. */
void wc_vk_height_force(struct WcField* f, double height_force);

/* Phase-B viscosity Jacobi (`iters` iterations) on the GPU. Latest velocity
 * copied back into f->velU / f->velV. */
void wc_vk_viscosity(struct WcField* f, double viscosity, int iters);

/* Phase-B pressure projection on the GPU (divergence -> pressure Jacobi ->
 * projection + tilt). Latest velocity copied back into f->velU / f->velV. */
void wc_vk_pressure_project(struct WcField* f, double height_force,
                            double gravity_x, double gravity_y,
                            double wet_threshold, int pressure_iters);

/* Conservative surface-water transport on the GPU (gather form of the CPU
 * scatter). Latest water copied back into f->waterH. */
void wc_vk_advect_surface_water(struct WcField* f);

/* Conservative suspended-pigment transport on the GPU. The per-cell transport
 * plan (fx, fy, hdir, vdir) is computed CPU-side (float arrays) and passed in;
 * the GPU gathers the 19 spectral/property channels. Results copied back into
 * f->ksus / f->ssus / f->props. */
void wc_vk_advect_suspended(struct WcField* f, const float* planFx,
                            const float* planFy, const float* planHdir,
                            const float* planVdir);

/* Suspended transport -> surface-water transport -> wet mixing in one queue
 * submission. The suspended transport plan remains CPU-authored. */
void wc_vk_transport_mix(struct WcField* f, const float* planFx,
                         const float* planFy, const float* planHdir,
                         const float* planVdir, double bleedClamped,
                         double wetThreshold, int iters);

/* Drying-edge pigment accumulation on the GPU. Threshold-sensitive donor and
 * fraction decisions are supplied as a CPU-computed per-cell plan; the GPU
 * gathers the 19 suspended channels. */
void wc_vk_edge_accumulate(struct WcField* f, const float* frac,
                           const float* donorIdx);

/* Capillary spread followed by soak/evaporation/mobility recomputation. */
void wc_vk_water(struct WcField* f, double wetSpread, double dry,
                 double paperDryFactor, double soak, double wetThreshold);

/* Per-cell settle / lift / finalize on the GPU (in-place; only mobility
 * neighbours are read across cells). */
void wc_vk_settle_lift(struct WcField* f, double settle, double lift,
                       double edge, double wetOff, double wetOn,
                       double dryHoldSeconds, double stepSeconds);

/* Edge accumulation followed by settle/lift in one submission. The edge plan
 * remains CPU-authored; only the redundant intermediate host round trip is
 * removed. */
void wc_vk_edge_settle_lift(struct WcField* f, const float* frac,
                            const float* donorIdx, double edge, double settle,
                            double lift, double wetOff, double wetOn,
                            double dryHoldSeconds, double stepSeconds);

/* Free any per-field GPU resources (called from wc_destroy). */
void wc_vk_release_field(struct WcField* f);

#endif /* WC_INTERNAL_H */
