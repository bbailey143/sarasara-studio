import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_params.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_simulation.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

WatercolorField _run(double edge) {
  final field = WatercolorField(64);
  final sim = WatercolorSimulation(
    field: field,
    params: WatercolorParams(edge: edge),
  );
  sim.splat(
    cx: 32,
    cy: 32,
    radius: 12,
    pressure: 1.0,
    kBand: Pigment.phthaloBlue.absorptionK,
    sBand: Pigment.phthaloBlue.scatteringS,
    load: 1.2,
    waterAmt: 2.0,
    gran: Pigment.phthaloBlue.granulation,
    stain: Pigment.phthaloBlue.staining,
  );
  for (var i = 0; i < 220; i++) {
    sim.step();
  }
  return field;
}

double _depRing(WatercolorField f, double a, double b) {
  var sum = 0.0;
  var n = 0;
  for (var y = 0; y < f.size; y++) {
    for (var x = 0; x < f.size; x++) {
      final dx = x + 0.5 - 32.0, dy = y + 0.5 - 32.0;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r >= a && r < b) {
        sum += f.propsDep[f.index(x, y) * WatercolorField.depProps];
        n++;
      }
    }
  }
  return n == 0 ? 0.0 : sum / n;
}

void main() {
  test('radial profile edge vs control', () {
    final withEdge = _run(3.0);
    final control = _run(0.0);
    for (var r = 0; r < 22; r += 2) {
      final a = r.toDouble(), b = r + 2.0;
      // ignore: avoid_print
      print(
        'ring $a-$b: edge3=${_depRing(withEdge, a, b).toStringAsFixed(4)} '
        'edge0=${_depRing(control, a, b).toStringAsFixed(4)}',
      );
    }
  });
}
