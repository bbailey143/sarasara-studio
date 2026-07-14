import 'dart:math' as math;
import 'dart:ui';

import '../../models/brush.dart';
import '../canvas/input_sample.dart';
import '../rendering/brush_physics_engine.dart';
import 'brush_contact.dart';
import 'brush_reservoir.dart';

/// Stateful spring response for one stroke. It converts normalized samples
/// into the stable medium-agnostic contact contract.
class BrushStrokeDynamics {
  BrushStrokeDynamics({
    required this.brush,
    required this.strokeId,
    required this.seed,
  }) : _restOffsets = BrushPhysicsEngine.generateClusterOffsets(brush, seed),
       _lagOffsets = List<Offset>.filled(
         (brush.tufts * brush.bristleCount).clamp(16, 64),
         Offset.zero,
       );

  final Brush brush;
  final int strokeId;
  final int seed;
  final List<Offset> _restOffsets;
  final List<Offset> _lagOffsets;
  InputSample? _previous;
  Offset _bend = Offset.zero;
  Offset _bendVelocity = Offset.zero;
  double _compression = 0.0;
  double _splay = 0.0;
  bool _splitLatched = false;
  int _sequence = 0;

  BrushContactSample evaluate(
    InputSample sample, {
    required BrushReservoir reservoir,
    double Function(Offset position)? surfaceHeight,
  }) {
    final reservoirFill = reservoir.fill;
    final previous = _previous ?? sample;
    final dt = ((sample.timestamp - previous.timestamp) / 1000.0)
        .clamp(1 / 1000, 1 / 30)
        .toDouble();
    final delta = sample.position - previous.position;
    final velocity = delta / dt;
    final speed = velocity.distance;
    final direction = speed <= 1e-6 ? Offset.zero : velocity / speed;
    final pressure = sample.pressure.clamp(0.0, 1.0);

    final qTarget = math.pow(pressure, 1.2).toDouble();
    _compression += (1.0 - math.exp(-dt / 0.018)) * (qTarget - _compression);
    final splayTarget =
        (_compression * 0.72 +
                speed * brush.frictionCoef * 0.0008 -
                brush.rigidity * 0.15 -
                brush.cohesion * reservoirFill * 0.12)
            .clamp(0.0, brush.maxSplay);
    _splay += (1.0 - math.exp(-dt / 0.035)) * (splayTarget - _splay);

    final dragForce =
        direction *
        (-speed * brush.frictionCoef * (1.0 - brush.rigidity) * 0.008);
    final springK = 20.0 + brush.spring * 90.0;
    final damping = 5.0 + brush.damping * 22.0;
    _bendVelocity +=
        (dragForce - _bend * springK - _bendVelocity * damping) * dt;
    _bend += _bendVelocity * dt;
    final maxBend = brush.bristleLength * (1.0 - brush.rigidity) * 0.55;
    if (_bend.distance > maxBend && maxBend > 0.0) {
      _bend = _bend / _bend.distance * maxBend;
    }

    // A flat/filbert/bright/fan has a real wide axis set by the handle/barrel.
    // It must not rotate itself to face every direction of travel: moving
    // along that axis gives a narrow edge stroke, while crossing it sweeps the
    // broad face. Radial rounds may follow travel without changing width.
    final keepsBarrelOrientation =
        brush.isFlat ||
        brush.family == BrushFamily.filbert ||
        brush.family == BrushFamily.fan ||
        brush.family == BrushFamily.bright;
    final angle = keepsBarrelOrientation || direction == Offset.zero
        ? sample.orientation
        : math.atan2(direction.dy, direction.dx);
    final deformation = BrushPhysicsEngine.computeDeformation(
      steadyOffsets: _restOffsets,
      rotationAngle: angle,
      moveDirection: direction,
      pressure: pressure,
      brush: brush,
      paintRemaining: reservoirFill,
      tilt: sample.tilt,
      tiltOrientation: sample.orientation,
    );
    if (deformation.isSplit) {
      _splitLatched = true;
    } else if (_splitLatched &&
        deformation.maxStress < brush.splitThreshold * 0.45 &&
        _splay < brush.maxSplay * 0.22) {
      _splitLatched = false;
    }
    final splitNormal = Offset(-math.sin(angle), math.cos(angle));
    final contacts = <BristleContact>[];
    Rect? bounds;
    var pressureWeight = 0.0;
    for (var i = 0; i < deformation.deformedOffsets.length; i++) {
      var target = deformation.deformedOffsets[i] + _bend;
      if (_splitLatched && !deformation.isSplit) {
        target +=
            splitNormal * (i.isEven ? -1.0 : 1.0) * brush.bundleRadius * 0.08;
      }
      final response = 1.0 - math.exp(-dt * (18.0 + brush.spring * 42.0));
      final oldLag = _lagOffsets[i];
      final lag = Offset.lerp(oldLag, target, response)!;
      _lagOffsets[i] = lag;
      final baseContact = (0.12 + _compression * 0.88).clamp(0.0, 1.0);
      final radius = math.max(
        0.18,
        brush.bundleRadius / math.sqrt(_restOffsets.length),
      );
      final position = sample.position + lag;
      final height = surfaceHeight?.call(position).clamp(0.0, 1.0) ?? 0.0;
      final textureReach = (0.22 + pressure * 0.78 + brush.softness * 0.15)
          .clamp(0.0, 1.0);
      final contact = (baseContact * (1.0 - height * (1.0 - textureReach)))
          .clamp(0.0, 1.0);
      final previousPosition = previous.position + oldLag;
      final rect = Rect.fromCircle(center: position, radius: radius);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
      pressureWeight += contact;
      contacts.add(
        BristleContact(
          id: i,
          position: position,
          previousPosition: previousPosition,
          radius: radius,
          contact: contact,
          pressure: 0.0,
          velocity: (position - previousPosition) / dt,
          isSplit: _splitLatched,
        ),
      );
    }

    final normalForce = pressure;
    final normalizedContacts = contacts
        .map(
          (c) => BristleContact(
            id: c.id,
            position: c.position,
            previousPosition: c.previousPosition,
            radius: c.radius,
            contact: c.contact,
            pressure: pressureWeight <= 0
                ? 0
                : normalForce * c.contact / pressureWeight,
            velocity: c.velocity,
            isSplit: c.isSplit,
          ),
        )
        .toList(growable: false);
    _previous = sample;
    return BrushContactSample(
      sequenceId: _sequence++,
      strokeId: strokeId,
      timestamp: sample.timestamp,
      dtSeconds: dt,
      center: sample.position,
      previousCenter: previous.position,
      velocity: velocity,
      pressure: pressure,
      tilt: sample.tilt,
      azimuth: sample.orientation,
      compression: _compression,
      splay: _splay,
      bend: _bend,
      bounds: bounds ?? Rect.fromCircle(center: sample.position, radius: 0.5),
      clusters: normalizedContacts,
      normalForce: normalForce,
      transferOffer: reservoir.offer(
        contact:
            normalizedContacts.fold(0.0, (sum, c) => sum + c.contact) /
            math.max(normalizedContacts.length, 1),
        dtSeconds: dt,
        brush: brush,
      ),
      reservoir: BrushReservoirSnapshot.from(reservoir),
    );
  }
}
