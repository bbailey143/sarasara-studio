import 'dart:math' as math;
import 'dart:ui';

/// Pigment identity — describes how a pigment behaves as a material.
///
/// A pigment carries eight-band absorption and scattering spectra plus the
/// material properties used for staining, lifting, and settling. Mixing lives
/// in the shared spectral pigment engine rather than RGB color space.
class Pigment {
  /// Display name (e.g., "Hansa Yellow", "French Ultramarine").
  final String name;

  /// Artist-facing swatch. Mixing uses [absorptionK]/[scatteringS], never RGB.
  final Color displayColor;

  /// Eight-band Kubelka-Munk coefficients at 400..708 nm.
  final List<double> absorptionK;
  final List<double> scatteringS;

  /// Opacity/transparency (0.0 = fully transparent glaze, 1.0 = fully opaque).
  final double opacity;

  /// Staining strength (0.0 = lifts easily, 1.0 = permanent stain).
  /// Controls how strongly pigment grabs the paper.
  final double staining;

  /// Granulation (0.0 = smooth flat color, 1.0 = heavy speckled settling).
  /// Tied to both pigment identity and paper texture.
  final double granulation;

  /// Density / settling speed (0.0 = stays suspended, travels far;
  /// 1.0 = settles quickly, stays put).
  final double density;

  /// Tint strength (0.0 = weak, easily overpowered; 1.0 = overpowers others).
  /// Determines how much this pigment dominates in dirty-brush mixes.
  final double tintStrength;

  Pigment({
    required this.name,
    required this.displayColor,
    required List<double> absorptionK,
    required List<double> scatteringS,
    this.opacity = 0.8,
    this.staining = 0.5,
    this.granulation = 0.3,
    this.density = 0.5,
    this.tintStrength = 0.5,
  }) : absorptionK = List.unmodifiable(absorptionK),
       scatteringS = List.unmodifiable(scatteringS) {
    if (this.absorptionK.length != 8 || this.scatteringS.length != 8) {
      throw ArgumentError('Pigments require exactly eight K/S bands.');
    }
  }

  factory Pigment.fromReflectance({
    required String name,
    required Color displayColor,
    required List<double> reflectance,
    double scattering = 0.65,
    double opacity = 0.8,
    double staining = 0.5,
    double granulation = 0.3,
    double density = 0.5,
    double tintStrength = 0.5,
  }) {
    if (reflectance.length != 8) {
      throw ArgumentError('Reflectance requires exactly eight bands.');
    }
    final s = List<double>.filled(8, scattering);
    final k = reflectance
        .map((value) {
          final r = value.clamp(0.01, 0.995);
          return ((1.0 - r) * (1.0 - r) / (2.0 * r)) * scattering;
        })
        .toList(growable: false);
    return Pigment(
      name: name,
      displayColor: displayColor,
      absorptionK: k,
      scatteringS: s,
      opacity: opacity,
      staining: staining,
      granulation: granulation,
      density: density,
      tintStrength: tintStrength,
    );
  }

  /// Create an unnamed picked color while still treating it like paint.
  ///
  /// Maps sRGB to a saturated 8-band reflectance (each band dominated by the
  /// channel that emits at that wavelength, off-channels pushed low) and uses
  /// **low scattering** like the transparent named pigments — otherwise picked
  /// colors read chalky and wash out as they thin, unlike the palette.
  factory Pigment.custom({required String name, required Color displayColor}) {
    final r = displayColor.r;
    final g = displayColor.g;
    final b = displayColor.b;
    // Bands ≈ 400(violet) 444(blue) 488(cyan) 532(green) 576(y-green)
    //         620(orange) 664(red) 708(deep red).
    final reflectance = <double>[
      0.55 * b + 0.20 * r,
      0.95 * b,
      0.55 * b + 0.45 * g,
      0.95 * g,
      0.70 * g + 0.25 * r,
      0.88 * r + 0.12 * g,
      0.97 * r,
      0.85 * r,
    ].map((value) => math.min(0.97, math.max(0.03, value))).toList();
    return Pigment.fromReflectance(
      name: name,
      displayColor: displayColor,
      reflectance: reflectance,
      scattering: 0.32,
      opacity: 0.8,
      staining: 0.5,
      granulation: 0.1,
      density: 0.4,
      tintStrength: 0.5,
    );
  }

  // ─── Default Watercolor Palette ────────────────────────────────────
  //
  // One blue, one yellow, one red/magenta, one white, plus a couple of
  // named earth pigments for mixing-character tests.

  static final Pigment phthaloBlue = Pigment.fromReflectance(
    name: 'Phthalo Blue',
    displayColor: Color(0xFF0D3B66),
    reflectance: [0.42, 0.72, 0.72, 0.58, 0.10, 0.035, 0.025, 0.02],
    scattering: 0.38,
    opacity: 0.7,
    staining: 0.9,
    granulation: 0.1,
    density: 0.4,
    tintStrength: 0.9,
  );

  static final Pigment frenchUltramarine = Pigment.fromReflectance(
    name: 'French Ultramarine',
    displayColor: Color(0xFF2C5F8A),
    reflectance: [0.5, 0.78, 0.62, 0.32, 0.09, 0.05, 0.035, 0.025],
    scattering: 0.75,
    opacity: 0.6,
    staining: 0.4,
    granulation: 0.7,
    density: 0.6,
    tintStrength: 0.7,
  );

  static final Pigment quinacridoneMagenta = Pigment.fromReflectance(
    name: 'Quinacridone Magenta',
    displayColor: Color(0xFF8B1A4A),
    reflectance: [0.58, 0.32, 0.08, 0.035, 0.12, 0.62, 0.7, 0.38],
    scattering: 0.3,
    opacity: 0.5,
    staining: 0.8,
    granulation: 0.1,
    density: 0.3,
    tintStrength: 0.8,
  );

  static final Pigment hansaYellow = Pigment.fromReflectance(
    name: 'Hansa Yellow',
    displayColor: Color(0xFFEBC944),
    reflectance: [0.035, 0.06, 0.22, 0.72, 0.92, 0.88, 0.64, 0.45],
    scattering: 0.42,
    opacity: 0.4,
    staining: 0.3,
    granulation: 0.0,
    density: 0.2,
    tintStrength: 0.6,
  );

  static final Pigment titaniumWhite = Pigment.fromReflectance(
    name: 'Titanium White',
    displayColor: Color(0xFFF5F5F5),
    reflectance: [0.94, 0.96, 0.975, 0.985, 0.985, 0.98, 0.97, 0.95],
    scattering: 2.4,
    opacity: 1.0,
    staining: 0.1,
    granulation: 0.0,
    density: 0.3,
    tintStrength: 0.4,
  );

  static final Pigment burntSienna = Pigment.fromReflectance(
    name: 'Burnt Sienna',
    displayColor: Color(0xFF8B4513),
    reflectance: [0.06, 0.055, 0.05, 0.08, 0.2, 0.48, 0.42, 0.24],
    scattering: 0.62,
    opacity: 0.6,
    staining: 0.5,
    granulation: 0.5,
    density: 0.6,
    tintStrength: 0.5,
  );

  /// The starter palette for testing and early builds.
  static final List<Pigment> starterPalette = List.unmodifiable([
    phthaloBlue,
    frenchUltramarine,
    quinacridoneMagenta,
    hansaYellow,
    titaniumWhite,
    burntSienna,
  ]);

  /// Forty-eight fixed-cost spectral entries ready for the shared GPU LUT.
  /// The first six have hand-shaped spectra above; the extended artist set is
  /// spectrally derived from its swatches and can be measurement-calibrated
  /// later without changing canvas storage or mixture code.
  static final List<Pigment> palette48 = List.unmodifiable([
    ...starterPalette,
    _swatch('Cadmium Yellow Light', 0xFFFFD83D),
    _swatch('Yellow Ochre', 0xFFC9973A),
    _swatch('Raw Sienna', 0xFFB8864B),
    _swatch('Cadmium Orange', 0xFFF36B21),
    _swatch('Pyrrol Orange', 0xFFE84B20),
    _swatch('Vermilion', 0xFFE34234),
    _swatch('Cadmium Red', 0xFFD9362B),
    _swatch('Pyrrol Red', 0xFFB82932),
    _swatch('Alizarin Crimson', 0xFF8C2034),
    _swatch('Quinacridone Rose', 0xFFB52363),
    _swatch('Dioxazine Purple', 0xFF4B286D),
    _swatch('Cobalt Violet', 0xFF76539A),
    _swatch('Ultramarine Violet', 0xFF554E91),
    _swatch('Cobalt Blue', 0xFF3568A8),
    _swatch('Cerulean Blue', 0xFF3E8EAD),
    _swatch('Indanthrone Blue', 0xFF1E3D67),
    _swatch('Prussian Blue', 0xFF183D54),
    _swatch('Cobalt Turquoise', 0xFF258F91),
    _swatch('Viridian', 0xFF247A61),
    _swatch('Phthalo Green', 0xFF08745B),
    _swatch('Sap Green', 0xFF597A3B),
    _swatch('Hookers Green', 0xFF315E3A),
    _swatch('Olive Green', 0xFF68713D),
    _swatch('Terre Verte', 0xFF718267),
    _swatch('Raw Umber', 0xFF76563A),
    _swatch('Burnt Umber', 0xFF5B392B),
    _swatch('Sepia', 0xFF4B342B),
    _swatch('Van Dyke Brown', 0xFF3F302A),
    _swatch('Mars Black', 0xFF202020),
    _swatch('Ivory Black', 0xFF292827),
    _swatch('Paynes Gray', 0xFF344552),
    _swatch('Neutral Tint', 0xFF514B52),
    _swatch('Zinc White', 0xFFF8F7F2),
    _swatch('Buff Titanium', 0xFFE6D4B3),
    _swatch('Naples Yellow', 0xFFE6C46A),
    _swatch('Indian Yellow', 0xFFE7A72D),
    _swatch('Aureolin', 0xFFF0D34F),
    _swatch('Potters Pink', 0xFFA76B70),
    _swatch('Cobalt Teal', 0xFF2C9A9B),
    _swatch('Manganese Blue', 0xFF3A91B5),
    _swatch('Chromium Oxide Green', 0xFF4D7044),
    _swatch('Venetian Red', 0xFF9B4438),
  ]);

  static Pigment _swatch(String name, int argb) =>
      Pigment.custom(name: name, displayColor: Color(argb));
}
