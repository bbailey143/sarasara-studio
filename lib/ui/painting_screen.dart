import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/canvas/canvas_controller.dart';
import '../core/canvas/input_sample.dart';
import '../core/pigment/paint_mixture.dart';
import '../core/rendering/paper_renderer.dart';
import '../core/rendering/stroke_renderer.dart';
import '../models/pigment.dart';
import 'toolbar/main_toolbar.dart';

/// The main painting workspace.
///
/// Full-screen canvas with a floating toolbar. Handles pointer input,
/// delegates rendering to [_CanvasPainter], and manages brush settings.
///
/// Architecture (see ARCHITECTURE.md "Reactive State Model"):
/// - [CanvasController] extends ChangeNotifier and serves as the repaint
///   listenable for [CustomPaint] — the canvas repaints on every
///   controller notification (every pointer move during drawing).
/// - [CanvasController] owns brush/pigment/paper selection directly
///   (public getters/setters), so toolbar callbacks write straight into
///   it inside [setState] rather than maintaining a separate local copy
///   of "current tool state" that has to be kept in sync every build.
/// - [RepaintBoundary] isolates the canvas from toolbar rebuilds.
class PaintingScreen extends StatefulWidget {
  const PaintingScreen({super.key});

  @override
  State<PaintingScreen> createState() => _PaintingScreenState();
}

class _PaintingScreenState extends State<PaintingScreen> {
  final CanvasController _controller = CanvasController();
  late final _CanvasPainter _canvasPainter;
  Timer? _dwellTimer;
  Timer? _watercolorTimer;

  @override
  void initState() {
    super.initState();
    // The painter owns the finished-stroke image cache. Keeping one painter
    // for the lifetime of this screen prevents toolbar setState calls and
    // stroke completion from throwing that cache away.
    _canvasPainter = _CanvasPainter(controller: _controller);
    // Advance both media near 30fps while work is light. The next one-shot tick
    // is scheduled only after this one finishes, so an expensive wet sheet can
    // never create a repeating-timer backlog that starves stylus input.
    _scheduleMediumTick(const Duration(milliseconds: 33));
  }

  void _scheduleMediumTick(Duration delay) {
    _watercolorTimer = Timer(delay, () {
      if (!mounted) return;
      final stopwatch = Stopwatch()..start();
      _controller.tickWatercolor();
      _controller.tickOil();
      stopwatch.stop();
      final workMs = stopwatch.elapsedMilliseconds;
      // Preserve the normal 33 ms cadence when possible. Once work crosses
      // half a frame, always leave at least 16 ms for input and painting.
      final nextDelayMs = workMs >= 17 ? 16 : 33 - workMs;
      _scheduleMediumTick(Duration(milliseconds: nextDelayMs));
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _watercolorTimer?.cancel();
    _canvasPainter.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _controller.paperColor,
      body: Stack(
        children: [
          // ── Canvas ──────────────────────────────────────────────
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _canvasPainter,
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // ── Toolbar ────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Center(
              child: MainToolbar(
                activeBrush: _controller.activeBrush,
                activePigment: _controller.activePigment,
                brushColor: _controller.brushColor,
                isEraser: _controller.isEraser,
                canUndo: _controller.canUndo,
                canRedo: _controller.canRedo,
                activePaper: _controller.activePaper,
                isBrushDirty: _controller.isBrushDirty,
                onBrushChanged: (brush) =>
                    setState(() => _controller.activeBrush = brush),
                onPigmentChanged: (pigment) => setState(() {
                  _controller.activePigment = pigment;
                  _controller.activePaint = PaintMixture.single(pigment);
                  _controller.brushColor = pigment.displayColor;
                  _controller.isEraser = false;
                }),
                onBrushColorChanged: (c) => setState(() {
                  final customPigment = Pigment.custom(
                    name: 'Custom Color',
                    displayColor: c,
                  );
                  _controller.activePigment = customPigment;
                  _controller.activePaint = PaintMixture.single(customPigment);
                  _controller.brushColor = c;
                  _controller.isEraser =
                      false; // Switch back to brush on color pick
                }),
                onEraserToggled: () => setState(
                  () => _controller.isEraser = !_controller.isEraser,
                ),
                onPaperChanged: (paper) =>
                    setState(() => _controller.activePaper = paper),
                onUndo: () => setState(_controller.undo),
                onRedo: () => setState(_controller.redo),
                onClear: () => setState(_controller.clear),
                onRinseBrush: () => setState(_controller.rinseBrush),
              ),
            ),
          ),

          // ── Medium controls (Water / Oil) ──────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: _buildMediumPanel(),
          ),
        ],
      ),
    );
  }

  // ─── Medium Controls ─────────────────────────────────────────────

  bool _mediumPanelOpen = false;
  bool _showWaterPerformance = false;

  Widget _buildMediumPanel() {
    final isOil = _controller.activeMedium == ActiveMedium.oil;
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xF21C1C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _mediumPanelOpen = !_mediumPanelOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isOil ? Icons.format_paint_outlined : Icons.water_drop_outlined,
                    size: 18,
                    color: const Color(0xFF6C63FF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOil ? 'Oil' : 'Water',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _mediumPanelOpen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          _buildMediumToggle(isOil),
          if (_mediumPanelOpen && !isOil) ..._waterSliders(),
          if (_mediumPanelOpen && isOil) ..._oilSliders(),
        ],
      ),
    );
  }

  Widget _buildMediumToggle(bool isOil) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: SegmentedButton<ActiveMedium>(
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: const [
          ButtonSegment(
            value: ActiveMedium.watercolor,
            label: Text('Water', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment(
            value: ActiveMedium.oil,
            label: Text('Oil', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: {_controller.activeMedium},
        onSelectionChanged: (selection) =>
            setState(() => _controller.activeMedium = selection.first),
      ),
    );
  }

  List<Widget> _waterSliders() {
    return [
      _levelSlider(
        'Flow',
        _controller.watercolorFlow,
        (v) => _controller.watercolorFlow = v,
      ),
      _levelSlider(
        'Wetness',
        _controller.watercolorWetness,
        (v) => _controller.watercolorWetness = v,
      ),
      _levelSlider(
        'Edge darkening',
        _controller.watercolorEdge,
        (v) => _controller.watercolorEdge = v,
      ),
      _levelSlider(
        'Dry rate',
        _controller.watercolorDryRate,
        (v) => _controller.watercolorDryRate = v,
      ),
      _levelSlider(
        'Canvas tilt',
        _controller.watercolorTilt,
        (v) => _controller.watercolorTilt = v,
      ),
      _levelSlider(
        'Tilt direction (${_controller.watercolorTiltDirectionLabel})',
        _controller.watercolorTiltDirection,
        (v) => _controller.watercolorTiltDirection = v,
      ),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Show wet areas',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Switch(
            value: _controller.showWetAreas,
            onChanged: (value) =>
                setState(() => _controller.showWetAreas = value),
          ),
        ],
      ),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Show performance',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Switch(
            value: _showWaterPerformance,
            onChanged: (value) =>
                setState(() => _showWaterPerformance = value),
          ),
        ],
      ),
      if (_showWaterPerformance)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final updateMs = _controller.watercolorTickMilliseconds;
            final color = updateMs > 33
                ? const Color(0xFFFFA6A6)
                : Colors.white60;
            final active = _controller.watercolorActiveWorkFraction * 100.0;
            final imageMs = _controller.watercolorCompositeMilliseconds;
            final historyMb =
                _controller.debugWatercolorHistoryBytes() / (1024 * 1024);
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Fluid update ${updateMs.toStringAsFixed(1)} ms\n'
                'Image build ${imageMs.toStringAsFixed(1)} ms\n'
                'Active water ${active.toStringAsFixed(0)}%\n'
                'Undo memory ${historyMb.toStringAsFixed(1)} MB',
                style: TextStyle(color: color, fontSize: 11, height: 1.35),
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _oilSliders() {
    return [
      _levelSlider(
        'Body (thin ↔ impasto)',
        _controller.oilBody,
        (v) => _controller.oilBody = v,
      ),
      _levelSlider(
        'Thinner',
        _controller.oilThinner,
        (v) => _controller.oilThinner = v,
      ),
      _levelSlider(
        'Load',
        _controller.oilLoad,
        (v) => _controller.oilLoad = v,
      ),
      _levelSlider(
        'Pickup / smear',
        _controller.oilPickup,
        (v) => _controller.oilPickup = v,
      ),
      _levelSlider(
        'Gloss',
        _controller.oilGloss,
        (v) => _controller.oilGloss = v,
      ),
      _levelSlider(
        'Light angle',
        _controller.oilLightAngle,
        (v) => _controller.oilLightAngle = v,
      ),
    ];
  }

  Widget _levelSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        SizedBox(
          height: 28,
          child: Slider(
            value: value,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
      ],
    );
  }

  // ─── Pointer Event Handlers ──────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _controller.beginStroke(InputSample.fromPointerEvent(event));
    _startDwellTimer();
  }

  void _startDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = Timer.periodic(
      const Duration(milliseconds: 17),
      (_) => _controller.dwellStroke(),
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    _controller.updateStroke(InputSample.fromPointerEvent(event));
    _startDwellTimer();
  }

  void _onPointerUp(PointerUpEvent event) {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _controller.endStroke();
    setState(() {}); // Update undo/redo button states.
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _controller.endStroke();
    setState(() {});
  }
}

// ─── Canvas Painter ──────────────────────────────────────────────────

/// Renders the paper texture and all strokes onto the canvas.
///
/// Uses the [CanvasController] as its repaint listenable — repaints
/// whenever the controller notifies (every pointer move during drawing,
/// and after undo/redo/clear).
///
/// Rendering order:
/// 1. Paper background with visible tooth texture (cached image).
/// 2. All strokes rendered with paper-aware dry-brush and granulation.
///
/// The paper texture is rendered first, then strokes are composited on
/// top within a [saveLayer] so that eraser strokes (BlendMode.clear)
/// erase the stroke layer rather than cutting through the paper.
class _CanvasPainter extends CustomPainter {
  final CanvasController controller;
  ui.Image? _completedStrokeCache;
  int? _cachedCompletedRevision;
  Size? _cachedSize;
  int? _cachedPaperSeed;
  int? _cachedStrokesCount;

  _CanvasPainter({required this.controller}) : super(repaint: controller);

  void dispose() {
    _completedStrokeCache?.dispose();
    _completedStrokeCache = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    controller.canvasSize = size;

    // ── Paper texture background ─────────────────────────────────
    // Renders the visible paper tooth. The paper renderer caches the
    // result as a ui.Image so this is fast on subsequent frames.
    final paperTexture = controller.getPaperTexture(gridSize: 512);
    final toothVisibility = PaperRenderer.toothVisibilityFromPaper(
      controller.activePaper.tooth,
    );

    controller.paperRenderer.renderPaperTexture(
      canvas,
      size,
      paperTexture,
      controller.paperColor,
      toothVisibility: toothVisibility,
      onCacheReady: controller.requestRepaint,
    );

    // ── Watercolor wash ───────────────────────────────────────────
    // The simulation composite IS the painting: it accumulates every stroke's
    // deposited pigment and shows it flowing and drying. Drawn as a transparent
    // layer over the paper (never covering it), scaled from sim resolution.
    // The in-progress stroke is previewed on top for immediate feedback while
    // the wash catches up a frame or two later.
    if (controller.watercolorEnabled) {
      final wash = controller.watercolorImage;
      if (wash != null) {
        // Source rect from the image itself: composite resolution may exceed
        // simulation resolution (display-scale supersampling).
        canvas.drawImageRect(
          wash,
          Rect.fromLTWH(0, 0, wash.width.toDouble(), wash.height.toDouble()),
          rect,
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true,
        );
      }
      final wetOverlay = controller.watercolorWetOverlay;
      if (wetOverlay != null) {
        canvas.drawImageRect(
          wetOverlay,
          Rect.fromLTWH(
            0,
            0,
            wetOverlay.width.toDouble(),
            wetOverlay.height.toDouble(),
          ),
          rect,
          Paint()
            ..filterQuality = FilterQuality.low
            ..isAntiAlias = false,
        );
      }

      // ── Oil paint ─────────────────────────────────────────────
      // The lit oil composite sits above the wash: paint bodies cover
      // whatever they were laid over, while its alpha stays transparent
      // wherever no oil has gone.
      final oil = controller.oilImage;
      if (oil != null) {
        canvas.drawImageRect(
          oil,
          Rect.fromLTWH(0, 0, oil.width.toDouble(), oil.height.toDouble()),
          rect,
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true,
        );
      }
      // No hard-edged stroke preview: the wet media ARE the painting. The old
      // bristle preview read as blocky "8-bit" marks on top of the wash.
      return;
    }

    // ── Stroke layer ──────────────────────────────────────────────
    // saveLayer creates a compositing boundary so BlendMode.clear
    // in eraser strokes erases from this layer, not the paper.
    canvas.saveLayer(rect, Paint());

    _ensureCompletedStrokeCache(size, paperTexture);
    final cache = _completedStrokeCache;
    if (cache != null) {
      canvas.drawImage(cache, Offset.zero, Paint());
    }

    // Draw active stroke (currently being drawn).
    final active = controller.activeStroke;
    if (active != null) {
      StrokeRenderer.renderLivePreview(canvas, active);
    }

    canvas.restore();
  }

  void _ensureCompletedStrokeCache(Size size, dynamic paperTexture) {
    final needsCache =
        _completedStrokeCache == null ||
        _cachedCompletedRevision != controller.completedRevision ||
        _cachedSize != size ||
        _cachedPaperSeed != controller.activePaper.seed;

    if (!needsCache) return;

    final double width = size.width;
    final double height = size.height;
    if (width <= 0 || height <= 0) return;

    // Check if we can perform incremental rendering.
    final bool canRenderIncrementally =
        _completedStrokeCache != null &&
        _cachedSize == size &&
        _cachedPaperSeed == controller.activePaper.seed &&
        _cachedStrokesCount != null &&
        controller.completedStrokes.length == _cachedStrokesCount! + 1;

    final recorder = ui.PictureRecorder();
    final cacheCanvas = Canvas(recorder);
    final rect = Offset.zero & size;

    cacheCanvas.saveLayer(rect, Paint());
    if (canRenderIncrementally) {
      // 1. Draw existing cache image.
      cacheCanvas.drawImage(_completedStrokeCache!, Offset.zero, Paint());

      // 2. Draw ONLY the new last stroke.
      final lastStroke = controller.completedStrokes.last;
      StrokeRenderer.render(
        cacheCanvas,
        lastStroke,
        paperTexture: paperTexture,
        canvasSize: size,
        paperGranulationSupport: controller.activePaper.granulationSupport,
        paperDryBrushBreakup: controller.activePaper.dryBrushBreakup,
      );
    } else {
      // Full rebuild: render all completed strokes from scratch.
      for (final stroke in controller.completedStrokes) {
        StrokeRenderer.render(
          cacheCanvas,
          stroke,
          paperTexture: paperTexture,
          canvasSize: size,
          paperGranulationSupport: controller.activePaper.granulationSupport,
          paperDryBrushBreakup: controller.activePaper.dryBrushBreakup,
        );
      }
    }
    cacheCanvas.restore();

    final picture = recorder.endRecording();
    final newCache = picture.toImageSync(width.ceil(), height.ceil());
    picture.dispose();

    // Dispose old cache and assign new cache.
    _completedStrokeCache?.dispose();
    _completedStrokeCache = newCache;
    _cachedCompletedRevision = controller.completedRevision;
    _cachedSize = size;
    _cachedPaperSeed = controller.activePaper.seed;
    _cachedStrokesCount = controller.completedStrokes.length;
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}
