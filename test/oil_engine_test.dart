import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sarasara_studio_01_rev1/core/brush/brush_reservoir.dart';
import 'package:sarasara_studio_01_rev1/core/brush/medium_adapter.dart';
import 'package:sarasara_studio_01_rev1/core/oil/oil_engine.dart';
import 'package:sarasara_studio_01_rev1/core/oil/oil_field.dart';
import 'package:sarasara_studio_01_rev1/core/oil/oil_params.dart';
import 'package:sarasara_studio_01_rev1/core/oil/oil_simulation.dart';
import 'package:sarasara_studio_01_rev1/models/brush.dart';
import 'package:sarasara_studio_01_rev1/models/pigment.dart';

/// Validation tests from `specs/oil-engine-spec.md` §13 — each isolates one
/// mechanism. These are the phase's definition of done.

/// Lay a smooth cosine dome of paint directly into the field (bypassing the
/// brush) so rheology tests start from an exactly known state.
void _fillDome(
  OilField f, {
  required double cx,
  required double cy,
  required double radius,
  required double height,
  required Pigment pigment,
  double loadPerH = 0.5,
  double mediumFrac = 0.0,
}) {
  for (var y = 0; y < f.size; y++) {
    for (var x = 0; x < f.size; x++) {
      final dx = x + 0.5 - cx;
      final dy = y + 0.5 - cy;
      final d = math.sqrt(dx * dx + dy * dy) / radius;
      if (d >= 1.0) continue;
      final hAdd = height * 0.5 * (1.0 + math.cos(math.pi * d));
      final i = f.index(x, y);
      f.paintH[i] += hAdd;
      f.mediumH[i] += hAdd * mediumFrac;
      final load = hAdd * loadPerH * (1.0 - mediumFrac);
      for (var b = 0; b < OilField.bands; b++) {
        f.kPaint[i * OilField.bands + b] += load * pigment.absorptionK[b];
        f.sPaint[i * OilField.bands + b] += load * pigment.scatteringS[b];
      }
      f.props[i * OilField.propChannels] += load;
      f.props[i * OilField.propChannels + 1] += load * pigment.granulation;
    }
  }
}

double _centroidX(OilField f) {
  var sum = 0.0, weighted = 0.0;
  for (var y = 0; y < f.size; y++) {
    for (var x = 0; x < f.size; x++) {
      final h = f.paintH[f.index(x, y)];
      sum += h;
      weighted += h * (x + 0.5);
    }
  }
  return sum <= 0 ? 0.0 : weighted / sum;
}

/// Cosine similarity between a cell's 8-band K vector and a pigment's.
double _cosSim(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < 8; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na <= 1e-18 || nb <= 1e-18) return 0.0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

List<double> _cellK(OilField f, int i) => List<double>.generate(
  8,
  (b) => f.kPaint[i * OilField.bands + b].toDouble(),
);

/// A cell holds a genuine mechanical mix if its spectrum is no longer a pure
/// multiple of either source pigment.
bool _isMixed(OilField f, int i, Pigment a, Pigment b, {double minLoad = 0.05}) {
  if (f.props[i * OilField.propChannels] < minLoad) return false;
  final k = _cellK(f, i);
  return _cosSim(k, a.absorptionK) < 0.995 && _cosSim(k, b.absorptionK) < 0.995;
}

BrushReservoir _loadedReservoir(Pigment pigment, {double amount = 1.0}) {
  final reservoir = BrushReservoir(
    capacity: 1.0,
    tipCapacityFraction: 0.3,
    medium: MediumFamily.oil,
  );
  reservoir.applyReceipt(
    TransferReceipt(
      medium: MediumFamily.oil,
      pigmentIn: amount,
      kIn: List<double>.generate(8, (b) => pigment.absorptionK[b] * amount),
      sIn: List<double>.generate(8, (b) => pigment.scatteringS[b] * amount),
      granulationIn: pigment.granulation * amount,
    ),
  );
  return reservoir;
}

/// Drive one straight engine stroke through footprint clusters, applying the
/// authoritative receipts to the reservoir exactly as the controller does.
void _engineStroke(
  OilEngine engine,
  BrushReservoir reservoir, {
  required double ax,
  required double ay,
  required double bx,
  required double by,
  int stamps = 20,
  double pressure = 0.9,
  double radiusPx = 14,
  double mediumFraction = 0.0,
}) {
  final size = ui.Size(
    engine.simSize.toDouble(),
    engine.simSize.toDouble(),
  );
  for (var i = 0; i <= stamps; i++) {
    final t = i / stamps;
    final snapshot = BrushReservoirSnapshot.from(reservoir);
    final offer = reservoir.offer(
      contact: 1.0,
      dtSeconds: 0.016,
      brush: _testBrush,
    );
    final receipt = engine.depositContact(
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

// BrushReservoir.offer only reads the release/pickup conductances; the
// default preset serves fine.
const _testBrush = Brush();

void main() {
  group('oil §13 rheology', () {
    test('1. impasto holds — a stiff sub-yield ridge keeps its relief', () {
      final field = OilField(64);
      final sim = OilSimulation(
        field: field,
        params: const OilParams(tauY0: 2.0, rhoG: 1.0),
      );
      _fillDome(
        field,
        cx: 32,
        cy: 32,
        radius: 8,
        height: 2.0,
        pigment: Pigment.titaniumWhite,
      );
      final before = Float32List.fromList(field.paintH);
      final volume = field.totalVolume();

      for (var i = 0; i < 200; i++) {
        sim.step();
      }

      var maxDelta = 0.0;
      for (var i = 0; i < field.cellCount; i++) {
        final d = (field.paintH[i] - before[i]).abs();
        if (d > maxDelta) maxDelta = d;
      }
      expect(maxDelta, lessThan(1e-9), reason: 'sub-yield relief must hold');
      expect(field.totalVolume(), closeTo(volume, 1e-6));

      // Raking light must show the ridge: with light arriving from +x, the
      // east slope (facing the light) is lit and the west slope shaded.
      final pixels = Uint8List(field.cellCount * 4);
      sim.params = sim.params.copyWith(lightAzimuth: 0.0, lightElevation: 0.3);
      sim.compositeToRgba(pixels);
      final litSide = pixels[(32 * 64 + 36) * 4];
      final shadeSide = pixels[(32 * 64 + 28) * 4];
      expect(
        litSide - shadeSide,
        greaterThan(8),
        reason: 'raking light must shade the relief',
      );
    });

    test('2. slump — an over-thick blob creeps downhill, then stops', () {
      final field = OilField(64);
      final sim = OilSimulation(
        field: field,
        params: const OilParams(
          tauY0: 0.6,
          rhoG: 1.6,
          consistencyK: 1.2,
          tiltX: 0.45,
        ),
      );
      _fillDome(
        field,
        cx: 24,
        cy: 32,
        radius: 8,
        height: 4.0,
        pigment: Pigment.frenchUltramarine,
      );
      final volume = field.totalVolume();
      final startX = _centroidX(field);

      var peakFlux = 0.0;
      for (var i = 0; i < 150; i++) {
        sim.step();
        if (sim.lastMaxFlux > peakFlux) peakFlux = sim.lastMaxFlux;
      }
      final earlyX = _centroidX(field);
      final earlyCreep = earlyX - startX;
      expect(
        earlyCreep,
        greaterThan(0.5),
        reason: 'blob must creep downhill under tilt',
      );

      // Keep flowing until the excess stress dies away. The Bingham factor
      // decays asymptotically, so "stopped" means a decisive deceleration and
      // near-vanished flux relative to the active slump — not bitwise
      // stillness.
      for (var i = 0; i < 900; i++) {
        sim.step();
        if (sim.lastMaxFlux < peakFlux * 0.005) break;
      }
      final lateStartX = _centroidX(field);
      for (var i = 0; i < 150; i++) {
        sim.step();
      }
      final lateCreep = _centroidX(field) - lateStartX;

      expect(
        lateCreep,
        lessThan(earlyCreep * 0.05),
        reason: 'yield stress must recapture the paint as it thins',
      );
      expect(
        sim.lastMaxFlux,
        lessThan(peakFlux * 0.02),
        reason: 'terminal flux must be a trace of the active slump',
      );
      expect(field.totalVolume(), closeTo(volume, volume * 1e-6));
    });

    test('3. marble, not bloom — drag folds colors; rest never blends', () {
      final field = OilField(64);
      final sim = OilSimulation(
        field: field,
        params: const OilParams(tauY0: 3.0),
      );
      // Two pure blocks meeting at x = 32.
      for (var y = 20; y < 44; y++) {
        for (var x = 16; x < 32; x++) {
          _fillDome(
            field,
            cx: x + 0.5,
            cy: y + 0.5,
            radius: 0.9,
            height: 1.2,
            pigment: Pigment.quinacridoneMagenta,
          );
        }
        for (var x = 32; x < 48; x++) {
          _fillDome(
            field,
            cx: x + 0.5,
            cy: y + 0.5,
            radius: 0.9,
            height: 1.2,
            pigment: Pigment.phthaloBlue,
          );
        }
      }

      // No mixed cells before the brush touches anything.
      var mixedBefore = 0;
      for (var i = 0; i < field.cellCount; i++) {
        if (_isMixed(
          field,
          i,
          Pigment.quinacridoneMagenta,
          Pigment.phthaloBlue,
        )) {
          mixedBefore++;
        }
      }
      expect(mixedBefore, 0);

      // Drag a brush across the boundary — the mechanical mixer.
      for (var pass = 0; pass < 14; pass++) {
        sim.drag(
          cx: 26.0 + pass,
          cy: 32,
          radius: 5,
          velX: 1.0,
          velY: 0.0,
        );
      }

      var mixedAfter = 0;
      for (var i = 0; i < field.cellCount; i++) {
        if (_isMixed(
          field,
          i,
          Pigment.quinacridoneMagenta,
          Pigment.phthaloBlue,
        )) {
          mixedAfter++;
        }
      }
      expect(
        mixedAfter,
        greaterThan(5),
        reason: 'dragging one color through another must fold them together',
      );

      // Let them sit. NO further mixing may occur — bitwise-identical
      // spectra, or a diffusion term leaked in.
      final kBefore = Float32List.fromList(field.kPaint);
      for (var i = 0; i < 300; i++) {
        sim.step();
      }
      var maxDrift = 0.0;
      for (var i = 0; i < field.kPaint.length; i++) {
        final d = (field.kPaint[i] - kBefore[i]).abs();
        if (d > maxDrift) maxDrift = d;
      }
      expect(
        maxDrift,
        lessThan(1e-12),
        reason: 'two touching colors at rest must never blend',
      );
    });

    test('7. volume conservation — Σh flat except at brush exchange', () {
      final field = OilField(64);
      final sim = OilSimulation(
        field: field,
        params: const OilParams(tauY0: 0.3, rhoG: 1.5, tiltX: 0.5),
      );
      var expected = 0.0;
      for (var i = 0; i < 12; i++) {
        final exchange = sim.stamp(
          cx: 16.0 + i * 2.5,
          cy: 30.0 + (i % 3) * 4,
          radius: 5,
          pressure: 0.9,
          film: 2.5,
          kUnit: Pigment.burntSienna.absorptionK,
          sUnit: Pigment.burntSienna.scatteringS,
          granUnit: 0.2,
          mediumFraction: 0.1,
          dragSpeed: 1.0,
        );
        expected += exchange.depositedVolume - exchange.pickedVolume;
        sim.drag(
          cx: 16.0 + i * 2.5,
          cy: 30.0 + (i % 3) * 4,
          radius: 5,
          velX: 0.8,
          velY: 0.2,
        );
      }
      expect(
        field.totalVolume(),
        closeTo(expected, math.max(1e-6, expected * 1e-6)),
        reason: 'brush exchange must account for every unit of volume',
      );

      final load = field.totalLoad();
      for (var i = 0; i < 300; i++) {
        sim.step();
      }
      expect(
        field.totalVolume(),
        closeTo(expected, math.max(1e-6, expected * 1e-6)),
        reason: 'rheology flow must conserve volume exactly',
      );
      expect(field.totalLoad(), closeTo(load, math.max(1e-6, load * 1e-6)));
    });
  });

  group('oil §13 brush interaction', () {
    test('4. dirty brush — white dragged through red paints pink', () {
      final engine = OilEngine(simSize: 96);

      // Lay a red passage with a red-loaded brush.
      final redReservoir = _loadedReservoir(Pigment.quinacridoneMagenta);
      _engineStroke(
        engine,
        redReservoir,
        ax: 20,
        ay: 40,
        bx: 76,
        by: 40,
        radiusPx: 16,
      );

      // Control: what pure white deposits look like on clean canvas.
      final controlReservoir = _loadedReservoir(Pigment.titaniumWhite);
      _engineStroke(
        engine,
        controlReservoir,
        ax: 20,
        ay: 14,
        bx: 76,
        by: 14,
        radiusPx: 10,
      );

      // The test brush: white, dragged straight through the red passage.
      final whiteReservoir = _loadedReservoir(Pigment.titaniumWhite);
      _engineStroke(
        engine,
        whiteReservoir,
        ax: 20,
        ay: 40,
        bx: 76,
        by: 40,
        radiusPx: 10,
      );
      // Then a mark on clean canvas below.
      _engineStroke(
        engine,
        whiteReservoir,
        ax: 20,
        ay: 74,
        bx: 76,
        by: 74,
        radiusPx: 10,
      );

      // Reservoir must have accumulated red: its average K is no longer
      // titanium white's.
      final snapshot = BrushReservoirSnapshot.from(whiteReservoir);
      expect(
        _cosSim(snapshot.kAverage, Pigment.titaniumWhite.absorptionK),
        lessThan(0.999),
        reason: 'picked-up paint must blend into the reservoir',
      );

      // And the clean-canvas mark must carry that contamination: compare the
      // magenta signature (strong green-band absorption) of the dirty mark
      // against the pure-white control mark.
      double greenBandK(int cy) {
        var sum = 0.0;
        for (var x = 30; x < 66; x++) {
          final i = engine.field.index(x, cy);
          sum += engine.field.kPaint[i * OilField.bands + 3];
        }
        return sum;
      }

      final dirtyMark = greenBandK(74);
      final controlMark = greenBandK(14);
      expect(
        dirtyMark,
        greaterThan(controlMark * 2.0 + 1e-6),
        reason: 'a stroke after dragging through red must start pink',
      );
    });

    test('5. wet-on-wet — mechanical blend at the interface, no outward '
        'diffusion', () {
      final field = OilField(80);
      final sim = OilSimulation(
        field: field,
        params: const OilParams(tauY0: 0.8),
      );
      // Thin, high-medium base layer (the "liquid white").
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 80; x++) {
          final i = field.index(x, y);
          field.paintH[i] = 0.6;
          field.mediumH[i] = 0.42;
          final load = 0.25;
          for (var b = 0; b < OilField.bands; b++) {
            field.kPaint[i * OilField.bands + b] +=
                load * Pigment.phthaloBlue.absorptionK[b];
            field.sPaint[i * OilField.bands + b] +=
                load * Pigment.phthaloBlue.scatteringS[b];
          }
          field.props[i * OilField.propChannels] += load;
        }
      }

      // A yellow stroke across the base: stamp + drag, the Bob Ross pass.
      for (var step = 0; step <= 30; step++) {
        final cx = 12.0 + step * 1.8;
        sim.stamp(
          cx: cx,
          cy: 40,
          radius: 4,
          pressure: 0.85,
          film: 2.0,
          kUnit: Pigment.hansaYellow.absorptionK,
          sUnit: Pigment.hansaYellow.scatteringS,
          granUnit: 0.0,
          mediumFraction: 0.15,
          dragSpeed: 1.8,
        );
        sim.drag(cx: cx, cy: 40, radius: 5, velX: 1.4, velY: 0.0);
      }

      // Soft interface: cells just off the stroke spine carry both pigments.
      var interfaceMixed = 0;
      for (var x = 20; x < 60; x++) {
        for (final y in [36, 37, 43, 44]) {
          if (_isMixed(
            field,
            field.index(x, y),
            Pigment.hansaYellow,
            Pigment.phthaloBlue,
            minLoad: 0.1,
          )) {
            interfaceMixed++;
          }
        }
      }
      expect(
        interfaceMixed,
        greaterThan(8),
        reason: 'the stroke must fold into the wet base at its interface',
      );

      // Rest. Yellow must not creep outward: far cells stay pure blue.
      for (var i = 0; i < 200; i++) {
        sim.step();
      }
      var farYellow = 0.0;
      final yellowGreenBand = Pigment.hansaYellow.absorptionK[1];
      expect(yellowGreenBand, greaterThan(0.0));
      for (var x = 20; x < 60; x++) {
        for (final y in [28, 52]) {
          final i = field.index(x, y);
          final k = _cellK(field, i);
          // Band 1 (blue light): yellow absorbs strongly, phthalo blue barely.
          final blueBaseline =
              field.props[i * OilField.propChannels] *
              Pigment.phthaloBlue.absorptionK[1];
          farYellow = math.max(farYellow, k[1] - blueBaseline * 1.05);
        }
      }
      expect(
        farYellow,
        lessThan(0.02),
        reason: 'colors must never diffuse outward at rest',
      );
    });

    test('6. drybrush — light pressure on rough canvas hits only peaks', () {
      double roughTooth(int x, int y) =>
          0.5 + 0.5 * math.sin(x * 1.9) * math.sin(y * 1.9);
      final field = OilField(64);
      final sim = OilSimulation(
        field: field,
        params: const OilParams(),
        canvasTooth: roughTooth,
      );

      // One light, fast pass.
      for (var step = 0; step <= 20; step++) {
        sim.stamp(
          cx: 10.0 + step * 2.2,
          cy: 32,
          radius: 5,
          pressure: 0.3,
          film: 1.2,
          kUnit: Pigment.burntSienna.absorptionK,
          sUnit: Pigment.burntSienna.scatteringS,
          granUnit: 0.3,
          mediumFraction: 0.0,
          dragSpeed: 2.2,
        );
      }

      var painted = 0, bare = 0;
      var paintedTooth = 0.0, bareTooth = 0.0;
      for (var y = 27; y <= 37; y++) {
        for (var x = 8; x <= 56; x++) {
          final h = field.paintH[field.index(x, y)];
          final tooth = roughTooth(x, y);
          if (h > 1e-4) {
            painted++;
            paintedTooth += tooth;
          } else {
            bare++;
            bareTooth += tooth;
          }
        }
      }
      expect(painted, greaterThan(10), reason: 'the pass must leave paint');
      expect(
        bare,
        greaterThan(painted * 0.3),
        reason: 'a light pass must skip the valleys — broken color',
      );
      expect(
        paintedTooth / painted,
        greaterThan(bareTooth / bare + 0.1),
        reason: 'deposits must sit on the tooth peaks',
      );

      // Full pressure fills what drybrush skipped.
      for (var step = 0; step <= 20; step++) {
        sim.stamp(
          cx: 10.0 + step * 2.2,
          cy: 32,
          radius: 5,
          pressure: 1.0,
          film: 2.5,
          kUnit: Pigment.burntSienna.absorptionK,
          sUnit: Pigment.burntSienna.scatteringS,
          granUnit: 0.3,
          mediumFraction: 0.0,
          dragSpeed: 0.5,
        );
      }
      var paintedFull = 0;
      var totalFull = 0;
      for (var y = 30; y <= 34; y++) {
        for (var x = 12; x <= 52; x++) {
          totalFull++;
          if (field.paintH[field.index(x, y)] > 1e-4) paintedFull++;
        }
      }
      expect(
        paintedFull / totalFull,
        greaterThan(0.9),
        reason: 'full pressure must reach the whole tooth profile',
      );
    });
  });

  group('oil engine state', () {
    test('checkpoint restores the exact live state', () {
      final engine = OilEngine(simSize: 48)..displayScale = 1;
      final reservoir = _loadedReservoir(Pigment.frenchUltramarine);
      _engineStroke(engine, reservoir, ax: 8, ay: 24, bx: 40, by: 24);
      engine.tick(5);

      final checkpoint = engine.snapshot();
      final volume = engine.field.totalVolume();
      final load = engine.field.totalLoad();
      final pixels = engine.compositePixels();

      _engineStroke(engine, reservoir, ax: 8, ay: 10, bx: 40, by: 38);
      engine.tick(8);
      expect(engine.field.totalVolume(), isNot(closeTo(volume, 1e-9)));

      engine.restore(checkpoint);
      expect(engine.field.totalVolume(), closeTo(volume, 1e-7));
      expect(engine.field.totalLoad(), closeTo(load, 1e-7));
      expect(engine.compositePixels(), equals(pixels));
    });

    test('composite is transparent where no paint has gone', () {
      // Pixel indices below address the sim grid directly.
      final engine = OilEngine(simSize: 48)..displayScale = 1;
      final pixels = engine.compositePixels();
      for (var i = 0; i < pixels.length; i += 4) {
        expect(pixels[i + 3], 0);
      }

      final reservoir = _loadedReservoir(Pigment.quinacridoneMagenta);
      _engineStroke(engine, reservoir, ax: 12, ay: 24, bx: 36, by: 24);
      final painted = engine.compositePixels();
      final center = (24 * 48 + 24) * 4;
      final corner = (2 * 48 + 2) * 4;
      expect(painted[center + 3], greaterThan(150));
      expect(painted[corner + 3], 0);
    });

    test('receipts stay inside the reservoir offer bounds', () {
      final engine = OilEngine(simSize: 48);
      final reservoir = _loadedReservoir(Pigment.hansaYellow);
      final snapshot = BrushReservoirSnapshot.from(reservoir);
      final offer = reservoir.offer(
        contact: 1.0,
        dtSeconds: 0.016,
        brush: _testBrush,
      );
      final receipt = engine.depositContact(
        [
          const MediumFootprintCluster(
            position: ui.Offset(24, 24),
            coverage: 1.0,
            pressure: 1.0,
            velocity: ui.Offset(2, 0),
          ),
        ],
        const ui.Size(48, 48),
        16,
        reservoir: snapshot,
        offer: offer,
      );
      expect(receipt.medium, MediumFamily.oil);
      expect(
        receipt.acceptedOutflow,
        lessThanOrEqualTo(offer.maximumOutflow + 1e-12),
      );
      expect(
        receipt.acceptedInflow,
        lessThanOrEqualTo(offer.maximumInflow + 1e-12),
      );
    });
  });
}
