import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/canvas_controller.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_engine.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/paint_mixture.dart';
import 'package:sarasara_studio_01_rev1/models/paper.dart';

void main() {
  test('field checkpoint restores exact wet and spectral state', () {
    final engine = WatercolorEngine(simSize: 32);
    engine.simulation.splat(
      cx: 16,
      cy: 16,
      radius: 5,
      pressure: 1,
      kBand: Pigment.phthaloBlue.absorptionK,
      sBand: Pigment.phthaloBlue.scatteringS,
      load: 1,
      waterAmt: 2,
      gran: Pigment.phthaloBlue.granulation,
      stain: Pigment.phthaloBlue.staining,
    );
    engine.tick(3);
    engine.field.kDry[0] = 0.25;
    engine.field.sDry[0] = 0.15;
    engine.field.propsDry[WatercolorField.depLoad] = 0.2;
    engine.field.propsDry[WatercolorField.depGranulation] = 0.08;
    engine.field.propsDry[WatercolorField.depStaining] = 0.12;
    engine.field.propsDep[WatercolorField.depDryClock] = 0.11;
    final checkpoint = engine.snapshot();
    final load = engine.field.totalLoad();
    final water = engine.field.totalWater();

    engine.clear();
    expect(engine.field.totalLoad(), 0);
    engine.restore(checkpoint);

    expect(engine.field.totalLoad(), closeTo(load, 1e-6));
    expect(engine.field.totalWater(), closeTo(water, 1e-6));
    expect(engine.field.kDry[0], closeTo(0.25, 1e-6));
    expect(engine.field.sDry[0], closeTo(0.15, 1e-6));
    expect(
      engine.field.propsDry[WatercolorField.depLoad],
      closeTo(0.2, 1e-6),
    );
    expect(
      engine.field.propsDry[WatercolorField.depGranulation],
      closeTo(0.08, 1e-6),
    );
    expect(
      engine.field.propsDry[WatercolorField.depStaining],
      closeTo(0.12, 1e-6),
    );
    expect(
      engine.field.propsDep[WatercolorField.depDryClock],
      closeTo(0.11, 1e-6),
    );
  });

  test('live undo history stores painted tiles instead of the blank sheet', () {
    final engine = WatercolorEngine(simSize: 224);
    expect(engine.historySnapshot().estimatedBytes, 0);
    engine.simulation.splat(
      cx: 40,
      cy: 48,
      radius: 5,
      pressure: 1,
      kBand: Pigment.phthaloBlue.absorptionK,
      sBand: Pigment.phthaloBlue.scatteringS,
      load: 1,
      waterAmt: 2,
      gran: Pigment.phthaloBlue.granulation,
      stain: Pigment.phthaloBlue.staining,
    );
    engine.tick(2);
    final expectedLoad = engine.field.totalLoad();
    final expectedWater = engine.field.totalWater();
    final compact = engine.historySnapshot();
    final full = engine.snapshot();
    final fullBytes = <Float32List>[
      full.velU,
      full.velV,
      full.pressure,
      full.divergence,
      full.waterH,
      full.waterM,
      full.saturation,
      full.ksus,
      full.ssus,
      full.propsSus,
      full.kdep,
      full.sdep,
      full.propsDep,
      full.kDry,
      full.sDry,
      full.propsDry,
    ].fold<int>(0, (sum, values) => sum + values.lengthInBytes);

    expect(compact.estimatedBytes, lessThan(fullBytes ~/ 4));
    engine.clear();
    engine.restoreHistory(compact);
    expect(engine.field.totalLoad(), closeTo(expectedLoad, 1e-6));
    expect(engine.field.totalWater(), closeTo(expectedWater, 1e-6));
  });

  test('an old property-stride checkpoint is rejected instead of shifted', () {
    final engine = WatercolorEngine(simSize: 8);
    final good = engine.snapshot();
    final stale = WatercolorFieldSnapshot(
      size: good.size,
      velU: good.velU,
      velV: good.velV,
      pressure: good.pressure,
      divergence: good.divergence,
      waterH: good.waterH,
      waterM: good.waterM,
      saturation: good.saturation,
      ksus: good.ksus,
      ssus: good.ssus,
      propsSus: good.propsSus,
      kdep: good.kdep,
      sdep: good.sdep,
      propsDep: Float32List(good.propsDep.length - 1),
      kDry: good.kDry,
      sDry: good.sDry,
      propsDry: good.propsDry,
    );

    expect(() => engine.restore(stale), throwsArgumentError);
  });

  testWidgets('controller undo and redo restore wet checkpoints', (
    tester,
  ) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    controller.activePaint = PaintMixture.single(Pigment.phthaloBlue);

    _stroke(controller, 70, 100, 150);
    controller.tickWatercolor();
    final firstLoad = controller.debugTotalLoad();

    _stroke(controller, 150, 220, 170);
    controller.tickWatercolor();
    final secondLoad = controller.debugTotalLoad();
    expect(secondLoad, greaterThan(firstLoad));

    controller.undo();
    expect(controller.debugTotalLoad(), closeTo(firstLoad, 1e-4));

    controller.redo();
    expect(controller.debugTotalLoad(), closeTo(secondLoad, 1e-4));
    controller.dispose();
  });

  testWidgets('six watercolor strokes do not retain six blank full sheets', (
    tester,
  ) async {
    final controller = CanvasController()..canvasSize = const Size(300, 300);
    controller.activePaint = PaintMixture.single(Pigment.phthaloBlue);

    for (var stroke = 0; stroke < 6; stroke++) {
      _stroke(controller, 80, 150, 120 + stroke * 3.0);
    }

    expect(
      controller.debugWatercolorHistoryBytes(),
      lessThan(20 * 1024 * 1024),
      reason: 'compact history must not grow by about 13 MB per stroke',
    );
    controller.dispose();
  });

  test('paper capacity changes regenerate the live watercolor texture', () {
    final controller = CanvasController();
    const first = Paper(
      seed: 19,
      tooth: 0.5,
      noiseScale: 1.1,
      absorbency: 0.2,
      sizing: 0.9,
      capacity: 0.2,
    );
    final second = first.copyWith(
      absorbency: 0.8,
      sizing: 0.2,
      capacity: 0.8,
    );
    controller.activePaper = first;
    final firstTexture = controller.getPaperTexture(gridSize: 32);
    controller.activePaper = second;
    final secondTexture = controller.getPaperTexture(gridSize: 32);

    expect(identical(firstTexture, secondTexture), isFalse);
    expect(
      secondTexture.capacityAt(0.5, 0.5),
      greaterThan(firstTexture.capacityAt(0.5, 0.5)),
    );
    controller.dispose();
  });
}

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
