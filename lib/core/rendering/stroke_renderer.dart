import 'dart:math' as math;
import 'dart:ui';

import '../canvas/stroke.dart';
import '../paper/granulation_helper.dart';
import '../paper/paper_texture.dart';
import 'brush_physics_engine.dart';

/// Renders [Stroke] data onto a Flutter [Canvas].
///
/// Completed strokes use persistent bristle contacts produced by the shared
/// Brush engine. This renderer consumes contact state; it contains no
/// deformation or medium-response equations.
class StrokeRenderer {
  /// Fast renderer used while the pointer is moving.
  ///
  /// Keeps painting responsive by drawing a simple pressure-sensitive
  /// stroke preview instead of the full render pipeline on every pointer
  /// move. Closed-form — fully implemented.
  static void renderLivePreview(Canvas canvas, Stroke stroke) {
    if (stroke.isEmpty) return;

    if (stroke.contacts.isNotEmpty) {
      _renderFastStrokeBody(canvas, stroke);
      // Full per-bristle replay grows linearly for the duration of a stroke.
      // Keep only the recent physical contact window live; the completed
      // stroke is rendered in full once and then cached by _CanvasPainter.
      final start = math.max(0, stroke.contacts.length - 48);
      _renderContacts(canvas, stroke, startContact: start);
      return;
    }

    final samples = stroke.samples;
    final color = stroke.isEraser ? stroke.color : stroke.paint.displayColor;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
      ..isAntiAlias = true;

    final brush = stroke.brush;
    final double transparencyFactor = brush.isFlat ? 1.0 : 0.45;

    if (samples.length == 1) {
      final sample = samples.first;
      final pressure = math
          .pow(sample.pressure, brush.pressureCurve)
          .toDouble();
      final contactScale = brush.isFlat
          ? 1.0
          : BrushPhysicsEngine.contactScaleForPressure(brush, sample.pressure);
      final width = brush.size * (0.16 + pressure * 0.84) * contactScale;
      paint
        ..style = PaintingStyle.fill
        ..color = stroke.isEraser
            ? const Color(0x00000000)
            : color.withValues(alpha: brush.opacity * transparencyFactor * 0.4);
      canvas.drawCircle(sample.position, width * 0.5, paint);
      return;
    }

    for (int i = 0; i < samples.length - 1; i++) {
      final a = samples[i];
      final b = samples[i + 1];
      final pressure = ((a.pressure + b.pressure) * 0.5).clamp(0.0, 1.0);
      final curvedPressure = math.pow(pressure, brush.pressureCurve).toDouble();
      final contactScale = brush.isFlat
          ? 1.0
          : BrushPhysicsEngine.contactScaleForPressure(brush, pressure);

      final Color colorA = stroke.isEraser
          ? stroke.color
          : (stroke.samplePaints.length > i
                ? stroke.samplePaints[i].displayColor
                : color);
      final Color colorB = stroke.isEraser
          ? stroke.color
          : (stroke.samplePaints.length > i + 1
                ? stroke.samplePaints[i + 1].displayColor
                : color);
      final Color segmentColor = Color.lerp(colorA, colorB, 0.5) ?? colorA;

      paint
        ..strokeWidth =
            brush.size * (0.16 + curvedPressure * 0.84) * contactScale
        ..color = stroke.isEraser
            ? const Color(0x00000000)
            : segmentColor.withValues(
                alpha:
                    brush.opacity *
                    (0.12 + curvedPressure * 0.18) *
                    transparencyFactor,
              );
      canvas.drawLine(a.position, b.position, paint);
    }
  }

  /// Render a single completed stroke onto the canvas.
  ///
  /// A single pressure-reactive ribbon (see file doc comment for why this
  /// isn't yet the full tuft/bristle engine). Still paper-aware: honors
  /// dry-brush skipping ([PaperTexture.shouldSkipBristle]) and granulation
  /// bias ([GranulationHelper.granulationBias]) when [paperTexture] is
  /// supplied, and honors per-sample pigment color
  /// ([Stroke.samplePaints]) for dirty-brush color variation along a
  /// stroke once that lands (see `CanvasController`).
  static void render(
    Canvas canvas,
    Stroke stroke, {
    PaperTexture? paperTexture,
    Size? canvasSize,
    double paperGranulationSupport = 0.5,
    double paperDryBrushBreakup = 0.5,
  }) {
    if (stroke.isEmpty) return;

    if (stroke.contacts.isNotEmpty) {
      _renderContacts(
        canvas,
        stroke,
        paperTexture: paperTexture,
        canvasSize: canvasSize,
        paperGranulationSupport: paperGranulationSupport,
        paperDryBrushBreakup: paperDryBrushBreakup,
      );
      return;
    }

    final samples = stroke.samples;
    final brush = stroke.brush;
    final renderColor = stroke.isEraser
        ? stroke.color
        : stroke.paint.displayColor;
    final pigmentGranulation = _granulationForStroke(stroke);

    final double cw = canvasSize?.width ?? 0;
    final double ch = canvasSize?.height ?? 0;
    final bool hasPaper = paperTexture != null && cw > 0 && ch > 0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

    if (samples.length == 1) {
      final sample = samples.first;
      final contactScale = BrushPhysicsEngine.contactScaleForPressure(
        brush,
        sample.pressure,
      );
      final width = brush.size * sample.pressureWidth * contactScale;
      paint
        ..style = PaintingStyle.fill
        ..color = stroke.isEraser
            ? const Color(0x00000000)
            : renderColor.withValues(
                alpha: brush.opacity * sample.pressureOpacity,
              );
      canvas.drawCircle(sample.position, width * 0.5, paint);
      return;
    }

    for (int i = 0; i < samples.length - 1; i++) {
      final a = samples[i];
      final b = samples[i + 1];
      final pressure = ((a.pressure + b.pressure) * 0.5).clamp(0.0, 1.0);
      final contactScale = BrushPhysicsEngine.contactScaleForPressure(
        brush,
        pressure,
      );

      double opacityMultiplier = 1.0;
      if (hasPaper) {
        final mid = Offset.lerp(a.position, b.position, 0.5)!;
        final uv = PaperTexture.positionToUV(mid.dx, mid.dy, cw, ch);
        final paperHeight = paperTexture.heightAt(uv[0], uv[1]);

        if (paperTexture.shouldSkipBristle(
          brush.wetness,
          pressure,
          paperHeight,
          paperDryBrushBreakup,
        )) {
          continue;
        }

        opacityMultiplier = GranulationHelper.granulationBias(
          paperHeight,
          pigmentGranulation,
          paperGranulationSupport,
        );
      }

      final Color colorA = stroke.isEraser
          ? stroke.color
          : (stroke.samplePaints.length > i
                ? stroke.samplePaints[i].displayColor
                : renderColor);
      final Color colorB = stroke.isEraser
          ? stroke.color
          : (stroke.samplePaints.length > i + 1
                ? stroke.samplePaints[i + 1].displayColor
                : renderColor);
      final Color segmentColor = Color.lerp(colorA, colorB, 0.5) ?? colorA;

      final double opacity =
          (brush.opacity * (0.5 + pressure * 0.5) * opacityMultiplier).clamp(
            0.0,
            1.0,
          );

      paint
        ..strokeWidth = brush.size * (0.16 + pressure * 0.84) * contactScale
        ..color = stroke.isEraser
            ? const Color(0x00000000)
            : segmentColor.withValues(alpha: opacity);
      canvas.drawLine(a.position, b.position, paint);
    }
  }

  /// Render all strokes in a list.
  static void renderAll(
    Canvas canvas,
    List<Stroke> strokes, {
    PaperTexture? paperTexture,
    Size? canvasSize,
    double paperGranulationSupport = 0.5,
    double paperDryBrushBreakup = 0.5,
  }) {
    for (final stroke in strokes) {
      render(
        canvas,
        stroke,
        paperTexture: paperTexture,
        canvasSize: canvasSize,
        paperGranulationSupport: paperGranulationSupport,
        paperDryBrushBreakup: paperDryBrushBreakup,
      );
    }
  }

  static double _granulationForStroke(Stroke stroke) {
    final portions = stroke.paint.portions;
    if (portions.isEmpty) return 0.3;

    var total = 0.0;
    var weightedGranulation = 0.0;
    for (final portion in portions) {
      final weight = portion.amount * (0.25 + portion.pigment.tintStrength);
      total += weight;
      weightedGranulation += portion.pigment.granulation * weight;
    }

    if (total <= 0.0) return 0.3;
    return (weightedGranulation / total).clamp(0.0, 1.0);
  }

  static void _renderContacts(
    Canvas canvas,
    Stroke stroke, {
    PaperTexture? paperTexture,
    Size? canvasSize,
    double paperGranulationSupport = 0.5,
    double paperDryBrushBreakup = 0.5,
    int startContact = 0,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;
    final hasPaper =
        paperTexture != null &&
        canvasSize != null &&
        canvasSize.width > 0 &&
        canvasSize.height > 0;
    final granulation = _granulationForStroke(stroke);

    for (
      var contactIndex = startContact.clamp(0, stroke.contacts.length);
      contactIndex < stroke.contacts.length;
      contactIndex++
    ) {
      final contact = stroke.contacts[contactIndex];
      final color = stroke.isEraser
          ? const Color(0x00000000)
          : (contactIndex < stroke.samplePaints.length
                ? stroke.samplePaints[contactIndex].displayColor
                : stroke.paint.displayColor);
      for (final cluster in contact.clusters) {
        var opacity =
            stroke.brush.opacity *
            cluster.contact /
            math.sqrt(contact.clusters.length);
        if (hasPaper) {
          final uv = PaperTexture.positionToUV(
            cluster.position.dx,
            cluster.position.dy,
            canvasSize.width,
            canvasSize.height,
          );
          final height = paperTexture.heightAt(uv[0], uv[1]);
          if (paperTexture.shouldSkipBristle(
            stroke.brush.wetness,
            contact.pressure,
            height,
            paperDryBrushBreakup,
          )) {
            continue;
          }
          opacity *= GranulationHelper.granulationBias(
            height,
            granulation,
            paperGranulationSupport,
          );
        }
        paint
          ..strokeWidth = cluster.radius * 2.0
          ..color = stroke.isEraser
              ? const Color(0x00000000)
              : color.withValues(alpha: opacity.clamp(0.0, 1.0));
        if (cluster.position == cluster.previousPosition) {
          canvas.drawCircle(
            cluster.position,
            cluster.radius,
            paint..style = PaintingStyle.fill,
          );
          paint.style = PaintingStyle.stroke;
        } else {
          canvas.drawLine(cluster.previousPosition, cluster.position, paint);
        }
      }
    }
  }

  /// One draw call preserves the whole gesture during live painting while
  /// the detailed bristle tail above shows the current physical response.
  static void _renderFastStrokeBody(Canvas canvas, Stroke stroke) {
    if (stroke.contacts.length < 2) return;
    final path = Path()
      ..moveTo(
        stroke.contacts.first.center.dx,
        stroke.contacts.first.center.dy,
      );
    for (var i = 1; i < stroke.contacts.length; i++) {
      final point = stroke.contacts[i].center;
      path.lineTo(point.dx, point.dy);
    }
    final last = stroke.contacts.last;
    final physicalWidth =
        stroke.brush.size *
        BrushPhysicsEngine.contactScaleForPressure(
          stroke.brush,
          last.pressure,
        ) *
        0.42;
    // This path is only a lightweight continuity guide behind the detailed
    // physical tail. Capping its live width prevents a large brush from
    // repainting a huge pixel area on every pointer event. Full-width bristle
    // contact remains visible in the recent tail and in the completed cache.
    final previewWidth = physicalWidth.clamp(0.5, 6.0).toDouble();
    final color = stroke.isEraser
        ? const Color(0x00000000)
        : stroke.paint.displayColor.withValues(
            alpha: (stroke.brush.opacity * 0.22).clamp(0.0, 1.0),
          );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = previewWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
        ..color = color,
    );
  }
}
