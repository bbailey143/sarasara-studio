import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/paper/paper_texture.dart';
import 'package:sarasara_studio_01_rev1/core/watercolor/watercolor_engine.dart';
import 'package:sarasara_studio_01_rev1/models/paper.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// Phase-4 artist-scenario harness. Renders every behavior on the artist
/// failure list through the live deposit path so the frames show what the
/// stylus produces: directional flow, paper-guided branching, cross-stroke
/// wet mixing, puddle redistribution, retained bloom centers, no Cheerios.
/// Inspect the PNGs by eye — that process is the authority here.
const _outDir =
    r'C:\Users\benja\AppData\Local\Temp\claude\d--sarasara-studio-01-rev1\dc74e3ca-de1d-4e2a-b978-2a2511141e55\scratchpad\wc_frames';

const _sim = 216;
const _canvas = ui.Size(400, 400);

WatercolorEngine _engine({Paper paper = Paper.coldPress}) {
  final texture = PaperTexture.generate(
    tooth: paper.tooth,
    absorbency: paper.absorbency,
    sizing: paper.sizing,
    capacity: paper.capacity,
    noiseScale: paper.noiseScale,
    seed: paper.seed,
    gridWidth: 512,
    gridHeight: 512,
  );
  return WatercolorEngine(
    simSize: _sim,
    paperHeight: (x, y) => texture.heightAt(x / _sim, y / _sim),
    paperCapacity: (x, y) => texture.capacityAt(x / _sim, y / _sim),
  );
}

void _stroke(
  WatercolorEngine e,
  Pigment p, {
  required double ax,
  required double ay,
  required double bx,
  required double by,
  double radiusPx = 26,
  double pressure = 0.75,
  int stamps = 30,
  int ticksBetween = 0,
}) {
  for (var i = 0; i <= stamps; i++) {
    final t = i / stamps;
    e.depositContact(
      [
        MediumFootprintCluster(
          position: ui.Offset(ax + (bx - ax) * t, ay + (by - ay) * t),
          coverage: 1.0,
          pressure: pressure,
          velocity: ui.Offset((bx - ax) / stamps, (by - ay) / stamps),
        ),
      ],
      _canvas,
      radiusPx,
      kBand: p.absorptionK,
      sBand: p.scatteringS,
      gran: p.granulation,
      stain: p.staining,
    );
    if (ticksBetween > 0) e.tick(ticksBetween);
  }
}

/// One stationary loaded touch — a drop of water/paint.
void _drop(
  WatercolorEngine e,
  Pigment p, {
  required double x,
  required double y,
  double radiusPx = 24,
  double pressure = 0.9,
  int stamps = 4,
}) {
  for (var i = 0; i < stamps; i++) {
    e.depositContact(
      [
        MediumFootprintCluster(
          position: ui.Offset(x, y),
          coverage: 1.0,
          pressure: pressure,
          velocity: ui.Offset.zero,
        ),
      ],
      _canvas,
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
  wash.dispose();
}

void main() {
  testWidgets('watercolor artist scenes', (tester) async {
    await tester.runAsync(() async {
      // ── 1. Single stroke: soft bleed, drying edge, kept center ────
      {
        final e = _engine();
        _stroke(e, Pigment.frenchUltramarine, ax: 60, ay: 110, bx: 340, by: 100);
        await _save(e, 'wc_01_stroke_t0');
        e.tick(30);
        await _save(e, 'wc_01_stroke_t30');
        e.tick(60);
        await _save(e, 'wc_01_stroke_t90');
        var guard = 0;
        while (!e.isDry && guard++ < 600) {
          e.tick();
        }
        await _save(e, 'wc_01_stroke_dry');
      }

      // ── 2. Drop into wet wash: bloom, retained center, no Cheerio ─
      {
        final e = _engine();
        _stroke(e, Pigment.burntSienna, ax: 80, ay: 180, bx: 320, by: 180,
            radiusPx: 40, pressure: 0.85);
        e.tick(45); // let it start drying
        _drop(e, Pigment.custom(name: 'Water', displayColor: const ui.Color(0x00FFFFFF)),
            x: 200, y: 180, radiusPx: 26, pressure: 0.95);
        await _save(e, 'wc_02_backrun_t0');
        e.tick(40);
        await _save(e, 'wc_02_backrun_t40');
        e.tick(80);
        await _save(e, 'wc_02_backrun_t120');
      }

      // ── 3. Cross-stroke wet mixing: blue over yellow reads green ──
      {
        final e = _engine();
        _stroke(e, Pigment.hansaYellow, ax: 90, ay: 120, bx: 310, by: 130,
            radiusPx: 32, pressure: 0.8);
        e.tick(6);
        _stroke(e, Pigment.phthaloBlue, ax: 140, ay: 60, bx: 260, by: 300,
            radiusPx: 32, pressure: 0.8);
        await _save(e, 'wc_03_cross_t0');
        e.tick(40);
        await _save(e, 'wc_03_cross_t40');
        e.tick(80);
        await _save(e, 'wc_03_cross_t120');
      }

      // ── 4. Tilt: wet wash travels downhill ────────────────────────
      {
        final e = _engine();
        e.params = e.params.copyWith(gravityX: 0.0, gravityY: 0.20);
        _stroke(e, Pigment.quinacridoneMagenta, ax: 120, ay: 120, bx: 280,
            by: 120, radiusPx: 36, pressure: 0.9);
        await _save(e, 'wc_04_tilt_t0');
        e.tick(50);
        await _save(e, 'wc_04_tilt_t50');
        e.tick(100);
        await _save(e, 'wc_04_tilt_t150');
      }

      // ── 5. Puddle redistribution on rough paper: branching front ──
      {
        final e = _engine(paper: Paper.rough);
        e.carrierGain = 2.2; // very wet loaded brush
        _drop(e, Pigment.phthaloBlue, x: 200, y: 200, radiusPx: 40,
            pressure: 1.0, stamps: 8);
        await _save(e, 'wc_05_puddle_t0');
        e.tick(40);
        await _save(e, 'wc_05_puddle_t40');
        e.tick(80);
        await _save(e, 'wc_05_puddle_t120');
        e.tick(120);
        await _save(e, 'wc_05_puddle_t240');
      }

      // ── 6. Momentum fling: fast stroke carries pigment forward ────
      {
        final e = _engine();
        _stroke(e, Pigment.frenchUltramarine, ax: 80, ay: 200, bx: 260,
            by: 200, radiusPx: 24, pressure: 0.85, stamps: 8);
        await _save(e, 'wc_06_fling_t0');
        e.tick(25);
        await _save(e, 'wc_06_fling_t25');
        e.tick(50);
        await _save(e, 'wc_06_fling_t75');
      }

      // ── 7. Two washes meeting: shared water, mingled boundary ─────
      {
        final e = _engine();
        _stroke(e, Pigment.quinacridoneMagenta, ax: 110, ay: 140, bx: 110,
            by: 300, radiusPx: 34, pressure: 0.9);
        _stroke(e, Pigment.hansaYellow, ax: 160, ay: 140, bx: 160, by: 300,
            radiusPx: 34, pressure: 0.9);
        await _save(e, 'wc_07_meet_t0');
        e.tick(40);
        await _save(e, 'wc_07_meet_t40');
        e.tick(100);
        await _save(e, 'wc_07_meet_t140');
      }
    });
  });
}
