import 'dart:ui';

import '../../models/brush.dart';
import '../brush/brush_contact.dart';
import '../brush/brush_reservoir.dart';
import '../pigment/paint_mixture.dart';
import 'input_sample.dart';

/// A complete or in-progress brush stroke.
///
/// Contains the raw input samples captured during drawing, plus a snapshot
/// of the brush settings that were active when the stroke began.
///
/// During active drawing, samples are added mutably via [addSample].
/// Once added to the completed strokes list, the stroke should be
/// treated as immutable.
class Stroke {
  /// Raw input samples captured during this stroke.
  final List<InputSample> samples;

  /// The dynamic pigment mixtures corresponding to each sample (for dirty brush smudging).
  final List<PaintMixture> samplePaints;

  /// Medium-agnostic physical contacts corresponding to resampled input.
  final List<BrushContactSample> contacts;

  /// The brush configuration snapshot when the stroke started.
  final Brush brush;

  /// Stroke color.
  final Color color;

  /// Pigment recipe carried by this stroke when it began.
  final PaintMixture paint;

  /// Whether this stroke erases instead of painting.
  final bool isEraser;

  /// Which medium this stroke fed. Undo/redo fallbacks replay a stroke only
  /// into its own medium's simulation.
  final MediumFamily medium;

  /// Unique seed for deterministic random generation of bristle offsets.
  final int seed;

  Stroke({
    List<InputSample>? samples,
    List<PaintMixture>? samplePaints,
    List<BrushContactSample>? contacts,
    required this.brush,
    required this.color,
    PaintMixture? paint,
    this.isEraser = false,
    this.medium = MediumFamily.watercolor,
    int? seed,
  }) : samples = samples ?? [],
       samplePaints = samplePaints ?? [],
       contacts = contacts ?? [],
       paint = paint ?? PaintMixture.customColor(color),
       seed = seed ?? DateTime.now().microsecondsSinceEpoch;

  /// Brush size at full pressure. Provided for backward compatibility.
  double get brushSize => brush.size;

  /// Stroke opacity. Provided for backward compatibility.
  double get opacity => brush.opacity;

  /// Add a new input sample to this stroke, optionally specifying its paint mixture.
  ///
  /// Only call during active drawing. Completed strokes should not
  /// be modified.
  void addSample(
    InputSample sample, [
    PaintMixture? samplePaint,
    BrushContactSample? contact,
  ]) {
    samples.add(sample);
    samplePaints.add(samplePaint ?? paint);
    if (contact != null) contacts.add(contact);
  }

  /// Whether this stroke has no samples.
  bool get isEmpty => samples.isEmpty;

  /// Whether this stroke has at least one sample.
  bool get isNotEmpty => samples.isNotEmpty;

  /// The bounding rectangle of all samples in this stroke.
  ///
  /// Returns [Rect.zero] if the stroke is empty.
  Rect get bounds {
    if (samples.isEmpty) return Rect.zero;

    double minX = samples.first.position.dx;
    double maxX = minX;
    double minY = samples.first.position.dy;
    double maxY = minY;

    for (final sample in samples) {
      final x = sample.position.dx;
      final y = sample.position.dy;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // Expand by brush size to account for stroke width.
    final expand = brushSize;
    return Rect.fromLTRB(
      minX - expand,
      minY - expand,
      maxX + expand,
      maxY + expand,
    );
  }
}
