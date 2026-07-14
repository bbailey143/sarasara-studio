import 'dart:typed_data';

/// The watercolor simulation state — a CPU implementation of the persistent
/// field set from `specs/watercolor-engine-spec.md` §3.
///
/// Every "texture" in the spec is a [Float32List] at simulation resolution
/// `size × size`. Fields that are read and written in the same logical pass
/// (§2 "ping-pong") own a matching scratch buffer and expose a `swap*` method;
/// the pass writes into the scratch buffer, then swaps.
///
/// This is the correctness reference the spec's §10 calls for before the GPU
/// (Metal) port: it holds the same field layout, precision intent (spectral
/// accumulation in float32), and wet/dry boundary semantics, so the eventual
/// shipping backend is a swap of *where* the passes run, not a redesign.
///
/// Spectra are stored interleaved as `[cell*bands + band]` (8 bands), which
/// keeps a cell's whole spectrum contiguous for the advect back-sample.
class WatercolorField {
  static const int bands = 8;

  /// Suspended (mobile) property channels: load, granWt, stainWt.
  static const int susProps = 3;

  /// Deposited property channels: load, granWt, stainWt, dryClock.
  static const int depProps = 4;
  static const int depLoad = 0;
  static const int depGranulation = 1;
  static const int depStaining = 2;
  static const int depDryClock = 3;

  final int size;
  final int _cells;

  // ── Fluid (Phase B) ──────────────────────────────────────────────
  Float32List velU;
  Float32List velV;
  Float32List _velUScratch;
  Float32List _velVScratch;

  Float32List pressure;
  Float32List _pressureScratch;
  final Float32List divergence;

  // ── Water & paper (Phase E) ──────────────────────────────────────
  /// Water height `h`.
  Float32List waterH;

  /// Wet mask `M` (soft 0..1). Derived in E2; read everywhere as the
  /// wet/dry boundary that keeps paint inside the wash.
  Float32List waterM;
  Float32List _waterHScratch;
  Float32List _waterMScratch;

  /// Paper capillary saturation `s`.
  Float32List saturation;
  Float32List _saturationScratch;

  // ── Suspended pigment (advects — Phase D1) ───────────────────────
  Float32List ksus;
  Float32List ssus;
  Float32List propsSus;
  Float32List _ksusScratch;
  Float32List _ssusScratch;
  Float32List _propsSusScratch;

  // ── Deposited pigment (fixed to paper — does NOT advect) ─────────
  final Float32List kdep;
  final Float32List sdep;
  final Float32List propsDep;

  /// Spectral subset frozen as a dry optical substrate. It remains included
  /// in kdep/sdep for compositing but is excluded from ordinary wet re-lift.
  final Float32List kDry;
  final Float32List sDry;
  final Float32List propsDry;

  WatercolorField(this.size)
    : assert(size > 1),
      _cells = size * size,
      velU = Float32List(size * size),
      velV = Float32List(size * size),
      _velUScratch = Float32List(size * size),
      _velVScratch = Float32List(size * size),
      pressure = Float32List(size * size),
      _pressureScratch = Float32List(size * size),
      divergence = Float32List(size * size),
      waterH = Float32List(size * size),
      waterM = Float32List(size * size),
      _waterHScratch = Float32List(size * size),
      _waterMScratch = Float32List(size * size),
      saturation = Float32List(size * size),
      _saturationScratch = Float32List(size * size),
      ksus = Float32List(size * size * bands),
      ssus = Float32List(size * size * bands),
      propsSus = Float32List(size * size * susProps),
      _ksusScratch = Float32List(size * size * bands),
      _ssusScratch = Float32List(size * size * bands),
      _propsSusScratch = Float32List(size * size * susProps),
      kdep = Float32List(size * size * bands),
      sdep = Float32List(size * size * bands),
      propsDep = Float32List(size * size * depProps),
      kDry = Float32List(size * size * bands),
      sDry = Float32List(size * size * bands),
      propsDry = Float32List(size * size * depProps);

  int get cellCount => _cells;

  /// Flatten grid coords to a cell index. Callers clamp to the domain.
  int index(int x, int y) => y * size + x;

  // ── Scratch accessors (a pass writes here, then swaps) ───────────
  Float32List get velUOut => _velUScratch;
  Float32List get velVOut => _velVScratch;
  Float32List get pressureOut => _pressureScratch;
  Float32List get waterHOut => _waterHScratch;
  Float32List get waterMOut => _waterMScratch;
  Float32List get saturationOut => _saturationScratch;
  Float32List get ksusOut => _ksusScratch;
  Float32List get ssusOut => _ssusScratch;
  Float32List get propsSusOut => _propsSusScratch;

  void swapVelocity() {
    var t = velU;
    velU = _velUScratch;
    _velUScratch = t;
    t = velV;
    velV = _velVScratch;
    _velVScratch = t;
  }

  void swapPressure() {
    final t = pressure;
    pressure = _pressureScratch;
    _pressureScratch = t;
  }

  void swapWater() {
    var t = waterH;
    waterH = _waterHScratch;
    _waterHScratch = t;
    t = waterM;
    waterM = _waterMScratch;
    _waterMScratch = t;
  }

  void swapSaturation() {
    final t = saturation;
    saturation = _saturationScratch;
    _saturationScratch = t;
  }

  void swapSuspended() {
    var t = ksus;
    ksus = _ksusScratch;
    _ksusScratch = t;
    t = ssus;
    ssus = _ssusScratch;
    _ssusScratch = t;
    t = propsSus;
    propsSus = _propsSusScratch;
    _propsSusScratch = t;
  }

  /// Total suspended + deposited pigment load over the whole sheet.
  /// Used by conservation tests (§11) and dirty-tile deactivation.
  double totalLoad() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      sum += propsSus[i * susProps] + propsDep[i * depProps];
    }
    return sum;
  }

  /// Pigment that still needs a final settle/freeze pass before a tile can be
  /// considered truly dry. A zero wet mask alone is not enough: otherwise the
  /// driver can stop with most of the colour stranded in the mobile arrays.
  double totalSuspendedLoad() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      sum += propsSus[i * susProps];
    }
    return sum;
  }

  /// Deposited pigment that has not yet completed the dry hold and joined the
  /// protected optical substrate.
  double totalUnprotectedDepositedLoad() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      final base = i * depProps;
      final active = propsDep[base] - propsDry[base];
      if (active > 0.0) sum += active;
    }
    return sum;
  }

  /// Total water volume (`h`) over the sheet — for evaporation/conservation.
  double totalWater() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      sum += waterH[i];
    }
    return sum;
  }

  double totalSaturation() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      sum += saturation[i];
    }
    return sum;
  }

  /// Fraction of cells currently wet (`M` above a small threshold).
  /// Drives the §7 dirty-tile deactivation check.
  double wetFraction([double threshold = 0.01]) {
    var wet = 0;
    for (var i = 0; i < _cells; i++) {
      if (waterM[i] > threshold) wet++;
    }
    return wet / _cells;
  }

  /// Exact persistent-state checkpoint for stroke-boundary undo/redo.
  WatercolorFieldSnapshot snapshot() => WatercolorFieldSnapshot(
    size: size,
    velU: Float32List.fromList(velU),
    velV: Float32List.fromList(velV),
    pressure: Float32List.fromList(pressure),
    divergence: Float32List.fromList(divergence),
    waterH: Float32List.fromList(waterH),
    waterM: Float32List.fromList(waterM),
    saturation: Float32List.fromList(saturation),
    ksus: Float32List.fromList(ksus),
    ssus: Float32List.fromList(ssus),
    propsSus: Float32List.fromList(propsSus),
    kdep: Float32List.fromList(kdep),
    sdep: Float32List.fromList(sdep),
    propsDep: Float32List.fromList(propsDep),
    kDry: Float32List.fromList(kDry),
    sDry: Float32List.fromList(sDry),
    propsDry: Float32List.fromList(propsDry),
  );

  /// Compact exact checkpoint for the live undo history.
  ///
  /// The former controller history copied every field across the entire sheet
  /// before every stroke (about 13 MB at 224x224). Most of those values were
  /// zero. This representation stores complete 16x16 tiles only where any
  /// watercolor state exists, so restoring it is still exact while blank paper
  /// is not duplicated dozens of times.
  WatercolorHistorySnapshot historySnapshot({int tileSize = 16}) {
    if (tileSize <= 0) throw ArgumentError.value(tileSize, 'tileSize');
    final tileColumns = (size + tileSize - 1) ~/ tileSize;
    final tileRows = (size + tileSize - 1) ~/ tileSize;
    final tileMask = Uint8List(tileColumns * tileRows);

    for (var i = 0; i < _cells; i++) {
      final sus = i * susProps;
      final dep = i * depProps;
      final hasState =
          velU[i] != 0.0 ||
          velV[i] != 0.0 ||
          pressure[i] != 0.0 ||
          divergence[i] != 0.0 ||
          waterH[i] != 0.0 ||
          waterM[i] != 0.0 ||
          saturation[i] != 0.0 ||
          propsSus[sus] != 0.0 ||
          propsDep[dep + depLoad] != 0.0 ||
          propsDry[dep + depLoad] != 0.0;
      if (!hasState) continue;
      final x = i % size;
      final y = i ~/ size;
      tileMask[(y ~/ tileSize) * tileColumns + (x ~/ tileSize)] = 1;
    }

    var storedCells = 0;
    for (var tileY = 0; tileY < tileRows; tileY++) {
      for (var tileX = 0; tileX < tileColumns; tileX++) {
        if (tileMask[tileY * tileColumns + tileX] == 0) continue;
        final remainingWidth = size - tileX * tileSize;
        final remainingHeight = size - tileY * tileSize;
        final width = remainingWidth < tileSize ? remainingWidth : tileSize;
        final height = remainingHeight < tileSize ? remainingHeight : tileSize;
        storedCells += width * height;
      }
    }

    final cellIndices = Uint32List(storedCells);
    var write = 0;
    for (var tileY = 0; tileY < tileRows; tileY++) {
      for (var tileX = 0; tileX < tileColumns; tileX++) {
        if (tileMask[tileY * tileColumns + tileX] == 0) continue;
        final x0 = tileX * tileSize;
        final y0 = tileY * tileSize;
        final x1 = x0 + tileSize < size ? x0 + tileSize : size;
        final y1 = y0 + tileSize < size ? y0 + tileSize : size;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            cellIndices[write++] = y * size + x;
          }
        }
      }
    }

    Float32List gather(Float32List source, int stride) {
      final out = Float32List(storedCells * stride);
      for (var n = 0; n < storedCells; n++) {
        final sourceStart = cellIndices[n] * stride;
        final targetStart = n * stride;
        out.setRange(
          targetStart,
          targetStart + stride,
          source,
          sourceStart,
        );
      }
      return out;
    }

    return WatercolorHistorySnapshot(
      size: size,
      cellIndices: cellIndices,
      velU: gather(velU, 1),
      velV: gather(velV, 1),
      pressure: gather(pressure, 1),
      divergence: gather(divergence, 1),
      waterH: gather(waterH, 1),
      waterM: gather(waterM, 1),
      saturation: gather(saturation, 1),
      ksus: gather(ksus, bands),
      ssus: gather(ssus, bands),
      propsSus: gather(propsSus, susProps),
      kdep: gather(kdep, bands),
      sdep: gather(sdep, bands),
      propsDep: gather(propsDep, depProps),
      kDry: gather(kDry, bands),
      sDry: gather(sDry, bands),
      propsDry: gather(propsDry, depProps),
    );
  }

  void restoreHistory(WatercolorHistorySnapshot snapshot) {
    if (snapshot.size != size) {
      throw ArgumentError('Watercolor history size does not match field.');
    }
    final storedCells = snapshot.cellIndices.length;

    void requireLength(String name, int actual, int stride) {
      if (actual != storedCells * stride) {
        throw ArgumentError(
          'Watercolor history $name schema does not match this engine.',
        );
      }
    }

    requireLength('velocity', snapshot.velU.length, 1);
    requireLength('velocity', snapshot.velV.length, 1);
    requireLength('pressure', snapshot.pressure.length, 1);
    requireLength('divergence', snapshot.divergence.length, 1);
    requireLength('water', snapshot.waterH.length, 1);
    requireLength('wet mask', snapshot.waterM.length, 1);
    requireLength('saturation', snapshot.saturation.length, 1);
    requireLength('suspended K', snapshot.ksus.length, bands);
    requireLength('suspended S', snapshot.ssus.length, bands);
    requireLength('suspended properties', snapshot.propsSus.length, susProps);
    requireLength('deposited K', snapshot.kdep.length, bands);
    requireLength('deposited S', snapshot.sdep.length, bands);
    requireLength('deposited properties', snapshot.propsDep.length, depProps);
    requireLength('dry K', snapshot.kDry.length, bands);
    requireLength('dry S', snapshot.sDry.length, bands);
    requireLength('dry properties', snapshot.propsDry.length, depProps);

    void clear(Float32List target) => target.fillRange(0, target.length, 0.0);
    clear(velU);
    clear(velV);
    clear(pressure);
    clear(divergence);
    clear(waterH);
    clear(waterM);
    clear(saturation);
    clear(ksus);
    clear(ssus);
    clear(propsSus);
    clear(kdep);
    clear(sdep);
    clear(propsDep);
    clear(kDry);
    clear(sDry);
    clear(propsDry);

    void scatter(Float32List target, Float32List source, int stride) {
      for (var n = 0; n < storedCells; n++) {
        final targetStart = snapshot.cellIndices[n] * stride;
        final sourceStart = n * stride;
        target.setRange(
          targetStart,
          targetStart + stride,
          source,
          sourceStart,
        );
      }
    }

    scatter(velU, snapshot.velU, 1);
    scatter(velV, snapshot.velV, 1);
    scatter(pressure, snapshot.pressure, 1);
    scatter(divergence, snapshot.divergence, 1);
    scatter(waterH, snapshot.waterH, 1);
    scatter(waterM, snapshot.waterM, 1);
    scatter(saturation, snapshot.saturation, 1);
    scatter(ksus, snapshot.ksus, bands);
    scatter(ssus, snapshot.ssus, bands);
    scatter(propsSus, snapshot.propsSus, susProps);
    scatter(kdep, snapshot.kdep, bands);
    scatter(sdep, snapshot.sdep, bands);
    scatter(propsDep, snapshot.propsDep, depProps);
    scatter(kDry, snapshot.kDry, bands);
    scatter(sDry, snapshot.sDry, bands);
    scatter(propsDry, snapshot.propsDry, depProps);
  }

  void restore(WatercolorFieldSnapshot snapshot) {
    if (snapshot.size != size) {
      throw ArgumentError('Watercolor checkpoint size does not match field.');
    }
    void requireLength(String name, int actual, int expected) {
      if (actual != expected) {
        throw ArgumentError(
          'Watercolor checkpoint $name schema does not match this engine.',
        );
      }
    }

    requireLength('velocity', snapshot.velU.length, _cells);
    requireLength('velocity', snapshot.velV.length, _cells);
    requireLength('pressure', snapshot.pressure.length, _cells);
    requireLength('divergence', snapshot.divergence.length, _cells);
    requireLength('water', snapshot.waterH.length, _cells);
    requireLength('wet mask', snapshot.waterM.length, _cells);
    requireLength('saturation', snapshot.saturation.length, _cells);
    requireLength('suspended K', snapshot.ksus.length, _cells * bands);
    requireLength('suspended S', snapshot.ssus.length, _cells * bands);
    requireLength(
      'suspended properties',
      snapshot.propsSus.length,
      _cells * susProps,
    );
    requireLength('deposited K', snapshot.kdep.length, _cells * bands);
    requireLength('deposited S', snapshot.sdep.length, _cells * bands);
    requireLength(
      'deposited properties',
      snapshot.propsDep.length,
      _cells * depProps,
    );
    requireLength('dry K', snapshot.kDry.length, _cells * bands);
    requireLength('dry S', snapshot.sDry.length, _cells * bands);
    requireLength(
      'dry properties',
      snapshot.propsDry.length,
      _cells * depProps,
    );
    velU.setAll(0, snapshot.velU);
    velV.setAll(0, snapshot.velV);
    pressure.setAll(0, snapshot.pressure);
    divergence.setAll(0, snapshot.divergence);
    waterH.setAll(0, snapshot.waterH);
    waterM.setAll(0, snapshot.waterM);
    saturation.setAll(0, snapshot.saturation);
    ksus.setAll(0, snapshot.ksus);
    ssus.setAll(0, snapshot.ssus);
    propsSus.setAll(0, snapshot.propsSus);
    kdep.setAll(0, snapshot.kdep);
    sdep.setAll(0, snapshot.sdep);
    propsDep.setAll(0, snapshot.propsDep);
    kDry.setAll(0, snapshot.kDry);
    sDry.setAll(0, snapshot.sDry);
    propsDry.setAll(0, snapshot.propsDry);
  }
}

class WatercolorFieldSnapshot {
  const WatercolorFieldSnapshot({
    required this.size,
    required this.velU,
    required this.velV,
    required this.pressure,
    required this.divergence,
    required this.waterH,
    required this.waterM,
    required this.saturation,
    required this.ksus,
    required this.ssus,
    required this.propsSus,
    required this.kdep,
    required this.sdep,
    required this.propsDep,
    required this.kDry,
    required this.sDry,
    required this.propsDry,
  });

  final int size;
  final Float32List velU;
  final Float32List velV;
  final Float32List pressure;
  final Float32List divergence;
  final Float32List waterH;
  final Float32List waterM;
  final Float32List saturation;
  final Float32List ksus;
  final Float32List ssus;
  final Float32List propsSus;
  final Float32List kdep;
  final Float32List sdep;
  final Float32List propsDep;
  final Float32List kDry;
  final Float32List sDry;
  final Float32List propsDry;
}

/// Exact watercolor undo state containing only occupied 16x16 sheet tiles.
class WatercolorHistorySnapshot {
  const WatercolorHistorySnapshot({
    required this.size,
    required this.cellIndices,
    required this.velU,
    required this.velV,
    required this.pressure,
    required this.divergence,
    required this.waterH,
    required this.waterM,
    required this.saturation,
    required this.ksus,
    required this.ssus,
    required this.propsSus,
    required this.kdep,
    required this.sdep,
    required this.propsDep,
    required this.kDry,
    required this.sDry,
    required this.propsDry,
  });

  final int size;
  final Uint32List cellIndices;
  final Float32List velU;
  final Float32List velV;
  final Float32List pressure;
  final Float32List divergence;
  final Float32List waterH;
  final Float32List waterM;
  final Float32List saturation;
  final Float32List ksus;
  final Float32List ssus;
  final Float32List propsSus;
  final Float32List kdep;
  final Float32List sdep;
  final Float32List propsDep;
  final Float32List kDry;
  final Float32List sDry;
  final Float32List propsDry;

  int get estimatedBytes =>
      cellIndices.lengthInBytes +
      velU.lengthInBytes +
      velV.lengthInBytes +
      pressure.lengthInBytes +
      divergence.lengthInBytes +
      waterH.lengthInBytes +
      waterM.lengthInBytes +
      saturation.lengthInBytes +
      ksus.lengthInBytes +
      ssus.lengthInBytes +
      propsSus.lengthInBytes +
      kdep.lengthInBytes +
      sdep.lengthInBytes +
      propsDep.lengthInBytes +
      kDry.lengthInBytes +
      sDry.lengthInBytes +
      propsDry.lengthInBytes;
}
