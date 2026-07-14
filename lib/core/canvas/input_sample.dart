import 'dart:math' as math;

import 'package:flutter/gestures.dart';

/// A single point of input captured during a stroke.
///
/// Stores raw position, pressure, tilt, and timing data from the
/// pointer/stylus device. This is the atomic unit of stroke input.
///
/// Pressure and tilt data may not be available on all devices.
/// Defaults provide a natural-feeling fallback.
class InputSample {
  /// Canvas-space position of the pointer.
  final Offset position;

  /// Pressure from 0.0 (no contact) to 1.0 (full pressure).
  /// Defaults to 0.5 for devices that don't report pressure.
  final double pressure;

  /// Tilt angle of the stylus from perpendicular, in radians.
  /// 0.0 = perpendicular to surface. Larger = more tilted.
  final double tilt;

  /// Rotation of the stylus around the axis perpendicular to the surface,
  /// in radians. Combined with [tilt] to derive directional tilt.
  final double orientation;

  /// Timestamp in milliseconds since app start.
  final int timestamp;

  /// The type of pointer device.
  final PointerDeviceKind deviceKind;

  const InputSample({
    required this.position,
    this.pressure = 0.5,
    this.tilt = 0.0,
    this.orientation = 0.0,
    required this.timestamp,
    this.deviceKind = PointerDeviceKind.unknown,
  });

  /// Create an [InputSample] from a Flutter [PointerEvent].
  ///
  /// Handles the case where pressure is reported as 0.0 (device doesn't
  /// support pressure) by defaulting to 0.5 for a natural feel.
  factory InputSample.fromPointerEvent(PointerEvent event) {
    final supportsPressure =
        event.pressureMax > event.pressureMin &&
        event.kind != PointerDeviceKind.mouse;
    final effectivePressure = supportsPressure
        ? normalizePressure(
            event.pressure,
            minimum: event.pressureMin,
            maximum: event.pressureMax,
          )
        : 0.55;

    return InputSample(
      position: event.localPosition,
      pressure: effectivePressure,
      tilt: event.tilt.isFinite
          ? event.tilt.clamp(0.0, 1.5707963267948966)
          : 0.0,
      orientation: event.orientation.isFinite ? event.orientation : 0.0,
      timestamp: event.timeStamp.inMilliseconds,
      deviceKind: event.kind,
    );
  }

  /// Device-safe pressure calibration from brush spec §5.1.
  static double normalizePressure(
    double raw, {
    required double minimum,
    required double maximum,
    double deadZone = 0.015,
    double curve = 1.35,
  }) {
    if (!raw.isFinite ||
        !minimum.isFinite ||
        !maximum.isFinite ||
        maximum <= minimum) {
      return 0.55;
    }
    final p0 = ((raw - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
    final p1 = ((p0 - deadZone) / (1.0 - deadZone)).clamp(0.0, 1.0);
    return _pow(p1, curve).clamp(0.0, 1.0);
  }

  static double _pow(double value, double exponent) {
    if (value <= 0.0) return 0.0;
    return math.exp(math.log(value) * exponent);
  }

  /// The effective brush width multiplier based on pressure.
  ///
  /// Maps pressure [0..1] to a width factor [0.15..1.0] so that
  /// even the lightest touch still leaves a visible mark.
  double get pressureWidth => 0.15 + pressure * 0.85;

  /// The effective opacity multiplier based on pressure.
  ///
  /// Maps pressure [0..1] to an opacity factor [0.3..1.0].
  double get pressureOpacity => 0.3 + pressure * 0.7;

  /// Linearly interpolate between this sample and [other].
  InputSample lerpTo(InputSample other, double t) {
    return InputSample(
      position: Offset.lerp(position, other.position, t)!,
      pressure: pressure + (other.pressure - pressure) * t,
      tilt: tilt + (other.tilt - tilt) * t,
      orientation: orientation + (other.orientation - orientation) * t,
      timestamp: (timestamp + (other.timestamp - timestamp) * t).round(),
      deviceKind: deviceKind,
    );
  }

  /// The velocity to the next sample, in logical pixels per millisecond.
  /// Returns 0.0 if timestamps are identical.
  double velocityTo(InputSample next) {
    final dt = (next.timestamp - timestamp).abs();
    if (dt == 0) return 0.0;
    return (next.position - position).distance / dt;
  }
}
