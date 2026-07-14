import 'dart:math' as math;

/// Tunable constants for the oil engine, following the parameter reference in
/// `specs/oil-engine-spec.md` §11. Names match the spec so a value in the
/// regime cookbook (§9) maps straight onto a field here.
///
/// Grid space: one cell = one texel, `Δx = 1`. One [dt] is one display frame;
/// the explicit Herschel-Bulkley flux is CFL-limited (§8), so Phase B runs
/// [substeps] times per frame at `dt / substeps` — never shrink [dt] itself.
class OilParams {
  // ── Rheology (§5, §8) ─────────────────────────────────────────────

  /// Frame timestep for the rheology solve.
  final double dt;

  /// Phase-B substeps per frame (2–8). Explicit flux stability.
  final int substeps;

  /// Base yield stress `τ_y`. Below this shear stress paint holds its shape —
  /// impasto ridges, knife marks, persistent brush texture.
  final double tauY0;

  /// Herschel-Bulkley consistency `K`: ↑ = thicker body, more flow resistance.
  final double consistencyK;

  /// Flow index `n` (< 1 = shear-thinning). 0.3–0.9.
  final double flowIndexN;

  /// Slump drive `ρ·g`: how strongly gravity levels thick/steep paint.
  final double rhoG;

  /// Constant canvas-tilt slope added to `∇H` (an artist control and the §13
  /// slump-test driver). Positive x pushes paint toward +x.
  final double tiltX;
  final double tiltY;

  // ── Brush exchange (§7 A) ─────────────────────────────────────────

  /// Brush → canvas laydown rate per stamp (0.1–0.6).
  final double depositRate;

  /// Canvas → brush lift rate per stamp (0.05–0.4). Scaled by drag speed:
  /// a stationary press lifts nothing.
  final double pickupRate;

  /// How much of the brush motion the touched paint inherits (0.2–1.0).
  /// 1 = full carry (grabbing drag), low = glide.
  final double coupling;

  /// Equilibrium film thickness a fully loaded brush drives the surface
  /// toward: deposit ∝ `max(0, film·fill − h)`, so a held press saturates
  /// instead of pumping paint forever.
  final double brushFilm;

  /// How far a light touch reaches down into the canvas tooth. At pressure 1
  /// the whole tooth profile is contacted; low pressure touches only peaks —
  /// the stamp-side half of drybrush (§7 F2 owns the display side).
  final double toothReach;

  // ── Medium / thinning (§1, §9) ────────────────────────────────────

  /// How much dissolved medium fluidizes the paint: `τ_y` and `K` are scaled
  /// by `(1 − m·mediumThinning)`. Never introduces diffusion (§6).
  final double mediumThinning;

  // ── Thixotropy (§7 D, optional but cheap) ─────────────────────────

  /// Blend of the structure field into the yield stress (0 = ignore).
  final double thixo;

  /// Structure recovery per frame (paint “sets up” at rest).
  final double recover;

  /// Structure breakdown per unit shear (working the paint thins it).
  final double breakdown;

  // ── Lighting & composite (§7 F) ───────────────────────────────────

  /// Specular exponent — fresh oil is glossy.
  final double gloss;

  /// Specular strength. Heavily-thinned passages read matte.
  final double oilSheen;

  /// Ambient light floor for the diffuse term.
  final double ambient;

  /// Light direction: azimuth in turns (0 = from +x) and elevation 0..1
  /// (0 = raking, 1 = overhead). Raking light is what makes impasto pop.
  final double lightAzimuth;
  final double lightElevation;

  /// Canvas tooth height contribution to `H = b + h` (physics + normals).
  final double toothAmp;

  /// Normal-map exaggeration for display only (never feeds physics).
  final double reliefAmp;

  /// Drybrush gating (§7 F2): canvas shows through where
  /// `tooth − h ∈ [toothLo, toothHi]` and the film is thinner than [dryThin].
  final double toothLo;
  final double toothHi;
  final double dryThin;

  /// Optical scale for the finite-thickness Kubelka-Munk layer: areal
  /// `K·t`/`S·t` per unit of accumulated spectral sum.
  final double kmScale;

  /// Paint height at which geometric coverage (alpha) saturates.
  final double hCover;

  const OilParams({
    this.dt = 1.0,
    this.substeps = 3,
    this.tauY0 = 1.1,
    this.consistencyK = 2.2,
    this.flowIndexN = 0.6,
    this.rhoG = 1.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.depositRate = 0.5,
    this.pickupRate = 0.26,
    this.coupling = 0.65,
    this.brushFilm = 2.4,
    this.toothReach = 1.15,
    this.mediumThinning = 0.85,
    this.thixo = 0.45,
    this.recover = 0.02,
    this.breakdown = 1.4,
    this.gloss = 26.0,
    this.oilSheen = 0.30,
    this.ambient = 0.62,
    this.lightAzimuth = 0.625,
    this.lightElevation = 0.42,
    this.toothAmp = 0.28,
    this.reliefAmp = 1.6,
    this.toothLo = 0.02,
    this.toothHi = 0.16,
    this.dryThin = 0.30,
    this.kmScale = 3.2,
    this.hCover = 0.075,
  });

  /// Effective yield stress once dissolved medium and thixotropic structure
  /// are applied. `mediumFraction`/`structure` are the local field values.
  double yieldStress(double mediumFraction, double structure) {
    final thinned = (1.0 - mediumFraction.clamp(0.0, 1.0) * mediumThinning)
        .clamp(0.0, 1.0);
    final structFactor = 1.0 + thixo * (structure.clamp(0.0, 1.0) - 1.0);
    return tauY0 * thinned * structFactor;
  }

  /// Effective consistency `K` after medium thinning (floored so mobility
  /// stays finite).
  double consistency(double mediumFraction) {
    final thinned = (1.0 - mediumFraction.clamp(0.0, 1.0) * mediumThinning)
        .clamp(0.05, 1.0);
    return consistencyK * thinned;
  }

  /// Herschel-Bulkley mobility `Mob(h) = (ρg/K)^(1/n) · h^(2+1/n) / (2+1/n)`.
  double mobility(double h, double mediumFraction) {
    if (h <= 0.0) return 0.0;
    final invN = 1.0 / flowIndexN;
    return math.pow(rhoG / consistency(mediumFraction), invN) *
        math.pow(h, 2.0 + invN) /
        (2.0 + invN);
  }

  OilParams copyWith({
    double? dt,
    int? substeps,
    double? tauY0,
    double? consistencyK,
    double? flowIndexN,
    double? rhoG,
    double? tiltX,
    double? tiltY,
    double? depositRate,
    double? pickupRate,
    double? coupling,
    double? brushFilm,
    double? toothReach,
    double? mediumThinning,
    double? thixo,
    double? recover,
    double? breakdown,
    double? gloss,
    double? oilSheen,
    double? ambient,
    double? lightAzimuth,
    double? lightElevation,
    double? toothAmp,
    double? reliefAmp,
    double? toothLo,
    double? toothHi,
    double? dryThin,
    double? kmScale,
    double? hCover,
  }) {
    return OilParams(
      dt: dt ?? this.dt,
      substeps: substeps ?? this.substeps,
      tauY0: tauY0 ?? this.tauY0,
      consistencyK: consistencyK ?? this.consistencyK,
      flowIndexN: flowIndexN ?? this.flowIndexN,
      rhoG: rhoG ?? this.rhoG,
      tiltX: tiltX ?? this.tiltX,
      tiltY: tiltY ?? this.tiltY,
      depositRate: depositRate ?? this.depositRate,
      pickupRate: pickupRate ?? this.pickupRate,
      coupling: coupling ?? this.coupling,
      brushFilm: brushFilm ?? this.brushFilm,
      toothReach: toothReach ?? this.toothReach,
      mediumThinning: mediumThinning ?? this.mediumThinning,
      thixo: thixo ?? this.thixo,
      recover: recover ?? this.recover,
      breakdown: breakdown ?? this.breakdown,
      gloss: gloss ?? this.gloss,
      oilSheen: oilSheen ?? this.oilSheen,
      ambient: ambient ?? this.ambient,
      lightAzimuth: lightAzimuth ?? this.lightAzimuth,
      lightElevation: lightElevation ?? this.lightElevation,
      toothAmp: toothAmp ?? this.toothAmp,
      reliefAmp: reliefAmp ?? this.reliefAmp,
      toothLo: toothLo ?? this.toothLo,
      toothHi: toothHi ?? this.toothHi,
      dryThin: dryThin ?? this.dryThin,
      kmScale: kmScale ?? this.kmScale,
      hCover: hCover ?? this.hCover,
    );
  }
}
