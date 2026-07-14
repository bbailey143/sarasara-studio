import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/canvas_controller.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/canvas_pigment_layer.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/paint_mixture.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/pigment_mixer.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/pigment_palette_lut.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

void main() {
  group('spectral Kubelka-Munk mixing', () {
    test('blue and yellow mix toward green rather than gray', () {
      final mixture = PigmentMixer.mix(
        PaintMixture.single(Pigment.phthaloBlue),
        PaintMixture.single(Pigment.hansaYellow),
      );
      final color = mixture.displayColor;
      expect(color.g, greaterThan(color.r));
      expect(color.g, greaterThan(color.b));
      expect(
        (color.g - color.r).abs() + (color.g - color.b).abs(),
        greaterThan(0.08),
      );
    });

    test('white raises luminosity without deleting pigment identity', () {
      final blue = PaintMixture.single(Pigment.phthaloBlue);
      final tint = PigmentMixer.mix(
        blue,
        PaintMixture.single(Pigment.titaniumWhite),
        bAmount: 2,
      );
      double luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      expect(
        luminance(tint.displayColor),
        greaterThan(luminance(blue.displayColor)),
      );
      expect(
        tint.portions.map((p) => p.pigment.name),
        containsAll(['Phthalo Blue', 'Titanium White']),
      );
    });

    test('mixture storage remains eight bands regardless of pigment count', () {
      final mixture = PigmentMixer.mixMany(
        Pigment.starterPalette
            .map((p) => PigmentPortion(pigment: p, amount: 0.2))
            .toList(),
      );
      expect(mixture.absorptionKSum, hasLength(8));
      expect(mixture.scatteringSSum, hasLength(8));
    });

    test('48-pigment LUT has fixed five-texel rows', () {
      final lut = PigmentPaletteLut.build();
      expect(Pigment.palette48, hasLength(48));
      expect(lut.rgba32f, hasLength(48 * 5 * 4));
      expect(lut.row(47), hasLength(20));
    });
  });

  group('canvas exchange', () {
    test('staining pigment resists lifting more than low-stain pigment', () {
      final layer = CanvasPigmentLayer(2, 1);
      layer.deposit(0, 0, PaintMixture.single(Pigment.phthaloBlue), 1);
      layer.deposit(1, 0, PaintMixture.single(Pigment.hansaYellow), 1);
      final blueLift = layer.lift(0, 0, 0.5).totalAmount;
      final yellowLift = layer.lift(1, 0, 0.5).totalAmount;
      expect(blueLift, lessThan(yellowLift));
    });

    test('wet watercolor crossing dirties the brush and rinse cleans it', () {
      // Pickup is contact-only: the brush may absorb wet pigment directly
      // under its bristles, but never from an unrelated nearby grid cell.
      final controller = CanvasController()..canvasSize = const Size(100, 100);
      controller.activePaint = PaintMixture.single(Pigment.hansaYellow);
      controller.beginStroke(_sample(45, 50, 0));
      controller.updateStroke(_sample(55, 50, 16));
      controller.endStroke();
      controller.tickWatercolor();

      controller.activePaint = PaintMixture.single(Pigment.phthaloBlue);
      controller.beginStroke(_sample(50, 50, 32));
      controller.updateStroke(_sample(52, 50, 48));
      expect(
        controller.isBrushDirty,
        isTrue,
        reason: 'wet pigment under the bristles must enter the reservoir',
      );
      controller.endStroke();
      controller.rinseBrush();
      expect(controller.isBrushDirty, isFalse);
      controller.dispose();
    });
  });
}

InputSample _sample(double x, double y, int time) => InputSample(
  position: Offset(x, y),
  pressure: 0.65,
  timestamp: time,
  deviceKind: PointerDeviceKind.stylus,
);
