import 'dart:ui';

/// Paper data model — defines how the painting surface behaves.
///
/// Paper is not just a background image. It is an active material that
/// changes how brushes, water, and pigments behave.
///
/// See ARCHITECTURE.md "Domain Separation" for the paper/brush/pigment
/// boundary, and ROADMAP.md Phase 3 for design rationale.
class Paper {
  /// Display name (e.g., "Cold Press", "Rough Arches").
  final String name;

  /// Paper type category.
  final PaperType type;

  /// Tooth / roughness (0.0 = glass smooth, 1.0 = very rough).
  /// Affects dry-brush breakup, granulation catching, and visible texture.
  final double tooth;

  /// Absorbency (0.0 = slow absorption, 1.0 = instant soak).
  /// Affects how quickly water sinks into the paper.
  final double absorbency;

  /// Sizing amount (0.0 = unsized / absorbs freely, 1.0 = heavily sized).
  /// Sizing slows water absorption and helps keep wet boundaries firm.
  final double sizing;

  /// Water-holding capacity (0.0 = sheds water, 1.0 = holds puddles).
  /// Varies per-pixel in the actual simulation; this is the base value.
  final double capacity;

  /// Edge darkening strength (0.0 = no edge effect, 1.0 = strong rim).
  /// Controls the classic watercolor darker-edge effect on drying.
  final double edgeDarkening;

  /// Granulation support (0.0 = ignores pigment granulation,
  /// 1.0 = enhances granulation settling).
  final double granulationSupport;

  /// Dry-brush breakup (0.0 = no breakup, 1.0 = maximum skip/gap).
  /// Works with [tooth] to determine how dry-brush strokes break apart.
  final double dryBrushBreakup;

  /// The base color of the paper surface.
  final Color paperColor;

  /// Noise seed for deterministic procedural texture generation.
  /// Different seeds produce different texture patterns with the same
  /// paper properties.
  final int seed;

  /// Noise scale controlling grain size.
  /// Lower values = coarser grain, higher values = finer grain.
  /// Typical range: 0.4 (very coarse rough paper) to 3.0 (fine hot press).
  final double noiseScale;

  const Paper({
    this.name = 'Cold Press',
    this.type = PaperType.coldPress,
    this.tooth = 0.5,
    this.absorbency = 0.5,
    this.sizing = 0.6,
    this.capacity = 0.5,
    this.edgeDarkening = 0.5,
    this.granulationSupport = 0.5,
    this.dryBrushBreakup = 0.5,
    this.paperColor = const Color(0xFFFAF8F5),
    this.seed = 42,
    this.noiseScale = 1.0,
  });

  /// Copy with modified values.
  Paper copyWith({
    String? name,
    PaperType? type,
    double? tooth,
    double? absorbency,
    double? sizing,
    double? capacity,
    double? edgeDarkening,
    double? granulationSupport,
    double? dryBrushBreakup,
    Color? paperColor,
    int? seed,
    double? noiseScale,
  }) {
    return Paper(
      name: name ?? this.name,
      type: type ?? this.type,
      tooth: tooth ?? this.tooth,
      absorbency: absorbency ?? this.absorbency,
      sizing: sizing ?? this.sizing,
      capacity: capacity ?? this.capacity,
      edgeDarkening: edgeDarkening ?? this.edgeDarkening,
      granulationSupport: granulationSupport ?? this.granulationSupport,
      dryBrushBreakup: dryBrushBreakup ?? this.dryBrushBreakup,
      paperColor: paperColor ?? this.paperColor,
      seed: seed ?? this.seed,
      noiseScale: noiseScale ?? this.noiseScale,
    );
  }

  // ─── Default Presets ───────────────────────────────────────────────

  /// Plain White — glass smooth, pure white background, no texture, no dry-brush breakup.
  static const Paper plain = Paper(
    name: 'Plain White',
    type: PaperType.hotPress,
    tooth: 0.0,
    absorbency: 0.0,
    sizing: 1.0,
    capacity: 0.0,
    edgeDarkening: 0.0,
    granulationSupport: 0.0,
    dryBrushBreakup: 0.0,
    paperColor: Color(0xFFFFFFFF),
    seed: 0,
    noiseScale: 1.0,
  );

  /// Hot press — smooth, even pigment, weaker dry-brush gaps.
  static const Paper hotPress = Paper(
    name: 'Hot Press',
    type: PaperType.hotPress,
    tooth: 0.15,
    absorbency: 0.3,
    sizing: 0.8,
    capacity: 0.4,
    edgeDarkening: 0.6,
    granulationSupport: 0.2,
    dryBrushBreakup: 0.15,
    paperColor: Color(0xFFFCFAF7),
    seed: 101,
    noiseScale: 2.0,
  );

  /// Cold press — medium tooth, visible granulation, natural variation.
  static const Paper coldPress = Paper(
    name: 'Cold Press',
    type: PaperType.coldPress,
    tooth: 0.5,
    absorbency: 0.5,
    sizing: 0.6,
    capacity: 0.5,
    edgeDarkening: 0.5,
    granulationSupport: 0.5,
    dryBrushBreakup: 0.5,
    paperColor: Color(0xFFFAF8F5),
    seed: 42,
    noiseScale: 1.0,
  );

  /// Rough — strong tooth, strong dry-brush skips, strong settling.
  static const Paper rough = Paper(
    name: 'Rough',
    type: PaperType.rough,
    tooth: 0.85,
    absorbency: 0.6,
    sizing: 0.5,
    capacity: 0.7,
    edgeDarkening: 0.4,
    granulationSupport: 0.8,
    dryBrushBreakup: 0.8,
    paperColor: Color(0xFFF5F0E8),
    seed: 7,
    noiseScale: 0.6,
  );

  /// All built-in paper presets.
  static const List<Paper> presets = [plain, hotPress, coldPress, rough];
}

/// Categories of watercolor paper.
enum PaperType {
  /// Hot press — smooth surface, calendered flat.
  hotPress,

  /// Cold press — medium texture, most popular for watercolor.
  coldPress,

  /// Rough — heavy texture, strong tooth.
  rough,

  /// Custom — user-defined paper.
  custom,
}
