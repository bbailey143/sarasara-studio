import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart 2D Perlin noise implementation.
///
/// Used by [PaperTexture] to generate procedural paper height maps and
/// capacity maps. No external dependencies.
///
/// Features:
/// - Classic 2D gradient noise with permutation table.
/// - Fractal Brownian motion (fBm) for layered roughness.
/// - Domain warping for anti-tiling across broad washes.
///
/// Closed-form and fully implemented — see ARCHITECTURE.md "Module Map"
/// for how this fits into paper texture generation.
class PerlinNoise {
  /// Permutation table (doubled for wrapping).
  late final Int32List _perm;

  /// Gradient vectors for 2D noise.
  static const List<List<double>> _gradients = [
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  /// Create a Perlin noise generator with the given [seed].
  PerlinNoise(int seed) {
    _perm = _buildPermutationTable(seed);
  }

  /// Build a seeded permutation table (512 entries = 256 doubled).
  Int32List _buildPermutationTable(int seed) {
    final random = math.Random(seed);
    final p = List<int>.generate(256, (i) => i);
    // Fisher-Yates shuffle.
    for (int i = 255; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = p[i];
      p[i] = p[j];
      p[j] = tmp;
    }
    // Double the table for easy wrapping.
    final table = Int32List(512);
    for (int i = 0; i < 512; i++) {
      table[i] = p[i & 255];
    }
    return table;
  }

  /// Fade/ease curve: 6t⁵ − 15t⁴ + 10t³ (improved Perlin).
  static double _fade(double t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  }

  /// Linear interpolation.
  static double _lerp(double a, double b, double t) {
    return a + t * (b - a);
  }

  /// Dot product of a gradient vector and a distance vector.
  double _grad(int hash, double x, double y) {
    final g = _gradients[hash & 7];
    return g[0] * x + g[1] * y;
  }

  /// Sample raw 2D Perlin noise at ([x], [y]).
  ///
  /// Returns a value in approximately [-1, 1].
  double noise2D(double x, double y) {
    // Grid cell coordinates.
    final xi = x.floor();
    final yi = y.floor();
    final xf = x - xi;
    final yf = y - yi;

    // Wrap to 0..255.
    final X = xi & 255;
    final Y = yi & 255;

    // Hash corners.
    final aa = _perm[_perm[X] + Y];
    final ab = _perm[_perm[X] + Y + 1];
    final ba = _perm[_perm[X + 1] + Y];
    final bb = _perm[_perm[X + 1] + Y + 1];

    // Fade curves.
    final u = _fade(xf);
    final v = _fade(yf);

    // Bilinear interpolation of gradients.
    final x1 = _lerp(_grad(aa, xf, yf), _grad(ba, xf - 1, yf), u);
    final x2 = _lerp(_grad(ab, xf, yf - 1), _grad(bb, xf - 1, yf - 1), u);
    return _lerp(x1, x2, v);
  }

  /// Fractal Brownian motion (fBm) — layered noise for natural roughness.
  ///
  /// [x], [y]: sample coordinates.
  /// [octaves]: number of noise layers (more = finer detail, slower).
  /// [lacunarity]: frequency multiplier per octave (typically 2.0).
  /// [persistence]: amplitude multiplier per octave (typically 0.5).
  ///
  /// Returns a value roughly in [-1, 1] (depends on octave count).
  double fBm(
    double x,
    double y, {
    int octaves = 4,
    double lacunarity = 2.0,
    double persistence = 0.5,
  }) {
    double total = 0.0;
    double amplitude = 1.0;
    double frequency = 1.0;
    double maxAmplitude = 0.0;

    for (int i = 0; i < octaves; i++) {
      total += noise2D(x * frequency, y * frequency) * amplitude;
      maxAmplitude += amplitude;
      amplitude *= persistence;
      frequency *= lacunarity;
    }

    // Normalize to [-1, 1].
    return total / maxAmplitude;
  }

  /// Domain-warped fBm — distorts the input coordinates with a secondary
  /// noise field to prevent visible repetition (tiling) across broad areas.
  ///
  /// [warpStrength] controls how much the coordinates are displaced.
  /// Typical values: 0.5–2.0. Higher = more organic distortion.
  double warpedFBm(
    double x,
    double y, {
    int octaves = 4,
    double lacunarity = 2.0,
    double persistence = 0.5,
    double warpStrength = 1.0,
  }) {
    // First warp pass: offset coordinates by noise.
    final wx =
        x +
        warpStrength *
            fBm(
              x + 5.2,
              y + 1.3,
              octaves: octaves ~/ 2 + 1,
              lacunarity: lacunarity,
              persistence: persistence,
            );
    final wy =
        y +
        warpStrength *
            fBm(
              x + 9.7,
              y + 6.8,
              octaves: octaves ~/ 2 + 1,
              lacunarity: lacunarity,
              persistence: persistence,
            );

    // Sample fBm at warped coordinates.
    return fBm(
      wx,
      wy,
      octaves: octaves,
      lacunarity: lacunarity,
      persistence: persistence,
    );
  }
}
