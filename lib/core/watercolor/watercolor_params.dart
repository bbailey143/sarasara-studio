/// Tunable constants for the watercolor Fluid + Pigment CPU reference. The
/// diffusion-only path is an isolated historical fallback; live values are
/// tuned by eye under the binding `watercolor-engine-spec.md` contract.
class WatercolorParams {
  final WatercolorTransportMode transportMode;

  /// Stable-fluids controls used by the binding Fluid pipeline.
  final double viscosity;
  final int viscosityIters;
  final int pressureIters;
  final double heightForce;
  final double gravityX;
  final double gravityY;

  /// Microscopic wet-into-wet exchange. Fluid velocity owns bulk movement;
  /// this only softens and mingles connected pigment. 0 = no exchange.
  final double bleed;

  /// How many diffusion sub-passes run per step. >1 lets pigment spread much
  /// wider than a single stable pass allows — the difference between a thin
  /// seam and colours genuinely blending across a wide wet zone.
  final int bleedIters;

  /// Capillary water spread: how fast the wet region grows into damp paper.
  final double wetSpread;

  /// Evaporation per step (dry rate). Lower = paint stays wet longer, so there
  /// is more time to see it bleed and settle.
  final double dry;

  /// How much slower paper saturation dries than surface water (keeps a region
  /// workably damp after the shine is gone).
  final double paperDryFactor;

  /// Edge-darkening strength: extra settling at the drying wet boundary.
  final double edge;

  /// Base settle rate: suspended → deposited as the wash dries.
  final double settle;

  /// Re-wet lift: settled pigment re-mobilized when water returns (blooms).
  final double lift;

  /// Brush-momentum carry: fraction of brush velocity imposed on fresh pigment
  /// (directional bleed + end-of-stroke fling).
  final double momentum;

  /// Velocity damping per step (how quickly momentum bleeding stops).
  final double velDamp;

  /// Water absorbed into paper saturation per step (extends wet time).
  final double soak;

  /// Scale used to derive the soft mobility mask from surface water and paper
  /// saturation. Final dry locking uses [wetOff]/[wetOn] plus the hold below.
  final double wetThreshold;

  /// Dry-state hysteresis and hold. A momentary dip below [wetOff] does not
  /// freeze a wash; mobility above [wetOn] cancels the pending dry lock.
  final double wetOff;
  final double wetOn;
  final double dryHoldSeconds;

  /// Fixed CPU-reference simulation cadence. The live driver still needs the
  /// roadmap's elapsed-time accumulator, but dry holds are expressed in real
  /// seconds rather than an unexplained frame count.
  final double stepSeconds;

  const WatercolorParams({
    this.transportMode = WatercolorTransportMode.fluid,
    this.viscosity = 0.055,
    this.viscosityIters = 1,
    this.pressureIters = 8,
    this.heightForce = 1.2,
    this.gravityX = 0.0,
    this.gravityY = 0.0,
    this.bleed = 0.22,
    this.bleedIters = 2,
    this.wetSpread = 0.22,
    this.dry = 0.0025,
    // Surface shine may disappear quickly while paper-held moisture remains
    // workable. This keeps a normal wash open through a colour change instead
    // of silently freezing it after only a few seconds.
    this.paperDryFactor = 0.22,
    this.edge = 2.2,
    this.settle = 0.06,
    this.lift = 0.035,
    this.momentum = 0.9,
    this.velDamp = 0.86,
    this.soak = 0.05,
    this.wetThreshold = 0.045,
    this.wetOff = 0.01,
    this.wetOn = 0.03,
    this.dryHoldSeconds = 0.15,
    this.stepSeconds = 1.0 / 30.0,
  });

  WatercolorParams copyWith({
    WatercolorTransportMode? transportMode,
    double? viscosity,
    int? viscosityIters,
    int? pressureIters,
    double? heightForce,
    double? gravityX,
    double? gravityY,
    double? bleed,
    int? bleedIters,
    double? wetSpread,
    double? dry,
    double? paperDryFactor,
    double? edge,
    double? settle,
    double? lift,
    double? momentum,
    double? velDamp,
    double? soak,
    double? wetThreshold,
    double? wetOff,
    double? wetOn,
    double? dryHoldSeconds,
    double? stepSeconds,
  }) {
    return WatercolorParams(
      transportMode: transportMode ?? this.transportMode,
      viscosity: viscosity ?? this.viscosity,
      viscosityIters: viscosityIters ?? this.viscosityIters,
      pressureIters: pressureIters ?? this.pressureIters,
      heightForce: heightForce ?? this.heightForce,
      gravityX: gravityX ?? this.gravityX,
      gravityY: gravityY ?? this.gravityY,
      bleed: bleed ?? this.bleed,
      bleedIters: bleedIters ?? this.bleedIters,
      wetSpread: wetSpread ?? this.wetSpread,
      dry: dry ?? this.dry,
      paperDryFactor: paperDryFactor ?? this.paperDryFactor,
      edge: edge ?? this.edge,
      settle: settle ?? this.settle,
      lift: lift ?? this.lift,
      momentum: momentum ?? this.momentum,
      velDamp: velDamp ?? this.velDamp,
      soak: soak ?? this.soak,
      wetThreshold: wetThreshold ?? this.wetThreshold,
      wetOff: wetOff ?? this.wetOff,
      wetOn: wetOn ?? this.wetOn,
      dryHoldSeconds: dryHoldSeconds ?? this.dryHoldSeconds,
      stepSeconds: stepSeconds ?? this.stepSeconds,
    );
  }
}

enum WatercolorTransportMode { fluid, diffusionFallback }
