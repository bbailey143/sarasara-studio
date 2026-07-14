import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/canvas_controller.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_reservoir.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/paint_mixture.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// End-to-end wiring of the oil medium through [CanvasController]: medium
/// switching, stroke routing, authoritative receipts, and per-stroke
/// checkpoints that coexist with the watercolor wash.

void _stroke(CanvasController controller, double x0, double x1, double y) {
  InputSample point(double x, int t) => InputSample(
    position: Offset(x, y),
    pressure: 0.8,
    timestamp: t,
    deviceKind: PointerDeviceKind.stylus,
  );
  controller.beginStroke(point(x0, 0));
  for (var i = 1; i <= 8; i++) {
    controller.updateStroke(point(x0 + (x1 - x0) * i / 8, i * 16));
  }
  controller.endStroke();
}

void main() {
  testWidgets('oil strokes feed the oil engine, not the wash', (tester) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    controller.activePaint = PaintMixture.single(Pigment.frenchUltramarine);

    controller.activeMedium = ActiveMedium.oil;
    expect(controller.brushReservoir.medium, MediumFamily.oil);

    _stroke(controller, 60, 220, 150);
    expect(controller.debugOilVolume(), greaterThan(0.0));
    expect(controller.debugOilLoad(), greaterThan(0.0));
    expect(
      controller.debugTotalLoad(),
      0.0,
      reason: 'an oil stroke must not touch the watercolor wash',
    );
    controller.dispose();
  });

  testWidgets('switching media rinses the reservoir to the new family', (
    tester,
  ) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    expect(controller.brushReservoir.medium, MediumFamily.watercolor);
    controller.activeMedium = ActiveMedium.oil;
    expect(controller.brushReservoir.medium, MediumFamily.oil);
    _stroke(controller, 60, 220, 150); // must not throw a medium mismatch
    controller.activeMedium = ActiveMedium.watercolor;
    expect(controller.brushReservoir.medium, MediumFamily.watercolor);
    _stroke(controller, 60, 220, 100);
    controller.dispose();
  });

  testWidgets('undo and redo restore each medium independently', (
    tester,
  ) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    controller.activePaint = PaintMixture.single(Pigment.phthaloBlue);

    // Watercolor stroke first, then an oil stroke above it.
    _stroke(controller, 60, 220, 100);
    controller.tickWatercolor();
    final washLoad = controller.debugTotalLoad();
    expect(washLoad, greaterThan(0.0));

    controller.activeMedium = ActiveMedium.oil;
    _stroke(controller, 60, 220, 180);
    final oilVolume = controller.debugOilVolume();
    expect(oilVolume, greaterThan(0.0));

    // Undo the oil stroke: oil state empties, the wash is untouched.
    controller.undo();
    expect(controller.debugOilVolume(), closeTo(0.0, 1e-9));
    expect(controller.debugTotalLoad(), closeTo(washLoad, washLoad * 0.05));

    // Undo the watercolor stroke: wash empties too.
    controller.undo();
    expect(controller.debugTotalLoad(), closeTo(0.0, 1e-9));

    // Redo both, in order.
    controller.redo();
    expect(controller.debugTotalLoad(), closeTo(washLoad, washLoad * 0.05));
    expect(controller.debugOilVolume(), closeTo(0.0, 1e-9));
    controller.redo();
    expect(controller.debugOilVolume(), closeTo(oilVolume, oilVolume * 0.05));
    controller.dispose();
  });

  testWidgets('dragging through wet oil paint dirties the brush', (
    tester,
  ) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    controller.activeMedium = ActiveMedium.oil;

    controller.activePaint = PaintMixture.single(Pigment.quinacridoneMagenta);
    _stroke(controller, 60, 240, 150);

    controller.activePaint = PaintMixture.single(Pigment.titaniumWhite);
    expect(controller.isBrushDirty, isFalse);
    _stroke(controller, 60, 240, 150); // straight through the red passage
    final reservoir = controller.brushReservoir;
    final snapshot = BrushReservoirSnapshot.from(reservoir);
    // Titanium white barely absorbs; picked-up magenta raises green-band K.
    expect(
      snapshot.kAverage[3],
      greaterThan(Pigment.titaniumWhite.absorptionK[3] * 1.5),
      reason: 'the reservoir must carry picked-up color forward',
    );
    expect(
      controller.isBrushDirty,
      isTrue,
      reason: 'the rinse control must follow the real oil reservoir pickup',
    );
    controller.rinseBrush();
    expect(controller.isBrushDirty, isFalse);
    controller.dispose();
  });

  testWidgets('clear empties both media', (tester) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    _stroke(controller, 60, 220, 100);
    controller.activeMedium = ActiveMedium.oil;
    _stroke(controller, 60, 220, 180);
    controller.clear();
    expect(controller.debugTotalLoad(), 0.0);
    expect(controller.debugOilVolume(), 0.0);
    controller.dispose();
  });
}
