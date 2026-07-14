import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_dynamics.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_reservoir.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/paint_mixture.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_engine.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_params.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_simulation.dart';
import 'package:sarasara_studio_01_rev1/models/brush.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// End-to-end integration: brush input → brush dynamics → watercolor adapter →
/// [WatercolorEngine] → composited pixels. This drives the exact seam the
/// canvas controller uses, proving the engine consumes real brush contacts and
/// produces visible paint (not that a hand-made splat works).
void main() {
  test('a real brush stroke deposits visible blue paint through the engine', () {
    const canvas = Size(400, 400);
    const adapter = WatercolorBrushAdapter();
    final brush = Brush.sableRound;

    // Load the reservoir with blue paint exactly as the controller does.
    final paint = PaintMixture.single(Pigment.phthaloBlue);
    final reservoir = BrushReservoir.forBrush(brush)
      ..applyReceipt(
        TransferReceipt(
          medium: MediumFamily.watercolor,
          pigmentIn: paint.totalAmount,
          kIn: paint.absorptionKSum,
          sIn: paint.scatteringSSum,
          granulationIn: paint.granulationWeight,
          stainingIn: paint.stainingWeight,
        ),
      );

    final dynamics = BrushStrokeDynamics(brush: brush, strokeId: 1, seed: 1);
    final engine = WatercolorEngine(
      simSize: 128,
      params: const WatercolorParams(),
    );

    // Build up one concentrated dab from a single finite brush load. Repeated
    // contact is time-integrated by the receipt and naturally tapers as the
    // reservoir depletes.
    for (var i = 0; i < 36; i++) {
      final sample = InputSample(
        position: const Offset(200, 200),
        pressure: 1.0,
        timestamp: i * 24,
        deviceKind: PointerDeviceKind.stylus,
      );
      final contact = dynamics.evaluate(sample, reservoir: reservoir);
      final payload = adapter.resolve(contact, const WatercolorContactState());
      final pigmentOut = payload.receipt.pigmentOut;
      final inv = pigmentOut > 1e-12 ? 1.0 / pigmentOut : 0.0;
      final actualReceipt = engine.depositContact(
        payload.footprint,
        canvas,
        brush.size,
        kBand: payload.receipt.kOut.map((v) => v * inv).toList(),
        sBand: payload.receipt.sOut.map((v) => v * inv).toList(),
        gran: payload.receipt.granulationOut * inv,
        stain: payload.receipt.stainingOut * inv,
        receipt: payload.receipt,
      );
      reservoir.applyReceipt(actualReceipt);
    }
    // Let the dab flow and settle briefly.
    engine.tick(3);

    final px = engine.compositePixels();
    final s = engine.simSize;

    // Find the most-painted cell.
    var maxLoad = 0.0;
    var mx = 0, my = 0;
    for (var y = 0; y < s; y++) {
      for (var x = 0; x < s; x++) {
        final l =
            engine.field.propsDep[
              engine.field.index(x, y) * WatercolorField.depProps
            ] +
            engine.field.propsSus[engine.field.index(x, y) * 3];
        if (l > maxLoad) {
          maxLoad = l;
          mx = x;
          my = y;
        }
      }
    }
    expect(
      maxLoad,
      greaterThan(0.3),
      reason: 'the dab transferred real pigment through the brush chain',
    );

    int cell(int x, int y) => (y * s + x) * 4;
    final mid = cell(mx, my);
    final r = px[mid], g = px[mid + 1], b = px[mid + 2];

    // Paint appeared: the wash center is clearly not bare paper (~0.96 white).
    expect(
      b < 245 || r < 245,
      isTrue,
      reason: 'the stroke should have deposited paint, darkening the paper',
    );
    // And it reads blue: blue dominates red, and green sits between (phthalo).
    expect(
      b,
      greaterThan(r),
      reason: 'phthalo blue should composite bluer than it is red',
    );
    expect(b, greaterThan(g), reason: 'blue channel should be the strongest');

    // A corner far from the stroke stays paper-white.
    final corner = cell(4, 4);
    expect(
      px[corner + 2],
      greaterThan(240),
      reason: 'untouched paper stays light — the wash is contained',
    );
  });

  test('pigment concentration increases colour load without adding water', () {
    const footprint = [
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 1,
        pressure: 1,
        velocity: Offset.zero,
      ),
    ];
    const canvas = Size(200, 200);
    final normal = WatercolorEngine(simSize: 64)..pigmentConcentration = 1;
    final strong = WatercolorEngine(simSize: 64)..pigmentConcentration = 3;

    void deposit(WatercolorEngine engine) {
      engine.depositContact(
        footprint,
        canvas,
        12,
        kBand: Pigment.phthaloBlue.absorptionK,
        sBand: Pigment.phthaloBlue.scatteringS,
        gran: Pigment.phthaloBlue.granulation,
        stain: Pigment.phthaloBlue.staining,
      );
    }

    deposit(normal);
    deposit(strong);

    expect(strong.field.totalWater(), closeTo(normal.field.totalWater(), 1e-6));
    expect(
      strong.field.totalLoad(),
      closeTo(normal.field.totalLoad() * 3, 1e-4),
    );
  });

  test('pressure separates pigment-rich touch from water-rich push', () {
    const canvas = Size(200, 200);

    WatercolorEngine deposit(double pressure) {
      final engine = WatercolorEngine(simSize: 64);
      engine.depositContact(
        [
          MediumFootprintCluster(
            position: const Offset(100, 100),
            coverage: 1,
            pressure: pressure,
            velocity: const Offset(20, 0),
          ),
        ],
        canvas,
        12,
        kBand: Pigment.phthaloBlue.absorptionK,
        sBand: Pigment.phthaloBlue.scatteringS,
        gran: Pigment.phthaloBlue.granulation,
        stain: Pigment.phthaloBlue.staining,
      );
      return engine;
    }

    final half = deposit(0.5);
    final full = deposit(1.0);
    expect(
      full.field.totalWater() / half.field.totalWater(),
      closeTo(math.pow(2, full.carrierPressureExponent), 0.02),
    );
    expect(
      full.field.totalLoad() / half.field.totalLoad(),
      closeTo(math.pow(2, full.pigmentPressureExponent), 0.02),
    );
    expect(
      half.field.totalLoad() / half.field.totalWater(),
      greaterThan(full.field.totalLoad() / full.field.totalWater()),
    );
    final halfPush = half.field.velU.fold<double>(0.0, (sum, v) => sum + v);
    final fullPush = full.field.velU.fold<double>(0.0, (sum, v) => sum + v);
    expect(
      fullPush / halfPush,
      closeTo(math.pow(2, full.pushPressureExponent), 0.03),
    );
  });

  test('a zero accepted receipt cannot create paint or water', () {
    const footprint = [
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 1,
        pressure: 1,
        velocity: Offset.zero,
        radius: 2,
      ),
    ];
    final engine = WatercolorEngine(simSize: 64);
    engine.depositContact(
      footprint,
      const Size(200, 200),
      12,
      kBand: Pigment.phthaloBlue.absorptionK,
      sBand: Pigment.phthaloBlue.scatteringS,
      gran: Pigment.phthaloBlue.granulation,
      stain: Pigment.phthaloBlue.staining,
      receipt: TransferReceipt(medium: MediumFamily.watercolor),
    );

    expect(engine.field.totalLoad(), 0);
    expect(engine.field.totalWater(), 0);
  });

  test('one accepted receipt deposits the same amount at any bristle radius', () {
    const pigmentAmount = 0.03;
    final receipt = TransferReceipt(
      medium: MediumFamily.watercolor,
      acceptedOutflow: 0.02,
      pigmentOut: pigmentAmount,
      kOut: Pigment.phthaloBlue.absorptionK
          .map((value) => value * pigmentAmount)
          .toList(growable: false),
      sOut: Pigment.phthaloBlue.scatteringS
          .map((value) => value * pigmentAmount)
          .toList(growable: false),
      granulationOut: Pigment.phthaloBlue.granulation * pigmentAmount,
      stainingOut: Pigment.phthaloBlue.staining * pigmentAmount,
    );

    WatercolorEngine deposit(double radius) {
      final engine = WatercolorEngine(simSize: 64);
      engine.depositContact(
        [
          MediumFootprintCluster(
            position: const Offset(100, 100),
            coverage: 1,
            pressure: 1,
            velocity: Offset.zero,
            radius: radius,
          ),
        ],
        const Size(200, 200),
        12,
        kBand: Pigment.phthaloBlue.absorptionK,
        sBand: Pigment.phthaloBlue.scatteringS,
        gran: Pigment.phthaloBlue.granulation,
        stain: Pigment.phthaloBlue.staining,
        receipt: receipt,
      );
      return engine;
    }

    final fineBristle = deposit(2);
    final broadBristle = deposit(18);
    double bandTotal(WatercolorEngine engine, int band, {required bool k}) {
      final mobile = k ? engine.field.ksus : engine.field.ssus;
      final deposited = k ? engine.field.kdep : engine.field.sdep;
      var total = 0.0;
      for (var i = band; i < mobile.length; i += WatercolorField.bands) {
        total += mobile[i] + deposited[i];
      }
      return total;
    }

    double propertyTotal(
      WatercolorEngine engine, {
      required int suspendedChannel,
      required int depositedChannel,
    }) {
      var total = 0.0;
      for (
        var i = suspendedChannel;
        i < engine.field.propsSus.length;
        i += WatercolorField.susProps
      ) {
        total += engine.field.propsSus[i];
      }
      for (
        var i = depositedChannel;
        i < engine.field.propsDep.length;
        i += WatercolorField.depProps
      ) {
        total += engine.field.propsDep[i];
      }
      return total;
    }

    // Tolerance is float32 accumulation noise across very different footprint
    // sizes (thousands of cells summed in different orders), not a physical
    // allowance: 1e-3 on totals of ~260 is still a 4e-6 relative bound.
    expect(
      broadBristle.field.totalLoad(),
      closeTo(fineBristle.field.totalLoad(), 1e-3),
    );
    expect(
      broadBristle.field.totalWater(),
      closeTo(fineBristle.field.totalWater(), 1e-3),
    );
    for (var band = 0; band < WatercolorField.bands; band++) {
      expect(
        bandTotal(broadBristle, band, k: true),
        closeTo(bandTotal(fineBristle, band, k: true), 1e-3),
      );
      expect(
        bandTotal(broadBristle, band, k: false),
        closeTo(bandTotal(fineBristle, band, k: false), 1e-3),
      );
    }
    expect(
      propertyTotal(
        broadBristle,
        suspendedChannel: 1,
        depositedChannel: WatercolorField.depGranulation,
      ),
      closeTo(
        propertyTotal(
          fineBristle,
          suspendedChannel: 1,
          depositedChannel: WatercolorField.depGranulation,
        ),
        1e-5,
      ),
    );
    expect(
      propertyTotal(
        broadBristle,
        suspendedChannel: 2,
        depositedChannel: WatercolorField.depStaining,
      ),
      closeTo(
        propertyTotal(
          fineBristle,
          suspendedChannel: 2,
          depositedChannel: WatercolorField.depStaining,
        ),
        1e-5,
      ),
    );
  });

  test('a live receipt cannot be recoloured by parallel synthetic arguments', () {
    const pigmentAmount = 0.02;
    final receiptK = List<double>.filled(WatercolorField.bands, 0)..[5] = 0.8;
    final receiptS = List<double>.filled(WatercolorField.bands, 0)..[5] = 0.3;
    final engine = WatercolorEngine(simSize: 48);
    engine.depositContact(
      const [
        MediumFootprintCluster(
          position: Offset(100, 100),
          coverage: 1,
          pressure: 1,
          velocity: Offset.zero,
          radius: 10,
        ),
      ],
      const Size(200, 200),
      12,
      // Deliberately contradictory synthetic colour. The accepted receipt
      // must win on the live path.
      kBand: const [1, 0, 0, 0, 0, 0, 0, 0],
      sBand: const [1, 0, 0, 0, 0, 0, 0, 0],
      gran: 0,
      stain: 0,
      receipt: TransferReceipt(
        medium: MediumFamily.watercolor,
        pigmentOut: pigmentAmount,
        kOut: receiptK.map((value) => value * pigmentAmount).toList(),
        sOut: receiptS.map((value) => value * pigmentAmount).toList(),
        granulationOut: pigmentAmount * 0.4,
        stainingOut: pigmentAmount * 0.25,
      ),
    );

    double totalBand(int band) {
      var total = 0.0;
      for (var i = band; i < engine.field.ksus.length; i += 8) {
        total += engine.field.ksus[i] + engine.field.kdep[i];
      }
      return total;
    }

    double totalScatteringBand(int band) {
      var total = 0.0;
      for (var i = band; i < engine.field.ssus.length; i += 8) {
        total += engine.field.ssus[i] + engine.field.sdep[i];
      }
      return total;
    }

    expect(totalBand(5), greaterThan(0));
    expect(totalBand(0), closeTo(0, 1e-8));
    expect(totalScatteringBand(5), greaterThan(0));
    expect(totalScatteringBand(0), closeTo(0, 1e-8));
  });

  test('reversing sibling bristles does not change one physical contact', () {
    const canvas = Size(200, 200);
    final receipt = TransferReceipt(
      medium: MediumFamily.watercolor,
      acceptedOutflow: 0.018,
      pigmentOut: 0.012,
      kOut: List<double>.generate(8, (band) => band == 4 ? 0.012 : 0.0),
      sOut: List<double>.generate(8, (band) => band == 4 ? 0.004 : 0.0),
      granulationOut: 0.003,
      stainingOut: 0.002,
    );
    final clusters = [
      const MediumFootprintCluster(
        position: Offset(96, 100),
        coverage: 0.35,
        pressure: 0.45,
        velocity: Offset(8, 1),
        radius: 7,
      ),
      const MediumFootprintCluster(
        position: Offset(103, 100),
        coverage: 0.9,
        pressure: 0.8,
        velocity: Offset(3, -2),
        radius: 13,
      ),
    ];

    WatercolorEngine paint(List<MediumFootprintCluster> ordered) {
      final engine = WatercolorEngine(simSize: 48);
      for (var y = 20; y <= 28; y++) {
        for (var x = 20; x <= 28; x++) {
          final cell = engine.field.index(x, y);
          engine.field.waterH[cell] = 0.5;
          engine.field.kdep[cell * WatercolorField.bands] = 0.1;
          engine.field.sdep[cell * WatercolorField.bands] = 0.04;
          engine.field.propsDep[cell * WatercolorField.depProps] = 0.1;
        }
      }
      engine.depositContact(
        ordered,
        canvas,
        20,
        kBand: List<double>.filled(8, 0),
        sBand: List<double>.filled(8, 0),
        gran: 0,
        stain: 0,
        receipt: receipt,
      );
      return engine;
    }

    final forward = paint(clusters);
    final reverse = paint(clusters.reversed.toList(growable: false));
    for (var i = 0; i < forward.field.cellCount; i++) {
      expect(
        reverse.field.waterH[i],
        closeTo(forward.field.waterH[i], 2e-5),
      );
      expect(reverse.field.velU[i], closeTo(forward.field.velU[i], 2e-5));
      expect(reverse.field.velV[i], closeTo(forward.field.velV[i], 2e-5));
    }
    for (var i = 0; i < forward.field.ksus.length; i++) {
      expect(reverse.field.ksus[i], closeTo(forward.field.ksus[i], 2e-5));
      expect(reverse.field.kdep[i], closeTo(forward.field.kdep[i], 2e-5));
      expect(reverse.field.ssus[i], closeTo(forward.field.ssus[i], 2e-5));
      expect(reverse.field.sdep[i], closeTo(forward.field.sdep[i], 2e-5));
    }
    for (var i = 0; i < forward.field.propsSus.length; i++) {
      expect(
        reverse.field.propsSus[i],
        closeTo(forward.field.propsSus[i], 2e-5),
      );
    }
    for (var i = 0; i < forward.field.propsDep.length; i++) {
      expect(
        reverse.field.propsDep[i],
        closeTo(forward.field.propsDep[i], 2e-5),
      );
    }
  });

  test('splitting one light touch into force shares preserves pressure', () {
    const canvas = Size(200, 200);
    final receipt = TransferReceipt(
      medium: MediumFamily.watercolor,
      acceptedOutflow: 0.01,
      pigmentOut: 0.008,
      kOut: List<double>.generate(8, (band) => band == 4 ? 0.008 : 0.0),
      sOut: List<double>.generate(8, (band) => band == 4 ? 0.0032 : 0.0),
      granulationOut: 0.0016,
      stainingOut: 0.0016,
    );

    WatercolorEngine paint(List<MediumFootprintCluster> clusters) {
      final engine = WatercolorEngine(simSize: 48);
      final center = engine.field.index(24, 24);
      final kb = center * WatercolorField.bands;
      final pd = center * WatercolorField.depProps;
      engine.field.waterH[center] = 0.2;
      engine.field.kdep[kb] = 0.5;
      engine.field.sdep[kb] = 0.2;
      engine.field.propsDep[pd] = 0.5;
      engine.field.propsDep[pd + WatercolorField.depStaining] = 0.2;
      engine.depositContact(
        clusters,
        canvas,
        20,
        kBand: List<double>.filled(8, 0),
        sBand: List<double>.filled(8, 0),
        gran: 0,
        stain: 0,
        receipt: receipt,
      );
      return engine;
    }

    final one = paint(const [
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 1,
        pressure: 0.25,
        velocity: Offset.zero,
        radius: 10,
      ),
    ]);
    final four = paint(const [
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 0.25,
        pressure: 0.0625,
        velocity: Offset.zero,
        radius: 10,
      ),
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 0.25,
        pressure: 0.0625,
        velocity: Offset.zero,
        radius: 10,
      ),
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 0.25,
        pressure: 0.0625,
        velocity: Offset.zero,
        radius: 10,
      ),
      MediumFootprintCluster(
        position: Offset(100, 100),
        coverage: 0.25,
        pressure: 0.0625,
        velocity: Offset.zero,
        radius: 10,
      ),
    ]);

    for (var i = 0; i < one.field.cellCount; i++) {
      expect(four.field.waterH[i], closeTo(one.field.waterH[i], 2e-5));
    }
    for (var i = 0; i < one.field.ksus.length; i++) {
      expect(four.field.ksus[i], closeTo(one.field.ksus[i], 2e-5));
      expect(four.field.kdep[i], closeTo(one.field.kdep[i], 2e-5));
      expect(four.field.ssus[i], closeTo(one.field.ssus[i], 2e-5));
      expect(four.field.sdep[i], closeTo(one.field.sdep[i], 2e-5));
    }
    for (var i = 0; i < one.field.propsDep.length; i++) {
      expect(
        four.field.propsDep[i],
        closeTo(one.field.propsDep[i], 2e-5),
      );
    }
    for (var i = 0; i < one.field.propsSus.length; i++) {
      expect(
        four.field.propsSus[i],
        closeTo(one.field.propsSus[i], 2e-5),
      );
    }
  });

  test('wet field returns exact picked-up watercolor to the brush', () {
    final engine = WatercolorEngine(simSize: 48);
    const canvas = Size(48, 48);
    final footprint = <MediumFootprintCluster>[
      const MediumFootprintCluster(
        position: Offset(24, 24),
        coverage: 1.0,
        pressure: 1.0,
        velocity: Offset.zero,
        radius: 7.0,
      ),
    ];
    TransferReceipt paintReceipt(Pigment pigment, {
      required double carrierOut,
      required double pigmentOut,
      double carrierRoom = 0.0,
    }) => TransferReceipt(
      medium: MediumFamily.watercolor,
      acceptedOutflow: carrierOut,
      acceptedInflow: carrierRoom,
      pigmentOut: pigmentOut,
      kOut: List<double>.generate(
        8,
        (band) => pigment.absorptionK[band] * pigmentOut,
      ),
      sOut: List<double>.generate(
        8,
        (band) => pigment.scatteringS[band] * pigmentOut,
      ),
      granulationOut: pigment.granulation * pigmentOut,
      stainingOut: pigment.staining * pigmentOut,
    );

    engine.depositContact(
      footprint,
      canvas,
      14,
      kBand: Pigment.phthaloBlue.absorptionK,
      sBand: Pigment.phthaloBlue.scatteringS,
      gran: Pigment.phthaloBlue.granulation,
      stain: Pigment.phthaloBlue.staining,
      receipt: paintReceipt(
        Pigment.phthaloBlue,
        carrierOut: 0.004,
        pigmentOut: 0.004,
      ),
    );
    engine.tick(2);
    final before = engine.field.totalLoad();
    final dragging = <MediumFootprintCluster>[
      const MediumFootprintCluster(
        position: Offset(24, 24),
        coverage: 1.0,
        pressure: 1.0,
        velocity: Offset(30, 0),
        radius: 7.0,
      ),
    ];
    const yellowOut = 0.001;
    final actual = engine.depositContact(
      dragging,
      canvas,
      14,
      kBand: Pigment.hansaYellow.absorptionK,
      sBand: Pigment.hansaYellow.scatteringS,
      gran: Pigment.hansaYellow.granulation,
      stain: Pigment.hansaYellow.staining,
      receipt: paintReceipt(
        Pigment.hansaYellow,
        carrierOut: 0.001,
        pigmentOut: yellowOut,
        carrierRoom: 0.02,
      ),
    );

    expect(actual.acceptedInflow, greaterThan(0.0));
    expect(actual.pigmentIn, greaterThan(0.0));
    expect(
      actual.kIn[2] / actual.pigmentIn,
      closeTo(Pigment.phthaloBlue.absorptionK[2], 1e-4),
      reason: 'the receipt must carry the color that was really on the paper',
    );
    expect(
      engine.field.totalLoad(),
      closeTo(
        before +
            yellowOut * WatercolorEngine.receiptPigmentGain -
            actual.pigmentIn * WatercolorEngine.receiptPigmentGain,
        2e-3,
      ),
      reason: 'pickup and deposit must conserve pigment exactly',
    );
  });

  test('contact pickup never removes protected dry watercolor', () {
    final field = WatercolorField(16);
    final sim = WatercolorSimulation(field: field);
    final cell = field.index(8, 8);
    final pd = cell * WatercolorField.depProps;
    final kb = cell * WatercolorField.bands;
    field.waterH[cell] = 1.0;
    field.propsDep[pd] = 1.0;
    field.propsDry[pd] = 1.0;
    for (var band = 0; band < WatercolorField.bands; band++) {
      final k = Pigment.phthaloBlue.absorptionK[band];
      final s = Pigment.phthaloBlue.scatteringS[band];
      field.kdep[kb + band] = k;
      field.kDry[kb + band] = k;
      field.sdep[kb + band] = s;
      field.sDry[kb + band] = s;
    }
    final beforeK = field.kdep[kb + 2];
    final pickup = sim.pickupContact(
      splats: const [
        WatercolorSplat(
          cx: 8.5,
          cy: 8.5,
          radius: 2.0,
          pressure: 1.0,
          load: 0.0,
          waterAmt: 0.0,
          dragSpeed: 10.0,
        ),
      ],
      maximumCarrier: 0.5,
    );

    expect(pickup.carrier, greaterThan(0.0));
    expect(pickup.pigment, 0.0);
    expect(field.propsDep[pd], 1.0);
    expect(field.kdep[kb + 2], beforeK);
  });

  test('live receipts keep a light touch more pigment-dense', () {
    TransferReceipt receiptAt(
      double pressure, {
      double carrierAcceptance = 1.0,
    }) {
      final brush = Brush.sableRound;
      final paint = PaintMixture.single(Pigment.phthaloBlue);
      final reservoir = BrushReservoir.forBrush(brush)
        ..applyReceipt(
          TransferReceipt(
            medium: MediumFamily.watercolor,
            pigmentIn: paint.totalAmount,
            kIn: paint.absorptionKSum,
            sIn: paint.scatteringSSum,
            granulationIn: paint.granulationWeight,
            stainingIn: paint.stainingWeight,
          ),
        );
      final dynamics = BrushStrokeDynamics(
        brush: brush,
        strokeId: pressure == 0.3 ? 30 : 90,
        seed: 7,
      );
      final contact = dynamics.evaluate(
        InputSample(
          position: const Offset(100, 100),
          pressure: pressure,
          timestamp: 16,
          deviceKind: PointerDeviceKind.stylus,
        ),
        reservoir: reservoir,
      );
      return const WatercolorBrushAdapter()
          .resolve(
            contact,
            WatercolorContactState(carrierAcceptance: carrierAcceptance),
          )
          .receipt;
    }

    final light = receiptAt(0.3);
    final firm = receiptAt(0.9);
    expect(light.acceptedOutflow, greaterThan(0));
    expect(firm.acceptedOutflow, greaterThan(light.acceptedOutflow));
    expect(
      light.pigmentOut / light.acceptedOutflow,
      greaterThan(firm.pigmentOut / firm.acceptedOutflow),
    );

    final drierSetting = receiptAt(0.6, carrierAcceptance: 0.25);
    final wetterSetting = receiptAt(0.6, carrierAcceptance: 1.0);
    expect(
      drierSetting.acceptedOutflow,
      closeTo(wetterSetting.acceptedOutflow * 0.25, 1e-9),
    );
    expect(
      drierSetting.pigmentOut,
      closeTo(wetterSetting.pigmentOut, 1e-9),
      reason: 'wetness changes accepted carrier, not the chosen pigment',
    );
  });
}
