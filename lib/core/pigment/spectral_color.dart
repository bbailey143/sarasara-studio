import 'dart:math' as math;
import 'dart:ui';

/// Shared eight-band Kubelka-Munk optics used by every medium.
class SpectralColor {
  const SpectralColor._();

  static const int bands = 8;

  // Compact band-to-linear-sRGB integration weights at the spec's band
  // centers. Each channel is normalized so a unit reflector maps to white.
  static const List<List<double>> _rgbWeights = [
    [0.35, 0.00, 0.65],
    [0.05, 0.10, 1.00],
    [0.00, 0.65, 0.85],
    [0.00, 1.00, 0.15],
    [0.85, 0.90, 0.00],
    [1.00, 0.25, 0.00],
    [0.75, 0.00, 0.00],
    [0.35, 0.00, 0.00],
  ];

  /// Per-band linear-sRGB integration weights, exposed so the watercolor
  /// composite (spec §F1) collapses spectra through the same single KM→RGB
  /// path used by [kubelkaMunkToColor] instead of duplicating the table.
  static List<List<double>> get rgbWeights => _rgbWeights;

  /// Column sums of [rgbWeights] — the normalization so a unit reflector maps
  /// to white. Precomputed once; the per-pixel composite divides by these.
  static const List<double> rgbWeightNorms = [3.35, 2.90, 2.65];

  /// Public linear→sRGB gamma for callers compositing raw linear RGB.
  static double linearToSrgb(double value) => _linearToSrgb(value);

  static Color kubelkaMunkToColor(
    List<double> k,
    List<double> s, {
    double opacity = 1.0,
  }) {
    if (k.length != bands || s.length != bands) {
      throw ArgumentError('Spectral color requires exactly eight K/S bands.');
    }
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var redNorm = 0.0;
    var greenNorm = 0.0;
    var blueNorm = 0.0;
    for (var band = 0; band < bands; band++) {
      final scattering = math.max(s[band], 1e-6);
      final ks = math.max(0.0, k[band]) / scattering;
      final reflectance = (1.0 + ks - math.sqrt(ks * ks + 2.0 * ks)).clamp(
        0.0,
        1.0,
      );
      final weights = _rgbWeights[band];
      red += reflectance * weights[0];
      green += reflectance * weights[1];
      blue += reflectance * weights[2];
      redNorm += weights[0];
      greenNorm += weights[1];
      blueNorm += weights[2];
    }
    return Color.from(
      alpha: opacity.clamp(0.0, 1.0),
      red: _linearToSrgb(red / redNorm),
      green: _linearToSrgb(green / greenNorm),
      blue: _linearToSrgb(blue / blueNorm),
    );
  }

  static double _linearToSrgb(double value) {
    final x = value.clamp(0.0, 1.0);
    return x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1.0 / 2.4) - 0.055;
  }
}
