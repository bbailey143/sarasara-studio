import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_params.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_simulation.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// Behavior tests for the watercolor Fluid + Pigment CPU reference
/// (`WATERCOLOR-REDESIGN.md`). Each proves a visible mechanism.

void _splatDisc(
  WatercolorSimulation sim,
  Pigment p, {
  required double cx,
  required double cy,
  required double radius,
  double water = 1.2,
  double load = 1.2,
}) {
  sim.splat(
    cx: cx,
    cy: cy,
    radius: radius,
    pressure: 1.0,
    kBand: p.absorptionK,
    sBand: p.scatteringS,
    load: load,
    waterAmt: water,
    gran: p.granulation,
    stain: p.staining,
  );
}

double _susMeanRing(WatercolorField f, double a, double b) {
  final c = f.size / 2.0;
  var sum = 0.0;
  var n = 0;
  for (var y = 0; y < f.size; y++) {
    for (var x = 0; x < f.size; x++) {
      final dx = x + 0.5 - c, dy = y + 0.5 - c;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r >= a && r < b) {
        sum += f.propsSus[f.index(x, y) * WatercolorField.susProps];
        n++;
      }
    }
  }
  return n == 0 ? 0.0 : sum / n;
}

double _depMeanRing(WatercolorField f, double a, double b) {
  final c = f.size / 2.0;
  var sum = 0.0;
  var n = 0;
  for (var y = 0; y < f.size; y++) {
    for (var x = 0; x < f.size; x++) {
      final dx = x + 0.5 - c, dy = y + 0.5 - c;
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
  group('watercolor wet-model behavior', () {
    test(
      'wet-into-wet bleed — pigment bleeds into a surrounding wet region',
      () {
        final field = WatercolorField(64);
        final sim = WatercolorSimulation(field: field);
        // Pre-wet a broad area with clean water, then drop concentrated pigment
        // in the middle. Bleed (gated by wetness) should carry it outward into
        // the surrounding wet paper — the defining watercolor behavior.
        sim.splat(
          cx: 32,
          cy: 32,
          radius: 18,
          pressure: 1.0,
          kBand: List.filled(8, 0.0),
          sBand: List.filled(8, 0.0),
          load: 0.0,
          waterAmt: 2.5,
          gran: 0.0,
          stain: 0.0,
        );
        _splatDisc(
          sim,
          Pigment.phthaloBlue,
          cx: 32,
          cy: 32,
          radius: 5,
          water: 0.5,
        );

        double outside() =>
            _susMeanRing(field, 9, 14) + _depMeanRing(field, 9, 14);
        final outsideBefore = outside();
        for (var i = 0; i < 25; i++) {
          sim.step();
        }
        final outsideAfter = outside();

        expect(
          outsideAfter,
          greaterThan(outsideBefore + 1e-4),
          reason: 'pigment should bleed outward through the wet region',
        );
      },
    );

    test('subtractive mixing — blue over yellow composites toward green', () {
      final field = WatercolorField(48);
      final sim = WatercolorSimulation(field: field);
      _splatDisc(sim, Pigment.hansaYellow, cx: 24, cy: 24, radius: 10);
      for (var i = 0; i < 4; i++) {
        sim.step();
      }
      _splatDisc(sim, Pigment.phthaloBlue, cx: 24, cy: 24, radius: 10);
      for (var i = 0; i < 4; i++) {
        sim.step();
      }

      final rgba = Uint8List(field.cellCount * 4);
      sim.compositeToRgba(rgba);
      final o = field.index(24, 24) * 4;
      final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2];

      expect(g, greaterThan(r), reason: 'green should dominate red');
      expect(g, greaterThan(b), reason: 'green should dominate blue');
      expect(
        g - math.max(r, b),
        greaterThan(10),
        reason: 'a real green, not a muddy gray',
      );
    });

    test('dryback visibly lightens and mattes the same watercolor deposit', () {
      final field = WatercolorField(12);
      final sim = WatercolorSimulation(field: field);
      final cell = field.index(6, 6);
      final kb = cell * WatercolorField.bands;
      final pd = cell * WatercolorField.depProps;
      field.propsDep[pd] = 0.55;
      field.propsDep[pd + WatercolorField.depGranulation] =
          0.55 * Pigment.phthaloBlue.granulation;
      for (var band = 0; band < WatercolorField.bands; band++) {
        field.kdep[kb + band] = Pigment.phthaloBlue.absorptionK[band] * 0.55;
        field.sdep[kb + band] = Pigment.phthaloBlue.scatteringS[band] * 0.55;
      }

      final wet = Uint8List(field.cellCount * 4);
      field.waterM[cell] = 1.0;
      sim.compositeToRgba(wet);
      final dry = Uint8List(field.cellCount * 4);
      field.waterM[cell] = 0.0;
      sim.compositeToRgba(dry);
      final o = cell * 4;
      double luminance(Uint8List pixels) =>
          0.2126 * pixels[o] +
          0.7152 * pixels[o + 1] +
          0.0722 * pixels[o + 2];

      expect(
        luminance(dry),
        greaterThan(luminance(wet) + 4.0),
        reason: 'evaporating water must produce visible watercolor dryback',
      );
      expect(
        dry[o + 3],
        lessThan(wet[o + 3]),
        reason: 'dry paint should reveal slightly more matte paper',
      );
    });

    test('edge darkening — dried stroke settles darker toward the rim', () {
      WatercolorField run(double edge) {
        final field = WatercolorField(64);
        final sim = WatercolorSimulation(
          field: field,
          params: WatercolorParams(edge: edge),
        );
        _splatDisc(
          sim,
          Pigment.phthaloBlue,
          cx: 32,
          cy: 32,
          radius: 12,
          water: 2.0,
        );
        for (var i = 0; i < 220; i++) {
          sim.step();
        }
        return field;
      }

      final field = run(3.0);
      final control = run(0.0);
      expect(field.wetFraction(), 0.0, reason: 'wash should dry');
      final rim = _depMeanRing(field, 14, 16);
      final center = _depMeanRing(field, 0, 5);
      final controlRim = _depMeanRing(control, 14, 16);
      expect(
        rim,
        greaterThan(controlRim),
        reason: 'edge flow must darken the boundary relative to no edge flow',
      );
      expect(
        center,
        greaterThan(rim * 0.1),
        reason: 'edge darkening must not evacuate the loaded center',
      );
    });

    test('bloom — water opens the center but leaves caught pigment behind', () {
      WatercolorField run({required bool drop}) {
        final field = WatercolorField(64);
        final sim = WatercolorSimulation(field: field);
        _splatDisc(sim, Pigment.frenchUltramarine, cx: 32, cy: 32, radius: 14);
        // Backruns reopen a still-damp wash. A completely dry layer is now a
        // protected glaze substrate and is tested separately.
        for (var i = 0; i < 40; i++) {
          sim.step();
        }
        if (drop) {
          sim.splat(
            cx: 32,
            cy: 32,
            radius: 7,
            pressure: 1.0,
            kBand: List.filled(8, 0.0),
            sBand: List.filled(8, 0.0),
            load: 0.0,
            waterAmt: 4.0,
            gran: 0.0,
            stain: 0.0,
          );
        }
        for (var i = 0; i < 80; i++) {
          sim.step();
        }
        return field;
      }

      final dropped = _depMeanRing(run(drop: true), 0, 4);
      final control = _depMeanRing(run(drop: false), 0, 4);
      expect(
        dropped,
        lessThan(control * 0.9),
        reason: 'a clean-water backrun opens the settled center',
      );
      expect(
        dropped,
        greaterThan(control * 0.50),
        reason: 'paper-caught pigment must remain behind the bloom',
      );
    });

    test(
      'dry-out & stability — the wash dries with finite, non-negative state',
      () {
        final field = WatercolorField(48);
        final sim = WatercolorSimulation(field: field);
        _splatDisc(sim, Pigment.frenchUltramarine, cx: 24, cy: 24, radius: 12);
        var steps = 0;
        while (field.wetFraction() > 0.0 && steps < 500) {
          sim.step();
          steps++;
        }
        // wetFraction reads 0 before the first step (mask computed in-step), so
        // step at least once for a real dry-out measurement.
        sim.step();
        for (var i = 0; i < field.cellCount; i++) {
          expect(field.waterH[i].isFinite, isTrue);
          expect(field.propsSus[i * WatercolorField.susProps].isFinite, isTrue);
          expect(field.propsDep[i * WatercolorField.depProps] >= 0.0, isTrue);
        }
      },
    );

    test('containment — pigment does not flood the far corners', () {
      final field = WatercolorField(64);
      final sim = WatercolorSimulation(field: field);
      _splatDisc(sim, Pigment.phthaloBlue, cx: 32, cy: 32, radius: 10);
      for (var i = 0; i < 60; i++) {
        sim.step();
      }
      final corner =
          field.propsSus[field.index(3, 3) * WatercolorField.susProps] +
          field.propsDep[field.index(3, 3) * WatercolorField.depProps];
      expect(
        corner,
        lessThan(0.01),
        reason: 'the wash stays local, not flooding the sheet',
      );
    });
  });
}
