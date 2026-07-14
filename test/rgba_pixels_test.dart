import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/rendering/rgba_pixels.dart';

void main() {
  test('RGBA8 image handoff premultiplies colour by alpha', () {
    final pixels = Uint8List.fromList([
      200,
      100,
      50,
      128,
      12,
      34,
      56,
      255,
      90,
      80,
      70,
      0,
    ]);

    premultiplyRgba8888(pixels);

    expect(
      pixels,
      orderedEquals([
        100,
        50,
        25,
        128,
        12,
        34,
        56,
        255,
        0,
        0,
        0,
        0,
      ]),
    );
  });

  test('RGBA8 image handoff rejects an incomplete pixel', () {
    expect(
      () => premultiplyRgba8888(Uint8List(3)),
      throwsArgumentError,
    );
  });
}
