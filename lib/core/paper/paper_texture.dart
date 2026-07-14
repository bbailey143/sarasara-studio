import 'dart:typed_data';

import 'perlin_noise.dart';

/// Procedural paper texture with height and capacity maps.
///
/// Paper is not just a background color — it is an active material. The
/// height map controls visible tooth, dry-brush breakup, and granulation
/// settling. The capacity map controls how much water each area can hold,
/// which drives wet-edge irregularity, damp working time, and backrun
/// branching in the watercolor engine.
///
/// Both maps are low-resolution grids (typically 128×128 or 256×256)
/// interpolated to canvas resolution via bilinear lookup. This keeps
/// simulation fast while producing organic-looking results (see
/// ARCHITECTURE.md "Performance Rules").
class PaperTexture {
  /// Grid width in cells.
  final int gridWidth;

  /// Grid height in cells.
  final int gridHeight;

  /// Height map: normalized 0.0–1.0 values.
  /// 0.0 = deepest valley, 1.0 = tallest peak.
  /// Peaks catch dry brush; valleys collect pigment and water.
  final Float64List heightMap;

  /// Capacity map: normalized 0.0–1.0 values.
  /// How much water each cell can hold before overflowing.
  /// Varies spatially to create irregular wet boundaries.
  final Float64List capacityMap;

  /// The noise seed used to generate this texture.
  final int seed;

  /// Whether this texture needs regeneration (e.g., paper preset changed).
  bool _isDirty = false;
  bool get isDirty => _isDirty;
  void markDirty() => _isDirty = true;

  PaperTexture._({
    required this.gridWidth,
    required this.gridHeight,
    required this.heightMap,
    required this.capacityMap,
    required this.seed,
  });

  /// Generate a paper texture from paper properties.
  ///
  /// [tooth] (0–1): roughness amplitude. Higher = bigger peaks/valleys.
  /// [absorbency] (0–1): affects capacity map variation.
  /// [sizing] (0–1): high sizing = more uniform capacity (water stays on surface).
  /// [capacity] (0–1): base water-holding capacity.
  /// [noiseScale] (0.1–5): controls grain size. Lower = coarser grain.
  /// [seed]: deterministic noise seed.
  /// [gridWidth], [gridHeight]: resolution of the texture grid.
  factory PaperTexture.generate({
    required double tooth,
    required double absorbency,
    required double sizing,
    required double capacity,
    required double noiseScale,
    required int seed,
    int gridWidth = 128,
    int gridHeight = 128,
  }) {
    final noise = PerlinNoise(seed);
    final heightData = Float64List(gridWidth * gridHeight);
    final capacityData = Float64List(gridWidth * gridHeight);

    // ─── Generate Height Map ──────────────────────────────────────────
    //
    // Uses domain-warped fBm so broad washes don't reveal tiling.
    // Tooth controls the amplitude; noiseScale controls the frequency.
    //
    // Octave count scales with tooth: smooth paper (low tooth) needs
    // fewer octaves; rough paper needs more for fine detail.
    final int heightOctaves = (3 + tooth * 3).round().clamp(3, 6);
    final double warpStrength = 0.8 + tooth * 0.6; // More warp on rough paper.

    double minH = double.infinity;
    double maxH = double.negativeInfinity;

    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final nx = x / gridWidth * 8.0 / noiseScale;
        final ny = y / gridHeight * 8.0 / noiseScale;

        double h = noise.warpedFBm(
          nx,
          ny,
          octaves: heightOctaves,
          warpStrength: warpStrength,
        );

        // Scale by tooth amplitude.
        h *= tooth;

        final idx = y * gridWidth + x;
        heightData[idx] = h;

        if (h < minH) minH = h;
        if (h > maxH) maxH = h;
      }
    }

    // Normalize height to 0..1.
    final hRange = maxH - minH;
    if (hRange > 0.0001) {
      for (int i = 0; i < heightData.length; i++) {
        heightData[i] = (heightData[i] - minH) / hRange;
      }
    } else {
      // Perfectly smooth paper — flat 0.5.
      heightData.fillRange(0, heightData.length, 0.5);
    }

    // ─── Generate Capacity Map ────────────────────────────────────────
    //
    // Capacity varies spatially. High sizing = more uniform capacity.
    // Absorbency shifts the baseline. The capacity map uses a different
    // noise seed to avoid visual correlation with the height map.
    final capacityNoise = PerlinNoise(seed + 7919); // Different seed.
    const int capOctaves = 3;
    final double capScale = noiseScale * 1.5; // Slightly larger features.

    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final nx = x / gridWidth * 6.0 / capScale;
        final ny = y / gridHeight * 6.0 / capScale;

        double c = capacityNoise.fBm(nx, ny, octaves: capOctaves);
        // Map from [-1,1] to [0,1].
        c = (c + 1.0) * 0.5;

        // Sizing makes capacity more uniform (less spatial variation).
        final uniformity = sizing; // 0 = wild variation, 1 = nearly flat.
        c = capacity + (c - 0.5) * (1.0 - uniformity) * 0.6;

        // Absorbency shifts overall capacity.
        c += (absorbency - 0.5) * 0.2;

        capacityData[y * gridWidth + x] = c.clamp(0.0, 1.0);
      }
    }

    return PaperTexture._(
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      heightMap: heightData,
      capacityMap: capacityData,
      seed: seed,
    );
  }

  // ─── Bilinear Lookup ──────────────────────────────────────────────

  /// Bilinear-interpolated height at normalized UV coordinates.
  ///
  /// [u], [v]: 0.0–1.0 mapping to the full texture grid.
  /// Returns height in 0.0–1.0 (0 = valley, 1 = peak).
  double heightAt(double u, double v) {
    return _bilinearSample(heightMap, u, v);
  }

  /// Bilinear-interpolated capacity at normalized UV coordinates.
  double capacityAt(double u, double v) {
    return _bilinearSample(capacityMap, u, v);
  }

  /// Internal bilinear interpolation on a grid.
  double _bilinearSample(Float64List map, double u, double v) {
    // Clamp UV to valid range.
    u = u.clamp(0.0, 1.0);
    v = v.clamp(0.0, 1.0);

    // Map to grid coordinates.
    final gx = u * (gridWidth - 1);
    final gy = v * (gridHeight - 1);

    final x0 = gx.floor().clamp(0, gridWidth - 2);
    final y0 = gy.floor().clamp(0, gridHeight - 2);
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final fx = gx - x0;
    final fy = gy - y0;

    final v00 = map[y0 * gridWidth + x0];
    final v10 = map[y0 * gridWidth + x1];
    final v01 = map[y1 * gridWidth + x0];
    final v11 = map[y1 * gridWidth + x1];

    // Bilinear blend.
    final top = v00 + (v10 - v00) * fx;
    final bottom = v01 + (v11 - v01) * fx;
    return top + (bottom - top) * fy;
  }

  // ─── Dry-Brush Decision ───────────────────────────────────────────

  /// Determine whether a bristle mark should be skipped (dry-brush breakup).
  ///
  /// Compares the brush wetness and pressure against the paper height at
  /// this point. A dry brush on a high peak has a good chance of contact;
  /// a dry brush in a valley will miss (skip).
  ///
  /// [brushWetness]: 0.0 = bone dry, 1.0 = dripping wet.
  /// [pressure]: 0.0 = no pressure, 1.0 = full pressure.
  /// [heightAtPoint]: paper height at the bristle position (0–1).
  /// [dryBrushBreakup]: paper's dry-brush breakup parameter (0–1).
  ///
  /// Returns true if the bristle should be SKIPPED (no mark).
  bool shouldSkipBristle(
    double brushWetness,
    double pressure,
    double heightAtPoint,
    double dryBrushBreakup,
  ) {
    if (dryBrushBreakup <= 0.0) return false;
    // A wet brush reaches everything — no skipping.
    if (brushWetness > 0.85) return false;

    // How "dry" the brush is (inverted wetness).
    final dryness = 1.0 - brushWetness;

    // The brush "reach" — how deep into valleys it can paint.
    // High pressure + high wetness = deep reach = paints everywhere.
    // Low pressure + low wetness = shallow reach = only peaks.
    final reach = pressure * 0.6 + brushWetness * 0.4;

    // Height threshold: bristle marks below this height get skipped.
    // On rough paper (high dryBrushBreakup), the threshold is higher
    // (more skipping).
    final threshold = dryness * dryBrushBreakup * 0.8;

    // Valleys (low height) below the reach threshold are skipped.
    // Inverted: height 1.0 = peak (always painted), height 0.0 = valley.
    // Skip if the valley is deeper than the brush can reach.
    return (1.0 - heightAtPoint) > reach && heightAtPoint < (1.0 - threshold);
  }

  // ─── Canvas-Space Helpers ─────────────────────────────────────────

  /// Convert a canvas-space position to UV coordinates.
  ///
  /// [x], [y]: position in canvas logical pixels.
  /// [canvasWidth], [canvasHeight]: total canvas size.
  static List<double> positionToUV(
    double x,
    double y,
    double canvasWidth,
    double canvasHeight,
  ) {
    return [
      canvasWidth > 0 ? (x / canvasWidth).clamp(0.0, 1.0) : 0.5,
      canvasHeight > 0 ? (y / canvasHeight).clamp(0.0, 1.0) : 0.5,
    ];
  }
}
