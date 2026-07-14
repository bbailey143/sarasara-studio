import 'dart:ui';

import 'paint_mixture.dart';
import 'spectral_color.dart';

/// Paint-like color mixing.
///
/// Eight-band, two-constant spectral Kubelka-Munk mixing. K and S are
/// extensive quantities, so mixture storage stays fixed regardless of palette
/// size and blue+yellow follows subtractive optics instead of screen blending.
class PigmentMixer {
  const PigmentMixer._();

  static PaintMixture mix(
    PaintMixture a,
    PaintMixture b, {
    double bAmount = 1.0,
  }) {
    return mixMany([
      ...a.portions,
      ...b.portions.map(
        (portion) => PigmentPortion(
          pigment: portion.pigment,
          amount: portion.amount * bAmount,
        ),
      ),
    ]);
  }

  static PaintMixture mixPigments(List<PigmentPortion> portions) {
    return mixMany(portions);
  }

  static PaintMixture mixMany(List<PigmentPortion> portions) {
    // Aggregate identical pigments to prevent the recipe list from growing indefinitely.
    final Map<String, PigmentPortion> aggregated = {};
    for (final p in portions) {
      if (p.amount <= 0.0) continue;
      final key = p.pigment.name;
      final existing = aggregated[key];
      if (existing != null) {
        aggregated[key] = PigmentPortion(
          pigment: p.pigment,
          amount: existing.amount + p.amount,
        );
      } else {
        aggregated[key] = p;
      }
    }

    final useful = aggregated.values.toList();
    if (useful.isEmpty) {
      return PaintMixture.customColor(const Color(0x00000000));
    }

    final k = List<double>.filled(SpectralColor.bands, 0.0);
    final s = List<double>.filled(SpectralColor.bands, 0.0);
    var totalLoad = 0.0;
    var opacityProduct = 1.0;

    for (final portion in useful) {
      final pigment = portion.pigment;
      final load = portion.amount;
      for (var band = 0; band < SpectralColor.bands; band++) {
        k[band] += load * pigment.absorptionK[band];
        s[band] += load * pigment.scatteringS[band];
      }
      opacityProduct *= 1.0 - pigment.opacity * load.clamp(0.0, 1.0);
      totalLoad += load;
    }

    if (totalLoad <= 0.0) {
      return PaintMixture.customColor(useful.first.pigment.displayColor);
    }
    final mixedColor = SpectralColor.kubelkaMunkToColor(
      k,
      s,
      opacity: (1.0 - opacityProduct).clamp(0.0, 1.0),
    );

    return PaintMixture(portions: useful, displayColor: mixedColor);
  }

  static Color mixColors(Color a, Color b, {double bAmount = 1.0}) {
    return mix(
      PaintMixture.customColor(a),
      PaintMixture.customColor(b),
      bAmount: bAmount,
    ).displayColor;
  }
}
