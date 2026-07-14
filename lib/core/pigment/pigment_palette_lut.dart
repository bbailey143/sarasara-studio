import 'dart:typed_data';

import '../../models/pigment.dart';

/// CPU representation of the static 48-row GPU palette texture described by
/// the engine specs. Packing is five RGBA texels per pigment: 8 K, 8 S, then
/// granulation/staining/opacity/density.
class PigmentPaletteLut {
  PigmentPaletteLut._(this.rgba32f);

  static const int pigmentCount = 48;
  static const int texelsPerPigment = 5;
  static const int floatsPerPigment = texelsPerPigment * 4;

  final Float32List rgba32f;

  factory PigmentPaletteLut.build([List<Pigment>? pigments]) {
    final palette = pigments ?? Pigment.palette48;
    if (palette.length != pigmentCount) {
      throw ArgumentError(
        'The shared palette LUT requires exactly 48 pigments.',
      );
    }
    final packed = Float32List(pigmentCount * floatsPerPigment);
    for (var row = 0; row < palette.length; row++) {
      final pigment = palette[row];
      final base = row * floatsPerPigment;
      for (var band = 0; band < 8; band++) {
        packed[base + band] = pigment.absorptionK[band];
        packed[base + 8 + band] = pigment.scatteringS[band];
      }
      packed[base + 16] = pigment.granulation;
      packed[base + 17] = pigment.staining;
      packed[base + 18] = pigment.opacity;
      packed[base + 19] = pigment.density;
    }
    return PigmentPaletteLut._(packed);
  }

  List<double> row(int pigmentIndex) {
    if (pigmentIndex < 0 || pigmentIndex >= pigmentCount) {
      throw RangeError.index(pigmentIndex, rgba32f, 'pigmentIndex');
    }
    final start = pigmentIndex * floatsPerPigment;
    return rgba32f.sublist(start, start + floatsPerPigment);
  }
}
