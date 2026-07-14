import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../canvas/input_sample.dart';

/// Event-rate-independent filtering and equal-distance sampling from brush
/// spec §5. All coordinates remain canvas coordinates; [unitsPerMillimeter]
/// is the sole view/device conversion.
class StrokeResampler {
  StrokeResampler({
    this.unitsPerMillimeter = 1.0,
    this.positionTauMs = 6.0,
    this.pressureTauMs = 10.0,
    this.tiltTauMs = 16.0,
  });

  final double unitsPerMillimeter;
  final double positionTauMs;
  final double pressureTauMs;
  final double tiltTauMs;

  InputSample? _filtered;

  void reset() => _filtered = null;

  List<InputSample> add(
    InputSample raw, {
    required double contactRadius,
    double spacingFactor = 0.18,
  }) {
    final previous = _filtered;
    if (previous == null) {
      _filtered = raw;
      return [raw];
    }

    final dtMs = math.max(1, raw.timestamp - previous.timestamp).toDouble();
    double alpha(double tau) => 1.0 - math.exp(-dtMs / tau);

    final position = Offset.lerp(
      previous.position,
      raw.position,
      alpha(positionTauMs),
    )!;
    final filtered = InputSample(
      position: position,
      pressure: _lerp(
        previous.pressure,
        raw.pressure,
        alpha(pressureTauMs),
      ).clamp(0.0, 1.0),
      tilt: _lerp(previous.tilt, raw.tilt, alpha(tiltTauMs)),
      orientation: _lerpAngle(
        previous.orientation,
        raw.orientation,
        alpha(tiltTauMs),
      ),
      timestamp: raw.timestamp,
      deviceKind: raw.deviceKind,
    );
    _filtered = filtered;

    final minSpacing = 0.08 * unitsPerMillimeter;
    final maxSpacing = 0.75 * unitsPerMillimeter;
    final spacing = (spacingFactor * contactRadius)
        .clamp(minSpacing, maxSpacing)
        .toDouble();
    final distance = (filtered.position - previous.position).distance;
    final count = math.max(1, (distance / math.max(spacing, 1e-6)).ceil());
    return List<InputSample>.generate(
      count,
      (index) => previous.lerpTo(filtered, (index + 1) / count),
      growable: false,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _lerpAngle(double a, double b, double t) {
    var delta = (b - a) % (math.pi * 2.0);
    if (delta > math.pi) delta -= math.pi * 2.0;
    return a + delta * t;
  }
}
