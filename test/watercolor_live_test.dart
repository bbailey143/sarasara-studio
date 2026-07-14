import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/canvas_controller.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';

/// Runtime test of the live watercolor path through [CanvasController]: enable
/// the medium, paint a stroke, tick the sim, and confirm a composited wash
/// image is produced (the exact chain the running app uses).
void main() {
  InputSample s(double x, double y, int t) => InputSample(
    position: Offset(x, y),
    pressure: 1.0,
    timestamp: t,
    deviceKind: PointerDeviceKind.stylus,
  );

  testWidgets('enabling watercolor and painting produces a wash image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = CanvasController();
      controller.canvasSize = const Size(400, 400);
      // Watercolor is always active now — no toggle needed.
      expect(controller.watercolorEnabled, isTrue);

      controller.beginStroke(s(120, 200, 0));
      for (var i = 1; i <= 24; i++) {
        controller.updateStroke(s(120 + i * 7.0, 200, i * 16));
      }
      controller.endStroke();

      // Fresh deposits have water height but derive their wet mask on the
      // first simulation step. The dirty-state gate must force that step.
      expect(controller.debugWetFraction(), 0.0);
      controller.showWetAreas = true;
      controller.tickWatercolor();
      expect(
        controller.debugWetFraction(),
        greaterThan(0.0),
        reason: 'fresh paint must start the live fluid simulation',
      );

      // Drive the sim a few frames and let async composites resolve.
      for (var i = 0; i < 12; i++) {
        controller.tickWatercolor();
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }

      expect(
        controller.watercolorImage,
        isNotNull,
        reason: 'painting in watercolor mode should produce a wash image',
      );
      expect(controller.watercolorImage!.width, controller.watercolorSimSize);
      expect(
        controller.watercolorWetOverlay,
        isNotNull,
        reason: 'wet-area diagnostic should render the water mask',
      );

      // The wash must be clearly visible where painted (high alpha) and fully
      // transparent where untouched (so it never covers the paper/other work).
      final px = controller.debugCompositePixels()!;
      final size = controller.watercolorSimSize;
      var maxAlpha = 0;
      for (var i = 0; i < px.length; i += 4) {
        if (px[i + 3] > maxAlpha) maxAlpha = px[i + 3];
      }
      expect(
        maxAlpha,
        greaterThan(90),
        reason: 'a painted stroke should read as clearly visible pigment',
      );
      // A far corner stays transparent.
      final cornerA = px[((2 * size) + 2) * 4 + 3];
      expect(
        cornerA,
        0,
        reason: 'untouched area is transparent — the wash never covers work',
      );

      controller.dispose();
    });
  });

  testWidgets('one touch cannot grow into a canvas-filling puddle', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = CanvasController();
      controller.canvasSize = const Size(400, 400);

      controller.beginStroke(s(200, 200, 0));
      controller.endStroke();

      for (var i = 0; i < 120; i++) {
        controller.tickWatercolor();
      }

      expect(
        controller.debugWetFraction(),
        lessThan(0.25),
        reason: 'a single touch must remain local after the brush lifts',
      );
      controller.dispose();
    });
  });

  testWidgets('holding still is time-integrated and reservoir-bounded', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = CanvasController();
      controller.canvasSize = const Size(400, 400);
      controller.beginStroke(s(200, 200, 0));
      final initialWater = controller.debugTotalWater();

      // Two seconds at the live dwell timer's ~60 Hz cadence. A real held
      // brush should release more than its 1 ms first-touch sample, but the
      // second second must taper as the finite reservoir depletes.
      for (var i = 0; i < 60; i++) {
        controller.dwellStroke();
      }
      final firstSecondWater = controller.debugTotalWater();
      for (var i = 0; i < 60; i++) {
        controller.dwellStroke();
      }
      final heldWater = controller.debugTotalWater();
      controller.endStroke();

      expect(initialWater, greaterThan(0));
      expect(firstSecondWater, greaterThan(initialWater));
      expect(
        heldWater - firstSecondWater,
        lessThan(firstSecondWater - initialWater),
        reason: 'finite reservoir release must taper rather than pump forever',
      );
      expect(heldWater.isFinite, isTrue);
      controller.dispose();
    });
  });

  testWidgets('a wet stroke remains available for a later overlapping stroke', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = CanvasController();
      controller.canvasSize = const Size(400, 400);
      controller.beginStroke(s(120, 200, 0));
      for (var i = 1; i <= 18; i++) {
        controller.updateStroke(s(120 + i * 7, 200, i * 16));
      }
      controller.endStroke();
      controller.tickWatercolor();
      final freshlyWet = controller.debugWetFraction();

      // One second at the live 30 fps simulation cadence.
      for (var i = 0; i < 30; i++) {
        controller.tickWatercolor();
      }

      expect(freshlyWet, greaterThan(0));
      expect(
        controller.debugWetFraction(),
        greaterThan(0),
        reason: 'the live wash needs a real wet interaction window',
      );
      controller.dispose();
    });
  });

  test('dry-rate slider reserves its lower half for long working time', () {
    final controller = CanvasController();
    controller.watercolorDryRate = 0.0;
    final slow = controller.debugWatercolorEvaporation;
    controller.watercolorDryRate = 0.4;
    final normal = controller.debugWatercolorEvaporation;
    controller.watercolorDryRate = 1.0;
    final fast = controller.debugWatercolorEvaporation;

    expect(slow, closeTo(0.000002, 1e-12));
    expect(normal, lessThan(0.00003));
    expect(fast, closeTo(0.0012, 1e-12));
    expect(
      0.0005 / slow,
      greaterThanOrEqualTo(250),
      reason: 'minimum must be dramatically slower than the rejected range',
    );
    expect(normal, greaterThan(slow));
    expect(fast, greaterThan(normal));
    controller.dispose();
  });
}
