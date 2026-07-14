import 'dart:math' as math;
import 'dart:typed_data';

import '../pigment/spectral_color.dart';
import 'watercolor_field.dart';
import 'watercolor_params.dart';

/// One already-resolved bristle cluster in simulation-cell units. [load] and
/// [waterAmt] are either integrated totals (live receipt path) or the explicit
/// synthetic amplitudes used by low-level tests.
class WatercolorSplat {
  const WatercolorSplat({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.pressure,
    required this.load,
    required this.waterAmt,
    this.impulseX = 0.0,
    this.impulseY = 0.0,
    this.dragSpeed = 0.0,
  });

  final double cx;
  final double cy;
  final double radius;
  final double pressure;
  final double load;
  final double waterAmt;
  final double impulseX;
  final double impulseY;
  final double dragSpeed;
}

/// Exact field material removed under a real brush contact. Values remain in
/// simulation units until [WatercolorEngine] converts them back into the
/// shared brush reservoir's units.
class WatercolorPickup {
  WatercolorPickup({
    this.carrier = 0.0,
    this.pigment = 0.0,
    List<double>? k,
    List<double>? s,
    this.granulation = 0.0,
    this.staining = 0.0,
  }) : k = k ?? List<double>.filled(WatercolorField.bands, 0.0),
       s = s ?? List<double>.filled(WatercolorField.bands, 0.0);

  final double carrier;
  final double pigment;
  final List<double> k;
  final List<double> s;
  final double granulation;
  final double staining;
}

/// CPU correctness reference for the binding watercolor Fluid + Pigment
/// pipeline. The older wet-map/diffusion experiment is available only through
/// [WatercolorTransportMode.diffusionFallback]; it never double-runs as the
/// primary motion model. See `WATERCOLOR-FLUID-RECOVERY.md`.
///
/// Per frame:
///   1. fluid solve — velocity advection, height force, viscosity and pressure
///      projection (or the isolated historical fallback);
///   2. transport — velocity carries suspended pigment and surface water;
///   3. microscopic union — conservative paired exchange in connected wet
///      cells, secondary to bulk fluid movement;
///   4. water/paper — capillary spread, soak, evaporation, shared mobility;
///   5. settle / lift / finalize — active pigment exchanges while wet and is
///      completely settled/protected at the dry transition.
///
/// Grid space: one cell = one texel, dt = 1. Colour is spectral Kubelka–Munk
/// (unchanged, shared with oil). Pressure/divergence buffers implement the CPU
/// projection reference.
class WatercolorSimulation {
  final WatercolorField field;

  // Reused per-contact accumulation buffers. Combining every bristle before
  // touching the persistent field makes one physical sample simultaneous and
  // avoids large temporary allocations during broad strokes.
  late final Float32List _contactPigment;
  late final Float32List _contactWater;
  late final Float32List _contactImpulseX;
  late final Float32List _contactImpulseY;
  late final Float32List _contactPickupWeight;
  late final Uint8List _contactMixMask;
  final List<int> _contactMixCells = <int>[];

  // The CPU simulation keeps one shared sheet, but only works on small tiles
  // around material that can still change. Separate wet marks therefore do
  // not make the empty space between them expensive on every frame.
  static const int _activeTileSize = 16;
  late final int _activeTileColumns;
  late final int _activeTileRows;
  late final Uint8List _activeTileMask;
  late final Uint8List _expandedTileMask;
  late final Uint8List _activeWorkMask;
  int _activeWorkCellCount = 0;

  /// Mutable so the UI can adjust levels live without rebuilding the field.
  WatercolorParams params;

  /// Static paper tooth height `τ` at a cell, 0..1 (valley..peak).
  final double Function(int x, int y) paperHeight;

  /// Static paper water capacity `κ` at a cell, 0..1.
  final double Function(int x, int y) paperCapacity;

  WatercolorSimulation({
    required this.field,
    this.params = const WatercolorParams(),
    double Function(int x, int y)? paperHeight,
    double Function(int x, int y)? paperCapacity,
  }) : paperHeight = paperHeight ?? _flatHalf,
       paperCapacity = paperCapacity ?? _flatOne {
    _contactPigment = Float32List(field.cellCount);
    _contactWater = Float32List(field.cellCount);
    _contactImpulseX = Float32List(field.cellCount);
    _contactImpulseY = Float32List(field.cellCount);
    _contactPickupWeight = Float32List(field.cellCount);
    _contactMixMask = Uint8List(field.cellCount);
    _activeTileColumns = (field.size + _activeTileSize - 1) ~/ _activeTileSize;
    _activeTileRows = (field.size + _activeTileSize - 1) ~/ _activeTileSize;
    final tileCount = _activeTileColumns * _activeTileRows;
    _activeTileMask = Uint8List(tileCount);
    _expandedTileMask = Uint8List(tileCount);
    _activeWorkMask = Uint8List(field.cellCount);
  }

  static double _flatHalf(int x, int y) => 0.5;
  static double _flatOne(int x, int y) => 1.0;

  int get _s => field.size;

  /// One shared, per-cell answer to "how freely can pigment move here?".
  ///
  /// Surface water can make a cell fully mobile. Water held down in the paper
  /// keeps it only partly mobile: that is the useful damp interval between a
  /// glossy wet wash and a locked dry glaze. Every wet-union and dispersion
  /// decision uses this same function so a cell cannot be wet to one pass and
  /// dry to another.
  double _wetMobilityValues(double surfaceWater, double paperSaturation) {
    final threshold = math.max(params.wetThreshold, 1e-6);
    final surface = _smoothstep(
      threshold * 0.35,
      threshold * 1.5,
      surfaceWater,
    );
    final paper = _smoothstep(
      threshold * 0.20,
      threshold * 1.10,
      paperSaturation,
    );
    // Paper-held water is slower than a glossy surface film, but it must still
    // leave a genuinely workable interval while an artist changes colour.
    // A value that is too small makes a visibly damp wash behave as dry paint.
    const dampMobility = 0.60;
    return 1.0 - (1.0 - surface) * (1.0 - dampMobility * paper);
  }

  double _wetMobilityAt(int i) =>
      _wetMobilityValues(field.waterH[i], field.saturation[i]);

  /// Lift mobile watercolor into the brush only beneath its true bristle
  /// footprint. Wet suspended pigment is easiest to collect; still-active
  /// deposited pigment lifts more gently and staining resists it. The frozen
  /// Dry substrate is never touched.
  WatercolorPickup pickupContact({
    required List<WatercolorSplat> splats,
    required double maximumCarrier,
  }) {
    if (splats.isEmpty || maximumCarrier <= 1e-12) {
      return WatercolorPickup();
    }
    var minX = _s, minY = _s, maxX = -1, maxY = -1;
    for (final splat in splats) {
      final r = math.max(splat.radius, 0.5);
      minX = math.min(minX, math.max(0, (splat.cx - r).floor()));
      minY = math.min(minY, math.max(0, (splat.cy - r).floor()));
      maxX = math.max(maxX, math.min(_s - 1, (splat.cx + r).ceil()));
      maxY = math.max(maxY, math.min(_s - 1, (splat.cy + r).ceil()));
    }
    if (maxX < minX || maxY < minY) return WatercolorPickup();
    for (var y = minY; y <= maxY; y++) {
      _contactPickupWeight.fillRange(
        field.index(minX, y),
        field.index(maxX, y) + 1,
        0.0,
      );
    }

    for (final splat in splats) {
      final r = math.max(splat.radius, 0.5);
      final x0 = math.max(0, (splat.cx - r).floor());
      final y0 = math.max(0, (splat.cy - r).floor());
      final x1 = math.min(_s - 1, (splat.cx + r).ceil());
      final y1 = math.min(_s - 1, (splat.cy + r).ceil());
      // A resting wet brush still wicks a little paint. Dragging engages far
      // more bristle area and therefore collects more of the shared wash.
      final drag = (1.0 - math.exp(-splat.dragSpeed * 0.10)).clamp(0.0, 1.0);
      final contactCoupling = 0.18 + drag * 0.82;
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final dx = x + 0.5 - splat.cx;
          final dy = y + 0.5 - splat.cy;
          final d = math.sqrt(dx * dx + dy * dy) / r;
          if (d >= 1.0) continue;
          _contactPickupWeight[field.index(x, y)] +=
              (1.0 - _smoothstep(0.55, 1.0, d)) * contactCoupling;
        }
      }
    }

    var eligibleWeight = 0.0;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final i = field.index(x, y);
        final mobility = _wetMobilityAt(i);
        if (_contactPickupWeight[i] <= 0.0 || mobility <= 1e-5) continue;
        final surface = _smoothstep(
          0.0,
          math.max(params.wetThreshold * 1.5, 1e-6),
          field.waterH[i],
        );
        eligibleWeight +=
            _contactPickupWeight[i] * mobility * (0.20 + surface * 0.80);
      }
    }
    if (eligibleWeight <= 1e-12) return WatercolorPickup();

    var carrier = 0.0, pigment = 0.0, granulation = 0.0, staining = 0.0;
    final k = List<double>.filled(WatercolorField.bands, 0.0);
    final s = List<double>.filled(WatercolorField.bands, 0.0);
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final i = field.index(x, y);
        final mobility = _wetMobilityAt(i);
        final weight = _contactPickupWeight[i];
        final waterBefore = field.waterH[i];
        if (weight <= 0.0 || mobility <= 1e-5 || waterBefore <= 1e-12) {
          continue;
        }
        final surface = _smoothstep(
          0.0,
          math.max(params.wetThreshold * 1.5, 1e-6),
          waterBefore,
        );
        final effectiveWeight = weight * mobility * (0.20 + surface * 0.80);
        final requested = maximumCarrier * effectiveWeight / eligibleWeight;
        final takenWater = math.min(requested, waterBefore * 0.38);
        if (takenWater <= 1e-12) continue;
        field.waterH[i] = math.max(0.0, waterBefore - takenWater);
        carrier += takenWater;

        final waterShare = (takenWater /
                math.max(waterBefore, params.wetThreshold * 0.25))
            .clamp(0.0, 1.0);
        final suspendedFraction = (waterShare * (0.38 + mobility * 0.42))
            .clamp(0.0, 0.48);
        final pSus = i * WatercolorField.susProps;
        final pDep = i * WatercolorField.depProps;
        final kBase = i * WatercolorField.bands;
        final susLoad = field.propsSus[pSus];
        final activeDepLoad = math.max(
          0.0,
          field.propsDep[pDep] - field.propsDry[pDep],
        );
        final activeStain = math.max(
          0.0,
          field.propsDep[pDep + WatercolorField.depStaining] -
              field.propsDry[pDep + WatercolorField.depStaining],
        );
        final stainAverage = activeDepLoad <= 1e-12
            ? 0.0
            : activeStain / activeDepLoad;
        final depositedFraction =
            (waterShare * mobility * 0.16 * (1.0 - stainAverage * 0.75))
                .clamp(0.0, 0.16);

        final liftedSus = susLoad * suspendedFraction;
        final liftedDep = activeDepLoad * depositedFraction;
        final lifted = liftedSus + liftedDep;
        if (lifted <= 1e-12) continue;
        pigment += lifted;
        for (var band = 0; band < WatercolorField.bands; band++) {
          final susK = field.ksus[kBase + band] * suspendedFraction;
          final susS = field.ssus[kBase + band] * suspendedFraction;
          final activeK = math.max(
            0.0,
            field.kdep[kBase + band] - field.kDry[kBase + band],
          );
          final activeS = math.max(
            0.0,
            field.sdep[kBase + band] - field.sDry[kBase + band],
          );
          final depK = activeK * depositedFraction;
          final depS = activeS * depositedFraction;
          field.ksus[kBase + band] -= susK;
          field.ssus[kBase + band] -= susS;
          field.kdep[kBase + band] -= depK;
          field.sdep[kBase + band] -= depS;
          k[band] += susK + depK;
          s[band] += susS + depS;
        }
        final susGran = field.propsSus[pSus + 1] * suspendedFraction;
        final susStain = field.propsSus[pSus + 2] * suspendedFraction;
        final activeGran = math.max(
          0.0,
          field.propsDep[pDep + WatercolorField.depGranulation] -
              field.propsDry[pDep + WatercolorField.depGranulation],
        );
        final depGran = activeGran * depositedFraction;
        final depStain = activeStain * depositedFraction;
        field.propsSus[pSus] -= liftedSus;
        field.propsSus[pSus + 1] -= susGran;
        field.propsSus[pSus + 2] -= susStain;
        field.propsDep[pDep] -= liftedDep;
        field.propsDep[pDep + WatercolorField.depGranulation] -= depGran;
        field.propsDep[pDep + WatercolorField.depStaining] -= depStain;
        granulation += susGran + depGran;
        staining += susStain + depStain;
      }
    }
    return WatercolorPickup(
      carrier: carrier,
      pigment: pigment,
      k: k,
      s: s,
      granulation: granulation,
      staining: staining,
    );
  }

  // ── Phase A — Splat (brush handoff) ──────────────────────────────

  /// Lay one synthetic splat. Live brush samples use [splatContact] so all
  /// bristle clusters land simultaneously.
  void splat({
    required double cx,
    required double cy,
    required double radius,
    required double pressure,
    double contactPressure = 1.0,
    required List<double> kBand,
    required List<double> sBand,
    required double load,
    required double waterAmt,
    required double gran,
    required double stain,
    double impulseX = 0.0,
    double impulseY = 0.0,
    bool amountsAreTotals = false,
  }) {
    splatContact(
      splats: [
        WatercolorSplat(
          cx: cx,
          cy: cy,
          radius: radius,
          pressure: pressure,
          load: load,
          waterAmt: waterAmt,
          impulseX: impulseX,
          impulseY: impulseY,
        ),
      ],
      contactPressure: contactPressure,
      kBand: kBand,
      sBand: sBand,
      gran: gran,
      stain: stain,
      amountsAreTotals: amountsAreTotals,
    );
  }

  /// Land every bristle cluster in one physical brush sample as a single
  /// simultaneous contact. Incoming pigment, water, and momentum are first
  /// accumulated without mutating the wash. The second pass reads one shared
  /// pre-contact wetness, reopens old active paint once, and then adds the new
  /// colour. This removes cluster-order artifacts and repeated mixing work.
  void splatContact({
    required List<WatercolorSplat> splats,
    required double contactPressure,
    required List<double> kBand,
    required List<double> sBand,
    required double gran,
    required double stain,
    bool amountsAreTotals = false,
  }) {
    if (splats.isEmpty) return;
    // Clear only cells marked by the preceding contact. This avoids a full-grid
    // mask clear for every stylus sample.
    for (final cell in _contactMixCells) {
      _contactMixMask[cell] = 0;
    }
    _contactMixCells.clear();
    var minX = _s;
    var minY = _s;
    var maxX = -1;
    var maxY = -1;
    for (final splat in splats) {
      final r = math.max(splat.radius, 0.5);
      final x0 = math.max(0, (splat.cx - r).floor());
      final y0 = math.max(0, (splat.cy - r).floor());
      final x1 = math.min(_s - 1, (splat.cx + r).ceil());
      final y1 = math.min(_s - 1, (splat.cy + r).ceil());
      if (x0 > x1 || y0 > y1) continue;
      minX = math.min(minX, x0);
      minY = math.min(minY, y0);
      maxX = math.max(maxX, x1);
      maxY = math.max(maxY, y1);
    }
    if (maxX < minX || maxY < minY) return;

    // Clear only the contact rectangle; the full-sheet buffers are reused.
    for (var y = minY; y <= maxY; y++) {
      final start = field.index(minX, y);
      final end = field.index(maxX, y) + 1;
      _contactPigment.fillRange(start, end, 0.0);
      _contactWater.fillRange(start, end, 0.0);
      _contactImpulseX.fillRange(start, end, 0.0);
      _contactImpulseY.fillRange(start, end, 0.0);
    }

    final mom = params.momentum;
    for (final splat in splats) {
      final r = math.max(splat.radius, 0.5);
      final x0 = math.max(0, (splat.cx - r).floor());
      final y0 = math.max(0, (splat.cy - r).floor());
      final x1 = math.min(_s - 1, (splat.cx + r).ceil());
      final y1 = math.min(_s - 1, (splat.cy + r).ceil());
      if (x0 > x1 || y0 > y1) continue;
      final p = splat.pressure.clamp(0.0, 1.0);
      var pigmentFootprintSum = 1.0;
      var waterFootprintSum = 1.0;
      if (amountsAreTotals) {
        pigmentFootprintSum = 0.0;
        waterFootprintSum = 0.0;
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            final dx = x + 0.5 - splat.cx;
            final dy = y + 0.5 - splat.cy;
            final d =
                (math.sqrt(dx * dx + dy * dy) / r).clamp(0.0, 1.0);
            if (d >= 1.0) continue;
            pigmentFootprintSum +=
                (1.0 - _smoothstep(0.55, 1.0, d)) * p;
            waterFootprintSum +=
                (1.0 - _smoothstep(0.7, 1.05, d)) * p;
          }
        }
        pigmentFootprintSum = math.max(pigmentFootprintSum, 1e-12);
        waterFootprintSum = math.max(waterFootprintSum, 1e-12);
      }

      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final dx = x + 0.5 - splat.cx;
          final dy = y + 0.5 - splat.cy;
          final d = (math.sqrt(dx * dx + dy * dy) / r).clamp(0.0, 1.0);
          if (d >= 1.0) continue;
          final footprintPig = (1.0 - _smoothstep(0.55, 1.0, d)) * p;
          final footprintWater = (1.0 - _smoothstep(0.7, 1.05, d)) * p;
          if (footprintPig <= 0.0 && footprintWater <= 0.0) continue;
          final fPig = footprintPig / pigmentFootprintSum;
          final fWater = footprintWater / waterFootprintSum;
          final i = field.index(x, y);
          _contactPigment[i] += splat.load * fPig;
          _contactWater[i] += splat.waterAmt * fWater;
          _contactImpulseX[i] += splat.impulseX * footprintWater * mom;
          _contactImpulseY[i] += splat.impulseY * footprintWater * mom;
          if (splat.waterAmt > 0.0 && d > 1e-4) {
            final dropPush = splat.waterAmt * fWater * 0.05;
            _contactImpulseX[i] += (dx / (r * d)) * dropPush;
            _contactImpulseY[i] += (dy / (r * d)) * dropPush;
          }
        }
      }
    }

    var strongestUnionWetness = 0.0;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final i = field.index(x, y);
        final amt = _contactPigment[i];
        final incomingWater = _contactWater[i];
        if (amt <= 0.0 && incomingWater <= 0.0 &&
            _contactImpulseX[i] == 0.0 && _contactImpulseY[i] == 0.0) {
          continue;
        }
        final priorWetness = _wetMobilityAt(i);
        final kBase = i * WatercolorField.bands;
        final pBase = i * WatercolorField.susProps;
        final depBase = i * WatercolorField.depProps;
        if (amt > 0.0 || incomingWater > 0.0) {
          field.propsDep[depBase + WatercolorField.depDryClock] = 0.0;
        }

        // Re-open only pigment that was active before this whole brush sample.
        // The cumulative incoming water makes this independent of cluster
        // order, so sibling bristles can never lift or freeze one another.
        final priorDepLoad = field.propsDep[depBase];
        final liftableDepLoad = math.max(
          0.0,
          priorDepLoad - field.propsDry[depBase],
        );
        final freshWaterActivation = _smoothstep(
          0.0,
          math.max(params.wetThreshold, 1e-6),
          incomingWater,
        );
        // Accepted carrier may re-wet only active, unprotected paint. It can
        // never bypass propsDry, but it should let a still-damp blue wash and a
        // wet yellow contact become one mobile mixture.
        final colouredContactWetness =
            priorWetness +
            (1.0 - priorWetness) * freshWaterActivation;
        final priorActiveLoad = field.propsSus[pBase] + liftableDepLoad;
        if (amt > 1e-10 &&
            priorActiveLoad > 1e-10 &&
            priorWetness > 0.05) {
          strongestUnionWetness = math.max(
            strongestUnionWetness,
            colouredContactWetness,
          );
          if (_contactMixMask[i] == 0) {
            _contactMixMask[i] = 1;
            _contactMixCells.add(i);
          }
        }
        if (liftableDepLoad > 0.0 &&
            (priorWetness > 1e-4 || incomingWater > 1e-8)) {
          final liftableStain = math.max(
            0.0,
            field.propsDep[depBase + WatercolorField.depStaining] -
                field.propsDry[depBase + WatercolorField.depStaining],
          );
          final liftableGranulation = math.max(
            0.0,
            field.propsDep[depBase + WatercolorField.depGranulation] -
                field.propsDry[depBase + WatercolorField.depGranulation],
          );
          final stainAverage = liftableStain / liftableDepLoad;
          final priorStainResistance =
              (1.0 - stainAverage * (1.0 - priorWetness) * 0.85).clamp(
                0.0,
                1.0,
              );
          final colouredStainResistance =
              (1.0 -
                      stainAverage *
                          (1.0 - colouredContactWetness) *
                          0.85)
                  .clamp(0.0, 1.0);
          // A fully wet crossing is one wash, not a new transparent mark over
          // an old ridge. Re-open nearly all active deposit at M near 1 so old
          // and new spectra occupy the same suspended mixture. Damp paint lifts
          // progressively less unless accepted carrier re-wets it. Protected
          // Dry pigment is excluded above.
          final wetUnion = _smoothstep(
            0.15,
            0.75,
            colouredContactWetness,
          );
          final colouredUnionLift =
              (colouredContactWetness *
                          (0.18 + contactPressure * 0.12) +
                      wetUnion * (0.72 + contactPressure * 0.02))
                  .clamp(0.0, 0.94);
          // Clean water must open a bloom without reviving the old hollow
          // center/Cheerio failure. A coloured crossing needs the stronger
          // union above because both spectra must become one wash immediately.
          final cleanWaterLift =
              (priorWetness * (0.20 + contactPressure * 0.22) +
                      freshWaterActivation *
                          (0.08 + contactPressure * 0.08))
                  .clamp(0.0, 0.46);
          final impactLift = amt > 1e-10
              ? colouredUnionLift * colouredStainResistance
              : cleanWaterLift * priorStainResistance;
          for (var band = 0; band < WatercolorField.bands; band++) {
            final movedK =
                math.max(
                  0.0,
                  field.kdep[kBase + band] - field.kDry[kBase + band],
                ) *
                impactLift;
            final movedS =
                math.max(
                  0.0,
                  field.sdep[kBase + band] - field.sDry[kBase + band],
                ) *
                impactLift;
            field.kdep[kBase + band] -= movedK;
            field.sdep[kBase + band] -= movedS;
            field.ksus[kBase + band] += movedK;
            field.ssus[kBase + band] += movedS;
          }
          final movedLoad = liftableDepLoad * impactLift;
          final movedStain = liftableStain * impactLift;
          field.propsDep[depBase] -= movedLoad;
          field.propsDep[depBase + WatercolorField.depGranulation] -=
              liftableGranulation * impactLift;
          field.propsDep[depBase + WatercolorField.depStaining] -= movedStain;
          field.propsSus[pBase] += movedLoad;
          field.propsSus[pBase + 1] += liftableGranulation * impactLift;
          field.propsSus[pBase + 2] += movedStain;
        }

        field.waterH[i] += incomingWater;
        final valley = 1.0 - paperHeight(x, y).clamp(0.0, 1.0);
        final lightContact = 1.0 - contactPressure.clamp(0.0, 1.0);
        final dryCaught =
            0.12 +
            stain * 0.08 +
            gran * valley * 0.06 +
            lightContact * (0.08 + gran * valley * 0.12);
        final wetCaught = gran * valley * 0.003;
        final catchWetness = amt > 1e-10
            ? colouredContactWetness
            : priorWetness;
        final caughtFraction =
            (dryCaught + (wetCaught - dryCaught) * catchWetness).clamp(
              0.0005,
              0.38,
            );
        final caught = amt * caughtFraction;
        final mobile = amt - caught;
        for (var band = 0; band < WatercolorField.bands; band++) {
          field.ksus[kBase + band] += mobile * kBand[band];
          field.ssus[kBase + band] += mobile * sBand[band];
          field.kdep[kBase + band] += caught * kBand[band];
          field.sdep[kBase + band] += caught * sBand[band];
        }
        field.propsSus[pBase] += mobile;
        field.propsSus[pBase + 1] += mobile * gran;
        field.propsSus[pBase + 2] += mobile * stain;
        field.propsDep[depBase] += caught;
        field.propsDep[depBase + WatercolorField.depGranulation] +=
            caught * gran;
        field.propsDep[depBase + WatercolorField.depStaining] += caught * stain;
        field.velU[i] += _contactImpulseX[i];
        field.velV[i] += _contactImpulseY[i];
      }
    }

    if (_contactMixCells.isNotEmpty) {
      _mixWetContactRegion(strongestUnionWetness);
    }
  }

  void _mixWetContactRegion(double strength) {
    // Grow three face-connected wet cells from each true old/new-colour
    // overlap. Unlike one bounding rectangle, this does not process empty
    // space between separated bristle islands on a broad brush.
    var frontierStart = 0;
    var frontierEnd = _contactMixCells.length;
    for (var expansion = 0; expansion < 3; expansion++) {
      for (var position = frontierStart; position < frontierEnd; position++) {
        final cell = _contactMixCells[position];
        final x = cell % _s;
        final y = cell ~/ _s;
        if (x > 0) _includeMixCell(cell - 1);
        if (x + 1 < _s) _includeMixCell(cell + 1);
        if (y > 0) _includeMixCell(cell - _s);
        if (y + 1 < _s) _includeMixCell(cell + _s);
      }
      frontierStart = frontierEnd;
      frontierEnd = _contactMixCells.length;
      if (frontierStart == frontierEnd) break;
    }

    // This is a short, contact-local union pass, not the bulk motion model.
    // Wet crossings need enough conservative exchange to erase the old seam;
    // damp joins remain gentler and retain more paper-tooth variation.
    final rate = (0.08 + strength * 0.14).clamp(0.0, 0.22);
    final iterations = strength > 0.75 ? 5 : (strength > 0.35 ? 3 : 2);
    for (var iteration = 0; iteration < iterations; iteration++) {
      for (final a in _contactMixCells) {
        final x = a % _s;
        final y = a ~/ _s;
        if (x + 1 < _s && _contactMixMask[a + 1] != 0) {
          _exchangeWetPair(a, a + 1, rate);
        }
        if (y + 1 < _s && _contactMixMask[a + _s] != 0) {
          _exchangeWetPair(a, a + _s, rate);
        }
      }
    }
  }

  void _includeMixCell(int cell) {
    if (_contactMixMask[cell] != 0 || _wetMobilityAt(cell) <= 1e-4) return;
    _contactMixMask[cell] = 1;
    _contactMixCells.add(cell);
  }

  void _exchangeWetPair(int a, int b, double rate) {
    final wetA = _wetMobilityAt(a);
    final wetB = _wetMobilityAt(b);
    if (wetA <= 1e-4 || wetB <= 1e-4) return;
    final pa = a * WatercolorField.susProps;
    final pb = b * WatercolorField.susProps;
    if (field.propsSus[pa] <= 1e-12 && field.propsSus[pb] <= 1e-12) {
      return;
    }
    final coupling = math.sqrt(wetA * wetB);
    final exchange = rate * coupling;
    final ka = a * WatercolorField.bands;
    final kb = b * WatercolorField.bands;
    for (var band = 0; band < WatercolorField.bands; band++) {
      final dk = (field.ksus[ka + band] - field.ksus[kb + band]) * exchange;
      final ds = (field.ssus[ka + band] - field.ssus[kb + band]) * exchange;
      field.ksus[ka + band] -= dk;
      field.ksus[kb + band] += dk;
      field.ssus[ka + band] -= ds;
      field.ssus[kb + band] += ds;
    }
    for (var channel = 0; channel < WatercolorField.susProps; channel++) {
      final delta =
          (field.propsSus[pa + channel] - field.propsSus[pb + channel]) *
          exchange;
      field.propsSus[pa + channel] -= delta;
      field.propsSus[pb + channel] += delta;
    }
  }

  // ── Active region ────────────────────────────────────────────────
  //
  // Every simulation pass runs only in activity tiles around cells that can
  // still change: wet, saturated, carrying suspended pigment or velocity, or
  // holding an unprotected deposit whose dry clock is counting. The outer box
  // bounds the loops; the work mask skips dry tiles inside that box.
  // The box is re-derived from the fields at the start of every step (a
  // full-grid scan is a few hundred microseconds — far cheaper than one
  // pass), so direct field writes, checkpoints, and tests need no hooks.
  // This is the CPU stand-in for the spec's activity tiling; correctness is
  // unchanged because everything outside the box is exactly the fixed point
  // of every pass.

  int _boxX0 = 0, _boxY0 = 0, _boxX1 = -1, _boxY1 = -1;

  /// Diagnostics used by the performance regression. These count actual CPU
  /// work cells, not merely the rectangle enclosing every wet mark.
  int get debugActiveWorkCellCount => _activeWorkCellCount;
  int get debugActiveBoxCellCount =>
      _boxX1 < _boxX0 ? 0 : (_boxX1 - _boxX0 + 1) * (_boxY1 - _boxY0 + 1);

  /// Rebuild the active tile mask and its one-tile halo. Returns false when
  /// nothing on the sheet can still change (fully dry, settled, and finalized).
  bool _scanActiveBox() {
    final h = field.waterH;
    final sat = field.saturation;
    final u = field.velU;
    final v = field.velV;
    final propsSus = field.propsSus;
    final propsDep = field.propsDep;
    final propsDry = field.propsDry;
    _activeTileMask.fillRange(0, _activeTileMask.length, 0);
    _expandedTileMask.fillRange(0, _expandedTileMask.length, 0);
    _activeWorkMask.fillRange(0, _activeWorkMask.length, 0);
    var foundActive = false;
    for (var y = 0; y < _s; y++) {
      final row = y * _s;
      for (var x = 0; x < _s; x++) {
        final i = row + x;
        // Capillary and pressure arithmetic can leave microscopic positive
        // tails far outside the visible wash. Treat values many orders below
        // the wet/mobility thresholds as the physical zero they represent;
        // otherwise one invisible trace keeps an entire halo tile alive.
        if (h[i].abs() < 1e-6) h[i] = 0.0;
        if (sat[i].abs() < 1e-6) sat[i] = 0.0;
        if (u[i].abs() < 1e-5) u[i] = 0.0;
        if (v[i].abs() < 1e-5) v[i] = 0.0;
        final active =
            h[i] > 0.0 ||
            sat[i] > 0.0 ||
            u[i] != 0.0 ||
            v[i] != 0.0 ||
            propsSus[i * WatercolorField.susProps] > 1e-12 ||
            // Unprotected deposit: keeps the dry clock counting until the
            // wet→dry transition finalizes and locks this cell.
            propsDep[i * WatercolorField.depProps] -
                    propsDry[i * WatercolorField.depProps] >
                1e-12;
        if (active) {
          foundActive = true;
          final tileX = x ~/ _activeTileSize;
          final tileY = y ~/ _activeTileSize;
          _activeTileMask[tileY * _activeTileColumns + tileX] = 1;
        }
      }
    }
    if (!foundActive) {
      _boxX0 = 0;
      _boxY0 = 0;
      _boxX1 = -1;
      _boxY1 = -1;
      _activeWorkCellCount = 0;
      return false;
    }

    // Expand each active tile by one complete tile. Sixteen cells is wider
    // than the maximum one-frame transport reach and avoids seams at borders.
    for (var tileY = 0; tileY < _activeTileRows; tileY++) {
      for (var tileX = 0; tileX < _activeTileColumns; tileX++) {
        if (_activeTileMask[tileY * _activeTileColumns + tileX] == 0) continue;
        final haloY0 = math.max(0, tileY - 1);
        final haloY1 = math.min(_activeTileRows - 1, tileY + 1);
        final haloX0 = math.max(0, tileX - 1);
        final haloX1 = math.min(_activeTileColumns - 1, tileX + 1);
        for (var haloY = haloY0; haloY <= haloY1; haloY++) {
          for (var haloX = haloX0; haloX <= haloX1; haloX++) {
            _expandedTileMask[haloY * _activeTileColumns + haloX] = 1;
          }
        }
      }
    }

    var x0 = _s, y0 = _s, x1 = -1, y1 = -1;
    _activeWorkCellCount = 0;
    for (var tileY = 0; tileY < _activeTileRows; tileY++) {
      for (var tileX = 0; tileX < _activeTileColumns; tileX++) {
        if (_expandedTileMask[tileY * _activeTileColumns + tileX] == 0) continue;
        final tileX0 = tileX * _activeTileSize;
        final tileY0 = tileY * _activeTileSize;
        final tileX1 = math.min(_s - 1, tileX0 + _activeTileSize - 1);
        final tileY1 = math.min(_s - 1, tileY0 + _activeTileSize - 1);
        if (tileX0 < x0) x0 = tileX0;
        if (tileY0 < y0) y0 = tileY0;
        if (tileX1 > x1) x1 = tileX1;
        if (tileY1 > y1) y1 = tileY1;
        final rowWidth = tileX1 - tileX0 + 1;
        for (var y = tileY0; y <= tileY1; y++) {
          final start = y * _s + tileX0;
          _activeWorkMask.fillRange(start, start + rowWidth, 1);
          _activeWorkCellCount += rowWidth;
        }
      }
    }
    _boxX0 = x0;
    _boxY0 = y0;
    _boxX1 = x1;
    _boxY1 = y1;
    return true;
  }

  /// Zero only active tile runs in an interleaved out-buffer. Other cells keep
  /// their [source] values while scatter passes accumulate into the runs.
  void _prepareScatterOut(Float32List out, Float32List source, int stride) {
    out.setAll(0, source);
    for (var y = _boxY0; y <= _boxY1; y++) {
      var runStart = -1;
      for (var x = _boxX0; x <= _boxX1 + 1; x++) {
        final working =
            x <= _boxX1 && _activeWorkMask[y * _s + x] != 0;
        if (working && runStart < 0) {
          runStart = x;
        } else if (!working && runStart >= 0) {
          final start = (y * _s + runStart) * stride;
          final end = (y * _s + x) * stride;
          out.fillRange(start, end, 0.0);
          runStart = -1;
        }
      }
    }
  }

  // ── Per-frame step ───────────────────────────────────────────────

  void step() {
    if (!_scanActiveBox()) return;
    if (params.transportMode == WatercolorTransportMode.fluid) {
      _fluidVelocitySolve();
      _advectSuspendedFluid();
      _advectSurfaceWater();
      // Microscopic dispersion softens transport without becoming the motion
      // model. The historical fallback uses the full authored bleed value.
      for (var i = 0; i < params.bleedIters; i++) {
        _bleed(scale: 0.55);
      }
    } else {
      _momentumAdvect();
      for (var i = 0; i < params.bleedIters; i++) {
        _bleed();
      }
    }
    _water();
    _edgeAccumulate();
    _settleLift();
  }

  int _cl(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  double _bilinearBand(
    Float32List f,
    double x,
    double y, {
    required int band,
    required int stride,
  }) {
    final cx = x.clamp(0.5, _s - 1.5);
    final cy = y.clamp(0.5, _s - 1.5);
    final x0 = cx.floor();
    final y0 = cy.floor();
    final fx = cx - x0;
    final fy = cy - y0;
    final x1 = _cl(x0 + 1, 0, _s - 1);
    final y1 = _cl(y0 + 1, 0, _s - 1);
    final v00 = f[(y0 * _s + x0) * stride + band];
    final v10 = f[(y0 * _s + x1) * stride + band];
    final v01 = f[(y1 * _s + x0) * stride + band];
    final v11 = f[(y1 * _s + x1) * stride + band];
    final top = v00 + (v10 - v00) * fx;
    final bot = v01 + (v11 - v01) * fx;
    return top + (bot - top) * fy;
  }

  double _bilinearScalar(Float32List f, double x, double y) {
    final cx = x.clamp(0.5, _s - 1.5);
    final cy = y.clamp(0.5, _s - 1.5);
    final x0 = cx.floor(), y0 = cy.floor();
    final x1 = _cl(x0 + 1, 0, _s - 1);
    final y1 = _cl(y0 + 1, 0, _s - 1);
    final fx = cx - x0, fy = cy - y0;
    final top = f[y0 * _s + x0] * (1.0 - fx) + f[y0 * _s + x1] * fx;
    final bottom = f[y1 * _s + x0] * (1.0 - fx) + f[y1 * _s + x1] * fx;
    return top * (1.0 - fy) + bottom * fy;
  }

  // ── Binding Fluid solve: advect → force → viscosity → project ────

  void _fluidVelocitySolve() {
    final x0 = _boxX0, x1 = _boxX1, y0 = _boxY0, y1 = _boxY1;
    var u = field.velU;
    var v = field.velV;
    var uo = field.velUOut;
    var vo = field.velVOut;

    // Self-advection (gather). Outside the active box velocity is zero and
    // stays zero, so the out-buffer starts as a copy.
    uo.setAll(0, u);
    vo.setAll(0, v);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        uo[i] = _bilinearScalar(u, x - u[i], y - v[i]);
        vo[i] = _bilinearScalar(v, x - u[i], y - v[i]);
      }
    }
    field.swapVelocity();
    u = field.velU;
    v = field.velV;

    // Shallow-water height force: high cells push toward lower neighbors.
    final h = field.waterH, sat = field.saturation;
    final force = params.heightForce;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final l = y * _s + _cl(x - 1, 0, _s - 1);
        final r = y * _s + _cl(x + 1, 0, _s - 1);
        final d = _cl(y - 1, 0, _s - 1) * _s + x;
        final up = _cl(y + 1, 0, _s - 1) * _s + x;
        final gx = 0.5 * ((h[r] + sat[r]) - (h[l] + sat[l]));
        final gy = 0.5 * ((h[up] + sat[up]) - (h[d] + sat[d]));
        u[i] = (u[i] - force * gx).clamp(-3.0, 3.0);
        v[i] = (v[i] - force * gy).clamp(-3.0, 3.0);
      }
    }

    // Implicit-style viscosity Jacobi.
    final nu = params.viscosity;
    for (var iter = 0; iter < params.viscosityIters; iter++) {
      u = field.velU;
      v = field.velV;
      uo = field.velUOut;
      vo = field.velVOut;
      uo.setAll(0, u);
      vo.setAll(0, v);
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final i = y * _s + x;
          if (_activeWorkMask[i] == 0) continue;
          final l = y * _s + _cl(x - 1, 0, _s - 1);
          final r = y * _s + _cl(x + 1, 0, _s - 1);
          final d = _cl(y - 1, 0, _s - 1) * _s + x;
          final up = _cl(y + 1, 0, _s - 1) * _s + x;
          uo[i] = (u[i] + nu * (u[l] + u[r] + u[d] + u[up])) / (1.0 + 4.0 * nu);
          vo[i] = (v[i] + nu * (v[l] + v[r] + v[d] + v[up])) / (1.0 + 4.0 * nu);
        }
      }
      field.swapVelocity();
    }

    // Divergence and pressure projection. Pressure is zero outside the box
    // (dry sheet); both ping-pong buffers start cleared so box-only Jacobi
    // iterations read zeros across the boundary exactly as before.
    u = field.velU;
    v = field.velV;
    final div = field.divergence;
    div.fillRange(0, div.length, 0.0);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final l = y * _s + _cl(x - 1, 0, _s - 1);
        final r = y * _s + _cl(x + 1, 0, _s - 1);
        final d = _cl(y - 1, 0, _s - 1) * _s + x;
        final up = _cl(y + 1, 0, _s - 1) * _s + x;
        div[i] = 0.5 * ((u[r] - u[l]) + (v[up] - v[d]));
      }
    }
    field.pressure.fillRange(0, field.pressure.length, 0.0);
    field.pressureOut.fillRange(0, field.pressureOut.length, 0.0);
    for (var iter = 0; iter < params.pressureIters; iter++) {
      final p = field.pressure, po = field.pressureOut;
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final i = y * _s + x;
          if (_activeWorkMask[i] == 0) continue;
          final l = y * _s + _cl(x - 1, 0, _s - 1);
          final r = y * _s + _cl(x + 1, 0, _s - 1);
          final d = _cl(y - 1, 0, _s - 1) * _s + x;
          final up = _cl(y + 1, 0, _s - 1) * _s + x;
          po[i] = (p[l] + p[r] + p[d] + p[up] - div[i]) * 0.25;
        }
      }
      field.swapPressure();
    }
    final p = field.pressure;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final l = y * _s + _cl(x - 1, 0, _s - 1);
        final r = y * _s + _cl(x + 1, 0, _s - 1);
        final d = _cl(y - 1, 0, _s - 1) * _s + x;
        final up = _cl(y + 1, 0, _s - 1) * _s + x;
        final wet = h[i] + sat[i] > params.wetThreshold * 0.35;
        if (!wet || x == 0 || y == 0 || x == _s - 1 || y == _s - 1) {
          u[i] = 0.0;
          v[i] = 0.0;
        } else {
          // Shallow watercolor is not a sealed incompressible volume: drops
          // and brush loading locally change height. Project most divergence
          // out of tangential motion while retaining part of that legitimate
          // free-surface expansion.
          const projectionStrength = 0.68;
          final projectedU = u[i] - projectionStrength * 0.5 * (p[r] - p[l]);
          final projectedV = v[i] - projectionStrength * 0.5 * (p[up] - p[d]);
          // A free watercolor surface is shallow and may locally converge or
          // diverge as height changes. Preserve a bounded residual height flow
          // after projecting brush momentum; otherwise projection cancels the
          // entire conservative height force and puddles cannot redistribute.
          final gx = 0.5 * ((h[r] + sat[r]) - (h[l] + sat[l]));
          final gy = 0.5 * ((h[up] + sat[up]) - (h[d] + sat[d]));
          // Tilt is applied after pressure projection. A constant downhill
          // force applied before projection is interpreted as divergence and
          // largely cancelled, which made the canvas-tilt control inert.
          u[i] =
              (projectedU - force * 0.28 * gx + params.gravityX).clamp(
                -3.0,
                3.0,
              ) *
              0.985;
          v[i] =
              (projectedV - force * 0.28 * gy + params.gravityY).clamp(
                -3.0,
                3.0,
              ) *
              0.985;
        }
      }
    }
  }

  void _advectSuspendedFluid() {
    final x0 = _boxX0, x1 = _boxX1, y0 = _boxY0, y1 = _boxY1;
    final u = field.velU, v = field.velV;
    final h = field.waterH, sat = field.saturation;
    final ksus = field.ksus, ssus = field.ssus, props = field.propsSus;
    final ko = field.ksusOut, so = field.ssusOut, po = field.propsSusOut;
    const bands = WatercolorField.bands, np = WatercolorField.susProps;
    final boundaryDistance = _wetBoundaryDistance();
    // Scatter pass: box cells redistribute (remain + moved); everything
    // outside keeps its value, including one-cell spill across the box edge,
    // which stays conservative because the donor keeps only its remainder.
    _prepareScatterOut(ko, ksus, bands);
    _prepareScatterOut(so, ssus, bands);
    _prepareScatterOut(po, props, np);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final l = y * _s + _cl(x - 1, 0, _s - 1);
        final r = y * _s + _cl(x + 1, 0, _s - 1);
        final d = _cl(y - 1, 0, _s - 1) * _s + x;
        final up = _cl(y + 1, 0, _s - 1) * _s + x;
        final ddx = 0.5 * (boundaryDistance[r] - boundaryDistance[l]);
        final ddy = 0.5 * (boundaryDistance[up] - boundaryDistance[d]);
        final dl = math.sqrt(ddx * ddx + ddy * ddy);
        // Edge flow is a gentle drying-boundary bias, not a radial pigment
        // ejector. Stronger values hollowed every mark into a "Cheerio".
        final edgeSpeed = params.edge * 0.025;
        final vx = u[i] + (dl > 1e-5 ? -ddx / dl * edgeSpeed : 0.0);
        final vy = v[i] + (dl > 1e-5 ? -ddy / dl * edgeSpeed : 0.0);
        var fx = (vx.abs() * 0.42).clamp(0.0, 0.42);
        var fy = (vy.abs() * 0.42).clamp(0.0, 0.42);
        final moved = fx + fy;
        if (moved > 0.78) {
          final scale = 0.78 / moved;
          fx *= scale;
          fy *= scale;
        }
        final tx = _cl(x + (vx >= 0 ? 1 : -1), 0, _s - 1);
        final ty = _cl(y + (vy >= 0 ? 1 : -1), 0, _s - 1);
        final ix = y * _s + tx;
        final iy = ty * _s + x;
        if (h[ix] + sat[ix] <= params.wetThreshold * 0.2 ||
            (field.waterM[i] > 0.0 && field.waterM[ix] < 0.25)) {
          fx = 0.0;
        }
        if (h[iy] + sat[iy] <= params.wetThreshold * 0.2 ||
            (field.waterM[i] > 0.0 && field.waterM[iy] < 0.25)) {
          fy = 0.0;
        }
        final remain = 1.0 - fx - fy;
        for (var b = 0; b < bands; b++) {
          final src = i * bands + b;
          final k = ksus[src], sValue = ssus[src];
          ko[src] += k * remain;
          so[src] += sValue * remain;
          ko[ix * bands + b] += k * fx;
          so[ix * bands + b] += sValue * fx;
          ko[iy * bands + b] += k * fy;
          so[iy * bands + b] += sValue * fy;
        }
        for (var c = 0; c < np; c++) {
          final src = i * np + c;
          final value = props[src];
          po[src] += value * remain;
          po[ix * np + c] += value * fx;
          po[iy * np + c] += value * fy;
        }
      }
    }
    field.swapSuspended();
  }

  /// Approximate distance to the nearest dry boundary. Its negative gradient
  /// gives each wet cell a local capillary direction toward its own drying
  /// edge, including long and curved marks where a global radial push fails.
  Float32List _wetBoundaryDistance() {
    final dist = field.divergence;
    final h = field.waterH, sat = field.saturation;
    const far = 10000.0;
    // Everything outside the active box is dry (distance 0); the chamfer
    // sweeps read those zeros across the box edge, which is exactly correct.
    dist.fillRange(0, dist.length, 0.0);
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        dist[i] = h[i] + sat[i] > params.wetThreshold * 0.35 ? far : 0.0;
      }
    }
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        var value = dist[i];
        if (x > 0) value = math.min(value, dist[i - 1] + 1.0);
        if (y > 0) value = math.min(value, dist[i - _s] + 1.0);
        dist[i] = value;
      }
    }
    for (var y = _boxY1; y >= _boxY0; y--) {
      for (var x = _boxX1; x >= _boxX0; x--) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        var value = dist[i];
        if (x + 1 < _s) value = math.min(value, dist[i + 1] + 1.0);
        if (y + 1 < _s) value = math.min(value, dist[i + _s] + 1.0);
        dist[i] = value;
      }
    }
    return dist;
  }

  void _advectSurfaceWater() {
    final h = field.waterH, out = field.waterHOut;
    final u = field.velU, v = field.velV;
    _prepareScatterOut(out, h, 1);
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        var fx = (u[i].abs() * 0.42).clamp(0.0, 0.42);
        var fy = (v[i].abs() * 0.42).clamp(0.0, 0.42);
        final moved = fx + fy;
        if (moved > 0.78) {
          final scale = 0.78 / moved;
          fx *= scale;
          fy *= scale;
        }
        final tx = _cl(x + (u[i] >= 0 ? 1 : -1), 0, _s - 1);
        final ty = _cl(y + (v[i] >= 0 ? 1 : -1), 0, _s - 1);
        final ix = y * _s + tx;
        final iy = ty * _s + x;
        final remain = 1.0 - fx - fy;
        final amount = h[i];
        out[i] += amount * remain;
        out[ix] += amount * fx;
        out[iy] += amount * fy;
      }
    }
    field.swapWater();
  }

  /// Coffee-ring transport: a drying boundary draws suspended pigment from
  /// its wetter immediate neighbor before settling. This is conservative and
  /// distinct from blur—the donor loses exactly what the rim cell gains.
  void _edgeAccumulate() {
    final m = field.waterM;
    final k = field.ksus, s = field.ssus, props = field.propsSus;
    final ko = field.ksusOut, so = field.ssusOut, po = field.propsSusOut;
    ko.setAll(0, k);
    so.setAll(0, s);
    po.setAll(0, props);
    const bands = WatercolorField.bands, np = WatercolorField.susProps;
    final ey0 = math.max(1, _boxY0), ey1 = math.min(_s - 2, _boxY1);
    final ex0 = math.max(1, _boxX0), ex1 = math.min(_s - 2, _boxX1);
    for (var y = ey0; y <= ey1; y++) {
      for (var x = ex0; x <= ex1; x++) {
        final target = y * _s + x;
        if (_activeWorkMask[target] == 0) continue;
        final mt = m[target];
        if (mt <= 0.04 || mt >= 0.92) continue;
        var donor = target;
        final left = target - 1;
        final right = target + 1;
        final down = target - _s;
        final up = target + _s;
        if (m[left] > m[donor]) donor = left;
        if (m[right] > m[donor]) donor = right;
        if (m[down] > m[donor]) donor = down;
        if (m[up] > m[donor]) donor = up;
        final delta = m[donor] - mt;
        if (delta <= 0.02) continue;
        final frac = (params.edge * 0.055 * delta).clamp(0.0, 0.12);
        for (var band = 0; band < bands; band++) {
          final from = donor * bands + band;
          final to = target * bands + band;
          final movedK = k[from] * frac;
          final movedS = s[from] * frac;
          ko[from] -= movedK;
          so[from] -= movedS;
          ko[to] += movedK;
          so[to] += movedS;
        }
        for (var c = 0; c < np; c++) {
          final from = donor * np + c;
          final to = target * np + c;
          final moved = props[from] * frac;
          po[from] -= moved;
          po[to] += moved;
        }
      }
    }
    // Clamp only active tile cells: elsewhere the out-buffers are untouched
    // non-negative copies of the source.
    for (var y = ey0; y <= ey1; y++) {
      for (var x = ex0; x <= ex1; x++) {
        final cell = y * _s + x;
        if (_activeWorkMask[cell] == 0) continue;
        final kStart = cell * bands;
        for (var i = kStart; i < kStart + bands; i++) {
          if (ko[i] < 0.0) ko[i] = 0.0;
          if (so[i] < 0.0) so[i] = 0.0;
        }
        final pStart = cell * np;
        for (var i = pStart; i < pStart + np; i++) {
          if (po[i] < 0.0) po[i] = 0.0;
        }
      }
    }
    field.swapSuspended();
  }

  // ── 1. Momentum advect ───────────────────────────────────────────

  void _momentumAdvect() {
    final u = field.velU, v = field.velV, m = field.waterM;
    final h = field.waterH, s = field.saturation;
    final ksus = field.ksus, ssus = field.ssus, props = field.propsSus;
    final ko = field.ksusOut, so = field.ssusOut, po = field.propsSusOut;
    const bands = WatercolorField.bands;
    const np = WatercolorField.susProps;
    // Edge-drive: carry suspended pigment gently down the wetness gradient
    // (toward the drying rim), so a drying wash concentrates pigment at its
    // edge instead of dumping it wherever it dries. Scales with `edge`.
    final eK = 0.48 * params.edge;
    final wetThr = params.wetThreshold;

    // Gather pass: box cells re-sample; the rest keeps its values.
    ko.setAll(0, ksus);
    so.setAll(0, ssus);
    po.setAll(0, props);
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final kBase = i * bands;
        final pBase = i * np;
        var vx = u[i];
        var vy = v[i];
        if (m[i] > wetThr) {
          final iL = y * _s + _cl(x - 1, 0, _s - 1);
          final iR = y * _s + _cl(x + 1, 0, _s - 1);
          final iD = _cl(y - 1, 0, _s - 1) * _s + x;
          final iU = _cl(y + 1, 0, _s - 1) * _s + x;
          vx -= eK * 0.5 * ((h[iR] + s[iR]) - (h[iL] + s[iL]));
          vy -= eK * 0.5 * ((h[iU] + s[iU]) - (h[iD] + s[iD]));
        }
        if (vx * vx + vy * vy < 1e-8) {
          for (var b = 0; b < bands; b++) {
            ko[kBase + b] = ksus[kBase + b];
            so[kBase + b] = ssus[kBase + b];
          }
          for (var c = 0; c < np; c++) {
            po[pBase + c] = props[pBase + c];
          }
          continue;
        }
        final bx = x - vx;
        final by = y - vy;
        for (var b = 0; b < bands; b++) {
          ko[kBase + b] = _bilinearBand(ksus, bx, by, band: b, stride: bands);
          so[kBase + b] = _bilinearBand(ssus, bx, by, band: b, stride: bands);
        }
        for (var c = 0; c < np; c++) {
          po[pBase + c] = _bilinearBand(props, bx, by, band: c, stride: np);
        }
      }
    }
    field.swapSuspended();

    // Decay momentum; kill it where dry.
    final damp = params.velDamp;
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        if (m[i] <= 0.02) {
          u[i] = 0.0;
          v[i] = 0.0;
        } else {
          u[i] *= damp;
          v[i] *= damp;
        }
      }
    }
  }

  // ── 2. Bleed (wet-into-wet diffusion) ────────────────────────────

  void _bleed({double scale = 1.0}) {
    final h = field.waterH, s = field.saturation;
    final ksus = field.ksus, ssus = field.ssus, props = field.propsSus;
    final ko = field.ksusOut, so = field.ssusOut, po = field.propsSusOut;
    // A four-neighbour explicit exchange stays non-negative at <= 0.25.
    final bleed = (params.bleed * scale).clamp(0.0, 0.24);

    // Start with the old state, then apply every face flux as an equal and
    // opposite pair. The old one-sided wetness-weighted Laplacian could create
    // or destroy pigment wherever a wet cell met a damp one.
    ko.setAll(0, ksus);
    so.setAll(0, ssus);
    po.setAll(0, props);
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final a = y * _s + x;
        if (_activeWorkMask[a] == 0) continue;
        if (x + 1 < _s) {
          _bleedPair(a, a + 1, bleed, h, s, ksus, ssus, props, ko, so, po);
        }
        if (y + 1 < _s) {
          _bleedPair(a, a + _s, bleed, h, s, ksus, ssus, props, ko, so, po);
        }
      }
    }
    field.swapSuspended();
  }

  void _bleedPair(
    int a,
    int b,
    double rate,
    Float32List h,
    Float32List saturation,
    Float32List ksus,
    Float32List ssus,
    Float32List props,
    Float32List kOut,
    Float32List sOut,
    Float32List propsOut,
  ) {
    final wetA = _wetMobilityValues(h[a], saturation[a]);
    final wetB = _wetMobilityValues(h[b], saturation[b]);
    if (wetA <= 1e-4 || wetB <= 1e-4) return;
    final exchange = rate * math.sqrt(wetA * wetB);
    const bands = WatercolorField.bands;
    const propsCount = WatercolorField.susProps;
    final ka = a * bands;
    final kb = b * bands;
    for (var band = 0; band < bands; band++) {
      final kFlux = (ksus[ka + band] - ksus[kb + band]) * exchange;
      final sFlux = (ssus[ka + band] - ssus[kb + band]) * exchange;
      kOut[ka + band] -= kFlux;
      kOut[kb + band] += kFlux;
      sOut[ka + band] -= sFlux;
      sOut[kb + band] += sFlux;
    }
    final pa = a * propsCount;
    final pb = b * propsCount;
    for (var channel = 0; channel < propsCount; channel++) {
      final flux = (props[pa + channel] - props[pb + channel]) * exchange;
      propsOut[pa + channel] -= flux;
      propsOut[pb + channel] += flux;
    }
  }

  // ── 3. Water: capillary spread, soak, evaporate, mask ────────────

  void _water() {
    final h = field.waterH, s = field.saturation;
    final hOut = field.waterHOut;
    final spread = params.wetSpread;

    // Conservative capillary spread. Water prefers connected low paper
    // valleys, producing branching, irregular wet fronts instead of a round
    // four-neighbour blur. Every transfer is removed from its donor, so this
    // pass cannot manufacture water.
    hOut.setAll(0, h);
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        if (x + 1 < _s) {
          _capillaryPair(i, i + 1, x, y, x + 1, y, h, hOut, spread);
        }
        if (y + 1 < _s) {
          _capillaryPair(i, i + _s, x, y, x, y + 1, h, hOut, spread);
        }
      }
    }
    field.swapWater(); // swaps h and m buffers; m recomputed below
    final h2 = field.waterH;
    final m2 = field.waterM;
    // Carry last step's mask over the whole sheet before recomputing the
    // active box, so cells outside the box (long dry, mask 0) never expose a
    // stale value from the ping-pong buffer.
    m2.setAll(0, field.waterMOut);
    final dry = params.dry;
    final paperDry = dry * params.paperDryFactor;
    final soak = params.soak;
    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final room = math.max(0.0, paperCapacity(x, y) - s[i]);
        final absorb = math.min(h2[i] * soak, room);
        h2[i] = math.max(0.0, h2[i] - absorb - dry);
        // Losing surface shine does not make the paper instantly dry. Keep the
        // normal paper rate throughout the workable damp interval; accelerate
        // only the sub-threshold tail after mobility has already reached zero,
        // so the live ticker still stops instead of nursing invisible water.
        final belowMobilePaper =
            s[i] <= params.wetThreshold * 0.20 && h2[i] <= 1e-6;
        final exposedDry = belowMobilePaper ? paperDry * 3.0 : paperDry;
        s[i] = math.max(0.0, s[i] + absorb - exposedDry);
        m2[i] = _wetMobilityValues(h2[i], s[i]);
      }
    }
  }

  void _capillaryPair(
    int a,
    int b,
    int ax,
    int ay,
    int bx,
    int by,
    Float32List h,
    Float32List out,
    double spread,
  ) {
    final delta = h[a] - h[b];
    if (delta.abs() < 1e-8) return;
    final valleyA = 1.0 - paperHeight(ax, ay).clamp(0.0, 1.0);
    final valleyB = 1.0 - paperHeight(bx, by).clamp(0.0, 1.0);
    // Squaring strongly favours continuous valleys and is intentionally kept
    // arithmetic-only: this inner loop runs for every wet simulation cell.
    final valleyConnection = (valleyA * valleyB).clamp(0.0, 1.0);
    final connection = valleyConnection * valleyConnection;
    final conductance = 0.12 + 0.88 * connection;
    final moved = delta * spread * 0.20 * conductance;
    out[a] -= moved;
    out[b] += moved;
  }

  // ── 4. Settle + lift ─────────────────────────────────────────────

  void _settleLift() {
    final ksus = field.ksus, ssus = field.ssus, props = field.propsSus;
    final kdep = field.kdep, sdep = field.sdep, pdep = field.propsDep;
    final kDry = field.kDry, sDry = field.sDry, pDry = field.propsDry;
    final m = field.waterM;
    final settle = params.settle, lift = params.lift, edge = params.edge;
    const bands = WatercolorField.bands;

    for (var y = _boxY0; y <= _boxY1; y++) {
      for (var x = _boxX0; x <= _boxX1; x++) {
        final i = y * _s + x;
        if (_activeWorkMask[i] == 0) continue;
        final ps = i * WatercolorField.susProps;
        final pd = i * WatercolorField.depProps;
        final loadSus = props[ps];
        final granSus = props[ps + 1];
        final stainSus = props[ps + 2];

        final mC = m[i];
        final dryness = 1.0 - mC;
        // Wetness gradient magnitude → drying-edge concentration.
        final mL = m[y * _s + _cl(x - 1, 0, _s - 1)];
        final mR = m[y * _s + _cl(x + 1, 0, _s - 1)];
        final mD = m[_cl(y - 1, 0, _s - 1) * _s + x];
        final mU = m[_cl(y + 1, 0, _s - 1) * _s + x];
        final gx = 0.5 * (mR - mL);
        final gy = 0.5 * (mU - mD);
        final grad = math.sqrt(gx * gx + gy * gy);

        final activeDeposit = math.max(0.0, pdep[pd] - pDry[pd]);
        final hasActivePigment = loadSus > 1e-10 || activeDeposit > 1e-10;
        var dryClock = pdep[pd + WatercolorField.depDryClock];
        if (!hasActivePigment) {
          dryClock = 0.0;
        } else if (mC <= params.wetOff) {
          dryClock += params.stepSeconds;
        } else if (mC >= params.wetOn) {
          dryClock = 0.0;
        } else {
          dryClock = math.max(0.0, dryClock - params.stepSeconds);
        }
        pdep[pd + WatercolorField.depDryClock] = dryClock;
        final dryLocked =
            hasActivePigment && dryClock >= params.dryHoldSeconds;

        // Fully wet paint stays suspended. Settling ramps in as the local
        // water film dries. Granulating pigment settles more readily in paper
        // valleys, where physical grains collect instead of forming a flat,
        // texture-blind deposit.
        final granAverage = granSus / math.max(loadSus, 1e-4);
        final valley = 1.0 - paperHeight(x, y).clamp(0.0, 1.0);
        final granulationBias =
            (1.0 + granAverage * (valley - 0.5)).clamp(0.65, 1.35);
        // The edge boost is deliberately mild: settling is how pigment LOCKS,
        // and a strong gradient boost freezes pigment at interior wetness
        // gradients during the initial spread — before it can migrate to the
        // rim — which inverted edge darkening entirely. Rim concentration is
        // owned by the transport passes; settling merely fixes what arrives.
        var settleFrac = dryLocked
            ? 1.0
            : settle * dryness * granulationBias * (1.0 + edge * grad * 0.35);
        settleFrac = settleFrac.clamp(0.0, 1.0);

        final loadDep = pdep[pd];
        final liftableLoad = math.max(0.0, loadDep - pDry[pd]);
        final liftableGranulation = math.max(
          0.0,
          pdep[pd + WatercolorField.depGranulation] -
              pDry[pd + WatercolorField.depGranulation],
        );
        final liftableStain = math.max(
          0.0,
          pdep[pd + WatercolorField.depStaining] -
              pDry[pd + WatercolorField.depStaining],
        );
        final stnDep = liftableStain / math.max(liftableLoad, 1e-4);
        // Keep active wet pigment mobile between contacts. Staining resistance
        // grows as the wash dries; at full wetness even a strong stainer must
        // not preserve the hard ridge of an earlier stroke.
        final stainResistance =
            (1.0 - stnDep * (1.0 - mC) * 0.85).clamp(0.0, 1.0);
        var liftFrac = dryLocked
            ? 0.0
            : lift * mC * 0.10 * stainResistance;
        liftFrac = liftFrac.clamp(0.0, 1.0);

        final kb = i * bands;
        for (var b = 0; b < bands; b++) {
          final ksO = ksus[kb + b];
          final kdO = kdep[kb + b];
          final kdLiftable = math.max(0.0, kdO - kDry[kb + b]);
          kdep[kb + b] = math.max(
            0.0,
            kdO + settleFrac * ksO - liftFrac * kdLiftable,
          );
          ksus[kb + b] = math.max(
            0.0,
            ksO - settleFrac * ksO + liftFrac * kdLiftable,
          );
          final ssO = ssus[kb + b];
          final sdO = sdep[kb + b];
          final sdLiftable = math.max(0.0, sdO - sDry[kb + b]);
          sdep[kb + b] = math.max(
            0.0,
            sdO + settleFrac * ssO - liftFrac * sdLiftable,
          );
          ssus[kb + b] = math.max(
            0.0,
            ssO - settleFrac * ssO + liftFrac * sdLiftable,
          );
        }

        props[ps] = math.max(
          0.0,
          loadSus - settleFrac * loadSus + liftFrac * liftableLoad,
        );
        props[ps + 1] = math.max(
          0.0,
          granSus -
              settleFrac * granSus +
              liftFrac * liftableGranulation,
        );
        props[ps + 2] = math.max(
          0.0,
          stainSus - settleFrac * stainSus + liftFrac * liftableStain,
        );
        pdep[pd] = math.max(
          0.0,
          loadDep + settleFrac * loadSus - liftFrac * liftableLoad,
        );
        pdep[pd + WatercolorField.depGranulation] = math.max(
          0.0,
          pdep[pd + WatercolorField.depGranulation] +
              settleFrac * granSus -
              liftFrac * liftableGranulation,
        );
        pdep[pd + WatercolorField.depStaining] = math.max(
          0.0,
          pdep[pd + WatercolorField.depStaining] +
              settleFrac * stainSus -
              liftFrac * liftableStain,
        );

        if (dryLocked && pdep[pd] > 0.0) {
          // Finalize on the actual wet -> dry transition, not lazily when a
          // later brush happens to touch this cell. This also guarantees the
          // last suspended fraction is settled before the live ticker stops.
          for (var b = 0; b < bands; b++) {
            kDry[kb + b] = kdep[kb + b];
            sDry[kb + b] = sdep[kb + b];
          }
          pDry[pd] = pdep[pd];
          pDry[pd + WatercolorField.depGranulation] =
              pdep[pd + WatercolorField.depGranulation];
          pDry[pd + WatercolorField.depStaining] =
              pdep[pd + WatercolorField.depStaining];
          pDry[pd + WatercolorField.depDryClock] = 0.0;
          field.velU[i] = 0.0;
          field.velV[i] = 0.0;
        }
      }
    }
  }

  // ── Composite (spectral KM → transparent RGBA8) ──────────────────

  /// Pigment over transparency: RGB = pigment colour, alpha = coverage. Cells
  /// with no pigment are fully transparent, so the wash overlays paper/marks.
  void compositeToRgba(Uint8List out, {double opacityScale = 3.2}) {
    final ksus = field.ksus, ssus = field.ssus;
    final kdep = field.kdep, sdep = field.sdep;
    final pSus = field.propsSus, pDep = field.propsDep;
    final m = field.waterM;
    final weights = SpectralColor.rgbWeights;
    final norms = SpectralColor.rgbWeightNorms;
    const bands = WatercolorField.bands;

    for (var i = 0; i < field.cellCount; i++) {
      // Untouched paper: fully transparent without spending the spectral
      // collapse. Most of the sheet is empty for typical paintings. RGB stays
      // white — with straight alpha, filtering blends RGB across the wash
      // edge, and black-under-transparent would fringe every rim dark.
      final thin =
          pDep[i * WatercolorField.depProps] +
          pSus[i * WatercolorField.susProps];
      if (thin <= 1e-9) {
        final o = i * 4;
        out[o] = 255;
        out[o + 1] = 255;
        out[o + 2] = 255;
        out[o + 3] = 0;
        continue;
      }
      final kb = i * bands;
      final wetness = m[i].clamp(0.0, 1.0);
      final dryness = 1.0 - wetness;
      var r = 0.0, g = 0.0, b = 0.0;
      for (var band = 0; band < bands; band++) {
        final k = kdep[kb + band] + ksus[kb + band];
        // Water fills the microscopic air gaps around particles. As it leaves,
        // those gaps scatter more light: the familiar watercolor dryback from
        // a deep, saturated wet wash to a lighter matte dry passage.
        final sc =
            (sdep[kb + band] + ssus[kb + band]) *
                (1.0 + dryness * 0.26) +
            1e-4;
        final ks = math.max(0.0, k) / sc;
        final refl = (1.0 + ks - math.sqrt(ks * ks + 2.0 * ks)).clamp(0.0, 1.0);
        final w = weights[band];
        r += refl * w[0];
        g += refl * w[1];
        b += refl * w[2];
      }
      r /= norms[0];
      g /= norms[1];
      b /= norms[2];

      final thick =
          pDep[i * WatercolorField.depProps] +
          pSus[i * WatercolorField.susProps];
      final baseOpacity = 1.0 - math.exp(-thick * opacityScale);
      // Dry paint reveals a little more paper, while wet paint remains deeper
      // and more optically continuous. This follows M every frame, so drying
      // is visible as an animation rather than a last-frame switch.
      final opacity = baseOpacity * (0.86 + wetness * 0.14);
      final wetDark = 1.0 - 0.10 * wetness;
      final o = i * 4;
      out[o] = (SpectralColor.linearToSrgb(r * wetDark) * 255.0).round().clamp(
        0,
        255,
      );
      out[o + 1] = (SpectralColor.linearToSrgb(g * wetDark) * 255.0)
          .round()
          .clamp(0, 255);
      out[o + 2] = (SpectralColor.linearToSrgb(b * wetDark) * 255.0)
          .round()
          .clamp(0, 255);
      out[o + 3] = (opacity * 255.0).round().clamp(0, 255);
    }
  }

  /// Diagnostic overlay: cyan shows every cell carrying surface water or
  /// paper saturation, independent of whether pigment is visible there.
  void wetMaskToRgba(Uint8List out) {
    if (out.length < field.cellCount * 4) {
      throw ArgumentError('Wet-mask output buffer is too small.');
    }
    for (var i = 0; i < field.cellCount; i++) {
      // Show the same mobility answer used by mixing/lift, not raw carrier
      // traces that are too weak to keep paint workable.
      final wet = field.waterM[i].clamp(0.0, 1.0);
      final o = i * 4;
      out[o] = 20;
      out[o + 1] = 155;
      out[o + 2] = 255;
      out[o + 3] = (wet * 150).round().clamp(0, 150);
    }
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }
}
