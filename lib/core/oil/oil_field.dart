import 'dart:typed_data';

/// The oil simulation state — a CPU implementation of the persistent texture
/// set from `specs/oil-engine-spec.md` §3.
///
/// Every "texture" is a [Float32List] at simulation resolution `size × size`.
/// There is **one** wet paint layer (no suspended/deposited split — oil is
/// wet-and-mobile everywhere in-session), so half the spectral storage of
/// watercolor:
///
/// - `Surface` → [paintH] (paint height/volume `h`) and [mediumH] (dissolved
///   binder volume). The spec stores medium as a fraction `m`; this reference
///   keeps the *extensive* binder volume so all transport moves one kind of
///   quantity, and exposes `m = mediumH / h` via [mediumFractionAt].
/// - `Flux` → [fluxX]/[fluxY], staggered face fluxes (scratch, recomputed
///   every substep). `fluxX[i]` lives on the face between cell `i` and
///   `i + 1`; `fluxY[i]` between `i` and `i + size`.
/// - `Struct` → [struct], thixotropic structure 0..1 (1 = fully set up).
/// - `Kpaint`/`Spaint` → [kPaint]/[sPaint], 8-band spectral sums interleaved
///   `[cell*8 + band]` (float32 accumulation, same packing as watercolor).
/// - `PaintProps` → [props]: extensive `(load, granWt)` per cell.
///
/// Height must stay float32: `h` is both the physics state (slope drives
/// flux) and the lighting input (normals are `∇H`).
class OilField {
  static const int bands = 8;

  /// Property channels: pigment load, granulation weight.
  static const int propChannels = 2;

  final int size;
  final int _cells;

  /// Paint height `h` ≥ 0.
  Float32List paintH;

  /// Dissolved medium/binder volume (≤ paintH in practice).
  Float32List mediumH;

  /// Thixotropic structure 0..1. Fresh paint arrives sheared (low), sets up
  /// toward 1 at rest.
  final Float32List struct;

  /// Staggered face fluxes from the rheology solve (scratch).
  final Float32List fluxX;
  final Float32List fluxY;

  /// Spectral absorption/scattering sums, 8 bands interleaved.
  Float32List kPaint;
  Float32List sPaint;

  /// Extensive property sums `(load, granWt)`.
  Float32List props;

  // Scratch pair for conservative transport passes (a pass accumulates into
  // the scratch buffer, then swaps).
  Float32List _paintHScratch;
  Float32List _mediumHScratch;
  Float32List _kScratch;
  Float32List _sScratch;
  Float32List _propsScratch;

  OilField(this.size)
    : assert(size > 1),
      _cells = size * size,
      paintH = Float32List(size * size),
      mediumH = Float32List(size * size),
      struct = Float32List(size * size)..fillRange(0, size * size, 1.0),
      fluxX = Float32List(size * size),
      fluxY = Float32List(size * size),
      kPaint = Float32List(size * size * bands),
      sPaint = Float32List(size * size * bands),
      props = Float32List(size * size * propChannels),
      _paintHScratch = Float32List(size * size),
      _mediumHScratch = Float32List(size * size),
      _kScratch = Float32List(size * size * bands),
      _sScratch = Float32List(size * size * bands),
      _propsScratch = Float32List(size * size * propChannels);

  int get cellCount => _cells;

  int index(int x, int y) => y * size + x;

  Float32List get paintHOut => _paintHScratch;
  Float32List get mediumHOut => _mediumHScratch;
  Float32List get kOut => _kScratch;
  Float32List get sOut => _sScratch;
  Float32List get propsOut => _propsScratch;

  /// Local medium/binder fraction `m ∈ [0, 1]` at a cell.
  double mediumFractionAt(int i) {
    final h = paintH[i];
    if (h <= 1e-6) return 0.0;
    final m = mediumH[i] / h;
    return m < 0.0 ? 0.0 : (m > 1.0 ? 1.0 : m);
  }

  /// Swap all material buffers after a transport pass that moved paint,
  /// medium, spectra, and properties together (they must never separate).
  void swapMaterial() {
    var t = paintH;
    paintH = _paintHScratch;
    _paintHScratch = t;
    t = mediumH;
    mediumH = _mediumHScratch;
    _mediumHScratch = t;
    t = kPaint;
    kPaint = _kScratch;
    _kScratch = t;
    t = sPaint;
    sPaint = _sScratch;
    _sScratch = t;
    t = props;
    props = _propsScratch;
    _propsScratch = t;
  }

  /// Total paint volume `Σh` — the §13.7 conservation quantity. Flat except
  /// under brush deposit/pickup; drift means a non-conservative advection
  /// slipped in.
  double totalVolume() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      sum += paintH[i];
    }
    return sum;
  }

  /// Total pigment load over the canvas.
  double totalLoad() {
    var sum = 0.0;
    for (var i = 0; i < _cells; i++) {
      sum += props[i * propChannels];
    }
    return sum;
  }

  double maxHeight() {
    var best = 0.0;
    for (var i = 0; i < _cells; i++) {
      if (paintH[i] > best) best = paintH[i];
    }
    return best;
  }

  /// Exact persistent-state checkpoint for stroke-boundary undo/redo. Oil has
  /// no dry/wet split in-session — the whole live state snapshots (§10).
  OilFieldSnapshot snapshot() => OilFieldSnapshot(
    size: size,
    paintH: Float32List.fromList(paintH),
    mediumH: Float32List.fromList(mediumH),
    struct: Float32List.fromList(struct),
    kPaint: Float32List.fromList(kPaint),
    sPaint: Float32List.fromList(sPaint),
    props: Float32List.fromList(props),
  );

  void restore(OilFieldSnapshot snapshot) {
    if (snapshot.size != size) {
      throw ArgumentError('Oil checkpoint size does not match field.');
    }
    paintH.setAll(0, snapshot.paintH);
    mediumH.setAll(0, snapshot.mediumH);
    struct.setAll(0, snapshot.struct);
    kPaint.setAll(0, snapshot.kPaint);
    sPaint.setAll(0, snapshot.sPaint);
    props.setAll(0, snapshot.props);
  }

  void clear() {
    paintH.fillRange(0, paintH.length, 0.0);
    mediumH.fillRange(0, mediumH.length, 0.0);
    struct.fillRange(0, struct.length, 1.0);
    fluxX.fillRange(0, fluxX.length, 0.0);
    fluxY.fillRange(0, fluxY.length, 0.0);
    kPaint.fillRange(0, kPaint.length, 0.0);
    sPaint.fillRange(0, sPaint.length, 0.0);
    props.fillRange(0, props.length, 0.0);
  }
}

class OilFieldSnapshot {
  const OilFieldSnapshot({
    required this.size,
    required this.paintH,
    required this.mediumH,
    required this.struct,
    required this.kPaint,
    required this.sPaint,
    required this.props,
  });

  final int size;
  final Float32List paintH;
  final Float32List mediumH;
  final Float32List struct;
  final Float32List kPaint;
  final Float32List sPaint;
  final Float32List props;
}
