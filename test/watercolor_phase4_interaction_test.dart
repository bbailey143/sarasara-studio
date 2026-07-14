import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_reservoir.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_engine.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_params.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_simulation.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

void main() {
  group('Phase 4 shared wet wash', () {
    test('the live Fluid path joins a second colour after one wet second', () {
      final engine = WatercolorEngine(
        simSize: 64,
        params: const WatercolorParams(dry: 0.0015),
      );
      const canvas = Size(200, 200);

      TransferReceipt receipt({
        required int band,
        required double pigment,
        required double carrier,
      }) {
        return TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedOutflow: carrier,
          pigmentOut: pigment,
          kOut: List<double>.generate(
            WatercolorField.bands,
            (i) => i == band ? pigment : 0.0,
          ),
          sOut: List<double>.generate(
            WatercolorField.bands,
            (i) => i == band ? pigment * 0.3 : 0.0,
          ),
          granulationOut: pigment * 0.25,
          stainingOut: pigment * 0.2,
        );
      }

      void deposit({
        required Offset at,
        required double radius,
        required TransferReceipt transfer,
      }) {
        engine.depositContact(
          [
            MediumFootprintCluster(
              position: at,
              coverage: 1,
              pressure: 1,
              velocity: Offset.zero,
              radius: radius,
            ),
          ],
          canvas,
          radius * 2,
          kBand: List<double>.filled(WatercolorField.bands, 0),
          sBand: List<double>.filled(WatercolorField.bands, 0),
          gran: 0,
          stain: 0,
          receipt: transfer,
        );
      }

      deposit(
        at: const Offset(100, 100),
        radius: 24,
        transfer: receipt(band: 0, pigment: 0.012, carrier: 0.05),
      );
      engine.tick(30);
      final center = engine.field.index(32, 32);
      expect(
        engine.field.waterH[center] + engine.field.saturation[center],
        greaterThan(0.01),
        reason: 'the first wash must still be workable one second later',
      );

      deposit(
        at: const Offset(104, 100),
        radius: 9,
        transfer: receipt(band: 1, pigment: 0.009, carrier: 0.018),
      );
      engine.tick(2);

      var newTotal = 0.0;
      var newInsideOlderWashOutsideSecondFootprint = 0.0;
      for (var y = 0; y < engine.simSize; y++) {
        for (var x = 0; x < engine.simSize; x++) {
          final cell = engine.field.index(x, y);
          final base = cell * WatercolorField.bands;
          final oldHere = engine.field.ksus[base] + engine.field.kdep[base];
          final newHere =
              engine.field.ksus[base + 1] + engine.field.kdep[base + 1];
          newTotal += newHere;
          final dx = x + 0.5 - 104 / 200 * engine.simSize;
          final dy = y + 0.5 - 100 / 200 * engine.simSize;
          final secondRadius = 9 / 200 * engine.simSize;
          if (dx * dx + dy * dy > secondRadius * secondRadius &&
              oldHere > 1e-5) {
            newInsideOlderWashOutsideSecondFootprint += newHere;
          }
        }
      }
      expect(newTotal, greaterThan(0));
      expect(
        newInsideOlderWashOutsideSecondFootprint / newTotal,
        greaterThan(0.005),
        reason:
            'a meaningful share of the later colour must enter the older '
            'connected wash instead of remaining a separate stamp',
      );
    });

    test(
      'a second colour joins a wet stroke instead of depositing a new layer',
      () {
        final wet = _secondContact(firstStrokeIsWet: true);
        final dry = _secondContact(firstStrokeIsWet: false);

        expect(
          wet.firstStrokeWetness,
          greaterThan(0.06),
          reason: 'the first stroke must still be genuinely wet at contact',
        );
        expect(dry.firstStrokeWetness, 0);
        expect(
          wet.mixedCellsOutsideNewFootprint,
          greaterThan(0),
          reason:
              'new colour must immediately enter neighbouring cells that '
              'belong to the connected wet stroke',
        );
        expect(
          wet.newColourDeposited,
          lessThan(dry.newColourDeposited * 0.35),
          reason:
              'a wet contact should keep most new pigment mobile; the same '
              'contact on dry paper should catch a visibly larger fraction',
        );
      },
    );

    test(
      'a wet yellow crossing dissolves an active blue ridge into one '
      'subtractive wash',
      () {
        final field = WatercolorField(32);
        final sim = WatercolorSimulation(
          field: field,
          paperHeight: (x, y) => 0.5,
          params: const WatercolorParams(
            transportMode: WatercolorTransportMode.diffusionFallback,
            bleed: 0,
            wetSpread: 0,
            dry: 0,
            soak: 0,
            settle: 0,
            lift: 0,
            edge: 0,
            momentum: 0,
          ),
        );
        final blue = Pigment.phthaloBlue;
        final yellow = Pigment.hansaYellow;

        // A still-active blue ridge: deposited on the paper, but not protected
        // as Dry. This is the line that survived under the yellow in the GIF.
        for (var y = 7; y <= 24; y++) {
          for (var x = 15; x <= 16; x++) {
            final cell = field.index(x, y);
            final kb = cell * WatercolorField.bands;
            final pd = cell * WatercolorField.depProps;
            field.waterH[cell] = 0.20;
            field.saturation[cell] = 0.10;
            for (var band = 0; band < WatercolorField.bands; band++) {
              field.kdep[kb + band] = blue.absorptionK[band];
              field.sdep[kb + band] = blue.scatteringS[band];
            }
            field.propsDep[pd] = 1.0;
            field.propsDep[pd + WatercolorField.depGranulation] =
                blue.granulation;
            field.propsDep[pd + WatercolorField.depStaining] = blue.staining;
          }
        }

        final center = field.index(16, 16);
        sim.splat(
          cx: 16,
          cy: 16,
          radius: 4,
          pressure: 1,
          contactPressure: 0.5,
          kBand: yellow.absorptionK,
          sBand: yellow.scatteringS,
          load: 1,
          waterAmt: 0.25,
          gran: yellow.granulation,
          stain: yellow.staining,
        );

        var maximumRemainingLoad = 0.0;
        var maximumBlueBandRatio = 0.0;
        const blueDiagnosticBand = 7;
        for (var y = 12; y <= 19; y++) {
          for (var x = 15; x <= 16; x++) {
            final cell = field.index(x, y);
            final remainingLoad =
                field.propsDep[cell * WatercolorField.depProps];
            if (remainingLoad > maximumRemainingLoad) {
              maximumRemainingLoad = remainingLoad;
            }
            final remainingBlueBand = field.kdep[
              cell * WatercolorField.bands + blueDiagnosticBand
            ];
            final blueBandRatio =
                remainingBlueBand / blue.absorptionK[blueDiagnosticBand];
            if (blueBandRatio > maximumBlueBandRatio) {
              maximumBlueBandRatio = blueBandRatio;
            }
          }
        }
        expect(
          maximumRemainingLoad,
          lessThan(0.12),
          reason:
              'the entire crossed stripe must re-open; checking only its '
              'center can miss a surviving visible ridge beside it',
        );
        expect(
          maximumBlueBandRatio,
          lessThan(0.12),
          reason:
              'the old blue deposit itself must leave the crossed stripe, '
              'not merely render green beneath suspended yellow',
        );

        var ridgeBandSum = 0.0;
        var shoulderBandSum = 0.0;
        var ridgeCellCount = 0;
        var shoulderCellCount = 0;
        for (var y = 12; y <= 19; y++) {
          for (final x in const [15, 16]) {
            final base = field.index(x, y) * WatercolorField.bands;
            ridgeBandSum +=
                field.kdep[base + blueDiagnosticBand] +
                field.ksus[base + blueDiagnosticBand];
            ridgeCellCount++;
          }
          for (final x in const [14, 17]) {
            final base = field.index(x, y) * WatercolorField.bands;
            shoulderBandSum +=
                field.kdep[base + blueDiagnosticBand] +
                field.ksus[base + blueDiagnosticBand];
            shoulderCellCount++;
          }
        }
        final ridgeBandAverage = ridgeBandSum / ridgeCellCount;
        final shoulderBandAverage = shoulderBandSum / shoulderCellCount;
        expect(
          ridgeBandAverage,
          lessThan(blue.absorptionK[blueDiagnosticBand] * 0.65),
          reason:
              're-suspension must visibly flatten the old blue concentration, '
              'not only move it between deposited and suspended storage',
        );
        expect(
          shoulderBandAverage,
          greaterThan(ridgeBandAverage * 0.35),
          reason:
              'the reopened blue must spread into both shoulders so its old '
              'two-cell line no longer survives beneath the yellow',
        );

        final rgba = Uint8List(field.cellCount * 4);
        sim.compositeToRgba(rgba);
        final o = center * 4;
        final red = rgba[o];
        final green = rgba[o + 1];
        final blueChannel = rgba[o + 2];
        expect(green, greaterThan(red));
        expect(
          green,
          greaterThan(blueChannel),
          reason:
              'co-located yellow and blue K/S spectra must resolve as a '
              'subtractive green mixture, not two alpha-blended marks',
        );
      },
    );

    test(
      'paper-held moisture still unifies two colours after an eight-second '
      'pause',
      () {
        final field = WatercolorField(32);
        final sim = WatercolorSimulation(
          field: field,
          params: const WatercolorParams(
            transportMode: WatercolorTransportMode.diffusionFallback,
            bleed: 0,
            wetSpread: 0,
            dry: 0.0017,
            paperDryFactor: 0.22,
            soak: 0,
            settle: 0,
            lift: 0,
            edge: 0,
            momentum: 0,
          ),
        );
        final center = field.index(16, 16);
        final blue = Pigment.phthaloBlue;
        final yellow = Pigment.hansaYellow;
        for (var y = 7; y <= 24; y++) {
          for (var x = 15; x <= 16; x++) {
            final cell = field.index(x, y);
            final kb = cell * WatercolorField.bands;
            final pd = cell * WatercolorField.depProps;
            field.waterH[cell] = 0.12;
            field.saturation[cell] = 0.20;
            for (var band = 0; band < WatercolorField.bands; band++) {
              field.kdep[kb + band] = blue.absorptionK[band];
              field.sdep[kb + band] = blue.scatteringS[band];
            }
            field.propsDep[pd] = 1.0;
            field.propsDep[pd + WatercolorField.depGranulation] =
                blue.granulation;
            field.propsDep[pd + WatercolorField.depStaining] = blue.staining;
          }
        }

        for (var frame = 0; frame < 240; frame++) {
          sim.step();
        }

        expect(
          field.waterM[center],
          greaterThan(0.45),
          reason:
              'surface shine may fade, but a normally wet wash must remain '
              'workable while the artist changes colour',
        );
        var maximumProtectedBlue = 0.0;
        for (var y = 12; y <= 19; y++) {
          for (var x = 15; x <= 16; x++) {
            final protected = field.propsDry[
              field.index(x, y) * WatercolorField.depProps
            ];
            if (protected > maximumProtectedBlue) {
              maximumProtectedBlue = protected;
            }
          }
        }
        expect(
          maximumProtectedBlue,
          closeTo(0.0, 1e-9),
          reason:
              'the blue must still be active rather than silently protected '
              'as a finished dry glaze during the colour change',
        );

        sim.splat(
          cx: 16,
          cy: 16,
          radius: 4,
          pressure: 1,
          contactPressure: 0.5,
          kBand: yellow.absorptionK,
          sBand: yellow.scatteringS,
          load: 1,
          waterAmt: 0.25,
          gran: yellow.granulation,
          stain: yellow.staining,
        );
        var maximumBlueDepositRatio = 0.0;
        for (var y = 12; y <= 19; y++) {
          for (var x = 15; x <= 16; x++) {
            final base = field.index(x, y) * WatercolorField.bands;
            final ratio =
                field.kdep[base + 7] / blue.absorptionK[7];
            if (ratio > maximumBlueDepositRatio) {
              maximumBlueDepositRatio = ratio;
            }
          }
        }
        expect(
          maximumBlueDepositRatio,
          lessThan(0.12),
          reason:
              'a wet second colour must re-wet and dissolve the old active '
              'blue line across the full crossing after the real eight-second '
              'picker pause',
        );
      },
    );

    test('wet, damp, and dry contact form a real mixing continuum', () {
      double newlyCaught({required double water, required double saturation}) {
        final field = WatercolorField(24);
        for (var i = 0; i < field.cellCount; i++) {
          field.waterH[i] = water;
          field.saturation[i] = saturation;
        }
        final sim = WatercolorSimulation(
          field: field,
          paperHeight: (x, y) => 0.25,
          params: const WatercolorParams(
            dry: 0,
            soak: 0,
            bleed: 0,
            settle: 0,
            lift: 0,
          ),
        );
        final pigment = List<double>.filled(WatercolorField.bands, 0)..[2] = 1;
        sim.splat(
          cx: 12,
          cy: 12,
          radius: 3,
          pressure: 1,
          contactPressure: 0.5,
          kBand: pigment,
          sBand: List<double>.filled(WatercolorField.bands, 0.2),
          load: 1,
          waterAmt: 0.2,
          gran: 0.4,
          stain: 0.2,
        );
        return _sumBand(field.kdep, 2);
      }

      final wet = newlyCaught(water: 0.5, saturation: 0);
      final damp = newlyCaught(water: 0, saturation: 0.05);
      final dry = newlyCaught(water: 0, saturation: 0);
      expect(wet, lessThan(damp));
      expect(damp, lessThan(dry));
    });

    test('bleeding conserves both spectra and pigment properties', () {
      final field = WatercolorField(36);
      // Deliberately put a damp half beside a fully wet half of one connected
      // wash. A one-sided diffusion update can appear conservative in a
      // uniform puddle while silently losing pigment at this transition.
      for (var y = 0; y < field.size; y++) {
        for (var x = 0; x < field.size; x++) {
          field.waterH[field.index(x, y)] = x < 18 ? 0.08 : 0.9;
        }
      }
      final sim = WatercolorSimulation(
        field: field,
        paperHeight: (x, y) => 0.5,
        params: const WatercolorParams(
          transportMode: WatercolorTransportMode.diffusionFallback,
          bleed: 0.12,
          bleedIters: 3,
          wetSpread: 0,
          dry: 0,
          soak: 0,
          settle: 0,
          lift: 0,
          edge: 0,
          momentum: 0,
        ),
      );

      final firstK = List<double>.filled(WatercolorField.bands, 0)
        ..[0] = 1.0
        ..[3] = 0.35;
      final firstS = List<double>.filled(WatercolorField.bands, 0)
        ..[0] = 0.25
        ..[3] = 0.7;
      final secondK = List<double>.filled(WatercolorField.bands, 0)
        ..[1] = 0.8
        ..[6] = 0.45;
      final secondS = List<double>.filled(WatercolorField.bands, 0)
        ..[1] = 0.55
        ..[6] = 0.2;
      sim.splat(
        cx: 16.5,
        cy: 18,
        radius: 2.5,
        pressure: 1,
        kBand: firstK,
        sBand: firstS,
        load: 1.1,
        waterAmt: 0,
        gran: 0.65,
        stain: 0.2,
      );
      sim.splat(
        cx: 19.5,
        cy: 18,
        radius: 2.5,
        pressure: 1,
        kBand: secondK,
        sBand: secondS,
        load: 0.8,
        waterAmt: 0,
        gran: 0.15,
        stain: 0.75,
      );

      final before = _totals(field);
      for (var i = 0; i < 30; i++) {
        sim.step();
      }
      final after = _totals(field);

      for (var band = 0; band < WatercolorField.bands; band++) {
        expect(
          after.k[band],
          closeTo(before.k[band], _scaledTolerance(before.k[band])),
          reason: 'absorption band $band must be transported, not created',
        );
        expect(
          after.s[band],
          closeTo(before.s[band], _scaledTolerance(before.s[band])),
          reason: 'scattering band $band must be transported, not created',
        );
      }
      expect(after.load, closeTo(before.load, _scaledTolerance(before.load)));
      expect(
        after.granulation,
        closeTo(before.granulation, _scaledTolerance(before.granulation)),
      );
      expect(
        after.staining,
        closeTo(before.staining, _scaledTolerance(before.staining)),
      );
    });
  });

  group('Phase 4 dry substrate boundary', () {
    test('the engine reports dry only after pigment is fully protected', () {
      final engine = WatercolorEngine(
        simSize: 32,
        params: const WatercolorParams(
          transportMode: WatercolorTransportMode.diffusionFallback,
          bleed: 0,
          wetSpread: 0,
          dry: 0.08,
          paperDryFactor: 1,
          soak: 0,
          settle: 0.05,
          lift: 0,
          edge: 0,
        ),
      );
      const pigment = 0.002;
      engine.depositContact(
        const [
          MediumFootprintCluster(
            position: Offset(50, 50),
            coverage: 1,
            pressure: 1,
            velocity: Offset.zero,
            radius: 7,
          ),
        ],
        const Size(100, 100),
        14,
        kBand: const [0, 0, 0, 0, 0, 0, 0, 0],
        sBand: const [0, 0, 0, 0, 0, 0, 0, 0],
        gran: 0,
        stain: 0,
        receipt: TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedOutflow: 0.002,
          pigmentOut: pigment,
          kOut: const [pigment, 0, 0, 0, 0, 0, 0, 0],
          sOut: const [0.0006, 0, 0, 0, 0, 0, 0, 0],
          granulationOut: 0.0005,
          stainingOut: 0.0004,
        ),
      );
      expect(engine.isDry, isFalse);

      var steps = 0;
      while (!engine.isDry && steps < 120) {
        engine.tick();
        steps++;
      }
      expect(engine.isDry, isTrue);
      expect(engine.field.totalSuspendedLoad(), lessThanOrEqualTo(1e-6));
      expect(
        engine.field.totalUnprotectedDepositedLoad(),
        lessThanOrEqualTo(1e-6),
      );
      for (var band = 0; band < WatercolorField.bands; band++) {
        expect(
          _sumBand(engine.field.kDry, band),
          closeTo(_sumBand(engine.field.kdep, band), 1e-5),
        );
        expect(
          _sumBand(engine.field.sDry, band),
          closeTo(_sumBand(engine.field.sdep, band), 1e-5),
        );
      }
    });

    test('a brief dry dip does not lock a wash, but a sustained one does', () {
      WatercolorSimulation seeded(WatercolorField field) {
        final center = field.index(8, 8);
        field.ksus[center * WatercolorField.bands] = 1;
        field.ssus[center * WatercolorField.bands] = 0.3;
        field.propsSus[center * WatercolorField.susProps] = 1;
        field.propsSus[center * WatercolorField.susProps + 1] = 0.4;
        return WatercolorSimulation(
          field: field,
          params: const WatercolorParams(
            transportMode: WatercolorTransportMode.diffusionFallback,
            bleed: 0,
            wetSpread: 0,
            dry: 0,
            soak: 0,
            settle: 0,
            lift: 0,
            edge: 0,
          ),
        );
      }

      final brieflyDry = WatercolorField(16);
      final briefSim = seeded(brieflyDry);
      briefSim.step();
      briefSim.step();
      final center = brieflyDry.index(8, 8);
      brieflyDry.waterH[center] = 0.2;
      briefSim.step();
      expect(_sumBand(brieflyDry.kDry, 0), 0);
      expect(
        brieflyDry.propsDep[
          center * WatercolorField.depProps + WatercolorField.depDryClock
        ],
        0,
        reason: 'renewed wetness must cancel the pending dry lock',
      );

      final sustainedDry = WatercolorField(16);
      final sustainedSim = seeded(sustainedDry);
      for (var i = 0; i < 6; i++) {
        sustainedSim.step();
      }
      expect(_sumBand(sustainedDry.ksus, 0), 0);
      expect(_sumBand(sustainedDry.kDry, 0), closeTo(1, 1e-5));
    });

    test('granulating pigment settles preferentially into paper valleys', () {
      double valleyAdvantage(double granulation) {
        final field = WatercolorField(10);
        final valley = field.index(2, 5);
        final peak = field.index(7, 5);
        for (final cell in [valley, peak]) {
          field.ksus[cell * WatercolorField.bands] = 1;
          field.ssus[cell * WatercolorField.bands] = 0.3;
          field.propsSus[cell * WatercolorField.susProps] = 1;
          field.propsSus[cell * WatercolorField.susProps + 1] = granulation;
        }
        final sim = WatercolorSimulation(
          field: field,
          paperHeight: (x, y) => x < 5 ? 0.0 : 1.0,
          params: const WatercolorParams(
            transportMode: WatercolorTransportMode.diffusionFallback,
            bleed: 0,
            wetSpread: 0,
            dry: 0,
            soak: 0,
            settle: 0.1,
            lift: 0,
            edge: 0,
          ),
        );
        sim.step();
        return field.propsDep[valley * WatercolorField.depProps] -
            field.propsDep[peak * WatercolorField.depProps];
      }

      expect(valleyAdvantage(1), greaterThan(0.04));
      expect(valleyAdvantage(0), closeTo(0, 1e-6));
    });

    test('granulation and staining identity survive settling and re-lift', () {
      final field = WatercolorField(12);
      final center = field.index(6, 6);
      final ps = center * WatercolorField.susProps;
      field.ksus[center * WatercolorField.bands] = 1;
      field.ssus[center * WatercolorField.bands] = 0.3;
      field.propsSus[ps] = 1;
      field.propsSus[ps + 1] = 0.8;
      field.propsSus[ps + 2] = 0.2;
      final sim = WatercolorSimulation(
        field: field,
        params: const WatercolorParams(
          transportMode: WatercolorTransportMode.diffusionFallback,
          bleed: 0,
          wetSpread: 0,
          dry: 0,
          soak: 0,
          settle: 1,
          lift: 1,
          edge: 0,
          dryHoldSeconds: 10,
        ),
      );

      sim.step();
      final pd = center * WatercolorField.depProps;
      expect(
        field.propsDep[pd + WatercolorField.depGranulation],
        greaterThan(0.7),
      );
      expect(
        field.propsDep[pd + WatercolorField.depStaining],
        greaterThan(0.15),
      );

      field.waterH[center] = 0.5;
      sim.step();
      final granulationTotal =
          field.propsSus[ps + 1] +
          field.propsDep[pd + WatercolorField.depGranulation];
      final stainingTotal =
          field.propsSus[ps + 2] +
          field.propsDep[pd + WatercolorField.depStaining];
      expect(field.propsSus[ps + 1], greaterThan(0));
      expect(granulationTotal, closeTo(0.8, 1e-5));
      expect(stainingTotal, closeTo(0.2, 1e-5));
    });

    test('actual drying settles and freezes every pigment channel', () {
      final dried = _makeActuallyDriedStroke();
      final field = dried.field;

      expect(field.wetFraction(), 0);
      expect(_sumChannel(field.propsSus, WatercolorField.susProps, 0), 0);
      expect(
        _sumChannel(field.propsDry, WatercolorField.depProps, 0),
        greaterThan(0.2),
        reason: 'the dry record must contain the real painted stroke',
      );

      for (var band = 0; band < WatercolorField.bands; band++) {
        expect(
          _sumBand(field.kDry, band),
          closeTo(_sumBand(field.kdep, band), 1e-5),
          reason: 'dry absorption band $band must be frozen at dry transition',
        );
        expect(
          _sumBand(field.sDry, band),
          closeTo(_sumBand(field.sdep, band), 1e-5),
          reason: 'dry scattering band $band must be frozen at dry transition',
        );
      }
      expect(
        _sumChannel(field.propsDry, WatercolorField.depProps, 0),
        closeTo(_sumChannel(field.propsDep, WatercolorField.depProps, 0), 1e-5),
      );
      expect(
        _sumChannel(field.propsDry, WatercolorField.depProps, 1),
        closeTo(_sumChannel(field.propsDep, WatercolorField.depProps, 1), 1e-5),
      );
      expect(
        _sumChannel(field.propsDry, WatercolorField.depProps, 2),
        closeTo(_sumChannel(field.propsDep, WatercolorField.depProps, 2), 1e-5),
      );
    });

    test('direct clean-water rewet cannot lift a frozen dry stroke', () {
      final dried = _makeActuallyDriedStroke();
      final before = dried.field.snapshot();
      final field = WatercolorField(before.size)..restore(before);
      final sim = _strongRewetSimulation(field);

      sim.splat(
        cx: 20.5,
        cy: 20.5,
        radius: 2.5,
        pressure: 1,
        contactPressure: 1,
        kBand: List<double>.filled(WatercolorField.bands, 0),
        sBand: List<double>.filled(WatercolorField.bands, 0),
        load: 0,
        waterAmt: 1.5,
        gran: 0,
        stain: 0,
      );
      for (var i = 0; i < 12; i++) {
        sim.step();
      }

      expect(
        field.waterH[field.index(20, 20)] +
            field.saturation[field.index(20, 20)],
        greaterThan(sim.params.wetThreshold),
        reason: 'the test must genuinely rewet the old mark',
      );
      _expectDryPigmentUntouched(field, before);
    });

    test('water arriving from a neighbour cannot lift a frozen dry stroke', () {
      final dried = _makeActuallyDriedStroke();
      final before = dried.field.snapshot();
      final field = WatercolorField(before.size)..restore(before);
      final sim = _strongRewetSimulation(field);
      final center = field.index(20, 20);
      final neighbour = field.index(21, 20);
      expect(field.waterH[center], 0);

      // Water starts beside the inspected dry cell. It can reach the old mark
      // only through the paper/water solver, rather than a brush splat there.
      field.waterH[neighbour] = 1.5;
      for (var i = 0; i < 12; i++) {
        sim.step();
      }

      expect(
        field.waterH[center] + field.saturation[center],
        greaterThan(sim.params.wetThreshold),
        reason: 'capillary flow must genuinely reach the dry pigment cell',
      );
      _expectDryPigmentUntouched(field, before);
    });
  });
}

({
  double newColourDeposited,
  int mixedCellsOutsideNewFootprint,
  double firstStrokeWetness,
})
_secondContact({required bool firstStrokeIsWet}) {
  final field = WatercolorField(40);
  final sim = WatercolorSimulation(
    field: field,
    paperHeight: (x, y) => 0.5,
    params: const WatercolorParams(
      transportMode: WatercolorTransportMode.diffusionFallback,
      bleed: 0.12,
      bleedIters: 2,
      wetSpread: 0,
      dry: 0,
      soak: 0,
      settle: 0,
      lift: 0,
      edge: 0,
      momentum: 0,
    ),
  );
  final oldK = List<double>.filled(WatercolorField.bands, 0)..[0] = 1;
  final newK = List<double>.filled(WatercolorField.bands, 0)..[1] = 1;
  final scattering = List<double>.filled(WatercolorField.bands, 0.25);

  sim.splat(
    cx: 16,
    cy: 20,
    radius: 6,
    pressure: 1,
    kBand: oldK,
    sBand: scattering,
    load: 1,
    waterAmt: 1.3,
    gran: 0.3,
    stain: 0.15,
  );
  if (firstStrokeIsWet) {
    for (var i = 0; i < 3; i++) {
      sim.step();
    }
  } else {
    _manuallyFinishAndFreeze(field);
  }
  final firstStrokeWetness =
      field.waterH[field.index(18, 20)] + field.saturation[field.index(18, 20)];

  sim.splat(
    cx: 20,
    cy: 20,
    radius: 3,
    pressure: 1,
    contactPressure: 0.5,
    kBand: newK,
    sBand: scattering,
    load: 0.75,
    waterAmt: 0.6,
    gran: 0.3,
    stain: 0.15,
  );

  var mixedOutside = 0;
  for (var y = 0; y < field.size; y++) {
    for (var x = 0; x < field.size; x++) {
      final dx = x + 0.5 - 20;
      final dy = y + 0.5 - 20;
      if (dx * dx + dy * dy < 3.1 * 3.1) continue;
      final base = field.index(x, y) * WatercolorField.bands;
      final oldHere = field.ksus[base] + field.kdep[base];
      final newHere = field.ksus[base + 1] + field.kdep[base + 1];
      if (oldHere > 1e-5 && newHere > 1e-7) mixedOutside++;
    }
  }
  return (
    newColourDeposited: _sumBand(field.kdep, 1),
    mixedCellsOutsideNewFootprint: mixedOutside,
    firstStrokeWetness: firstStrokeWetness,
  );
}

void _manuallyFinishAndFreeze(WatercolorField field) {
  for (var i = 0; i < field.cellCount; i++) {
    final kb = i * WatercolorField.bands;
    for (var band = 0; band < WatercolorField.bands; band++) {
      field.kdep[kb + band] += field.ksus[kb + band];
      field.sdep[kb + band] += field.ssus[kb + band];
      field.ksus[kb + band] = 0;
      field.ssus[kb + band] = 0;
      field.kDry[kb + band] = field.kdep[kb + band];
      field.sDry[kb + band] = field.sdep[kb + band];
    }
    final ps = i * WatercolorField.susProps;
    final pd = i * WatercolorField.depProps;
    field.propsDep[pd] += field.propsSus[ps];
    field.propsDep[pd + WatercolorField.depGranulation] +=
        field.propsSus[ps + 1];
    field.propsDep[pd + WatercolorField.depStaining] += field.propsSus[ps + 2];
    field.propsDry[pd] = field.propsDep[pd];
    field.propsDry[pd + WatercolorField.depGranulation] =
        field.propsDep[pd + WatercolorField.depGranulation];
    field.propsDry[pd + WatercolorField.depStaining] =
        field.propsDep[pd + WatercolorField.depStaining];
    field.propsSus[ps] = 0;
    field.propsSus[ps + 1] = 0;
    field.propsSus[ps + 2] = 0;
    field.waterH[i] = 0;
    field.waterM[i] = 0;
    field.saturation[i] = 0;
  }
}

({WatercolorField field, WatercolorSimulation sim}) _makeActuallyDriedStroke() {
  final field = WatercolorField(40);
  final sim = WatercolorSimulation(
    field: field,
    paperHeight: (x, y) => 0.5,
    params: const WatercolorParams(
      transportMode: WatercolorTransportMode.diffusionFallback,
      bleed: 0,
      bleedIters: 1,
      wetSpread: 0,
      dry: 0.08,
      paperDryFactor: 1,
      soak: 0,
      settle: 0.2,
      lift: 0,
      edge: 0,
      momentum: 0,
    ),
  );
  final k = List<double>.filled(WatercolorField.bands, 0)
    ..[0] = 1
    ..[4] = 0.35;
  final s = List<double>.filled(WatercolorField.bands, 0)
    ..[0] = 0.3
    ..[4] = 0.8;
  sim.splat(
    cx: 20.5,
    cy: 20.5,
    radius: 5,
    pressure: 1,
    kBand: k,
    sBand: s,
    load: 1,
    waterAmt: 0.7,
    gran: 0.4,
    stain: 0.25,
  );
  for (var i = 0; i < 30; i++) {
    sim.step();
  }
  return (field: field, sim: sim);
}

WatercolorSimulation _strongRewetSimulation(WatercolorField field) {
  return WatercolorSimulation(
    field: field,
    paperHeight: (x, y) => 0.5,
    params: const WatercolorParams(
      transportMode: WatercolorTransportMode.diffusionFallback,
      bleed: 0,
      bleedIters: 1,
      wetSpread: 0.8,
      dry: 0,
      soak: 0,
      settle: 0,
      lift: 1,
      edge: 0,
      momentum: 0,
    ),
  );
}

void _expectDryPigmentUntouched(
  WatercolorField field,
  WatercolorFieldSnapshot before,
) {
  for (var band = 0; band < WatercolorField.bands; band++) {
    expect(
      _sumBand(field.kdep, band),
      closeTo(_sumBand(before.kdep, band), 1e-5),
      reason: 'rewetting must not lift frozen absorption band $band',
    );
    expect(
      _sumBand(field.sdep, band),
      closeTo(_sumBand(before.sdep, band), 1e-5),
      reason: 'rewetting must not lift frozen scattering band $band',
    );
    expect(
      _sumBand(field.ksus, band),
      closeTo(0, 1e-6),
      reason: 'frozen absorption band $band must not become mobile again',
    );
    expect(
      _sumBand(field.ssus, band),
      closeTo(0, 1e-6),
      reason: 'frozen scattering band $band must not become mobile again',
    );
  }
  for (final channel in [
    WatercolorField.depLoad,
    WatercolorField.depGranulation,
    WatercolorField.depStaining,
  ]) {
    expect(
      _sumChannel(field.propsDep, WatercolorField.depProps, channel),
      closeTo(
        _sumChannel(before.propsDep, WatercolorField.depProps, channel),
        1e-5,
      ),
    );
  }
  expect(_sumChannel(field.propsSus, WatercolorField.susProps, 0), 0);
}

_PigmentTotals _totals(WatercolorField field) {
  final k = List<double>.filled(WatercolorField.bands, 0);
  final s = List<double>.filled(WatercolorField.bands, 0);
  for (var band = 0; band < WatercolorField.bands; band++) {
    k[band] = _sumBand(field.ksus, band) + _sumBand(field.kdep, band);
    s[band] = _sumBand(field.ssus, band) + _sumBand(field.sdep, band);
  }
  return _PigmentTotals(
    k: k,
    s: s,
    load:
        _sumChannel(field.propsSus, WatercolorField.susProps, 0) +
        _sumChannel(field.propsDep, WatercolorField.depProps, 0),
    granulation:
        _sumChannel(field.propsSus, WatercolorField.susProps, 1) +
        _sumChannel(
          field.propsDep,
          WatercolorField.depProps,
          WatercolorField.depGranulation,
        ),
    staining:
        _sumChannel(field.propsSus, WatercolorField.susProps, 2) +
        _sumChannel(
          field.propsDep,
          WatercolorField.depProps,
          WatercolorField.depStaining,
        ),
  );
}

double _sumBand(Float32List values, int band) {
  var sum = 0.0;
  for (var i = band; i < values.length; i += WatercolorField.bands) {
    sum += values[i];
  }
  return sum;
}

double _sumChannel(Float32List values, int stride, int channel) {
  var sum = 0.0;
  for (var i = channel; i < values.length; i += stride) {
    sum += values[i];
  }
  return sum;
}

double _scaledTolerance(double value) => 2e-5 + value.abs() * 5e-4;

class _PigmentTotals {
  const _PigmentTotals({
    required this.k,
    required this.s,
    required this.load,
    required this.granulation,
    required this.staining,
  });

  final List<double> k;
  final List<double> s;
  final double load;
  final double granulation;
  final double staining;
}
