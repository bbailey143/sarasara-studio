/// Brush data model — defines how a brush behaves.
///
/// Pure data: no simulation logic lives here. Brush *shape/motion* behavior
/// lives in core/rendering/brush_physics_engine.dart and
/// core/rendering/stroke_renderer.dart, which read these fields but never
/// write pigment or paper state (see ARCHITECTURE.md "Domain Separation").
enum BrushFamily { round, flat, bright, filbert, mop, rigger, fan, knife }

class Brush {
  final String id;

  /// Display name for the brush.
  final String name;

  /// Physical construction family. It never identifies the loaded medium.
  final BrushFamily family;

  /// Brush radius in logical pixels at full pressure.
  final double size;

  /// Base opacity (0.0 = fully transparent, 1.0 = fully opaque).
  final double opacity;

  /// Wetness of the brush (0.0 = bone dry, 1.0 = dripping wet).
  /// Affects pigment release, the wet contact zone, and dry-brush breakup.
  final double wetness;

  /// How much paint the brush starts with (0.0 = empty, 1.0 = fully loaded).
  /// Load depletes over a stroke, affecting density and dry-brush skipping.
  final double paintLoad;

  /// Softness of the brush (0.0 = stiff/synthetic, 1.0 = floppy/mop).
  /// Affects pressure response and tuft spread.
  final double softness;

  /// Spring/snap recovery speed (0.0 = no snap, 1.0 = instant recovery).
  /// Controls how fast the brush shape recovers after pressure or
  /// direction changes.
  final double spring;

  /// Number of tufts in the brush head.
  /// Each tuft produces multiple bristle marks.
  final int tufts;

  /// Pressure sensitivity curve power.
  /// 1.0 = linear, <1.0 = more responsive at light pressure,
  /// >1.0 = more responsive at heavy pressure.
  final double pressureCurve;

  /// Whether the brush head is flat (linear layout) or round (circular layout).
  final bool isFlat;

  /// Number of bristles per tuft.
  final int bristleCount;

  /// Scatter/jitter offset for bristles (0.0 to 1.0).
  final double bristleScatter;

  /// Point-wise stress split threshold.
  final double splitThreshold;

  /// Rigidity coefficient of the bristles (0 = fully limp, 1 = fully rigid).
  final double rigidity;

  /// Friction coefficient against the paper (0 = no friction, 1 = high friction).
  final double frictionCoef;

  /// Damping factor for wetness-based lag (0 = no damp, 1 = high damp).
  final double damping;

  /// Exposed hair length and bundle radius in the same canvas-physical units
  /// as [size]. These describe the tool, not a painted mark.
  final double bristleLength;
  final double bundleRadius;

  /// Fiber grouping and surface behavior.
  final double cohesion;
  final double roughness;
  final double absorbency;
  final double maxSplay;

  /// Reservoir construction. Medium contents live in BrushReservoir.
  final double reservoirCapacity;
  final double tipCapacityFraction;
  final double releaseConductance;
  final double pickupConductance;

  const Brush({
    this.id = 'sable-round',
    this.name = 'Sable Round',
    this.family = BrushFamily.round,
    this.size = 8.0,
    this.opacity = 1.0,
    this.wetness = 0.6,
    this.paintLoad = 0.8,
    this.softness = 0.4,
    this.spring = 0.5,
    this.tufts = 5,
    this.pressureCurve = 1.0,
    this.isFlat = false,
    this.bristleCount = 8,
    this.bristleScatter = 0.15,
    this.splitThreshold = 0.6,
    this.rigidity = 0.4,
    this.frictionCoef = 0.3,
    this.damping = 0.4,
    this.bristleLength = 18.0,
    this.bundleRadius = 4.0,
    this.cohesion = 0.75,
    this.roughness = 0.15,
    this.absorbency = 0.75,
    this.maxSplay = 0.65,
    this.reservoirCapacity = 1.0,
    this.tipCapacityFraction = 0.3,
    this.releaseConductance = 0.3,
    this.pickupConductance = 0.2,
  });

  /// Copy with modified values.
  Brush copyWith({
    String? id,
    String? name,
    BrushFamily? family,
    double? size,
    double? opacity,
    double? wetness,
    double? paintLoad,
    double? softness,
    double? spring,
    int? tufts,
    double? pressureCurve,
    bool? isFlat,
    int? bristleCount,
    double? bristleScatter,
    double? splitThreshold,
    double? rigidity,
    double? frictionCoef,
    double? damping,
    double? bristleLength,
    double? bundleRadius,
    double? cohesion,
    double? roughness,
    double? absorbency,
    double? maxSplay,
    double? reservoirCapacity,
    double? tipCapacityFraction,
    double? releaseConductance,
    double? pickupConductance,
  }) {
    return Brush(
      id: id ?? this.id,
      name: name ?? this.name,
      family: family ?? this.family,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      wetness: wetness ?? this.wetness,
      paintLoad: paintLoad ?? this.paintLoad,
      softness: softness ?? this.softness,
      spring: spring ?? this.spring,
      tufts: tufts ?? this.tufts,
      pressureCurve: pressureCurve ?? this.pressureCurve,
      isFlat: isFlat ?? this.isFlat,
      bristleCount: bristleCount ?? this.bristleCount,
      bristleScatter: bristleScatter ?? this.bristleScatter,
      splitThreshold: splitThreshold ?? this.splitThreshold,
      rigidity: rigidity ?? this.rigidity,
      frictionCoef: frictionCoef ?? this.frictionCoef,
      damping: damping ?? this.damping,
      bristleLength: bristleLength ?? this.bristleLength,
      bundleRadius: bundleRadius ?? this.bundleRadius,
      cohesion: cohesion ?? this.cohesion,
      roughness: roughness ?? this.roughness,
      absorbency: absorbency ?? this.absorbency,
      maxSplay: maxSplay ?? this.maxSplay,
      reservoirCapacity: reservoirCapacity ?? this.reservoirCapacity,
      tipCapacityFraction: tipCapacityFraction ?? this.tipCapacityFraction,
      releaseConductance: releaseConductance ?? this.releaseConductance,
      pickupConductance: pickupConductance ?? this.pickupConductance,
    );
  }

  // ─── Default Presets ───────────────────────────────────────────────

  /// A size-8 watercolor round: crisp toe, full belly, soft sable recovery.
  static const Brush sableRound = Brush(
    id: 'sable-round-5',
    name: 'Sable Round',
    family: BrushFamily.round,
    size: 8.0,
    opacity: 0.92,
    wetness: 0.76,
    paintLoad: 0.92,
    softness: 0.68,
    spring: 0.42,
    tufts: 3,
    pressureCurve: 1.25,
    isFlat: false,
    bristleCount: 3,
    bristleScatter: 0.15,
    splitThreshold: 0.95,
    rigidity: 0.26,
    frictionCoef: 0.18,
    damping: 0.58,
    bristleLength: 20.0,
    bundleRadius: 4.0,
    cohesion: 0.9,
    roughness: 0.08,
    absorbency: 0.9,
    maxSplay: 0.72,
    reservoirCapacity: 1.0,
    tipCapacityFraction: 0.24,
    releaseConductance: 0.24,
    pickupConductance: 0.18,
  );

  /// A large, soft mop brush that has a lot of lag and holds a lot of water.
  static const Brush sableMop = Brush(
    id: 'sable-mop',
    name: 'Sable Mop',
    family: BrushFamily.mop,
    size: 14.0,
    opacity: 0.7,
    wetness: 0.8,
    paintLoad: 0.9,
    softness: 0.8,
    spring: 0.3,
    tufts: 3,
    pressureCurve: 1.0,
    isFlat: false,
    bristleCount: 4,
    bristleScatter: 0.2,
    splitThreshold: 0.8,
    rigidity: 0.2,
    frictionCoef: 0.2,
    damping: 0.7,
    bristleLength: 27.0,
    bundleRadius: 7.0,
    cohesion: 0.78,
    roughness: 0.12,
    absorbency: 1.0,
    maxSplay: 0.9,
    reservoirCapacity: 1.8,
    tipCapacityFraction: 0.2,
    releaseConductance: 0.18,
    pickupConductance: 0.2,
  );

  /// A small, snappy brush for fine detail work.
  static const Brush syntheticDetailRound = Brush(
    id: 'synthetic-detail-round',
    name: 'Synthetic Detail Round',
    family: BrushFamily.round,
    size: 4.0,
    opacity: 1.0,
    wetness: 0.4,
    paintLoad: 0.9,
    softness: 0.2,
    spring: 0.8,
    tufts: 1,
    pressureCurve: 1.0,
    isFlat: false,
    bristleCount: 5,
    bristleScatter: 0.05,
    splitThreshold: 0.7,
    rigidity: 0.8,
    frictionCoef: 0.5,
    damping: 0.2,
    bristleLength: 10.0,
    bundleRadius: 2.0,
    cohesion: 0.95,
    roughness: 0.04,
    absorbency: 0.35,
    maxSplay: 0.35,
    reservoirCapacity: 0.35,
  );

  /// A flat brush for calligraphic strokes and broad flat washes.
  static const Brush sableFlat = Brush(
    id: 'sable-flat',
    name: 'Sable Flat',
    family: BrushFamily.flat,
    size: 20.0,
    opacity: 0.8,
    wetness: 0.7,
    paintLoad: 0.8,
    softness: 0.5,
    spring: 0.4,
    tufts: 6,
    pressureCurve: 1.0,
    isFlat: true,
    bristleCount: 2,
    bristleScatter: 0.15,
    splitThreshold: 0.5,
    rigidity: 0.3,
    frictionCoef: 0.4,
    damping: 0.5,
    bristleLength: 16.0,
    bundleRadius: 10.0,
    cohesion: 0.72,
    roughness: 0.1,
    absorbency: 0.72,
    maxSplay: 0.6,
    reservoirCapacity: 1.2,
  );

  /// A firm flat brush for dry texture.
  static const Brush bristleFlat = Brush(
    id: 'bristle-flat',
    name: 'Bristle Flat',
    family: BrushFamily.bright,
    size: 10.0,
    opacity: 0.95,
    wetness: 0.3,
    paintLoad: 0.8,
    softness: 0.2,
    spring: 0.7,
    tufts: 5,
    pressureCurve: 1.0,
    isFlat: true,
    bristleCount: 2,
    bristleScatter: 0.25,
    splitThreshold: 0.4,
    rigidity: 0.6,
    frictionCoef: 0.7,
    damping: 0.3,
    bristleLength: 11.0,
    bundleRadius: 5.0,
    cohesion: 0.42,
    roughness: 0.48,
    absorbency: 0.25,
    maxSplay: 0.48,
    reservoirCapacity: 0.55,
  );

  /// A split, heavily worn filbert brush.
  static const Brush wornBristleFilbert = Brush(
    id: 'worn-bristle-filbert',
    name: 'Worn Bristle Filbert',
    family: BrushFamily.filbert,
    size: 12.0,
    opacity: 0.85,
    wetness: 0.25,
    paintLoad: 0.7,
    softness: 0.5,
    spring: 0.3,
    tufts: 5,
    pressureCurve: 1.0,
    isFlat: true,
    bristleCount: 2,
    bristleScatter: 0.45,
    splitThreshold: 0.3,
    rigidity: 0.3,
    frictionCoef: 0.6,
    damping: 0.4,
    bristleLength: 13.0,
    bundleRadius: 6.0,
    cohesion: 0.24,
    roughness: 0.72,
    absorbency: 0.3,
    maxSplay: 0.75,
    reservoirCapacity: 0.6,
  );

  /// All built-in brush presets.
  static const List<Brush> presets = [
    sableRound,
    sableMop,
    syntheticDetailRound,
    sableFlat,
    bristleFlat,
    wornBristleFilbert,
  ];
}
