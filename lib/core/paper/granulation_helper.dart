/// Utility for biasing pigment deposit based on paper surface geometry.
///
/// Granulating pigments (e.g., French Ultramarine, Burnt Sienna) settle
/// unevenly — heavier particles drop into paper valleys, leaving peaks
/// cleaner. This creates the characteristic speckled/granulated look.
///
/// This helper connects [Pigment.granulation] to the paper surface height
/// map. See ARCHITECTURE.md "Domain Separation": this lives outside both
/// [Pigment] and [PaperTexture] because it's a rule that relates the two,
/// not a property either one owns alone.
class GranulationHelper {
  /// Calculate an opacity multiplier for pigment deposit based on paper
  /// surface geometry and pigment granulation properties.
  ///
  /// [paperHeight]: height map value at this point (0.0 = valley, 1.0 = peak).
  /// [pigmentGranulation]: pigment's granulation property (0.0 = smooth, 1.0 = heavy).
  /// [paperGranulationSupport]: paper's granulation support (0.0 = ignores, 1.0 = enhances).
  ///
  /// Returns an opacity multiplier in [0.3, 1.4]:
  /// - Valley + granulating pigment + rough paper → higher multiplier (more deposit).
  /// - Peak + granulating pigment + rough paper → lower multiplier (less deposit).
  /// - Non-granulating pigment → near 1.0 regardless of paper height.
  static double granulationBias(
    double paperHeight,
    double pigmentGranulation,
    double paperGranulationSupport,
  ) {
    // Combined granulation strength: both pigment and paper must contribute.
    final strength = pigmentGranulation * paperGranulationSupport;

    // No granulation effect when either pigment or paper don't support it.
    if (strength < 0.01) return 1.0;

    // Valley depth: 0.0 = peak, 1.0 = deepest valley.
    final valleyDepth = 1.0 - paperHeight;

    // Bias curve: valleys get more pigment, peaks get less.
    //
    // At valleyDepth = 1.0 (deep valley): multiplier > 1.0 (more deposit).
    // At valleyDepth = 0.0 (peak): multiplier < 1.0 (less deposit).
    // At valleyDepth = 0.5 (mid): multiplier ≈ 1.0 (neutral).
    final bias = 1.0 + (valleyDepth - 0.5) * strength * 0.8;

    return bias.clamp(0.3, 1.4);
  }

  // Note: a distance-based "density settling bias" (lighter pigments travel
  // farther, denser pigments settle sooner within a moving wash) belongs
  // here once Phase 4 (water flow) exists to call it. It isn't stubbed
  // ahead of time — see ARCHITECTURE.md "Known Architectural Decisions" on
  // not scaffolding unused code speculatively.
}
