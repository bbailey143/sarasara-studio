import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_params.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_simulation.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

void main() {
  test('sub-visible fluid tails retire instead of activating distant tiles', () {
    final field = WatercolorField(128);
    field.waterH[field.index(8, 8)] = 1.0;
    final tail = field.index(120, 120);
    field.waterH[tail] = 5e-7;
    field.saturation[tail] = 5e-7;
    field.velU[tail] = 5e-6;
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        heightForce: 0,
        viscosity: 0,
        viscosityIters: 0,
        pressureIters: 1,
        bleed: 0,
        bleedIters: 0,
        wetSpread: 0,
        dry: 0,
        soak: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );

    sim.step();

    expect(field.waterH[tail], 0);
    expect(field.saturation[tail], 0);
    expect(field.velU[tail], 0);
    expect(sim.debugActiveWorkCellCount, lessThan(2048));
  });

  test('separate wet marks do not simulate the empty rectangle between them', () {
    final field = WatercolorField(128);
    field.waterH[field.index(8, 8)] = 1.0;
    field.waterH[field.index(120, 120)] = 1.0;
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        heightForce: 0,
        viscosity: 0,
        viscosityIters: 0,
        pressureIters: 1,
        bleed: 0,
        bleedIters: 0,
        wetSpread: 0,
        dry: 0,
        soak: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );

    sim.step();

    expect(sim.debugActiveWorkCellCount, lessThan(4096));
    expect(
      sim.debugActiveWorkCellCount,
      lessThan(sim.debugActiveBoxCellCount ~/ 2),
      reason: 'the dry space between separate wet marks must be skipped',
    );
  });

  test('pressure projection substantially reduces velocity divergence', () {
    final field = WatercolorField(40);
    for (var y = 0; y < field.size; y++) {
      for (var x = 0; x < field.size; x++) {
        final i = field.index(x, y);
        field.waterH[i] = 1;
        field.waterM[i] = 1;
        field.velU[i] = math.sin(x * 0.47) * math.cos(y * 0.19);
        field.velV[i] = math.cos(x * 0.23) * math.sin(y * 0.41);
      }
    }
    final before = _divergence(field);
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        heightForce: 0,
        viscosity: 0,
        viscosityIters: 0,
        pressureIters: 30,
        bleed: 0,
        dry: 0,
        soak: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );
    sim.step();
    final after = _divergence(field);
    expect(after, lessThan(before * 0.78));
  });

  test('brush momentum carries water and pigment directionally', () {
    final field = WatercolorField(64);
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        heightForce: 0,
        bleed: 0,
        dry: 0,
        soak: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );
    sim.splat(
      cx: 24,
      cy: 32,
      radius: 6,
      pressure: 1,
      kBand: Pigment.phthaloBlue.absorptionK,
      sBand: Pigment.phthaloBlue.scatteringS,
      load: 1,
      waterAmt: 1,
      gran: 0,
      stain: 0,
      impulseX: 2.2,
    );
    final before = _pigmentCentroidX(field);
    final loadBefore = field.totalLoad();
    for (var i = 0; i < 8; i++) {
      sim.step();
    }
    expect(_pigmentCentroidX(field), greaterThan(before + 0.6));
    expect(field.totalLoad(), closeTo(loadBefore, loadBefore * 0.015));
  });

  test('fallback mode is isolated from the pressure solver', () {
    final field = WatercolorField(24);
    field.waterH[field.index(12, 12)] = 2;
    field.velU[field.index(12, 12)] = 1;
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        transportMode: WatercolorTransportMode.diffusionFallback,
        dry: 0,
        soak: 0,
      ),
    );
    sim.step();
    expect(field.pressure.every((value) => value == 0), isTrue);
  });

  test('canvas tilt carries a wet wash downhill', () {
    final field = WatercolorField(64);
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        gravityX: 0.22,
        heightForce: 0,
        bleed: 0,
        dry: 0,
        soak: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );
    sim.splat(
      cx: 26,
      cy: 32,
      radius: 7,
      pressure: 1,
      kBand: Pigment.hansaYellow.absorptionK,
      sBand: Pigment.hansaYellow.scatteringS,
      load: 1,
      waterAmt: 1.5,
      gran: 0,
      stain: 0,
    );
    final before = _pigmentCentroidX(field);
    for (var i = 0; i < 12; i++) {
      sim.step();
    }
    expect(_pigmentCentroidX(field), greaterThan(before + 0.8));
  });

  test('fluid transport cannot create water after the brush lifts', () {
    final field = WatercolorField(64);
    final sim = WatercolorSimulation(
      field: field,
      params: const WatercolorParams(
        gravityX: 0.24,
        gravityY: 0.12,
        wetSpread: 0,
        dry: 0,
        soak: 0,
        bleed: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );
    sim.splat(
      cx: 20,
      cy: 20,
      radius: 5,
      pressure: 1,
      kBand: List<double>.filled(8, 0),
      sBand: List<double>.filled(8, 0),
      load: 0,
      waterAmt: 2,
      gran: 0,
      stain: 0,
    );
    final initial = field.totalWater();
    for (var i = 0; i < 80; i++) {
      sim.step();
    }
    expect(field.totalWater(), closeTo(initial, initial * 0.002));
  });

  test('capillary front branches along connected paper valleys', () {
    final field = WatercolorField(64);
    final sim = WatercolorSimulation(
      field: field,
      paperHeight: (x, y) => (y - 32).abs() <= 2 ? 0.0 : 1.0,
      params: const WatercolorParams(
        heightForce: 0,
        viscosityIters: 0,
        pressureIters: 0,
        wetSpread: 0.45,
        dry: 0,
        soak: 0,
        bleed: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );
    sim.splat(
      cx: 32,
      cy: 32,
      radius: 3,
      pressure: 1,
      kBand: List<double>.filled(8, 0),
      sBand: List<double>.filled(8, 0),
      load: 0,
      waterAmt: 2,
      gran: 0,
      stain: 0,
    );
    for (var i = 0; i < 50; i++) {
      sim.step();
    }
    final alongGrain = field.waterH[field.index(39, 32)];
    final acrossGrain = field.waterH[field.index(32, 39)];
    expect(alongGrain, greaterThan(acrossGrain * 4));
  });

  test('neighboring wet strokes merge and exchange suspended pigment', () {
    final field = WatercolorField(64);
    final sim = WatercolorSimulation(
      field: field,
      paperHeight: (x, y) => 0.0,
      params: const WatercolorParams(
        pressureIters: 4,
        wetSpread: 0.4,
        dry: 0,
        soak: 0,
        settle: 0,
        lift: 0,
        edge: 0,
      ),
    );
    final first = List<double>.filled(8, 0)..[0] = 1;
    final second = List<double>.filled(8, 0)..[1] = 1;
    for (final stroke in [(24.0, first), (40.0, second)]) {
      sim.splat(
        cx: stroke.$1,
        cy: 32,
        radius: 7,
        pressure: 1,
        kBand: stroke.$2,
        sBand: List<double>.filled(8, 0.2),
        load: 1,
        waterAmt: 2,
        gran: 0,
        stain: 0,
      );
    }
    for (var i = 0; i < 45; i++) {
      sim.step();
    }
    final bridge = field.index(32, 32) * WatercolorField.bands;
    expect(field.ksus[bridge], greaterThan(1e-4));
    expect(field.ksus[bridge + 1], greaterThan(1e-4));
  });

  test('a coloured drop blooms inside an older wet stroke', () {
    final field = WatercolorField(64);
    final sim = WatercolorSimulation(
      field: field,
      paperHeight: (x, y) => 0.25,
      params: const WatercolorParams(
        pressureIters: 6,
        wetSpread: 0.18,
        dry: 0,
        soak: 0,
        edge: 0.5,
      ),
    );
    final oldPigment = List<double>.filled(8, 0)..[0] = 1;
    final newPigment = List<double>.filled(8, 0)..[1] = 1;
    sim.splat(
      cx: 32,
      cy: 32,
      radius: 11,
      pressure: 1,
      kBand: oldPigment,
      sBand: List<double>.filled(8, 0.2),
      load: 1,
      waterAmt: 1.5,
      gran: 0.2,
      stain: 0.2,
    );
    for (var i = 0; i < 12; i++) {
      sim.step();
    }

    double oldAt(int x, int y) {
      final base = field.index(x, y) * WatercolorField.bands;
      return field.ksus[base] + field.kdep[base];
    }

    double oldRadiusMoment() {
      var weighted = 0.0;
      var total = 0.0;
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final radius = math.sqrt((x - 32) * (x - 32) + (y - 32) * (y - 32));
          final pigment = oldAt(x, y);
          weighted += pigment * radius;
          total += pigment;
        }
      }
      return weighted / total;
    }

    final centerBefore = oldAt(32, 32);
    final radiusBefore = oldRadiusMoment();
    sim.splat(
      cx: 32,
      cy: 32,
      radius: 4,
      pressure: 1,
      kBand: newPigment,
      sBand: List<double>.filled(8, 0.2),
      load: 0.7,
      waterAmt: 2.5,
      gran: 0,
      stain: 0.1,
    );
    for (var i = 0; i < 14; i++) {
      sim.step();
    }

    expect(oldRadiusMoment(), greaterThan(radiusBefore));
    expect(
      oldAt(32, 32),
      greaterThan(centerBefore * 0.30),
      reason: 'the bloom moves old pigment without hollowing its center',
    );
  });

  test('wet overlap unifies while a dry layer remains a glaze', () {
    WatercolorField overlay({required bool wet}) {
      final field = WatercolorField(32);
      final center = field.index(16, 16);
      final oldBand = center * WatercolorField.bands;
      final oldProps = center * WatercolorField.depProps;
      field.kdep[oldBand] = 1.0;
      field.sdep[oldBand] = 0.4;
      field.propsDep[oldProps] = 1.0;
      field.propsDep[oldProps + WatercolorField.depStaining] = 0.2;
      if (wet) {
        field.waterH[center] = 1.0;
      } else {
        field.kDry[oldBand] = field.kdep[oldBand];
        field.sDry[oldBand] = field.sdep[oldBand];
        field.propsDry[oldProps] = field.propsDep[oldProps];
        field.propsDry[oldProps + WatercolorField.depStaining] =
            field.propsDep[oldProps + WatercolorField.depStaining];
      }

      final sim = WatercolorSimulation(
        field: field,
        paperHeight: (x, y) => 0.2,
      );
      final newK = List<double>.filled(8, 0)..[1] = 1;
      sim.splat(
        cx: 16.5,
        cy: 16.5,
        radius: 2,
        pressure: 1,
        contactPressure: 0.2,
        kBand: newK,
        sBand: List<double>.filled(8, 0.2),
        load: 1,
        waterAmt: 1,
        gran: 0.8,
        stain: 0.1,
      );
      for (var i = 0; i < 10; i++) {
        sim.step();
      }
      return field;
    }

    final wet = overlay(wet: true);
    final dry = overlay(wet: false);
    final center = wet.index(16, 16);
    final bands = center * WatercolorField.bands;

    expect(
      wet.kdep[bands],
      lessThan(dry.kdep[bands]),
      reason: 'still-wet underlying pigment is reopened into the shared wash',
    );
    expect(
      wet.kdep[bands + 1],
      lessThan(dry.kdep[bands + 1]),
      reason:
          'new wet-over-wet pigment stays mobile instead of forming a layer',
    );
    expect(
      dry.kdep[bands],
      closeTo(1.0, 1e-6),
      reason: 'a dry underlying layer remains undisturbed for glazing',
    );
  });

  test('perfectly wet contact immediately shares pigment across the wash', () {
    WatercolorField contact({required bool preWet}) {
      final field = WatercolorField(32);
      if (preWet) {
        for (var y = 10; y <= 22; y++) {
          for (var x = 10; x <= 22; x++) {
            final i = field.index(x, y);
            field.waterH[i] = 0.8;
            field.ksus[i * WatercolorField.bands] = 0.2;
            field.propsSus[i * WatercolorField.susProps] = 0.2;
          }
        }
      }
      final sim = WatercolorSimulation(
        field: field,
        params: const WatercolorParams(dry: 0, soak: 0),
      );
      final newPigment = List<double>.filled(8, 0)..[1] = 1;
      sim.splat(
        cx: 16.5,
        cy: 16.5,
        radius: 1.5,
        pressure: 1,
        contactPressure: 0.5,
        kBand: newPigment,
        sBand: List<double>.filled(8, 0.2),
        load: 1,
        waterAmt: 0.5,
        gran: 0,
        stain: 0.2,
      );
      return field;
    }

    final wet = contact(preWet: true);
    final dry = contact(preWet: false);
    final sharedBand = wet.index(18, 16) * WatercolorField.bands + 1;
    expect(
      wet.ksus[sharedBand],
      greaterThan(1e-5),
      reason: 'new pigment enters neighbouring cells of the connected wash',
    );
    expect(
      dry.ksus[sharedBand],
      0,
      reason: 'dry contact keeps its own bristle footprint for glazing',
    );
  });
}

double _divergence(WatercolorField field) {
  var sum = 0.0;
  var count = 0;
  for (var y = 1; y < field.size - 1; y++) {
    for (var x = 1; x < field.size - 1; x++) {
      final du =
          field.velU[field.index(x + 1, y)] - field.velU[field.index(x - 1, y)];
      final dv =
          field.velV[field.index(x, y + 1)] - field.velV[field.index(x, y - 1)];
      sum += (0.5 * (du + dv)).abs();
      count++;
    }
  }
  return sum / count;
}

double _pigmentCentroidX(WatercolorField field) {
  var weighted = 0.0;
  var total = 0.0;
  for (var y = 0; y < field.size; y++) {
    for (var x = 0; x < field.size; x++) {
      final load = field.propsSus[field.index(x, y) * WatercolorField.susProps];
      weighted += x * load;
      total += load;
    }
  }
  return weighted / total;
}
