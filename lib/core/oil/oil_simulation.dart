import 'dart:math' as math;
import 'dart:typed_data';

import '../pigment/spectral_color.dart';
import 'oil_field.dart';
import 'oil_params.dart';

/// CPU reference of the oil medium from `specs/oil-engine-spec.md`.
///
/// The two facts everything descends from (spec §1):
///
/// 1. **Oil is viscoplastic** — below the yield stress `τ_y` it does not flow.
///    The yield gate in [_computeFlux] is a hard branch; sub-yield relief
///    holds indefinitely (impasto), and marks freeze when the brush lifts.
/// 2. **Pigment never diffuses.** There is no diffusion term anywhere in this
///    file. Color moves only where paint is mechanically transported — by the
///    brush ([stamp]/[drag]) or by the yield-gated slump flux ([step]). Two
///    touching colors at rest never blend.
///
/// Per frame: **A** brush exchange & drag (invoked per contact via
/// [stamp]/[drag]), **B** substepped Herschel-Bulkley flux with pigment
/// riding the same flux, **D** thixotropic structure, **F** lit composite on
/// demand ([compositeToRgba]).
///
/// Transport is conservative donor-cell/upwind on staggered faces for the
/// rheology (spec §8) *and* for the brush drag. The spec's §6 preference for
/// BFECC/MacCormack in the brush pass is deliberately traded for strict
/// volume/pigment conservation on this CPU reference path; the GPU port is
/// the place to upgrade drag crispness (documented in ARCHITECTURE.md).
class OilSimulation {
  final OilField field;

  /// Mutable so the UI can adjust levels live without rebuilding the field.
  OilParams params;

  /// Static canvas tooth height at a cell, 0..1 (valley..peak).
  final double Function(int x, int y) canvasTooth;

  /// Optional fine tooth sampler in unit UV. When set, the display-resolution
  /// composite reads canvas grain at full paper-texture detail instead of the
  /// simulation grid — the weave stays crisp however coarse the rheology runs
  /// (spec §10: the resolution split between simulation and display normals).
  double Function(double u, double v)? canvasToothUv;

  OilSimulation({
    required this.field,
    this.params = const OilParams(),
    double Function(int x, int y)? canvasTooth,
    this.canvasToothUv,
  }) : canvasTooth = canvasTooth ?? _flatHalf {
    _setSubstrateBands();
  }

  static double _flatHalf(int x, int y) => 0.5;

  int get _s => field.size;

  /// Largest face-flux magnitude from the most recent [step] — the activity
  /// signal. Zero means every face is sub-yield and the paint has set.
  double lastMaxFlux = 0.0;

  // ── Substrate (glazing background) ────────────────────────────────

  /// Substrate reflectance per spectral band, derived from a uniform linear
  /// RGB. The finite-thickness Kubelka-Munk layer (§7 F1) reflects over this,
  /// which is what makes a thin glaze read as optical depth over the ground.
  final Float32List _substrateBands = Float32List(OilField.bands);

  double _subR = 0.937, _subG = 0.921, _subB = 0.878;

  /// Set the ground color (linear RGB 0..1) the paint layer sits on.
  void setSubstrate(double r, double g, double b) {
    _subR = r.clamp(0.0, 1.0);
    _subG = g.clamp(0.0, 1.0);
    _subB = b.clamp(0.0, 1.0);
    _setSubstrateBands();
  }

  void _setSubstrateBands() {
    final weights = SpectralColor.rgbWeights;
    for (var band = 0; band < OilField.bands; band++) {
      final w = weights[band];
      final norm = w[0] + w[1] + w[2];
      _substrateBands[band] = norm <= 0.0
          ? 1.0
          : ((w[0] * _subR + w[1] * _subG + w[2] * _subB) / norm).clamp(
              0.02,
              1.0,
            );
    }
  }

  // ── Phase A1 — bidirectional brush exchange ───────────────────────

  /// One footprint-cell exchange between a loaded brush and the canvas at
  /// ([cx],[cy]) in cell units (spec §7 A1). Pickup runs first so a dragging
  /// brush lifts the *older* paint beneath it — that lifted spectrum is the
  /// dirty brush; then the deposit lays the brush's current blend down toward
  /// the pressure-weighted equilibrium film.
  ///
  /// [film] is the equilibrium film height the brush drives toward
  /// (`brushFilm × reservoir fill`); deposit is `∝ max(0, film − h)` so a
  /// held press saturates instead of pumping volume forever. [kUnit]/[sUnit]
  /// are the brush's carried spectrum per unit pigment; [mediumFraction] is
  /// the binder share of deposited volume (thinner ⇒ less pigment per
  /// height). [dragSpeed] gates pickup: a stationary press lifts nothing.
  ///
  /// Returns the extensive amounts actually exchanged, from which the caller
  /// builds the authoritative transfer receipt.
  OilStampExchange stamp({
    required double cx,
    required double cy,
    required double radius,
    required double pressure,
    required double film,
    required List<double> kUnit,
    required List<double> sUnit,
    required double granUnit,
    required double mediumFraction,
    required double dragSpeed,
    double depositRateScale = 1.0,
  }) {
    final r = math.max(radius, 0.75);
    final minX = math.max(0, (cx - r).floor());
    final maxX = math.min(_s - 1, (cx + r).ceil());
    final minY = math.max(0, (cy - r).floor());
    final maxY = math.min(_s - 1, (cy + r).ceil());
    final p = pressure.clamp(0.0, 1.0);
    final mB = mediumFraction.clamp(0.0, 0.98);
    final speed01 = (dragSpeed / (r * 0.9 + 1e-6)).clamp(0.0, 1.0);

    // The brush rides the *local* tooth peaks: it always contacts the highest
    // texture under its footprint (smooth canvas is touched everywhere at any
    // pressure), and lower pressure reaches proportionally less far down into
    // the valleys — the stamp side of drybrush (§7 F2 owns the display side).
    final toothMap = _tooth;
    var localPeak = 0.0;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final tooth = toothMap[y * _s + x];
        if (tooth > localPeak) localPeak = tooth;
      }
    }
    final skim = localPeak - p * params.toothReach;

    final exchange = OilStampExchange();
    final h = field.paintH;
    final medium = field.mediumH;
    final k = field.kPaint;
    final s = field.sPaint;
    final props = field.props;
    final struct = field.struct;
    const bands = OilField.bands;
    const np = OilField.propChannels;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        final d = math.sqrt(dx * dx + dy * dy) / r;
        if (d >= 1.0) continue;
        final fall = 1.0 - _smoothstep(0.3, 1.0, d);
        final fp = fall * p;
        if (fp <= 1e-4) continue;

        final i = field.index(x, y);
        final kBase = i * bands;
        final pBase = i * np;

        // Contact gate: existing paint raises the surface into reach, so
        // painting over paint always connects while a light pass over bare
        // rough canvas only kisses the peaks.
        final tooth01 = toothMap[i];
        final reachSurface =
            tooth01 + (h[i] / math.max(film, 0.3)).clamp(0.0, 1.0) * 0.6;
        final gate = _smoothstep(skim, skim + 0.18, reachSurface + 0.02);
        if (gate <= 1e-4) continue;

        // Pickup first (canvas → brush): dragging lifts the older wet paint.
        final hOld = h[i];
        if (hOld > 1e-6 && speed01 > 0.0) {
          final pick = math.min(
            params.pickupRate * fp * gate * speed01 * hOld,
            0.45 * hOld,
          );
          if (pick > 0.0) {
            final frac = pick / hOld;
            h[i] = hOld - pick;
            final mMoved = medium[i] * frac;
            medium[i] -= mMoved;
            exchange.pickedVolume += pick;
            exchange.pickedMedium += mMoved;
            for (var b = 0; b < bands; b++) {
              final dK = k[kBase + b] * frac;
              final dS = s[kBase + b] * frac;
              k[kBase + b] -= dK;
              s[kBase + b] -= dS;
              exchange.pickedK[b] += dK;
              exchange.pickedS[b] += dS;
            }
            final dLoad = props[pBase] * frac;
            final dGran = props[pBase + 1] * frac;
            props[pBase] -= dLoad;
            props[pBase + 1] -= dGran;
            exchange.pickedLoad += dLoad;
            exchange.pickedGran += dGran;
          }
        }

        // Deposit (brush → canvas) toward the equilibrium film.
        final dep =
            params.depositRate *
            depositRateScale *
            fp *
            gate *
            math.max(0.0, film - h[i]);
        if (dep > 0.0) {
          final depPigment = dep * (1.0 - mB);
          h[i] += dep;
          medium[i] += dep * mB;
          for (var b = 0; b < bands; b++) {
            k[kBase + b] += depPigment * kUnit[b];
            s[kBase + b] += depPigment * sUnit[b];
          }
          props[pBase] += depPigment;
          props[pBase + 1] += depPigment * granUnit;
          exchange.depositedVolume += dep;
          exchange.depositedLoad += depPigment;
        }

        // Worked paint arrives sheared: knock the thixotropic structure down
        // under the footprint so a fresh passage stays mobile briefly.
        final sheared = 1.0 - 0.85 * fp * gate;
        if (struct[i] > sheared) struct[i] = sheared;
      }
    }
    return exchange;
  }

  // ── Phase A2 — brush drag (the primary mixer) ─────────────────────

  /// Impose the brush motion on the paint under the footprint (spec §7 A2).
  /// All extensive fields — height, medium, spectra, properties — move with
  /// the *same* donor-cell fractions, so pigment can never separate from the
  /// paint that carries it and no color appears where no paint went.
  ///
  /// [velX]/[velY] are in cells per stamp and should already include the
  /// medium's `coupling` factor (< 1 lets the brush glide over the paint).
  void drag({
    required double cx,
    required double cy,
    required double radius,
    required double velX,
    required double velY,
  }) {
    if (velX.abs() < 1e-4 && velY.abs() < 1e-4) return;
    final r = math.max(radius, 0.75);
    // Expanded box: donor-cell targets reach one cell beyond the footprint.
    final minX = math.max(0, (cx - r).floor() - 1);
    final maxX = math.min(_s - 1, (cx + r).ceil() + 1);
    final minY = math.max(0, (cy - r).floor() - 1);
    final maxY = math.min(_s - 1, (cy + r).ceil() + 1);
    final w = maxX - minX + 1;
    final hgt = maxY - minY + 1;
    if (w <= 0 || hgt <= 0) return;

    const bands = OilField.bands;
    const np = OilField.propChannels;
    // 20 channels per cell: h, medium, 8×K, 8×S, load, gran.
    const channels = 2 + bands * 2 + np;
    final acc = Float32List(w * hgt * channels);

    final h = field.paintH;
    final medium = field.mediumH;
    final k = field.kPaint;
    final s = field.sPaint;
    final props = field.props;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final i = field.index(x, y);
        final local = (y - minY) * w + (x - minX);
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        final d = math.sqrt(dx * dx + dy * dy) / r;
        final fall = d >= 1.0 ? 0.0 : 1.0 - _smoothstep(0.45, 1.0, d);

        var fx = 0.0, fy = 0.0;
        var tx = x, ty = y;
        if (fall > 0.0 && h[i] > 1e-7) {
          final vx = velX * fall;
          final vy = velY * fall;
          fx = (vx.abs() * 0.42).clamp(0.0, 0.42);
          fy = (vy.abs() * 0.42).clamp(0.0, 0.42);
          final moved = fx + fy;
          if (moved > 0.8) {
            final scale = 0.8 / moved;
            fx *= scale;
            fy *= scale;
          }
          tx = (x + (vx >= 0 ? 1 : -1)).clamp(minX, maxX);
          ty = (y + (vy >= 0 ? 1 : -1)).clamp(minY, maxY);
        }
        final remain = 1.0 - fx - fy;
        final lx = (y - minY) * w + (tx - minX);
        final ly = (ty - minY) * w + (x - minX);

        void scatter(int channel, double value) {
          acc[local * channels + channel] += value * remain;
          acc[lx * channels + channel] += value * fx;
          acc[ly * channels + channel] += value * fy;
        }

        scatter(0, h[i]);
        scatter(1, medium[i]);
        for (var b = 0; b < bands; b++) {
          scatter(2 + b, k[i * bands + b]);
          scatter(2 + bands + b, s[i * bands + b]);
        }
        scatter(2 + bands * 2, props[i * np]);
        scatter(2 + bands * 2 + 1, props[i * np + 1]);
      }
    }

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final i = field.index(x, y);
        final local = ((y - minY) * w + (x - minX)) * channels;
        h[i] = acc[local];
        medium[i] = acc[local + 1];
        for (var b = 0; b < bands; b++) {
          k[i * bands + b] = acc[local + 2 + b];
          s[i * bands + b] = acc[local + 2 + bands + b];
        }
        props[i * np] = acc[local + 2 + bands * 2];
        props[i * np + 1] = acc[local + 2 + bands * 2 + 1];
      }
    }
  }

  // ── Phase B — yield-gated Herschel-Bulkley flow ───────────────────

  /// Advance the paint one frame: substepped explicit flux (§8), pigment
  /// riding the same flux, then thixotropic structure recovery (§7 D).
  void step() {
    lastMaxFlux = 0.0;
    if (field.maxHeight() <= 1e-6) {
      _recoverStructure(0.0);
      return;
    }
    final dtSub = params.dt / params.substeps;
    for (var sub = 0; sub < params.substeps; sub++) {
      final active = _computeFlux(dtSub);
      if (active == 0) break;
      _applyFlux(dtSub);
    }
    _recoverStructure(params.dt);
  }

  /// Fill the staggered face fluxes (§5). Zero where sub-yield — the hard
  /// branch is what freezes relief; do not smooth it (§8). Returns the count
  /// of active faces so a fully-set canvas costs nothing downstream.
  int _computeFlux(double dtSub) {
    final h = field.paintH;
    final struct = field.struct;
    final fluxX = field.fluxX;
    final fluxY = field.fluxY;
    fluxX.fillRange(0, fluxX.length, 0.0);
    fluxY.fillRange(0, fluxY.length, 0.0);
    var active = 0;
    final tooth = _tooth;

    double surfaceH(int x, int y, int i) =>
        tooth[i] * params.toothAmp + h[i];

    for (var y = 0; y < _s; y++) {
      for (var x = 0; x < _s; x++) {
        final i = y * _s + x;
        // x-face between (x,y) and (x+1,y).
        if (x + 1 < _s) {
          final j = i + 1;
          if (h[i] > 1e-7 || h[j] > 1e-7) {
            final grad = (surfaceH(x + 1, y, j) - surfaceH(x, y, i)) -
                params.tiltX;
            final q = _faceFlux(grad, i, j, h, struct, dtSub);
            if (q != 0.0) {
              fluxX[i] = q;
              active++;
              final mag = q.abs();
              if (mag > lastMaxFlux) lastMaxFlux = mag;
            }
          }
        }
        // y-face between (x,y) and (x,y+1).
        if (y + 1 < _s) {
          final j = i + _s;
          if (h[i] > 1e-7 || h[j] > 1e-7) {
            final grad = (surfaceH(x, y + 1, j) - surfaceH(x, y, i)) -
                params.tiltY;
            final q = _faceFlux(grad, i, j, h, struct, dtSub);
            if (q != 0.0) {
              fluxY[i] = q;
              active++;
              final mag = q.abs();
              if (mag > lastMaxFlux) lastMaxFlux = mag;
            }
          }
        }
      }
    }
    return active;
  }

  /// Herschel-Bulkley face flux with the Bingham excess-stress factor
  /// (spec §5). Positive flux moves material from the lower-index cell toward
  /// the higher-index cell. Donor quantities (`h`, structure, medium) come
  /// from the upwind cell so a cell can never give what it does not have.
  double _faceFlux(
    double grad,
    int i,
    int j,
    Float32List h,
    Float32List struct,
    double dtSub,
  ) {
    if (grad.abs() < 1e-9) return 0.0;
    // q = −Mob·excess·∇H: flow runs downhill, so the donor is the higher cell.
    final donor = grad > 0.0 ? j : i;
    final hd = h[donor];
    if (hd <= 1e-7) return 0.0;

    final mFrac = field.mediumFractionAt(donor);
    final tauY = params.yieldStress(mFrac, struct[donor]);
    final tau = params.rhoG * hd * grad.abs();
    if (tau <= tauY) return 0.0; // ← sub-yield: relief HOLDS.

    final excess = math.pow(
      1.0 - tauY / tau,
      1.0 + 1.0 / params.flowIndexN,
    ).toDouble();
    var q = -params.mobility(hd, mFrac) * excess * grad;
    // Explicit-flux safety: never move more than a fifth of the donor per
    // substep, whatever the parameters say (CFL backstop, §8).
    final maxQ = 0.2 * hd / dtSub;
    if (q > maxQ) q = maxQ;
    if (q < -maxQ) q = -maxQ;
    return q;
  }

  /// Volume-conserving height update `∂h/∂t = −∇·q` done as a face walk, with
  /// every material field riding the identical donor fractions (spec §7 B2 —
  /// upwind/donor-cell, mass-weighted, never diffused).
  void _applyFlux(double dtSub) {
    final h = field.paintH;
    final medium = field.mediumH;
    final k = field.kPaint;
    final s = field.sPaint;
    final props = field.props;
    final hOut = field.paintHOut;
    final mOut = field.mediumHOut;
    final kOut = field.kOut;
    final sOut = field.sOut;
    final pOut = field.propsOut;
    const bands = OilField.bands;
    const np = OilField.propChannels;

    hOut.setAll(0, h);
    mOut.setAll(0, medium);
    kOut.setAll(0, k);
    sOut.setAll(0, s);
    pOut.setAll(0, props);

    void moveAcrossFace(int i, int j, double q) {
      if (q == 0.0) return;
      final volume = q.abs() * dtSub;
      final donor = q > 0.0 ? i : j;
      final receiver = q > 0.0 ? j : i;
      final hd = h[donor];
      if (hd <= 1e-9) return;
      final moved = math.min(volume, 0.2 * hd);
      final frac = moved / hd;
      hOut[donor] -= moved;
      hOut[receiver] += moved;
      final mMoved = medium[donor] * frac;
      mOut[donor] -= mMoved;
      mOut[receiver] += mMoved;
      final kb = donor * bands;
      final kr = receiver * bands;
      for (var b = 0; b < bands; b++) {
        final dK = k[kb + b] * frac;
        final dS = s[kb + b] * frac;
        kOut[kb + b] -= dK;
        kOut[kr + b] += dK;
        sOut[kb + b] -= dS;
        sOut[kr + b] += dS;
      }
      final pb = donor * np;
      final pr = receiver * np;
      for (var c = 0; c < np; c++) {
        final dP = props[pb + c] * frac;
        pOut[pb + c] -= dP;
        pOut[pr + c] += dP;
      }
    }

    for (var y = 0; y < _s; y++) {
      for (var x = 0; x < _s; x++) {
        final i = y * _s + x;
        if (x + 1 < _s) moveAcrossFace(i, i + 1, field.fluxX[i]);
        if (y + 1 < _s) moveAcrossFace(i, i + _s, field.fluxY[i]);
      }
    }

    // h ≥ 0 clamp on every height write: negative height → NaN normals →
    // black holes under lighting (§8). Donor bounds make violations tiny.
    for (var i = 0; i < field.cellCount; i++) {
      if (hOut[i] < 0.0) hOut[i] = 0.0;
      if (mOut[i] < 0.0) mOut[i] = 0.0;
    }
    field.swapMaterial();
  }

  /// Phase D — structure recovers at rest, breaks down under shear (§7 D).
  void _recoverStructure(double dt) {
    if (dt <= 0.0) return;
    final struct = field.struct;
    final fluxX = field.fluxX;
    final fluxY = field.fluxY;
    final recover = params.recover;
    final breakdown = params.breakdown;
    for (var y = 0; y < _s; y++) {
      for (var x = 0; x < _s; x++) {
        final i = y * _s + x;
        final shear =
            0.5 *
            (fluxX[i].abs() +
                (x > 0 ? fluxX[i - 1].abs() : 0.0) +
                fluxY[i].abs() +
                (y > 0 ? fluxY[i - _s].abs() : 0.0));
        final value =
            struct[i] +
            dt * (recover * (1.0 - struct[i]) - breakdown * shear * struct[i]);
        struct[i] = value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
      }
    }
  }

  // ── Phase F — light & composite ───────────────────────────────────

  /// Lazily cached static tooth at simulation resolution. The tooth callback
  /// is pure but not free; physics and fallback display sampling read this.
  Float32List? _toothCache;

  Float32List get _tooth {
    var cache = _toothCache;
    if (cache == null) {
      cache = Float32List(field.cellCount);
      for (var y = 0; y < _s; y++) {
        for (var x = 0; x < _s; x++) {
          cache[y * _s + x] = canvasTooth(x, y).clamp(0.0, 1.0);
        }
      }
      _toothCache = cache;
    }
    return cache;
  }

  /// Call when the canvas/paper texture behind [canvasTooth] changes.
  void invalidateToothCache() => _toothCache = null;

  double _bilinear(Float32List f, double x, double y, {int stride = 1, int channel = 0}) {
    final cx = x.clamp(0.0, _s - 1.001);
    final cy = y.clamp(0.0, _s - 1.001);
    final x0 = cx.floor();
    final y0 = cy.floor();
    final x1 = x0 + 1 < _s ? x0 + 1 : x0;
    final y1 = y0 + 1 < _s ? y0 + 1 : y0;
    final fx = cx - x0;
    final fy = cy - y0;
    final v00 = f[(y0 * _s + x0) * stride + channel];
    final v10 = f[(y0 * _s + x1) * stride + channel];
    final v01 = f[(y1 * _s + x0) * stride + channel];
    final v11 = f[(y1 * _s + x1) * stride + channel];
    final top = v00 + (v10 - v00) * fx;
    final bot = v01 + (v11 - v01) * fx;
    return top + (bot - top) * fy;
  }

  // Sim-resolution scratch for the F1 albedo (rgb) + medium fraction.
  Float32List? _albedoCache;

  /// Composite the paint into straight-alpha RGBA8: finite-thickness
  /// Kubelka-Munk over the substrate (F1 — mandatory for glazing to read),
  /// then height-field normals with diffuse + oil specular (F2). Cells with
  /// no paint stay fully transparent so the layer overlays the canvas.
  ///
  /// [displayScale] renders F2 at `scale×` the simulation resolution (spec
  /// §10/§12: the lighting pass wants display-resolution normals). Albedo is
  /// computed once per sim cell and sampled bilinearly; height, normals,
  /// specular, tooth breakup, and alpha are evaluated per display pixel so
  /// relief and canvas grain stay crisp instead of quantizing into sim-size
  /// blocks. The output buffer holds `(size·scale)²` RGBA pixels.
  void compositeToRgba(Uint8List out, {int displayScale = 1}) {
    final scale = displayScale < 1 ? 1 : displayScale;
    final outSize = _s * scale;
    if (out.length < outSize * outSize * 4) {
      throw ArgumentError('Oil composite buffer is too small.');
    }
    final h = field.paintH;
    final k = field.kPaint;
    final s = field.sPaint;
    final props = field.props;
    final weights = SpectralColor.rgbWeights;
    final norms = SpectralColor.rgbWeightNorms;
    const bands = OilField.bands;
    const np = OilField.propChannels;

    // ── F1 at sim resolution: albedo rgb + medium fraction ─────────
    final albedo = _albedoCache ??= Float32List(field.cellCount * 4);
    // Substrate linear rgb, so edge bilinear blends toward the ground the
    // alpha is already fading into.
    final subR = _subR, subG = _subG, subB = _subB;
    final kmScale = params.kmScale;
    for (var i = 0; i < field.cellCount; i++) {
      final o = i * 4;
      if (h[i] <= 1e-5 && props[i * np] <= 1e-6) {
        albedo[o] = subR;
        albedo[o + 1] = subG;
        albedo[o + 2] = subB;
        albedo[o + 3] = 0.0;
        continue;
      }
      var r = 0.0, g = 0.0, b = 0.0;
      final kb = i * bands;
      for (var band = 0; band < bands; band++) {
        final refl = _finiteLayerReflectance(
          math.max(0.0, k[kb + band]) * kmScale,
          math.max(0.0, s[kb + band]) * kmScale,
          _substrateBands[band],
        );
        final w = weights[band];
        r += refl * w[0];
        g += refl * w[1];
        b += refl * w[2];
      }
      albedo[o] = r / norms[0];
      albedo[o + 1] = g / norms[1];
      albedo[o + 2] = b / norms[2];
      albedo[o + 3] = field.mediumFractionAt(i);
    }

    // Light and half vectors (view is straight down the z axis).
    final az = params.lightAzimuth * math.pi * 2.0;
    final el = params.lightElevation.clamp(0.05, 1.0) * math.pi * 0.5;
    final lx = math.cos(az) * math.cos(el);
    final ly = math.sin(az) * math.cos(el);
    final lz = math.sin(el);
    var hvx = lx, hvy = ly, hvz = lz + 1.0;
    final hLen = math.sqrt(hvx * hvx + hvy * hvy + hvz * hvz);
    hvx /= hLen;
    hvy /= hLen;
    hvz /= hLen;

    final ambient = params.ambient;
    final relief = params.reliefAmp;
    final toothAmp = params.toothAmp;
    final tooth = _tooth;
    final fineTooth = canvasToothUv;
    final invScale = 1.0 / scale;
    final invOut = 1.0 / outSize;

    double toothAt(double px, double py) {
      // px/py in display pixels. Fine sampler reads the real paper texture;
      // fallback interpolates the sim-res cache.
      if (fineTooth != null) {
        return fineTooth((px + 0.5) * invOut, (py + 0.5) * invOut).clamp(
          0.0,
          1.0,
        );
      }
      return _bilinear(tooth, (px + 0.5) * invScale - 0.5,
          (py + 0.5) * invScale - 0.5);
    }

    // ── F2 at display resolution ────────────────────────────────────
    for (var py = 0; py < outSize; py++) {
      final fy = (py + 0.5) * invScale - 0.5;
      for (var px = 0; px < outSize; px++) {
        final o = (py * outSize + px) * 4;
        final fx = (px + 0.5) * invScale - 0.5;
        final hC = _bilinear(h, fx, fy);
        final load = _bilinear(props, fx, fy, stride: np);
        if (hC <= 1e-5 && load <= 1e-6) {
          out[o] = 0;
          out[o + 1] = 0;
          out[o + 2] = 0;
          out[o + 3] = 0;
          continue;
        }

        final tooth01 = toothAt(px.toDouble(), py.toDouble());
        final cover = _smoothstep(0.0, params.hCover, hC + load * 0.35);
        final thin =
            1.0 - _smoothstep(params.dryThin * 0.6, params.dryThin * 1.4, hC);
        final poke =
            _smoothstep(
              params.toothLo,
              params.toothHi,
              tooth01 * toothAmp - hC,
            ) *
            thin;
        final alpha = (cover * (1.0 - poke)).clamp(0.0, 1.0);
        if (alpha <= 0.002) {
          out[o] = 0;
          out[o + 1] = 0;
          out[o + 2] = 0;
          out[o + 3] = 0;
          continue;
        }

        // Display-resolution normals: paint height bilinear, tooth at fine
        // detail, differenced one display pixel apart in sim-cell units.
        final hXm = _bilinear(h, fx - invScale, fy);
        final hXp = _bilinear(h, fx + invScale, fy);
        final hYm = _bilinear(h, fx, fy - invScale);
        final hYp = _bilinear(h, fx, fy + invScale);
        final tXm = toothAt(px - 1.0, py.toDouble());
        final tXp = toothAt(px + 1.0, py.toDouble());
        final tYm = toothAt(px.toDouble(), py - 1.0);
        final tYp = toothAt(px.toDouble(), py + 1.0);
        final dHdx =
            ((tXp * toothAmp + hXp) - (tXm * toothAmp + hXm)) /
            (2.0 * invScale);
        final dHdy =
            ((tYp * toothAmp + hYp) - (tYm * toothAmp + hYm)) /
            (2.0 * invScale);
        var nx = -dHdx * relief;
        var ny = -dHdy * relief;
        var nz = 1.0;
        final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
        nx /= nLen;
        ny /= nLen;
        nz /= nLen;

        final r = _bilinear(albedo, fx, fy, stride: 4, channel: 0);
        final g = _bilinear(albedo, fx, fy, stride: 4, channel: 1);
        final b = _bilinear(albedo, fx, fy, stride: 4, channel: 2);
        final mFrac = _bilinear(albedo, fx, fy, stride: 4, channel: 3);

        final nDotL = math.max(0.0, nx * lx + ny * ly + nz * lz);
        final diffuse = ambient + (1.0 - ambient) * nDotL;
        final sheen =
            params.oilSheen * (1.0 - 0.6 * mFrac) * _smoothstep(0.0, 0.03, hC);
        final nDotH = math.max(0.0, nx * hvx + ny * hvy + nz * hvz);
        final spec = sheen <= 0.0
            ? 0.0
            : math.pow(nDotH, params.gloss).toDouble() * sheen;

        final litR = (r * diffuse + spec).clamp(0.0, 1.0);
        final litG = (g * diffuse + spec).clamp(0.0, 1.0);
        final litB = (b * diffuse + spec).clamp(0.0, 1.0);

        out[o] = (SpectralColor.linearToSrgb(litR) * 255.0).round().clamp(
          0,
          255,
        );
        out[o + 1] = (SpectralColor.linearToSrgb(litG) * 255.0).round().clamp(
          0,
          255,
        );
        out[o + 2] = (SpectralColor.linearToSrgb(litB) * 255.0).round().clamp(
          0,
          255,
        );
        out[o + 3] = (alpha * 255.0).round().clamp(0, 255);
      }
    }
  }

  /// Kubelka-Munk reflectance of a layer with areal absorption [kt] = `K·t`
  /// and areal scattering [st] = `S·t` over a substrate of reflectance [rg]
  /// (the watercolor §12 finite-thickness form; mandatory here for glazing).
  static double _finiteLayerReflectance(double kt, double st, double rg) {
    if (kt + st < 1e-7) return rg; // vanishing layer → substrate.
    if (st < 1e-6) return rg * math.exp(-2.0 * kt); // pure absorber (glaze).
    if (kt < 1e-6) {
      // Pure scatterer: the hyperbolic form degenerates; use the K→0 limit.
      final t = st * (1.0 - rg);
      return ((t + rg) / (t + 1.0)).clamp(0.0, 1.0);
    }
    final a = (kt + st) / st;
    final x = math.sqrt(kt * kt + 2.0 * kt * st); // = b·S·t
    final bCothX = x >= 20.0
        ? x / st // coth → 1
        : (x / st) * ((math.exp(2.0 * x) + 1.0) / (math.exp(2.0 * x) - 1.0));
    final reflectance = (1.0 - rg * (a - bCothX)) / (a + bCothX - rg);
    return reflectance.clamp(0.0, 1.0);
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }
}

/// Extensive material amounts moved by one [OilSimulation.stamp] — the raw
/// truth the engine turns into an accepted [TransferReceipt]. Spectra are
/// extensive sums (already multiplied by the picked pigment load).
class OilStampExchange {
  double depositedVolume = 0.0;
  double depositedLoad = 0.0;
  double pickedVolume = 0.0;
  double pickedMedium = 0.0;
  double pickedLoad = 0.0;
  double pickedGran = 0.0;
  final List<double> pickedK = List<double>.filled(OilField.bands, 0.0);
  final List<double> pickedS = List<double>.filled(OilField.bands, 0.0);

  void addFrom(OilStampExchange other) {
    depositedVolume += other.depositedVolume;
    depositedLoad += other.depositedLoad;
    pickedVolume += other.pickedVolume;
    pickedMedium += other.pickedMedium;
    pickedLoad += other.pickedLoad;
    pickedGran += other.pickedGran;
    for (var b = 0; b < OilField.bands; b++) {
      pickedK[b] += other.pickedK[b];
      pickedS[b] += other.pickedS[b];
    }
  }
}
