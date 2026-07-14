import 'dart:ui';

import 'brush_reservoir.dart';

/// One persistent bristle cluster at a particular contact sample.
class BristleContact {
  const BristleContact({
    required this.id,
    required this.position,
    required this.previousPosition,
    required this.radius,
    required this.contact,
    required this.pressure,
    required this.velocity,
    required this.isSplit,
  });

  final int id;
  final Offset position;
  final Offset previousPosition;
  final double radius;
  final double contact;
  final double pressure;
  final Offset velocity;
  final bool isSplit;
}

/// Stable, medium-agnostic handoff defined by brush spec §9.
class BrushContactSample {
  const BrushContactSample({
    required this.sequenceId,
    required this.strokeId,
    required this.timestamp,
    required this.dtSeconds,
    required this.center,
    required this.previousCenter,
    required this.velocity,
    required this.pressure,
    required this.tilt,
    required this.azimuth,
    required this.compression,
    required this.splay,
    required this.bend,
    required this.bounds,
    required this.clusters,
    required this.normalForce,
    required this.transferOffer,
    required this.reservoir,
  });

  final int sequenceId;
  final int strokeId;
  final int timestamp;
  final double dtSeconds;
  final Offset center;
  final Offset previousCenter;
  final Offset velocity;
  final double pressure;
  final double tilt;
  final double azimuth;
  final double compression;
  final double splay;
  final Offset bend;
  final Rect bounds;
  final List<BristleContact> clusters;
  final double normalForce;
  final TransferOffer transferOffer;
  final BrushReservoirSnapshot reservoir;

  double get totalContact => clusters.fold(0.0, (sum, c) => sum + c.contact);
}
