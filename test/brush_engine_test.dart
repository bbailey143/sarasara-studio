import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_dynamics.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_reservoir.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/brush/stroke_resampler.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';
import 'package:sarasara_studio_01_rev1/core/rendering/brush_physics_engine.dart';
import 'package:sarasara_studio_01_rev1/models/brush.dart';

InputSample sample(
  double x,
  int time, {
  double pressure = 0.5,
  double tilt = 0.0,
  double orientation = 0.0,
}) => InputSample(
  position: Offset(x, 0),
  pressure: pressure,
  tilt: tilt,
  orientation: orientation,
  timestamp: time,
  deviceKind: PointerDeviceKind.stylus,
);

void main() {
  group('input safety and resampling', () {
    test('pressure calibration is finite and clamped', () {
      expect(
        InputSample.normalizePressure(5000, minimum: 0, maximum: 1024),
        1.0,
      );
      expect(InputSample.normalizePressure(-4, minimum: 0, maximum: 1024), 0.0);
      expect(
        InputSample.normalizePressure(double.nan, minimum: 0, maximum: 1),
        0.55,
      );
    });

    test('equal-distance resampling fills fast input without gaps', () {
      final resampler = StrokeResampler();
      expect(resampler.add(sample(0, 0), contactRadius: 4), hasLength(1));
      final emitted = resampler.add(sample(20, 16), contactRadius: 4);
      expect(emitted.length, greaterThan(20));
      expect(emitted.last.position.dx, closeTo(18.61, 0.1));
    });
  });

  group('physical contact', () {
    test('round grows smoothly from point to belly', () {
      final toe = BrushPhysicsEngine.contactScaleForPressure(
        Brush.sableRound,
        0.02,
      );
      final middle = BrushPhysicsEngine.contactScaleForPressure(
        Brush.sableRound,
        0.5,
      );
      final belly = BrushPhysicsEngine.contactScaleForPressure(
        Brush.sableRound,
        1.0,
      );
      expect(toe, lessThan(middle));
      expect(middle, lessThan(belly));
    });

    test('cluster layout is deterministic and shipping-sized', () {
      final a = BrushPhysicsEngine.generateClusterOffsets(Brush.sableRound, 42);
      final b = BrushPhysicsEngine.generateClusterOffsets(Brush.sableRound, 42);
      expect(a, b);
      expect(a.length, inInclusiveRange(16, 64));
    });

    test('normal force is conserved across clusters', () {
      final dynamics = BrushStrokeDynamics(
        brush: Brush.sableRound,
        strokeId: 1,
        seed: 7,
      );
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      final contact = dynamics.evaluate(
        sample(0, 0, pressure: 0.8),
        reservoir: reservoir,
      );
      final distributed = contact.clusters.fold<double>(
        0,
        (sum, cluster) => sum + cluster.pressure,
      );
      expect(distributed, closeTo(contact.normalForce, 1e-9));
      expect(
        contact.clusters.every((c) => c.contact >= 0 && c.contact <= 1),
        isTrue,
      );
    });

    test('same brush and gesture produce identical contact geometry', () {
      List<Offset> replay() {
        final dynamics = BrushStrokeDynamics(
          brush: Brush.sableRound,
          strokeId: 8,
          seed: 99,
        );
        final reservoir = BrushReservoir.forBrush(Brush.sableRound);
        dynamics.evaluate(sample(0, 0, pressure: 0.2), reservoir: reservoir);
        return dynamics
            .evaluate(sample(10, 16, pressure: 0.8), reservoir: reservoir)
            .clusters
            .map((c) => c.position)
            .toList();
      }

      expect(replay(), replay());
    });

    test('stationary dwell advances compression without inventing motion', () {
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      final dynamics = BrushStrokeDynamics(
        brush: Brush.sableRound,
        strokeId: 9,
        seed: 3,
      );
      final first = dynamics.evaluate(
        sample(2, 0, pressure: 0.8),
        reservoir: reservoir,
      );
      final dwell = dynamics.evaluate(
        sample(2, 17, pressure: 0.8),
        reservoir: reservoir,
      );
      expect(dwell.velocity, Offset.zero);
      expect(dwell.compression, greaterThan(first.compression));
    });

    test('high paper tooth reduces light cluster contact', () {
      BrushContactSampleWithTotal evaluate(double height) {
        final reservoir = BrushReservoir.forBrush(Brush.sableRound);
        final dynamics = BrushStrokeDynamics(
          brush: Brush.sableRound,
          strokeId: 11,
          seed: 5,
        );
        final contact = dynamics.evaluate(
          sample(0, 0, pressure: 0.15),
          reservoir: reservoir,
          surfaceHeight: (_) => height,
        );
        return BrushContactSampleWithTotal(contact.totalContact);
      }

      expect(evaluate(1).total, lessThan(evaluate(0).total));
    });

    test('tilting a round stretches contact along the tilt axis', () {
      double widthFor(double tilt) {
        final reservoir = BrushReservoir.forBrush(Brush.sableRound);
        final dynamics = BrushStrokeDynamics(
          brush: Brush.sableRound,
          strokeId: 15,
          seed: 8,
        );
        final contact = dynamics.evaluate(
          sample(0, 0, pressure: 0.5, tilt: tilt),
          reservoir: reservoir,
        );
        return contact.bounds.width;
      }

      expect(widthFor(1.2), greaterThan(widthFor(0)));
    });
  });

  group('reservoir receipts', () {
    test('cannot release more carrier than the brush holds', () {
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      final before = reservoir.totalVolume;
      reservoir.applyReceipt(
        TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedOutflow: before * 10,
        ),
      );
      expect(reservoir.totalVolume, 0);
    });

    test('spectral receipt updates extensive quantities exactly', () {
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      reservoir.applyReceipt(
        TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedInflow: 0.05,
          pigmentIn: 0.2,
          kIn: List<double>.filled(8, 0.3),
          sIn: List<double>.filled(8, 0.4),
          granulationIn: 0.1,
          stainingIn: 0.15,
        ),
      );
      expect(reservoir.pigmentLoad, 0.2);
      expect(reservoir.kSum, everyElement(0.3));
      expect(reservoir.sSum, everyElement(0.4));
      expect(reservoir.granulationWeight, 0.1);
      expect(reservoir.stainingWeight, 0.15);
    });

    test('release opportunity falls as the brush depletes', () {
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      final first = reservoir.offer(
        contact: 1,
        dtSeconds: 0.1,
        brush: Brush.sableRound,
      );
      reservoir.applyReceipt(
        TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedOutflow: reservoir.totalVolume * 0.7,
        ),
      );
      final later = reservoir.offer(
        contact: 1,
        dtSeconds: 0.1,
        brush: Brush.sableRound,
      );
      expect(later.maximumOutflow, lessThan(first.maximumOutflow));
    });

    test('accepted spectral pickup and deposit conserve a round trip', () {
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      final initialVolume = reservoir.totalVolume;
      reservoir.applyReceipt(
        TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedInflow: 0.05,
          pigmentIn: 0.1,
          kIn: List<double>.filled(8, 0.2),
          sIn: List<double>.filled(8, 0.3),
        ),
      );
      reservoir.applyReceipt(
        TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedOutflow: 0.05,
          pigmentOut: 0.1,
          kOut: List<double>.filled(8, 0.2),
          sOut: List<double>.filled(8, 0.3),
        ),
      );
      expect(reservoir.totalVolume, closeTo(initialVolume, 1e-9));
      expect(reservoir.pigmentLoad, 0);
      expect(reservoir.kSum, everyElement(0));
      expect(reservoir.sSum, everyElement(0));
    });

    test('incompatible medium cannot be silently loaded', () {
      final reservoir = BrushReservoir.forBrush(Brush.sableRound);
      expect(
        () => reservoir.applyReceipt(TransferReceipt(medium: MediumFamily.oil)),
        throwsStateError,
      );
    });
  });

  test('watercolor and oil consume identical geometry differently', () {
    final reservoir = BrushReservoir.forBrush(Brush.sableRound);
    final dynamics = BrushStrokeDynamics(
      brush: Brush.sableRound,
      strokeId: 4,
      seed: 12,
    );
    final contact = dynamics.evaluate(
      sample(4, 16, pressure: 0.7),
      reservoir: reservoir,
    );
    final watercolor = const WatercolorBrushAdapter().resolve(
      contact,
      const WatercolorContactState(dragCoupling: 0.1),
    );
    reservoir.medium = MediumFamily.oil;
    final oil = const OilBrushAdapter().resolve(
      contact,
      const OilContactState(coupling: 0.8),
    );
    expect(watercolor.footprint.length, oil.footprint.length);
    expect(watercolor.footprint.first.position, oil.footprint.first.position);
    expect(watercolor.footprint.first.radius, contact.clusters.first.radius);
    expect(oil.footprint.first.radius, contact.clusters.first.radius);
    expect(
      watercolor.footprint.first.velocity.distance,
      lessThan(oil.footprint.first.velocity.distance),
    );
  });
}

class BrushContactSampleWithTotal {
  const BrushContactSampleWithTotal(this.total);
  final double total;
}
