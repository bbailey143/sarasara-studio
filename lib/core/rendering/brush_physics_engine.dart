import 'dart:math' as math;
import 'dart:ui';

import '../../models/brush.dart';

/// Output of a brush footprint stress & splitting calculation.
class BrushDeformation {
  final List<Offset> deformedOffsets;
  final double averageStress;
  final double maxStress;
  final bool isSplit;

  BrushDeformation({
    required this.deformedOffsets,
    required this.averageStress,
    required this.maxStress,
    required this.isSplit,
  });
}

/// Natural-hair brush physics: pressure-driven footprint, directional
/// bending, stress-driven splitting, and friction kinking.
///
/// This is the single source of truth for how a brush's bristle footprint
/// deforms under motion, pressure, and paint load. [StrokeRenderer] must
/// obtain deformed offsets by calling [computeDeformation] — it must never
/// recompute stress/split math inline itself. That duplication was a real
/// bug in the prior implementation (stress/split math copy-pasted between
/// the two files, only one copy ever exercised in production); see
/// ARCHITECTURE.md "Known Architectural Decisions" for the full story.
class BrushPhysicsEngine {
  const BrushPhysicsEngine._();

  /// Maps pressure into the visible contact footprint for a brush.
  ///
  /// Round watercolor brushes touch with the toe at light pressure, then
  /// open into the belly as pressure rises. Flat brushes keep their
  /// broader footprint and spread outward under pressure.
  static double contactScaleForPressure(Brush brush, double pressure) {
    final curvedPressure = math
        .pow(pressure.clamp(0.0, 1.0), brush.pressureCurve)
        .toDouble();

    if (brush.isFlat) {
      return 1.0 + curvedPressure * brush.softness * 1.5;
    }

    final easedPressure = 1.0 - math.pow(1.0 - curvedPressure, 3.0);
    final toeScale = 0.16 + (1.0 - brush.softness) * 0.04;
    final bellyScale = 1.0 + brush.softness * 0.55;
    return toeScale + (bellyScale - toeScale) * easedPressure;
  }

  /// Computes the 2D skeleton path of the brush head from attachment to
  /// contact, as a cubic Bezier curve (4 control points).
  ///
  /// The middle controls lag opposite travel and lean along stylus tilt.
  static List<Offset> computeSkeleton({
    required Offset handlePos,
    required Offset tipPos,
    required Offset moveDirection,
    required double speed,
    required double pressure,
    required double tilt,
    required double orientation,
    required Brush brush,
  }) {
    final direction = _normalized(moveDirection);
    final tiltDirection = Offset(math.cos(orientation), math.sin(orientation));
    final drag =
        direction *
        (-brush.bristleLength *
            (1.0 - brush.rigidity) *
            (1.0 - math.exp(-speed * 0.025)) *
            (0.3 + pressure * 0.7));
    final lean =
        tiltDirection *
        (brush.bristleLength * math.sin(tilt.clamp(0.0, math.pi / 2.0)) * 0.35);
    final axis = tipPos - handlePos;
    final Offset p0 = handlePos;
    final Offset p3 = tipPos;
    final Offset p1 = p0 + axis * 0.35 + lean * 0.25;
    final Offset p2 = p0 + axis * 0.72 + drag + lean;
    return [p0, p1, p2, p3];
  }

  /// Evaluates a cubic Bezier curve at parameter [t] (0.0 to 1.0).
  ///
  /// Closed-form — fully implemented.
  static Offset evaluateBezier(List<Offset> points, double t) {
    if (points.length < 4) return Offset.zero;
    final double mt = 1.0 - t;
    final double mt2 = mt * mt;
    final double mt3 = mt2 * mt;
    final double t2 = t * t;
    final double t3 = t2 * t;

    return points[0] * mt3 +
        points[1] * (3.0 * mt2 * t) +
        points[2] * (3.0 * mt * t2) +
        points[3] * t3;
  }

  /// Computes each bristle's deformed offset from its steady-state rest
  /// offset, given the brush's current rotation and pressure.
  ///
  /// [steadyOffsets]: brush-local, UNROTATED bristle rest positions
  ///   (tuft/bristle layout is a brush-*shape* concern owned by the
  ///   caller — [StrokeRenderer] generates these from [Brush.tufts]/
  ///   [Brush.bristleCount]; this engine only handles motion/pressure).
  /// [rotationAngle]: world-space radians to orient the head along
  ///   travel — typically `atan2(moveDirection.dy, moveDirection.dx)`,
  ///   with an added `pi/2` for flat brushes, which paint edge-on. This
  ///   engine owns rotation so callers never need their own rotated copy
  ///   of contact-scaled offsets.
  ///
  static BrushDeformation computeDeformation({
    required List<Offset> steadyOffsets,
    required double rotationAngle,
    required Offset moveDirection,
    required double pressure,
    required Brush brush,
    required double paintRemaining,
    double tilt = 0.0,
    double tiltOrientation = 0.0,
  }) {
    if (steadyOffsets.isEmpty) {
      return BrushDeformation(
        deformedOffsets: [],
        averageStress: 0.0,
        maxStress: 0.0,
        isSplit: false,
      );
    }

    final double contactScale = contactScaleForPressure(brush, pressure);
    final double cosA = math.cos(rotationAngle);
    final double sinA = math.sin(rotationAngle);

    final direction = _normalized(moveDirection);
    final normal = Offset(-direction.dy, direction.dx);
    final dryness = (1.0 - paintRemaining.clamp(0.0, 1.0));
    final shear = direction.distance == 0.0
        ? 0.0
        : (brush.frictionCoef * (1.0 - brush.rigidity));
    final splay =
        (pressure.clamp(0.0, 1.0) * brush.maxSplay +
                shear * 0.35 -
                brush.cohesion * paintRemaining * 0.2)
            .clamp(0.0, brush.maxSplay);
    final splitDrive = (splay + dryness * brush.roughness).clamp(0.0, 2.0);
    final split = splitDrive > brush.splitThreshold;
    var stressSum = 0.0;
    var maxStress = 0.0;

    final deformed = steadyOffsets.asMap().entries.map((entry) {
      final s = entry.value;
      final double rx = s.dx * cosA - s.dy * sinA;
      final double ry = s.dx * sinA + s.dy * cosA;
      var radial = Offset(rx, ry);
      final tiltAxis = Offset(
        math.cos(tiltOrientation),
        math.sin(tiltOrientation),
      );
      final alongTilt = radial.dx * tiltAxis.dx + radial.dy * tiltAxis.dy;
      final tiltStretch = math.sin(tilt.clamp(0.0, math.pi / 2.0)) * 0.85;
      radial += tiltAxis * alongTilt * tiltStretch;
      final localStress =
          (radial.distance / math.max(brush.bundleRadius, 1e-6) * splay).clamp(
            0.0,
            2.0,
          );
      stressSum += localStress;
      maxStress = math.max(maxStress, localStress);
      var result = radial * (contactScale * (1.0 + splay * 0.45));
      result += direction * (-shear * brush.bristleLength * 0.08);
      if (split) {
        final side = entry.key.isEven ? -1.0 : 1.0;
        result +=
            normal *
            side *
            brush.bundleRadius *
            (splitDrive - brush.splitThreshold) *
            0.35;
      }
      return result;
    }).toList();

    return BrushDeformation(
      deformedOffsets: deformed,
      averageStress: stressSum / steadyOffsets.length,
      maxStress: maxStress,
      isSplit: split,
    );
  }

  /// Calculates a kinked position on sharp turns, simulating bristle
  /// catching/friction against the paper.
  ///
  /// Closed-form — fully implemented.
  static Offset applyFrictionKinking({
    required Offset currentPos,
    required Offset previousPos,
    required Offset previousDirection,
    required Offset currentDirection,
    required double frictionCoef,
    required double speed,
  }) {
    if (previousDirection.dx * previousDirection.dx +
                previousDirection.dy * previousDirection.dy <
            0.01 ||
        currentDirection.dx * currentDirection.dx +
                currentDirection.dy * currentDirection.dy <
            0.01) {
      return currentPos;
    }

    final double dot =
        previousDirection.dx * currentDirection.dx +
        previousDirection.dy * currentDirection.dy;
    final double angle = math.acos(dot.clamp(-1.0, 1.0));

    // Turn is sharp: apply circular arc kinking offset.
    if (angle > math.pi / 4.0) {
      final double kinkStrength =
          frictionCoef *
          (angle / math.pi) *
          (1.0 / (speed * 0.08 + 1.0)).clamp(0.1, 1.0);
      final Offset normal = Offset(-currentDirection.dy, currentDirection.dx);
      return currentPos + normal * (kinkStrength * brushScale(frictionCoef));
    }

    return currentPos;
  }

  static double brushScale(double coeff) {
    return 12.0 * coeff;
  }

  /// Stable cluster rest layout. Randomness is derived only from [seed].
  static List<Offset> generateClusterOffsets(Brush brush, int seed) {
    final count = (brush.tufts * brush.bristleCount).clamp(16, 64);
    final random = math.Random(seed);
    return List<Offset>.generate(count, (index) {
      final t = (index + 0.5) / count;
      if (brush.isFlat) {
        final x = (t * 2.0 - 1.0) * brush.bundleRadius;
        final y =
            (random.nextDouble() - 0.5) *
            brush.bundleRadius *
            (0.2 + brush.bristleScatter);
        return Offset(x, y);
      }
      final radius = math.sqrt(t) * brush.bundleRadius;
      final angle =
          index * 2.399963229728653 +
          (random.nextDouble() - 0.5) * brush.bristleScatter;
      return Offset(math.cos(angle), math.sin(angle)) * radius;
    }, growable: false);
  }

  static Offset _normalized(Offset value) {
    final length = value.distance;
    return length <= 1e-9 ? Offset.zero : value / length;
  }
}
