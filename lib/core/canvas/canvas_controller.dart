import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../models/brush.dart';
import '../../models/paper.dart';
import '../../models/pigment.dart';
import '../paper/paper_texture.dart';
import '../brush/brush_contact.dart';
import '../brush/brush_dynamics.dart';
import '../brush/brush_reservoir.dart';
import '../brush/medium_adapter.dart';
import '../brush/stroke_resampler.dart';
import '../oil/oil_engine.dart';
import '../oil/oil_field.dart';
import '../oil/oil_params.dart';
import '../pigment/canvas_pigment_layer.dart';
import '../pigment/paint_mixture.dart';
import '../rendering/paper_renderer.dart';
import '../watercolor/watercolor_engine.dart';
import '../watercolor/watercolor_field.dart';
import '../watercolor/watercolor_params.dart';
import 'input_sample.dart';
import 'stroke.dart';

/// Which physical medium new strokes feed. Both simulations persist on the
/// sheet at once (an oil passage does not erase a watercolor wash); the
/// switch controls where the *next* contact goes and which panel the UI
/// shows.
enum ActiveMedium { watercolor, oil }

/// Central state hub for the painting canvas: strokes, active drawing,
/// undo/redo, and repaint signaling.
///
/// Extends [ChangeNotifier] and is the ONLY reactive primitive in the app
/// (see ARCHITECTURE.md "Reactive State Model"). High-frequency updates
/// (every pointer move) call [notifyListeners] and are consumed only by
/// [CustomPaint]'s `repaint: controller` inside a `RepaintBoundary` — never
/// a widget rebuild. Low-frequency changes (tool switches, undo/redo) flow
/// through `ui/painting_screen.dart`'s `setState`.
///
/// This controller does NOT import `stroke_renderer.dart`. Rendering is
/// invoked only from the UI layer's `CustomPainter` — this controller owns
/// state/simulation, the UI layer owns presentation. Keep this boundary.
class CanvasController extends ChangeNotifier {
  // ─── Stroke Storage ────────────────────────────────────────────────

  final List<Stroke> _completedStrokes = [];
  Stroke? _activeStroke;
  int _completedRevision = 0;
  final List<Stroke> _redoStack = [];
  final StrokeResampler _strokeResampler = StrokeResampler();
  BrushStrokeDynamics? _brushDynamics;
  late BrushReservoir _brushReservoir;
  String _reservoirBrushId = '';
  static const WatercolorBrushAdapter _watercolorAdapter =
      WatercolorBrushAdapter();

  BrushReservoir get brushReservoir => _brushReservoir;

  /// Spatial deposited-pigment grid. Fixed at 128x128 — deliberately
  /// decoupled from canvas/display resolution for performance (see
  /// ARCHITECTURE.md "Performance Rules"). Nothing deposits into it yet
  /// (see [_depositStrokeToPigmentLayer]), so it stays empty in this
  /// scaffold; it is fully implemented and ready to be driven once the
  /// pickup/deposit simulation lands.
  final CanvasPigmentLayer pigmentLayer = CanvasPigmentLayer(128, 128);

  /// Canvas dimensions, updated by the CustomPainter each frame so pointer
  /// positions can be mapped to pigment-grid/paper-UV coordinates.
  Size canvasSize = Size.zero;

  // ─── Watercolor Medium (Phase 4) ──────────────────────────────────
  //
  // When enabled, brush contacts feed the watercolor simulation instead of
  // the flat stroke renderer, and the canvas shows its live composite. When
  // disabled, everything behaves exactly as the approved Phase-1 path.

  // The current watercolor solver runs on the CPU. Artist review showed that
  // a brute-force 320-cell field freezes when wet colours combine, so the safe
  // reference remains 224 while CPU activity masking and compact history keep
  // it usable; higher fidelity still belongs on the tiled GPU path.
  static const int _watercolorSimSize = 224;
  // Watercolor behaviour is always active — it is how paint behaves, not a
  // separate mode. Kept as a field for future "dry media" work, not a toggle.
  final bool _watercolorEnabled = true;
  WatercolorEngine? _watercolorEngine;
  Image? _watercolorImage;
  Image? _watercolorWetOverlay;
  bool _watercolorCompositing = false;
  bool _watercolorCompositeQueued = false;
  int _watercolorGeneration = 0;
  bool _disposed = false;
  bool _watercolorDirty = false;
  bool _showWetAreas = false;
  int _lastWatercolorTickMicros = 0;
  int _lastWatercolorCompositeMicros = 0;

  // Per-stroke compact wet-state checkpoints. Entries align 1:1 with completed
  // strokes; a stroke that fed the other medium stores null (that stroke
  // never changed this medium's state, so undoing it restores nothing here).
  // Watercolor stores only occupied 16x16 tiles instead of copying roughly
  // 13 MB of blank full-sheet fields before every stroke.
  WatercolorHistorySnapshot? _pendingWatercolorUndo;
  final List<WatercolorHistorySnapshot?> _watercolorUndo = [];
  final List<WatercolorHistorySnapshot?> _watercolorRedo = [];

  // ─── Oil Medium (Phase 5) ──────────────────────────────────────────
  //
  // A second persistent simulation beside the wash. Strokes feed whichever
  // medium is active; the painter composites the wash first, oil above it.

  static const int _oilSimSize = 192;
  static const OilBrushAdapter _oilAdapter = OilBrushAdapter();
  ActiveMedium _activeMedium = ActiveMedium.watercolor;
  OilEngine? _oilEngine;
  Image? _oilImage;
  bool _oilCompositing = false;
  bool _oilDirty = false;
  OilFieldSnapshot? _pendingOilUndo;
  final List<OilFieldSnapshot?> _oilUndo = [];
  final List<OilFieldSnapshot?> _oilRedo = [];

  // Artist-facing oil levels, 0..1, mapped onto oil spec §9/§11 parameters.
  double _oilBody = 0.55; // yield + consistency: fluid ↔ stiff impasto
  double _oilThinner = 0.12; // medium fraction of deposits
  double _oilLoad = 0.5; // equilibrium film thickness
  double _oilPickup = 0.5; // dirty-brush / smear strength
  double _oilGloss = 0.5; // specular character
  double _oilLightAngle = 0.625; // raking-light azimuth, turns

  // Artist-facing levels, 0..1, mapped onto spec §9 parameters.
  double _wcFlow = 0.5; // ↑ = lower viscosity, freer spread
  double _wcWetness = 0.55; // carrier volume per contact
  double _wcEdge = 0.7; // edge-darkening / bloom strength
  double _wcDryRate = 0.4; // evaporation speed
  double _wcTilt = 0.0;
  double _wcTiltDirection = 0.25; // turns: 0=right, .25=down

  bool get watercolorEnabled => _watercolorEnabled;

  double get watercolorFlow => _wcFlow;
  set watercolorFlow(double v) {
    _wcFlow = v.clamp(0.0, 1.0);
    _applyWatercolorLevels();
  }

  double get watercolorWetness => _wcWetness;
  set watercolorWetness(double v) {
    _wcWetness = v.clamp(0.0, 1.0);
    _applyWatercolorLevels();
  }

  double get watercolorEdge => _wcEdge;
  set watercolorEdge(double v) {
    _wcEdge = v.clamp(0.0, 1.0);
    _applyWatercolorLevels();
  }

  double get watercolorDryRate => _wcDryRate;
  set watercolorDryRate(double v) {
    _wcDryRate = v.clamp(0.0, 1.0);
    _applyWatercolorLevels();
  }

  /// Current live surface evaporation, exposed only for regression tests. The
  /// artist-facing control remains the normalized [watercolorDryRate] slider.
  @visibleForTesting
  double get debugWatercolorEvaporation => _dryPerStepForLevel(_wcDryRate);

  double get watercolorTilt => _wcTilt;
  set watercolorTilt(double v) {
    _wcTilt = v.clamp(0.0, 1.0);
    _applyWatercolorLevels();
  }

  double get watercolorTiltDirection => _wcTiltDirection;
  String get watercolorTiltDirectionLabel {
    final turn = _wcTiltDirection;
    if (turn < 0.125 || turn >= 0.875) return 'right';
    if (turn < 0.375) return 'down';
    if (turn < 0.625) return 'left';
    return 'up';
  }

  set watercolorTiltDirection(double v) {
    _wcTiltDirection = v.clamp(0.0, 1.0);
    _applyWatercolorLevels();
  }

  // ─── Oil public API ────────────────────────────────────────────────

  ActiveMedium get activeMedium => _activeMedium;
  set activeMedium(ActiveMedium value) {
    if (_activeMedium == value) return;
    _activeMedium = value;
    // The brush is one physical tool but its reservoir carries one medium at
    // a time: switching media rinses it (applyReceipt guards against silent
    // cross-medium mixing).
    rinseBrush();
  }

  double get oilBody => _oilBody;
  set oilBody(double v) {
    _oilBody = v.clamp(0.0, 1.0);
    _applyOilLevels();
  }

  double get oilThinner => _oilThinner;
  set oilThinner(double v) {
    _oilThinner = v.clamp(0.0, 1.0);
    _applyOilLevels();
  }

  double get oilLoad => _oilLoad;
  set oilLoad(double v) {
    _oilLoad = v.clamp(0.0, 1.0);
    _applyOilLevels();
  }

  double get oilPickup => _oilPickup;
  set oilPickup(double v) {
    _oilPickup = v.clamp(0.0, 1.0);
    _applyOilLevels();
  }

  double get oilGloss => _oilGloss;
  set oilGloss(double v) {
    _oilGloss = v.clamp(0.0, 1.0);
    _applyOilLevels();
  }

  double get oilLightAngle => _oilLightAngle;
  set oilLightAngle(double v) {
    _oilLightAngle = v.clamp(0.0, 1.0);
    _applyOilLevels();
  }

  /// The latest lit oil composite, or null before the first oil stroke.
  Image? get oilImage => _oilImage;

  int get oilSimSize => _oilSimSize;

  void _ensureOilEngine() {
    if (_oilEngine != null) return;
    final engine = OilEngine(
      simSize: _oilSimSize,
      params: _oilParamsFromLevels(),
      canvasTooth: _oilCanvasTooth,
      // Fine UV sampler: the display-resolution composite reads canvas grain
      // straight from the paper texture, not the coarse rheology grid.
      canvasToothUv: _oilCanvasToothUv,
    );
    engine.setSubstrateColor(paperColor);
    _oilEngine = engine;
  }

  double _oilCanvasTooth(int x, int y) {
    return getPaperTexture(
      gridSize: 512,
    ).heightAt(x / _oilSimSize, y / _oilSimSize);
  }

  double _oilCanvasToothUv(double u, double v) {
    return getPaperTexture(gridSize: 512).heightAt(u, v);
  }

  /// Body → yield + consistency (fluid ↔ stiff), Load → equilibrium film,
  /// Pickup → smear/dirty-brush lift, Gloss → specular, Light angle → raking
  /// azimuth. Thinner is per-deposit (see [_depositOil]) since it describes
  /// what leaves the brush, not the canvas paint.
  OilParams _oilParamsFromLevels() {
    return OilParams(
      tauY0: 0.25 + _oilBody * 3.2,
      consistencyK: 1.0 + _oilBody * 3.4,
      brushFilm: 1.0 + _oilLoad * 3.2,
      pickupRate: 0.04 + _oilPickup * 0.4,
      oilSheen: 0.06 + _oilGloss * 0.45,
      gloss: 10.0 + _oilGloss * 44.0,
      lightAzimuth: _oilLightAngle,
    );
  }

  void _applyOilLevels() {
    final engine = _oilEngine;
    if (engine != null) {
      engine.params = _oilParamsFromLevels();
      // Lighting is display-side: recomposite even while the paint is still.
      _oilDirty = true;
      _requestOilComposite();
    }
    notifyListeners();
  }

  /// Feed one brush contact into the oil paint. The engine performs the real
  /// bidirectional exchange and returns the authoritative receipt; applying
  /// it is what depletes the reservoir and dirties the brush with picked-up
  /// color. No-op while erasing (oil scraping is future work).
  void _depositOil(BrushContactSample contact) {
    if (isEraser) return;
    _ensureOilEngine();
    final payload = _oilAdapter.resolve(
      contact,
      const OilContactState(pickupAvailability: 1.0),
    );
    final receipt = _oilEngine!.depositContact(
      payload.footprint,
      canvasSize,
      activeBrush.size,
      reservoir: contact.reservoir,
      offer: TransferOffer(
        maximumOutflow: payload.receipt.acceptedOutflow,
        maximumInflow: payload.receipt.acceptedInflow,
      ),
      mediumFraction: _oilThinner * 0.85,
    );
    _brushReservoir.applyReceipt(receipt);
    if (receipt.pigmentIn > 1e-10) _brushHasPickup = true;
    _oilDirty = true;
  }

  /// Advance the oil rheology one frame and refresh its composite. Driven by
  /// the same UI timer as the wash; a no-op once the paint has set.
  void tickOil() {
    final engine = _oilEngine;
    if (engine == null) return;
    if (!_oilDirty && engine.isSettled) return;
    engine.tick();
    _oilDirty = false;
    _requestOilComposite();
  }

  void _requestOilComposite() {
    final engine = _oilEngine;
    if (engine == null || _oilCompositing) return;
    _oilCompositing = true;
    engine.compositeImage().then((image) {
      if (_disposed) {
        image.dispose();
        return;
      }
      _oilImage?.dispose();
      _oilImage = image;
      _oilCompositing = false;
      notifyListeners();
    });
  }

  /// Fallback rebuild of the oil paint by replaying stored contacts of oil
  /// strokes. Undo/redo normally restores exact checkpoints; this exists for
  /// robustness parity with the wash. Replay bypasses reservoir receipts (the
  /// live pass already accounted them) by offering zero volume.
  void _rebuildOilFromStrokes() {
    final engine = _oilEngine;
    if (engine == null) return;
    engine.clear();
    for (final stroke in _completedStrokes) {
      if (stroke.isEraser || stroke.medium != MediumFamily.oil) continue;
      for (final contact in stroke.contacts) {
        final payload = _oilAdapter.resolve(
          contact,
          const OilContactState(pickupAvailability: 1.0),
        );
        engine.depositContact(
          payload.footprint,
          canvasSize,
          stroke.brush.size,
          reservoir: contact.reservoir,
          offer: const TransferOffer(maximumOutflow: 0, maximumInflow: 0),
          mediumFraction: _oilThinner * 0.85,
        );
      }
    }
    engine.tick(2);
    _oilDirty = true;
    _requestOilComposite();
  }

  /// Debug: total oil paint volume on the canvas.
  double debugOilVolume() => _oilEngine?.field.totalVolume() ?? 0.0;
  double debugOilLoad() => _oilEngine?.field.totalLoad() ?? 0.0;

  /// Debug: raw lit composite of the oil paint (diagnostics/harness).
  Uint8List? debugOilCompositePixels() => _oilEngine?.compositePixels();

  /// The latest composited wash image, or null before the first tick.
  Image? get watercolorImage => _watercolorImage;
  Image? get watercolorWetOverlay => _watercolorWetOverlay;

  bool get showWetAreas => _showWetAreas;
  set showWetAreas(bool value) {
    if (_showWetAreas == value) return;
    _showWetAreas = value;
    if (!value) {
      _watercolorWetOverlay?.dispose();
      _watercolorWetOverlay = null;
      notifyListeners();
    } else {
      _requestWatercolorComposite();
    }
  }

  /// Simulation grid size (used by the painter to scale the wash image).
  int get watercolorSimSize => _watercolorSimSize;

  void _ensureWatercolorEngine() {
    if (_watercolorEngine != null) return;
    final engine = WatercolorEngine(
      simSize: _watercolorSimSize,
      params: _paramsFromLevels(),
      paperHeight: _watercolorPaperHeight,
      paperCapacity: _watercolorPaperCapacity,
    );
    _watercolorEngine = engine;
  }

  double _watercolorPaperHeight(int x, int y) {
    return getPaperTexture(
      gridSize: 512,
    ).heightAt(x / _watercolorSimSize, y / _watercolorSimSize);
  }

  double _watercolorPaperCapacity(int x, int y) {
    return getPaperTexture(
      gridSize: 512,
    ).capacityAt(x / _watercolorSimSize, y / _watercolorSimSize);
  }

  WatercolorParams _paramsFromLevels() {
    // Flow → how much pigment bleeds wet-into-wet; Edge → drying-rim darkening;
    // Dry rate → evaporation. Wetness is resolved into each accepted receipt.
    final angle = _wcTiltDirection * math.pi * 2.0;
    final tiltForce = _wcTilt * 0.24;
    final evaporation = _dryPerStepForLevel(_wcDryRate);
    return WatercolorParams(
      bleed: 0.05 + _wcFlow * 0.16,
      edge: 0.8 + _wcEdge * 2.6,
      // A curved range gives the lower half of the slider real painting time
      // instead of spending most of its travel on nearly identical fast-dry
      // values. At minimum, a wash can remain workable for minutes; the high
      // end still supports an intentionally quick dry.
      dry: evaporation,
      // Surface shine can fade while paper-held moisture stays workable long
      // enough to change colour and return to the wash.
      paperDryFactor: 0.22,
      wetThreshold: 0.045,
      gravityX: math.cos(angle) * tiltForce,
      gravityY: math.sin(angle) * tiltForce,
    );
  }

  static double _dryPerStepForLevel(double level) {
    const slow = 0.000002;
    const fast = 0.0012;
    final t = level.clamp(0.0, 1.0);
    return slow * math.pow(fast / slow, t).toDouble();
  }

  WatercolorContactState _watercolorContactState() => WatercolorContactState(
    // This must be decided before the receipt is issued: the brush reservoir
    // and the paper then agree on exactly how much water left the brush.
    carrierAcceptance: 0.25 + _wcWetness * 0.75,
    pickupAvailability: 1.0,
  );

  void _applyWatercolorLevels() {
    final engine = _watercolorEngine;
    if (engine != null) {
      engine.params = _paramsFromLevels();
    }
    notifyListeners();
  }

  /// Feed one brush contact into the wash using the brush's carried colour.
  /// No-op unless the medium is active (and not erasing).
  TransferReceipt _depositWatercolor(
    MediumContactPayload<WatercolorContactState> payload,
  ) {
    if (!_watercolorEnabled || isEraser) {
      return TransferReceipt(medium: MediumFamily.watercolor);
    }
    _ensureWatercolorEngine();
    final engine = _watercolorEngine!;
    final receipt = payload.receipt;
    final pigment = receipt.pigmentOut;
    final inv = pigment > 1e-12 ? 1.0 / pigment : 0.0;
    final actualReceipt = engine.depositContact(
      payload.footprint,
      canvasSize,
      activeBrush.size,
      kBand: List<double>.generate(
        8,
        (b) => receipt.kOut[b] * inv,
        growable: false,
      ),
      sBand: List<double>.generate(
        8,
        (b) => receipt.sOut[b] * inv,
        growable: false,
      ),
      gran: receipt.granulationOut * inv,
      stain: receipt.stainingOut * inv,
      receipt: receipt,
    );
    _watercolorDirty = true;
    return actualReceipt;
  }

  /// Advance the wash one frame and refresh its composite. Driven by a timer
  /// in the UI layer while the medium is active.
  void tickWatercolor() {
    final engine = _watercolorEngine;
    if (!_watercolorEnabled || engine == null) return;
    if (!_watercolorDirty && engine.isDry) return;
    final stopwatch = Stopwatch()..start();
    // Fresh splats have raw water before their mobility mask is derived.
    // _watercolorDirty guarantees the first visible step; engine.isDry also
    // checks raw water so non-UI callers get the same truthful answer.
    final shouldStep = _watercolorDirty || !engine.isDry;
    if (shouldStep) engine.tick();
    if (shouldStep) {
      _watercolorDirty = false;
      _requestWatercolorComposite();
    }
    stopwatch.stop();
    _lastWatercolorTickMicros = stopwatch.elapsedMicroseconds;
  }

  /// Compatibility fallback that rebuilds the wash from stored contacts.
  /// Normal undo/redo restores exact wet-state checkpoints; replay uses the
  /// same reconstructed receipts and stored cluster geometry if a checkpoint
  /// is unavailable.
  void _rebuildWatercolorFromStrokes() {
    final engine = _watercolorEngine;
    if (engine == null) return;
    engine.clear();
    for (final stroke in _completedStrokes) {
      if (stroke.isEraser || stroke.medium != MediumFamily.watercolor) {
        continue;
      }
      for (final contact in stroke.contacts) {
        final payload = _watercolorAdapter.resolve(
          contact,
          _watercolorContactState(),
        );
        final receipt = payload.receipt;
        final pigment = receipt.pigmentOut;
        final inv = pigment > 1e-12 ? 1.0 / pigment : 0.0;
        final replayReceipt = TransferReceipt(
          medium: MediumFamily.watercolor,
          acceptedOutflow: receipt.acceptedOutflow,
          pigmentOut: receipt.pigmentOut,
          kOut: receipt.kOut,
          sOut: receipt.sOut,
          granulationOut: receipt.granulationOut,
          stainingOut: receipt.stainingOut,
        );
        engine.depositContact(
          payload.footprint,
          canvasSize,
          stroke.brush.size,
          kBand: List<double>.generate(
            8,
            (b) => receipt.kOut[b] * inv,
            growable: false,
          ),
          sBand: List<double>.generate(
            8,
            (b) => receipt.sOut[b] * inv,
            growable: false,
          ),
          gran: receipt.granulationOut * inv,
          stain: receipt.stainingOut * inv,
          // Stored reservoir snapshots already preserve historical dirty
          // colour. Replay deposits them but must not pick material up twice.
          receipt: replayReceipt,
        );
      }
    }
    engine.tick(4);
    _watercolorDirty = true;
    _requestWatercolorComposite();
  }

  /// Debug: raw composite pixels of the current wash (for diagnostics/tests).
  Uint8List? debugCompositePixels() => _watercolorEngine?.compositePixels();

  /// Debug: total pigment load currently in the wash.
  double debugTotalLoad() => _watercolorEngine?.field.totalLoad() ?? 0.0;
  double debugTotalWater() => _watercolorEngine?.field.totalWater() ?? 0.0;
  double debugWetFraction() => _watercolorEngine?.field.wetFraction() ?? 0.0;
  int debugWatercolorHistoryBytes() => _watercolorUndo
      .whereType<WatercolorHistorySnapshot>()
      .fold<int>(0, (sum, snapshot) => sum + snapshot.estimatedBytes);
  double get watercolorActiveWorkFraction {
    final engine = _watercolorEngine;
    if (engine == null || engine.field.cellCount == 0) return 0.0;
    return engine.activeWorkCellCount / engine.field.cellCount;
  }

  double get watercolorTickMilliseconds => _lastWatercolorTickMicros / 1000.0;
  double get watercolorCompositeMilliseconds =>
      _lastWatercolorCompositeMicros / 1000.0;

  void _requestWatercolorComposite() {
    final engine = _watercolorEngine;
    if (engine == null) return;
    if (_watercolorCompositing) {
      // Keep one latest-frame request. Dropping requests while image decoding
      // was busy could leave the canvas showing the older, pre-mix frame.
      _watercolorCompositeQueued = true;
      return;
    }
    _watercolorCompositing = true;
    final generation = _watercolorGeneration;
    final compositeWatch = Stopwatch()..start();
    final compositeFuture = engine.compositeImage();
    compositeWatch.stop();
    _lastWatercolorCompositeMicros = compositeWatch.elapsedMicroseconds;
    compositeFuture.then((image) async {
      Image? wetOverlay;
      if (_showWetAreas) {
        wetOverlay = await engine.wetOverlayImage();
      }
      if (_disposed ||
          generation != _watercolorGeneration ||
          engine != _watercolorEngine) {
        image.dispose();
        wetOverlay?.dispose();
        _finishWatercolorComposite(engine);
        return;
      }
      _watercolorImage?.dispose();
      _watercolorImage = image;
      _watercolorWetOverlay?.dispose();
      _watercolorWetOverlay = wetOverlay;
      notifyListeners();
      _finishWatercolorComposite(engine);
    }).catchError((Object error, StackTrace _) {
      debugPrint('Watercolor image build failed: $error');
      _finishWatercolorComposite(engine);
    });
  }

  void _finishWatercolorComposite(WatercolorEngine engine) {
    _watercolorCompositing = false;
    final shouldBuildLatest =
        _watercolorCompositeQueued &&
        !_disposed &&
        engine == _watercolorEngine;
    _watercolorCompositeQueued = false;
    if (shouldBuildLatest) _requestWatercolorComposite();
  }

  /// Current carried paint cup in the brush.
  late PaintMixture _brushPaintCup;
  PaintMixture get brushPaintCup => _brushPaintCup;
  bool _brushHasPickup = false;

  /// Whether the real medium field has returned pigment to this brush. The
  /// toolbar uses this reservoir event, rather than the stroke's color label,
  /// to enable rinsing for watercolor and oil alike.
  bool get isBrushDirty => _brushHasPickup;

  CanvasController() {
    _brushPaintCup = _activePaint;
    _resetReservoir();
  }

  // ─── Current Brush / Pigment / Paper Settings ─────────────────────
  //
  // Set directly by the UI layer (see painting_screen.dart) and snapshot
  // into each new stroke.

  /// Active brush configuration.
  Brush activeBrush = Brush.sableRound;

  /// Current painting color.
  Color brushColor = Pigment.phthaloBlue.displayColor;

  /// Current named pigment.
  Pigment activePigment = Pigment.phthaloBlue;

  /// Current paint recipe carried by new strokes.
  PaintMixture _activePaint = PaintMixture.single(Pigment.phthaloBlue);
  PaintMixture get activePaint => _activePaint;
  set activePaint(PaintMixture value) {
    _activePaint = value;
    if (_activeStroke == null) {
      _brushPaintCup = value;
      _resetReservoir();
      notifyListeners();
    }
  }

  /// Rinse the brush, cleaning the paint cup and restoring the active paint.
  void rinseBrush() {
    _brushPaintCup = _activePaint;
    _resetReservoir();
    notifyListeners();
  }

  void _resetReservoir() {
    final family = _activeMedium == ActiveMedium.oil
        ? MediumFamily.oil
        : MediumFamily.watercolor;
    _brushReservoir = BrushReservoir.forBrush(activeBrush)..medium = family;
    _brushHasPickup = false;
    _reservoirBrushId = activeBrush.id;
    final load = _activePaint.totalAmount;
    _brushReservoir.applyReceipt(
      TransferReceipt(
        medium: family,
        pigmentIn: load,
        kIn: _activePaint.absorptionKSum,
        sIn: _activePaint.scatteringSSum,
        granulationIn: _activePaint.granulationWeight,
        stainingIn: _activePaint.stainingWeight,
      ),
    );
  }

  /// Request a repaint when an async renderer cache finishes.
  void requestRepaint() {
    notifyListeners();
  }

  /// Brush radius in logical pixels.
  double get brushSize => activeBrush.size;
  set brushSize(double value) {
    activeBrush = activeBrush.copyWith(size: value);
  }

  /// Current brush opacity.
  double get brushOpacity => activeBrush.opacity;
  set brushOpacity(double value) {
    activeBrush = activeBrush.copyWith(opacity: value);
  }

  /// Whether the current tool is an eraser.
  bool isEraser = false;

  // ─── Paper Surface ──────────────────────────────────────────────

  Paper _activePaper = Paper.plain;
  Paper get activePaper => _activePaper;

  /// Set the active paper, invalidating texture caches only when the
  /// texture-relevant parameters actually changed.
  set activePaper(Paper paper) {
    final previous = _activePaper;
    final sameTexture =
        previous.seed == paper.seed &&
        previous.tooth == paper.tooth &&
        previous.noiseScale == paper.noiseScale &&
        previous.absorbency == paper.absorbency &&
        previous.sizing == paper.sizing &&
        previous.capacity == paper.capacity;
    _activePaper = paper;
    _oilEngine?.setSubstrateColor(paperColor);
    if (!sameTexture) {
      _paperTexture = null; // Will regenerate on next access.
      _oilEngine?.simulation.invalidateToothCache();
      _oilDirty = true;
    }
    if (!sameTexture || previous.paperColor != paper.paperColor) {
      paperRenderer.invalidate();
    }
    notifyListeners();
  }

  PaperTexture? _paperTexture;

  /// Get the paper texture, generating it if needed.
  ///
  /// Kept separate from [pigmentLayer], which intentionally stays at
  /// 128x128 regardless of the requested paper texture resolution.
  PaperTexture getPaperTexture({int gridSize = 128}) {
    if (_paperTexture == null ||
        _paperTexture!.isDirty ||
        _paperTexture!.gridWidth != gridSize ||
        _paperTexture!.gridHeight != gridSize) {
      _paperTexture = PaperTexture.generate(
        tooth: _activePaper.tooth,
        absorbency: _activePaper.absorbency,
        sizing: _activePaper.sizing,
        capacity: _activePaper.capacity,
        noiseScale: _activePaper.noiseScale,
        seed: _activePaper.seed,
        gridWidth: gridSize,
        gridHeight: gridSize,
      );
    }
    return _paperTexture!;
  }

  /// Paper texture renderer with image caching.
  final PaperRenderer paperRenderer = PaperRenderer();

  /// The paper background color (derived from active paper).
  Color get paperColor => _activePaper.paperColor;

  // ─── Accessors ────────────────────────────────────────────────────

  List<Stroke> get completedStrokes => List.unmodifiable(_completedStrokes);
  Stroke? get activeStroke => _activeStroke;
  bool get canUndo => _completedStrokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get strokeCount => _completedStrokes.length;

  /// Changes whenever the finished-stroke layer needs to be redrawn.
  int get completedRevision => _completedRevision;

  // ─── Drawing Lifecycle ────────────────────────────────────────────

  /// Route one evaluated brush contact into the active medium. The brush
  /// pipeline upstream is identical for both media (one physical tool); only
  /// the medium adapter + simulation differ, per the shared contact contract.
  void _routeContact(BrushContactSample contact) {
    if (_activeMedium == ActiveMedium.oil) {
      _depositOil(contact);
    } else {
      final payload = _watercolorAdapter.resolve(
        contact,
        _watercolorContactState(),
      );
      final receipt = _depositWatercolor(payload);
      _brushReservoir.applyReceipt(receipt);
      if (receipt.pigmentIn > 1e-10) _brushHasPickup = true;
    }
  }

  /// Begin a new stroke with the first input sample.
  void beginStroke(InputSample firstSample) {
    if (_reservoirBrushId != activeBrush.id) _resetReservoir();
    if (isEraser) {
      _brushPaintCup = PaintMixture.customColor(paperColor);
    }

    _activeStroke = Stroke(
      brush: activeBrush,
      color: isEraser ? paperColor : brushColor,
      paint: _brushPaintCup,
      isEraser: isEraser,
      medium: _activeMedium == ActiveMedium.oil
          ? MediumFamily.oil
          : MediumFamily.watercolor,
    );

    // Checkpoint only the medium this stroke will touch; the other medium's
    // state is unchanged by it, so its checkpoint entry stays null.
    if (_activeMedium == ActiveMedium.oil) {
      _ensureOilEngine();
      _pendingOilUndo = _oilEngine!.snapshot();
      _pendingWatercolorUndo = null;
    } else {
      _ensureWatercolorEngine();
      _pendingWatercolorUndo = _watercolorEngine!.historySnapshot();
      _pendingOilUndo = null;
    }

    _strokeResampler.reset();
    _brushDynamics = BrushStrokeDynamics(
      brush: activeBrush,
      strokeId: _activeStroke!.seed,
      seed: _activeStroke!.seed,
    );

    for (final sample in _strokeResampler.add(
      firstSample,
      contactRadius: activeBrush.bundleRadius,
    )) {
      final contact = _brushDynamics!.evaluate(
        sample,
        reservoir: _brushReservoir,
        surfaceHeight: _surfaceHeightAt,
      );
      _routeContact(contact);
      _activeStroke!.addSample(sample, _brushPaintCup, contact);
    }
    notifyListeners();
  }

  /// Continue the active stroke with a new input sample.
  void updateStroke(InputSample sample) {
    if (_activeStroke == null) return;

    final resampled = _strokeResampler.add(
      sample,
      contactRadius: activeBrush.bundleRadius,
    );
    for (final point in resampled) {
      final contact = _brushDynamics!.evaluate(
        point,
        reservoir: _brushReservoir,
        surfaceHeight: _surfaceHeightAt,
      );
      _routeContact(contact);
      _activeStroke!.addSample(point, _brushPaintCup, contact);
    }
    notifyListeners();
  }

  /// Advances compression/recovery and bounded material exchange while the
  /// stylus is held still. Called by a lightweight pointer-down timer.
  void dwellStroke() {
    final stroke = _activeStroke;
    if (stroke == null || stroke.samples.isEmpty || _brushDynamics == null) {
      return;
    }
    final last = stroke.samples.last;
    final dwell = InputSample(
      position: last.position,
      pressure: last.pressure,
      tilt: last.tilt,
      orientation: last.orientation,
      timestamp: last.timestamp + 17,
      deviceKind: last.deviceKind,
    );
    final contact = _brushDynamics!.evaluate(
      dwell,
      reservoir: _brushReservoir,
      surfaceHeight: _surfaceHeightAt,
    );
    // The reservoir offer already integrates this 17 ms contact duration, so
    // a held stylus makes one bounded drop rather than repeated full stamps.
    _routeContact(contact);
    stroke.addSample(dwell, _brushPaintCup, contact);
    notifyListeners();
  }

  double _surfaceHeightAt(Offset position) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return 0.0;
    final uv = PaperTexture.positionToUV(
      position.dx,
      position.dy,
      canvasSize.width,
      canvasSize.height,
    );
    return getPaperTexture(gridSize: 512).heightAt(uv[0], uv[1]);
  }

  /// Finish the active stroke and add it to the completed list.
  ///
  /// Any new stroke clears the redo stack (standard undo behavior).
  void endStroke() {
    if (_activeStroke != null && _activeStroke!.isNotEmpty) {
      _depositStrokeToPigmentLayer(_activeStroke!);
      _completedStrokes.add(_activeStroke!);
      _redoStack.clear();
      // One (possibly null) checkpoint per medium per stroke keeps the lists
      // stroke-aligned; null means "this stroke never touched that medium".
      _watercolorUndo.add(_pendingWatercolorUndo);
      _oilUndo.add(_pendingOilUndo);
      _watercolorRedo.clear();
      _oilRedo.clear();
      _completedRevision++;
    }
    _pendingWatercolorUndo = null;
    _pendingOilUndo = null;
    _activeStroke = null;
    _brushDynamics = null;
    notifyListeners();
  }

  /// TODO(Pigment Mixing): rasterize [stroke]'s samples into [pigmentLayer]
  /// cells with a circular per-sample falloff footprint, calling
  /// [CanvasPigmentLayer.deposit]. The footprint math (grid-radius clamp,
  /// normalized elliptical distance test) and the deposit-rate constant
  /// are a tuned-feel decision, not a closed-form one — see
  /// ARCHITECTURE.md "Performance Rules" (this must stay cheap; it runs
  /// once per completed stroke, iterating a small local footprint, not the
  /// whole canvas).
  ///
  /// Currently a no-op: [pigmentLayer] stays empty. This only affects
  /// pickup/dirty-brush behavior — visible strokes still render from
  /// [Stroke.samples]/[Stroke.samplePaints] regardless (see
  /// ARCHITECTURE.md "Known Architectural Decisions" on the
  /// rendering-vs-pigment-grid boundary).
  void _depositStrokeToPigmentLayer(Stroke stroke) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    for (var i = 0; i < stroke.samples.length; i++) {
      final sample = stroke.samples[i];
      final paint = i < stroke.samplePaints.length
          ? stroke.samplePaints[i]
          : stroke.paint;
      final gx = sample.position.dx / canvasSize.width * pigmentLayer.width;
      final gy = sample.position.dy / canvasSize.height * pigmentLayer.height;
      final radius =
          (stroke.brush.size / canvasSize.width * pigmentLayer.width * 0.45)
              .clamp(0.75, 6.0);
      final minX = (gx - radius).floor().clamp(0, pigmentLayer.width - 1);
      final maxX = (gx + radius).ceil().clamp(0, pigmentLayer.width - 1);
      final minY = (gy - radius).floor().clamp(0, pigmentLayer.height - 1);
      final maxY = (gy + radius).ceil().clamp(0, pigmentLayer.height - 1);
      for (var cy = minY; cy <= maxY; cy++) {
        for (var cx = minX; cx <= maxX; cx++) {
          final dx = (cx + 0.5 - gx) / radius;
          final dy = (cy + 0.5 - gy) / radius;
          final distance2 = dx * dx + dy * dy;
          if (distance2 > 1.0) continue;
          final falloff = (1.0 - distance2).clamp(0.0, 1.0);
          final amount =
              0.018 * sample.pressure * falloff * stroke.brush.paintLoad;
          pigmentLayer.deposit(cx, cy, paint, amount);
        }
      }
    }
  }

  /// Regenerate the entire pigment layer from completed strokes.
  ///
  /// Called by undo/redo instead of storing pigment-grid snapshots — a
  /// deliberate simplicity-over-memory tradeoff (strokes are deterministic
  /// and replay cheaply since the grid is only 128x128).
  void _regeneratePigmentLayer() {
    pigmentLayer.clear();
    for (final stroke in _completedStrokes) {
      _depositStrokeToPigmentLayer(stroke);
    }
  }

  // ─── Undo / Redo ─────────────────────────────────────────────────

  void undo() {
    if (_completedStrokes.isEmpty) return;
    _redoStack.add(_completedStrokes.removeLast());
    _regeneratePigmentLayer();

    // Watercolor: a non-null checkpoint means the undone stroke touched the
    // wash — swap current state onto the redo stack and restore. A null
    // entry passes through so both stacks stay stroke-aligned.
    if (_watercolorUndo.isNotEmpty) {
      final checkpoint = _watercolorUndo.removeLast();
      final engine = _watercolorEngine;
      if (checkpoint != null && engine != null) {
        _watercolorRedo.add(engine.historySnapshot());
        engine.restoreHistory(checkpoint);
        _watercolorDirty = true;
        _requestWatercolorComposite();
      } else {
        _watercolorRedo.add(null);
      }
    } else {
      _rebuildWatercolorFromStrokes();
    }

    if (_oilUndo.isNotEmpty) {
      final checkpoint = _oilUndo.removeLast();
      final engine = _oilEngine;
      if (checkpoint != null && engine != null) {
        _oilRedo.add(engine.snapshot());
        engine.restore(checkpoint);
        _oilDirty = true;
        _requestOilComposite();
      } else {
        _oilRedo.add(null);
      }
    } else if (_oilEngine != null) {
      _rebuildOilFromStrokes();
    }

    _completedRevision++;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _completedStrokes.add(_redoStack.removeLast());
    _regeneratePigmentLayer();

    if (_watercolorRedo.isNotEmpty) {
      final checkpoint = _watercolorRedo.removeLast();
      final engine = _watercolorEngine;
      if (checkpoint != null && engine != null) {
        _watercolorUndo.add(engine.historySnapshot());
        engine.restoreHistory(checkpoint);
        _watercolorDirty = true;
        _requestWatercolorComposite();
      } else {
        _watercolorUndo.add(null);
      }
    } else {
      _rebuildWatercolorFromStrokes();
    }

    if (_oilRedo.isNotEmpty) {
      final checkpoint = _oilRedo.removeLast();
      final engine = _oilEngine;
      if (checkpoint != null && engine != null) {
        _oilUndo.add(engine.snapshot());
        engine.restore(checkpoint);
        _oilDirty = true;
        _requestOilComposite();
      } else {
        _oilUndo.add(null);
      }
    } else if (_oilEngine != null) {
      _rebuildOilFromStrokes();
    }

    _completedRevision++;
    notifyListeners();
  }

  // ─── Clear ────────────────────────────────────────────────────────

  /// Remove all completed strokes. Not undoable.
  void clear() {
    final hadStrokes = _completedStrokes.isNotEmpty || _redoStack.isNotEmpty;
    _completedStrokes.clear();
    _redoStack.clear();
    _watercolorUndo.clear();
    _watercolorRedo.clear();
    _pendingWatercolorUndo = null;
    _oilUndo.clear();
    _oilRedo.clear();
    _pendingOilUndo = null;
    pigmentLayer.clear();
    _watercolorGeneration++;
    _watercolorEngine?.clear();
    _watercolorImage?.dispose();
    _watercolorImage = null;
    _watercolorWetOverlay?.dispose();
    _watercolorWetOverlay = null;
    _watercolorDirty = true;
    _watercolorCompositing = false;
    _watercolorCompositeQueued = false;
    _oilEngine?.clear();
    _oilImage?.dispose();
    _oilImage = null;
    _oilDirty = true;
    if (hadStrokes) _completedRevision++;
    notifyListeners();
  }

  // ─── Disposal ─────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    paperRenderer.dispose();
    _watercolorImage?.dispose();
    _watercolorWetOverlay?.dispose();
    _oilImage?.dispose();
    super.dispose();
  }
}
