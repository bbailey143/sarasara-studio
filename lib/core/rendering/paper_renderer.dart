import 'dart:typed_data';
import 'dart:ui' as ui;

import '../paper/paper_texture.dart';

/// Renders the visible paper texture (tooth grain) onto the canvas.
///
/// The paper tooth is visible as subtle light/dark variation across the
/// surface, giving the appearance of textured paper. This is drawn once
/// and cached as a [ui.Image] — it only re-renders when the paper preset
/// changes, not on every frame.
///
/// The rendering approach:
/// 1. Convert the texture grid into a small pixel image.
/// 2. Each pixel's color is the paper base color, slightly lightened
///    (peaks) or darkened (valleys) based on the height map.
/// 3. The cached image is then scaled to the canvas by Flutter.
class PaperRenderer {
  /// Cached rendered paper texture image.
  ui.Image? _cachedImage;

  /// The seed of the texture that was cached (for invalidation).
  int? _cachedSeed;

  /// The size the cache was rendered at (for invalidation on resize).
  ui.Size? _cachedSize;

  /// Cached texture dimensions and rendering settings.
  int? _cachedTextureWidth;
  int? _cachedTextureHeight;
  double? _cachedToothVisibility;
  ui.Color? _cachedPaperColor;

  /// Whether a cache rebuild is in progress.
  bool _isBuilding = false;

  /// Used to ignore stale async cache builds after paper changes.
  int _buildGeneration = 0;

  /// Dispose of cached resources.
  void dispose() {
    _cachedImage?.dispose();
    _cachedImage = null;
  }

  /// Invalidate the cache (call when paper preset changes).
  void invalidate() {
    _cachedImage?.dispose();
    _cachedImage = null;
    _cachedSeed = null;
    _cachedSize = null;
    _cachedTextureWidth = null;
    _cachedTextureHeight = null;
    _cachedToothVisibility = null;
    _cachedPaperColor = null;
    _isBuilding = false;
    _buildGeneration++;
  }

  /// Draw the paper background with visible tooth texture.
  ///
  /// If the cache is valid, blits the cached image. Otherwise, renders
  /// and caches a new image.
  ///
  /// [toothVisibility]: how strongly the texture is visible (0–1).
  ///   Typical values: 0.06 for hot press, 0.12 for cold press, 0.18 for
  ///   rough paper.
  void renderPaperTexture(
    ui.Canvas canvas,
    ui.Size size,
    PaperTexture texture,
    ui.Color paperColor, {
    double toothVisibility = 0.12,
    void Function()? onCacheReady,
  }) {
    if (toothVisibility <= 0.0) {
      canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = paperColor);
      return;
    }

    final needsRebuild =
        _cachedImage == null ||
        _cachedSeed != texture.seed ||
        _cachedSize != size ||
        _cachedTextureWidth != texture.gridWidth ||
        _cachedTextureHeight != texture.gridHeight ||
        _cachedToothVisibility != toothVisibility ||
        _cachedPaperColor != paperColor;

    if (needsRebuild && !_isBuilding) {
      _buildCache(size, texture, paperColor, toothVisibility, onCacheReady);
    }

    if (_cachedImage != null) {
      // Draw the cached paper texture scaled up using bilinear interpolation.
      canvas.drawImageRect(
        _cachedImage!,
        ui.Rect.fromLTWH(
          0,
          0,
          _cachedImage!.width.toDouble(),
          _cachedImage!.height.toDouble(),
        ),
        ui.Offset.zero & size,
        ui.Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.medium,
      );
    } else {
      // Fallback: draw flat paper color while cache builds.
      canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = paperColor);
    }
  }

  /// Build and cache the paper texture image.
  void _buildCache(
    ui.Size size,
    PaperTexture texture,
    ui.Color paperColor,
    double toothVisibility,
    void Function()? onCacheReady,
  ) {
    _isBuilding = true;
    final buildGeneration = _buildGeneration;

    final baseR = paperColor.r;
    final baseG = paperColor.g;
    final baseB = paperColor.b;
    final width = texture.gridWidth;
    final height = texture.gridHeight;
    final pixels = Uint8List(width * height * 4);

    for (int gy = 0; gy < texture.gridHeight; gy++) {
      for (int gx = 0; gx < texture.gridWidth; gx++) {
        final u = gx / (width - 1);
        final v = gy / (height - 1);
        final paperHeight = texture.heightAt(u, v);

        // Height deviation from middle (0.5).
        // Positive = peak (lighter), negative = valley (darker).
        final deviation = (paperHeight - 0.5) * 2.0 * toothVisibility;

        final r = (baseR + deviation).clamp(0.0, 1.0);
        final g = (baseG + deviation).clamp(0.0, 1.0);
        final b = (baseB + deviation).clamp(0.0, 1.0);

        final offset = (gy * width + gx) * 4;
        pixels[offset] = (r * 255).round().clamp(0, 255);
        pixels[offset + 1] = (g * 255).round().clamp(0, 255);
        pixels[offset + 2] = (b * 255).round().clamp(0, 255);
        pixels[offset + 3] = 255;
      }
    }

    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      if (buildGeneration != _buildGeneration) {
        image.dispose();
        _isBuilding = false;
        return;
      }

      _cachedImage?.dispose();
      _cachedImage = image;
      _cachedSeed = texture.seed;
      _cachedSize = size;
      _cachedTextureWidth = texture.gridWidth;
      _cachedTextureHeight = texture.gridHeight;
      _cachedToothVisibility = toothVisibility;
      _cachedPaperColor = paperColor;
      _isBuilding = false;
      onCacheReady?.call();
    });
  }

  /// Calculate tooth visibility from paper properties.
  ///
  /// Hot press (tooth ~0.15) → subtle grain. Rough (tooth ~0.85) → strong
  /// grain.
  static double toothVisibilityFromPaper(double tooth) {
    if (tooth <= 0.0) return 0.0;
    // Map tooth [0..1] to visibility [0.03..0.20].
    return 0.03 + tooth * 0.17;
  }
}
