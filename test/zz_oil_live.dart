import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/canvas_controller.dart';
import 'package:sarasara_studio_01_rev1/core/canvas/input_sample.dart';
import 'package:sarasara_studio_01_rev1/core/pigment/paint_mixture.dart';
import 'package:sarasara_studio_01_rev1/core/rendering/rgba_pixels.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// Live-path visual harness: strokes travel the exact controller route the
/// stylus uses (resampler → brush dynamics → adapter → engine → receipts),
/// so this frame shows what the user will actually see. Inspect by eye.
const _outDir =
    r'C:\Users\benja\AppData\Local\Temp\claude\d--sarasara-studio-01-rev1\dc74e3ca-de1d-4e2a-b978-2a2511141e55\scratchpad\oil_frames';

void _stroke(
  CanvasController c,
  double x0,
  double y0,
  double x1,
  double y1, {
  double pressure = 0.8,
}) {
  InputSample point(double x, double y, int t) => InputSample(
    position: Offset(x, y),
    pressure: pressure,
    timestamp: t,
    deviceKind: PointerDeviceKind.stylus,
  );
  c.beginStroke(point(x0, y0, 0));
  for (var i = 1; i <= 24; i++) {
    final t = i / 24;
    c.updateStroke(point(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, i * 12));
  }
  c.endStroke();
}

Future<void> _saveOil(CanvasController c, String name) async {
  final pixels = c.debugOilCompositePixels()!;
  premultiplyRgba8888(pixels);
  // Composite resolution may exceed sim resolution (display supersampling).
  final size = math.sqrt(pixels.length / 4).round();
  final ui.Image image = await (() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  })();
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = c.paperColor,
  );
  canvas.drawImage(image, ui.Offset.zero, ui.Paint());
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('$_outDir\\$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('oil live controller path', (tester) async {
    await tester.runAsync(() async {
      final controller = CanvasController()
        ..canvasSize = const ui.Size(400, 400);
      controller.activeMedium = ActiveMedium.oil;

      controller.activePaint = PaintMixture.single(Pigment.titaniumWhite);
      _stroke(controller, 60, 90, 340, 80, pressure: 0.9);

      controller.activePaint = PaintMixture.single(Pigment.frenchUltramarine);
      _stroke(controller, 60, 160, 340, 170, pressure: 0.9);

      // Light-pressure drybrush pass.
      controller.activePaint = PaintMixture.single(Pigment.burntSienna);
      _stroke(controller, 60, 240, 340, 235, pressure: 0.25);

      // White dragged straight through the blue stroke, then a clean mark:
      // the dirty-brush behavior a tester will try first.
      controller.activePaint = PaintMixture.single(Pigment.titaniumWhite);
      _stroke(controller, 60, 160, 340, 170, pressure: 0.7);
      _stroke(controller, 60, 320, 340, 320, pressure: 0.8);

      for (var i = 0; i < 12; i++) {
        controller.tickOil();
      }
      await _saveOil(controller, 'oil_10_live_path');
      controller.dispose();
    });
  });
}
