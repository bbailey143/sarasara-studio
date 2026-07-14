import 'dart:ui';

import 'paint_mixture.dart';
import 'pigment_mixer.dart';

/// Tracks deposited pigment concentrations across a grid on the canvas.
///
/// Implements the spatial paint buffer. Brushes deposit paint into this grid,
/// and can pick up/lift paint from it to create dirty brush and smudge effects.
///
/// Nothing calls [deposit] or [lift] yet in this scaffold — see
/// [CanvasController]'s doc comments for why the pickup/deposit simulation
/// is left as a TODO. This class itself is fully implemented and ready to
/// be driven once that simulation lands.
class CanvasPigmentLayer {
  /// Grid width in cells.
  final int width;

  /// Grid height in cells.
  final int height;

  /// The grid storage of paint mixtures per cell.
  final List<PaintMixture?> _grid;

  CanvasPigmentLayer(this.width, this.height)
    : _grid = List.filled(width * height, null);

  /// Get the paint mixture at the given cell coordinates.
  PaintMixture? getPaintAt(int cx, int cy) {
    if (cx < 0 || cx >= width || cy < 0 || cy >= height) return null;
    return _grid[cy * width + cx];
  }

  /// Set the paint mixture directly at the given cell coordinates.
  void setPaintAt(int cx, int cy, PaintMixture? paint) {
    if (cx < 0 || cx >= width || cy < 0 || cy >= height) return;
    _grid[cy * width + cx] = paint;
  }

  /// Deposit a paint mixture into a grid cell.
  ///
  /// [cx], [cy]: grid coordinates.
  /// [depositPaint]: the paint mixture to deposit.
  /// [amount]: multiplier for the deposited amount (density/opacity).
  void deposit(int cx, int cy, PaintMixture depositPaint, double amount) {
    if (cx < 0 || cx >= width || cy < 0 || cy >= height) return;
    if (depositPaint.isEmpty || amount <= 0.001) return;

    final idx = cy * width + cx;
    final existing = _grid[idx];
    final added = depositPaint.scale(amount);

    if (existing == null || existing.isEmpty) {
      _grid[idx] = added;
    } else {
      _grid[idx] = PigmentMixer.mix(existing, added);
    }
  }

  /// Lift a portion of paint from a grid cell.
  ///
  /// Lifts paint based on the [liftRatio] (0.0 to 1.0). Lighter/low-stain
  /// pigments lift more easily. This reduces the concentration remaining
  /// in the cell and returns the lifted paint mixture.
  ///
  /// [cx], [cy]: grid coordinates.
  /// [liftRatio]: fraction of the paint to lift (0.0 = none, 1.0 = all).
  PaintMixture lift(int cx, int cy, double liftRatio) {
    if (cx < 0 || cx >= width || cy < 0 || cy >= height) {
      return PaintMixture(portions: [], displayColor: const Color(0x00000000));
    }

    final idx = cy * width + cx;
    final existing = _grid[idx];
    if (existing == null || existing.isEmpty || liftRatio <= 0.001) {
      return PaintMixture(portions: [], displayColor: const Color(0x00000000));
    }

    final clampedRatio = liftRatio.clamp(0.0, 1.0);
    final liftedPortions = <PigmentPortion>[];
    final remainingPortions = <PigmentPortion>[];

    for (final portion in existing.portions) {
      // Scale lift factor by the pigment's staining power:
      // High staining (1.0) -> lifts very little.
      // Low staining (0.0) -> lifts fully based on liftRatio.
      final stainingModifier = (1.0 - portion.pigment.staining).clamp(
        0.18,
        1.0,
      );
      final actualLiftAmount = portion.amount * clampedRatio * stainingModifier;
      final remainingAmount = portion.amount - actualLiftAmount;

      if (actualLiftAmount > 0.000001) {
        liftedPortions.add(
          PigmentPortion(pigment: portion.pigment, amount: actualLiftAmount),
        );
      }
      if (remainingAmount > 0.000001) {
        remainingPortions.add(
          PigmentPortion(pigment: portion.pigment, amount: remainingAmount),
        );
      }
    }

    // Rebuild remaining mixture
    if (remainingPortions.isEmpty) {
      _grid[idx] = null;
    } else {
      _grid[idx] = PigmentMixer.mixMany(remainingPortions);
    }

    // Rebuild and return lifted mixture
    if (liftedPortions.isEmpty) {
      return PaintMixture(portions: [], displayColor: const Color(0x00000000));
    } else {
      return PigmentMixer.mixMany(liftedPortions);
    }
  }

  /// Empty the entire grid.
  void clear() {
    _grid.fillRange(0, _grid.length, null);
  }
}
