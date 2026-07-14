import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_engine.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_field.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_params.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

const _outDir =
    r'C:\Users\benja\AppData\Local\Temp\claude\d--sarasara-studio-01-rev1\df99b007-54d4-4848-9cb3-863ebca9d055\scratchpad\frames';

void _stroke(
  WatercolorEngine e,
  Pigment p,
  double ax,
  double ay,
  double bx,
  double by, {
  double radiusPx = 22,
}) {
  for (var i = 0; i <= 26; i++) {
    final t = i / 26;
    e.depositContact(
      [
        MediumFootprintCluster(
          position: ui.Offset(ax + (bx - ax) * t, ay + (by - ay) * t),
          coverage: 1.0,
          pressure: 1.0,
          velocity: ui.Offset((bx - ax) / 26, (by - ay) / 26),
        ),
      ],
      const ui.Size(400, 400),
      radiusPx,
      kBand: p.absorptionK,
      sBand: p.scatteringS,
      gran: p.granulation,
      stain: p.staining,
    );
  }
}

Future<void> _save(WatercolorEngine e, String name) async {
  final wash = await e.compositeImage();
  final s = e.simSize.toDouble();
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    ui.Rect.fromLTWH(0, 0, s, s),
    ui.Paint()..color = const ui.Color(0xFFF6F4EF),
  );
  c.drawImage(wash, ui.Offset.zero, ui.Paint());
  final img = await rec.endRecording().toImage(e.simSize, e.simSize);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('$_outDir\\$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('fluid', (tester) async {
    await tester.runAsync(() async {
      final e =
          WatercolorEngine(
              simSize: 224,
              params: const WatercolorParams(
                bleed: 0.22,
                wetSpread: 0.25,
                dry: 0.0025,
                settle: 0.01,
                soak: 0.02,
                lift: 0.06,
                edge: 2.0,
              ),
            )
            ..depositRate = 2.0
            ..waterRatio = 4.0;
      // Two vertical strokes laid side by side, edges nearly touching.
      _stroke(e, Pigment.phthaloBlue, 95, 60, 95, 300);
      _stroke(e, Pigment.hansaYellow, 135, 60, 135, 300);
      await _save(e, 'fl_00_fresh');
      for (var i = 0; i < 25; i++) {
        e.tick();
      }
      await _save(e, 'fl_01_t25');
      for (var i = 0; i < 50; i++) {
        e.tick();
      }
      await _save(e, 'fl_02_t75');
      for (var i = 0; i < 120; i++) {
        e.tick();
      }
      await _save(e, 'fl_03_dry');

      // Measure suspended-load + alpha profile across x at the mid row.
      final px = e.compositePixels();
      final s = e.simSize;
      final y = 112;
      final buf = StringBuffer('sus load @y112: ');
      for (var x = 40; x <= 110; x += 5) {
        buf.write(
          '$x=${e.field.propsSus[(y * s + x) * 3].toStringAsFixed(2)} ',
        );
      }
      // ignore: avoid_print
      print(buf);
      final ab = StringBuffer('alpha @y112: ');
      for (var x = 40; x <= 110; x += 5) {
        ab.write('$x=${px[(y * s + x) * 4 + 3]} ');
      }
      // ignore: avoid_print
      print(ab);
      final wb = StringBuffer('h+s @y112: ');
      for (var x = 40; x <= 110; x += 5) {
        wb.write(
          '$x=${(e.field.waterH[y * s + x] + e.field.saturation[y * s + x]).toStringAsFixed(2)} ',
        );
      }
      // ignore: avoid_print
      print(wb);
      final db = StringBuffer('dep @y112: ');
      for (var x = 40; x <= 110; x += 5) {
        db.write(
          '$x=${e.field.propsDep[(y * s + x) * WatercolorField.depProps].toStringAsFixed(2)} ',
        );
      }
      // ignore: avoid_print
      print(db);
      final rgb = StringBuffer('rgb @y112: ');
      for (var x = 45; x <= 90; x += 4) {
        final o = (y * s + x) * 4;
        rgb.write('$x=(${px[o]},${px[o + 1]},${px[o + 2]}) ');
      }
      // ignore: avoid_print
      print(rgb);
    });
  });
}
