import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_reservoir.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/oil/oil_engine.dart';
import 'package:sarasara_studio_01_rev1/core/oil/oil_params.dart';
import 'package:sarasara_studio_01_rev1/models/brush.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// Render-to-PNG harness for tuning the oil engine BY EYE (the process that
/// unstuck watercolor). Paints scripted strokes through the real engine +
/// reservoir path, composites over a canvas ground, writes frames to the
/// scratchpad. Not a behavior test — visual inspection only.
const _outDir =
    r'C:\Users\benja\AppData\Local\Temp\claude\d--sarasara-studio-01-rev1\dc74e3ca-de1d-4e2a-b978-2a2511141e55\scratchpad\oil_frames';

const _canvasGround = ui.Color(0xFFEFEAE0);

double _roughTooth(int x, int y) {
  final a = math.sin(x * 2.3 + math.sin(y * 1.13) * 1.7);
  final b = math.sin(y * 2.17 + math.sin(x * 1.31) * 1.3);
  return 0.5 + 0.26 * a * b + 0.12 * math.sin((x + y) * 0.71);
}

BrushReservoir _load(Pigment p, {double amount = 1.0}) {
  final r = BrushReservoir(
    capacity: 1.0,
    tipCapacityFraction: 0.3,
    medium: MediumFamily.oil,
  );
  r.applyReceipt(
    TransferReceipt(
      medium: MediumFamily.oil,
      pigmentIn: amount,
      kIn: List<double>.generate(8, (b) => p.absorptionK[b] * amount),
      sIn: List<double>.generate(8, (b) => p.scatteringS[b] * amount),
      granulationIn: p.granulation * amount,
    ),
  );
  return r;
}

void _stroke(
  OilEngine e,
  BrushReservoir reservoir, {
  required double ax,
  required double ay,
  required double bx,
  required double by,
  int stamps = 55,
  double pressure = 0.85,
  double radiusPx = 20,
  double mediumFraction = 0.0,
}) {
  final size = ui.Size(e.simSize.toDouble(), e.simSize.toDouble());
  for (var i = 0; i <= stamps; i++) {
    final t = i / stamps;
    final snapshot = BrushReservoirSnapshot.from(reservoir);
    final offer = reservoir.offer(
      contact: 1.0,
      dtSeconds: 0.016,
      brush: const Brush(),
    );
    final receipt = e.depositContact(
      [
        MediumFootprintCluster(
          position: ui.Offset(ax + (bx - ax) * t, ay + (by - ay) * t),
          coverage: 1.0,
          pressure: pressure,
          velocity: ui.Offset((bx - ax) / stamps, (by - ay) / stamps),
        ),
      ],
      size,
      radiusPx,
      reservoir: snapshot,
      offer: offer,
      mediumFraction: mediumFraction,
    );
    reservoir.applyReceipt(receipt);
  }
}

Future<void> _save(OilEngine e, String name) async {
  final paintImage = await e.compositeImage();
  final s = e.displaySize.toDouble();
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(ui.Rect.fromLTWH(0, 0, s, s), ui.Paint()..color = _canvasGround);
  c.drawImage(paintImage, ui.Offset.zero, ui.Paint());
  final img = await rec.endRecording().toImage(e.displaySize, e.displaySize);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('$_outDir\\$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('oil visual scenes', (tester) async {
    await tester.runAsync(() async {
      // ── Scene 1: impasto — thick strokes, raking light ────────────
      {
        final e = OilEngine(
          simSize: 224,
          params: const OilParams(tauY0: 2.2, brushFilm: 3.4),
          canvasTooth: _roughTooth,
        )..setSubstrateColor(_canvasGround);
        final white = _load(Pigment.titaniumWhite);
        final blue = _load(Pigment.frenchUltramarine);
        _stroke(e, white, ax: 30, ay: 60, bx: 195, by: 55, radiusPx: 26);
        _stroke(e, white, ax: 30, ay: 95, bx: 195, by: 100, radiusPx: 26);
        _stroke(e, blue, ax: 30, ay: 150, bx: 195, by: 145, radiusPx: 26);
        await _save(e, 'oil_01_impasto_fresh');
        e.tick(60);
        await _save(e, 'oil_01_impasto_t60');
      }

      // ── Scene 2: marble — drag white through wet red ──────────────
      {
        final e = OilEngine(
          simSize: 224,
          params: const OilParams(tauY0: 1.4, brushFilm: 2.8),
        )..setSubstrateColor(_canvasGround);
        final red = _load(Pigment.quinacridoneMagenta);
        for (var y = 70; y <= 150; y += 16) {
          _stroke(
            e,
            red,
            ax: 40,
            ay: y.toDouble(),
            bx: 185,
            by: y.toDouble(),
            radiusPx: 24,
          );
        }
        await _save(e, 'oil_02_marble_base');
        final white = _load(Pigment.titaniumWhite);
        _stroke(e, white, ax: 50, ay: 130, bx: 180, by: 85, radiusPx: 18);
        await _save(e, 'oil_02_marble_dragged');
        e.tick(120);
        await _save(e, 'oil_02_marble_rested');
      }

      // ── Scene 3: drybrush on rough canvas ─────────────────────────
      {
        final e = OilEngine(
          simSize: 224,
          params: const OilParams(brushFilm: 1.6),
          canvasTooth: _roughTooth,
        )..setSubstrateColor(_canvasGround);
        final sienna = _load(Pigment.burntSienna);
        _stroke(
          e,
          sienna,
          ax: 25,
          ay: 80,
          bx: 200,
          by: 75,
          radiusPx: 22,
          pressure: 0.3,
          stamps: 22,
        );
        _stroke(
          e,
          sienna,
          ax: 25,
          ay: 145,
          bx: 200,
          by: 150,
          radiusPx: 22,
          pressure: 1.0,
        );
        await _save(e, 'oil_03_drybrush_vs_full');
      }

      // ── Scene 4: glaze — thin transparent layer over ground ───────
      {
        final e = OilEngine(
          simSize: 224,
          params: const OilParams(tauY0: 0.5, brushFilm: 0.9),
        )..setSubstrateColor(_canvasGround);
        final white = _load(Pigment.titaniumWhite);
        _stroke(e, white, ax: 30, ay: 70, bx: 195, by: 70, radiusPx: 30);
        e.tick(30);
        final glaze = _load(Pigment.phthaloBlue, amount: 0.35);
        _stroke(
          e,
          glaze,
          ax: 60,
          ay: 30,
          bx: 60,
          by: 190,
          radiusPx: 24,
          mediumFraction: 0.8,
          pressure: 0.5,
        );
        _stroke(
          e,
          glaze,
          ax: 140,
          ay: 30,
          bx: 140,
          by: 190,
          radiusPx: 24,
          mediumFraction: 0.8,
          pressure: 0.9,
        );
        await _save(e, 'oil_04_glaze');
      }

      // ── Scene 5: dirty brush — white through red, then clean mark ─
      {
        final e = OilEngine(
          simSize: 224,
          params: const OilParams(tauY0: 1.4, brushFilm: 2.6),
        )..setSubstrateColor(_canvasGround);
        final red = _load(Pigment.quinacridoneMagenta);
        _stroke(e, red, ax: 30, ay: 70, bx: 195, by: 70, radiusPx: 26);
        final white = _load(Pigment.titaniumWhite);
        _stroke(e, white, ax: 30, ay: 70, bx: 195, by: 70, radiusPx: 16);
        _stroke(e, white, ax: 30, ay: 140, bx: 195, by: 140, radiusPx: 16);
        _stroke(e, white, ax: 30, ay: 180, bx: 195, by: 180, radiusPx: 16);
        await _save(e, 'oil_05_dirty_brush');
      }

      // ── Scene 6: wet-on-wet fold — yellow into blue base ──────────
      {
        final e = OilEngine(
          simSize: 224,
          params: const OilParams(tauY0: 0.8, brushFilm: 2.2),
        )..setSubstrateColor(_canvasGround);
        final blue = _load(Pigment.phthaloBlue, amount: 0.6);
        for (var y = 40; y <= 190; y += 14) {
          _stroke(
            e,
            blue,
            ax: 25,
            ay: y.toDouble(),
            bx: 200,
            by: y.toDouble(),
            radiusPx: 22,
            mediumFraction: 0.5,
          );
        }
        final yellow = _load(Pigment.hansaYellow);
        _stroke(e, yellow, ax: 60, ay: 170, bx: 120, by: 55, radiusPx: 18);
        _stroke(e, yellow, ax: 120, ay: 55, bx: 175, by: 170, radiusPx: 18);
        await _save(e, 'oil_06_wet_on_wet');
        e.tick(90);
        await _save(e, 'oil_06_wet_on_wet_rested');
      }
    });
  });
}
