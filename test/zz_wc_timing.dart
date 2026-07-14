import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_engine.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

void main() {
  test('step timing at 160 vs 224', () {
    for (final size in [160, 224]) {
      final e = WatercolorEngine(simSize: size);
      for (var i = 0; i <= 24; i++) {
        e.depositContact(
          [MediumFootprintCluster(position: ui.Offset(40.0 + i * 10, 150), coverage: 1, pressure: 0.8, velocity: const ui.Offset(10, 0))],
          const ui.Size(400, 400), 30,
          kBand: Pigment.phthaloBlue.absorptionK, sBand: Pigment.phthaloBlue.scatteringS,
          gran: 0.2, stain: 0.4,
        );
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) { e.tick(); }
      sw.stop();
      // ignore: avoid_print
      print('size=$size: ${(sw.elapsedMicroseconds / 60 / 1000).toStringAsFixed(2)} ms/step');
    }
  });
}
