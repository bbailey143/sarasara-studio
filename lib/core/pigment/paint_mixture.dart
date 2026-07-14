import 'dart:ui';

import '../../models/pigment.dart';

/// One pigment and how much of it is present in a paint mix.
class PigmentPortion {
  final Pigment pigment;
  final double amount;

  const PigmentPortion({required this.pigment, required this.amount});
}

/// A small paint cup carried by the brush.
///
/// Named pigment portions plus a display color. Watercolor layers can
/// later store these same portions per wet area or per pixel.
class PaintMixture {
  final List<PigmentPortion> portions;
  final Color displayColor;

  const PaintMixture({required this.portions, required this.displayColor});

  factory PaintMixture.single(Pigment pigment, {double amount = 1.0}) {
    return PaintMixture(
      portions: [PigmentPortion(pigment: pigment, amount: amount)],
      displayColor: pigment.displayColor,
    );
  }

  factory PaintMixture.customColor(Color color) {
    return PaintMixture(
      portions: [
        PigmentPortion(
          pigment: Pigment.custom(name: 'Custom Color', displayColor: color),
          amount: 1.0,
        ),
      ],
      displayColor: color,
    );
  }

  bool get isEmpty => portions.isEmpty;

  double get totalAmount {
    var total = 0.0;
    for (final portion in portions) {
      total += portion.amount;
    }
    return total;
  }

  List<double> get absorptionKSum {
    final result = List<double>.filled(8, 0.0);
    for (final portion in portions) {
      for (var band = 0; band < 8; band++) {
        result[band] += portion.amount * portion.pigment.absorptionK[band];
      }
    }
    return result;
  }

  List<double> get scatteringSSum {
    final result = List<double>.filled(8, 0.0);
    for (final portion in portions) {
      for (var band = 0; band < 8; band++) {
        result[band] += portion.amount * portion.pigment.scatteringS[band];
      }
    }
    return result;
  }

  double get granulationWeight =>
      portions.fold(0.0, (sum, p) => sum + p.amount * p.pigment.granulation);

  double get stainingWeight =>
      portions.fold(0.0, (sum, p) => sum + p.amount * p.pigment.staining);

  /// Scale the amounts of all pigment portions in the mixture.
  PaintMixture scale(double factor) {
    if (factor <= 0.0) {
      return PaintMixture(portions: [], displayColor: const Color(0x00000000));
    }
    final scaled = portions.map((p) {
      return PigmentPortion(pigment: p.pigment, amount: p.amount * factor);
    }).toList();

    // Scale display color alpha.
    final color = displayColor.withValues(
      alpha: (displayColor.a * factor).clamp(0.0, 1.0),
    );
    return PaintMixture(portions: scaled, displayColor: color);
  }
}
