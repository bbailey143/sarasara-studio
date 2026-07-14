import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../brush/brush_reservoir.dart';
import '../brush/medium_adapter.dart';
import '../rendering/rgba_pixels.dart';
import 'oil_field.dart';
import 'oil_params.dart';
import 'oil_simulation.dart';

/// Facade that connects the shared brush pipeline to the oil simulation — the
/// concrete "oil adapter consuming a brush contact" (oil spec §2/§7 A).
///
/// Brush contacts arrive as footprint clusters in canvas pixels plus the
/// brush's carried spectrum; this maps them into Phase-A stamps and drags at
/// simulation resolution, then returns the **authoritative**
/// [TransferReceipt] built from what the canvas actually accepted and
/// released. Applying that receipt to the shared [BrushReservoir] is what
/// makes a dirty brush dirty: picked-up spectra blend into the reservoir and
/// tint every later mark until the brush is rinsed.
///
/// The engine owns no brush rules and no pigment optics of its own.
class OilEngine {
  OilEngine({
    int simSize = 192,
    OilParams params = const OilParams(),
    double Function(int x, int y)? canvasTooth,
    double Function(double u, double v)? canvasToothUv,
  }) : field = OilField(simSize) {
    simulation = OilSimulation(
      field: field,
      params: params,
      canvasTooth: canvasTooth,
      canvasToothUv: canvasToothUv,
    );
  }

  /// Display supersampling for the lit composite (spec §10: normals want
  /// display resolution). 2 renders lighting/tooth/alpha at twice the
  /// rheology grid; 1 disables the split.
  int displayScale = 2;

  /// Pixel width/height of [compositePixels]/[compositeImage] output.
  int get displaySize => simSize * (displayScale < 1 ? 1 : displayScale);

  final OilField field;
  late final OilSimulation simulation;

  /// Extra scale on the per-stamp deposit rate. Bristle clusters overlap, so
  /// the raw spec rate applied per cluster reaches the equilibrium film too
  /// fast; this is the display-feel knob (tuned by eye, like watercolor's
  /// depositRate).
  double depositRateScale = 0.65;

  /// Cluster stamp radius as a fraction of the brush radius. Individual
  /// bristle-cluster stamps overlap into the full footprint shape, which is
  /// what keeps flats directional instead of blobby.
  double clusterRadiusFraction = 0.5;

  /// Brush velocity (canvas px per contact) → imposed drag in cells. Tuned by
  /// eye: full-strength per-stamp pushes washboard the stroke into periodic
  /// heaps, so the imposed drag is a fraction of the raw stamp advance.
  double dragScale = 0.35;

  /// Canvas-volume → reservoir-volume conversion for receipts. Reservoir
  /// capacities are ~1.0; a stamp exchanges a few height·cell units.
  double volumeToReservoir = 0.02;

  /// Picked canvas pigment → reservoir pigment units. Sets how fast a drag
  /// through wet paint visibly dirties the brush.
  double pigmentPickupScale = 0.02;

  /// Per-contact cap on reservoir pigment intake so a full drag pass tints
  /// the carried color believably (~a third) instead of swamping it.
  double pigmentPickupCap = 0.02;

  int get simSize => field.size;

  OilParams get params => simulation.params;
  set params(OilParams value) => simulation.params = value;

  /// True once face flux is imperceptible — the paint has set and a driver
  /// can stop ticking (activity tiling's cheap CPU stand-in). The threshold
  /// is visual, not bitwise: the Bingham excess-stress factor decays
  /// asymptotically near yield, so exact zero can take unbounded time while
  /// nothing visibly moves.
  bool get isSettled => simulation.lastMaxFlux <= 1e-6;

  /// Deposit one brush contact into the paint and return the authoritative
  /// receipt of what moved. [footprint] are the contact's clusters (canvas
  /// pixels, velocities already coupling-scaled by the medium adapter);
  /// [reservoir] is the brush's carried state — its averages are the spectrum
  /// laid down, its fill scales the equilibrium film. [offer] bounds the
  /// reservoir-side volumes (from brush spec §8); [mediumFraction] is the
  /// binder share of deposited volume (the "thinner" control).
  TransferReceipt depositContact(
    List<MediumFootprintCluster> footprint,
    ui.Size canvasSize,
    double brushSizePx, {
    required BrushReservoirSnapshot reservoir,
    required TransferOffer offer,
    double mediumFraction = 0.0,
  }) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0 || footprint.isEmpty) {
      return TransferReceipt(medium: MediumFamily.oil);
    }
    final sx = simSize / canvasSize.width;
    final sy = simSize / canvasSize.height;
    final brushRadiusCells = (brushSizePx * sx * 0.5)
        .clamp(1.0, simSize * 0.25)
        .toDouble();
    final clusterRadius = math.max(
      0.75,
      brushRadiusCells * clusterRadiusFraction,
    );
    final film = simulation.params.brushFilm * reservoir.fill.clamp(0.0, 1.0);

    final kUnit = reservoir.kAverage;
    final sUnit = reservoir.sAverage;
    final exchange = OilStampExchange();

    // Live contacts conserve total pressure across their bristle clusters, so
    // each cluster's share is tiny. Normalize once: the whole contact carries
    // the stylus pressure, the strongest cluster stamps at that pressure and
    // the rest proportionally. Applying raw per-cluster shares here re-applies
    // pressure a second time and slams the drybrush gate shut (the same
    // double-application watercolor had to remove).
    final totalPressure = footprint
        .fold<double>(0.0, (sum, c) => sum + c.pressure)
        .clamp(0.0, 1.0);
    var maxClusterPressure = 0.0;
    for (final c in footprint) {
      if (c.pressure > maxClusterPressure) maxClusterPressure = c.pressure;
    }
    if (totalPressure <= 0.0 || maxClusterPressure <= 0.0) {
      return TransferReceipt(medium: MediumFamily.oil);
    }

    for (final c in footprint) {
      final cx = c.position.dx * sx;
      final cy = c.position.dy * sy;
      var vx = c.velocity.dx * sx * dragScale;
      var vy = c.velocity.dy * sy * dragScale;
      final speed = math.sqrt(vx * vx + vy * vy);
      const maxDrag = 0.5;
      if (speed > maxDrag) {
        vx *= maxDrag / speed;
        vy *= maxDrag / speed;
      }

      // Drag FIRST, exchange second. The brush belly pushes the paint already
      // on the canvas ahead and aside; the bristle film then re-wets the track
      // it leaves, so the deposit toward the equilibrium film is the LAST
      // thing that happens at each contact and the stroke center stays filled
      // with medium. The previous order (deposit, then drag the fresh paint
      // away) trenched every stroke into a watercolor-like hollow spine.
      simulation.drag(
        cx: cx,
        cy: cy,
        radius: clusterRadius * 1.35,
        velX: vx,
        velY: vy,
      );
      exchange.addFrom(
        simulation.stamp(
          cx: cx,
          cy: cy,
          radius: clusterRadius,
          pressure:
              (c.coverage * totalPressure * (c.pressure / maxClusterPressure))
                  .clamp(0.0, 1.0),
          film: film,
          kUnit: kUnit,
          sUnit: sUnit,
          granUnit: reservoir.granulationAverage,
          mediumFraction: mediumFraction,
          dragSpeed: speed,
          depositRateScale: depositRateScale,
        ),
      );
    }

    return _buildReceipt(exchange, reservoir, offer);
  }

  /// Turn the raw exchanged amounts into the accepted receipt that mutates
  /// the shared brush reservoir. Deposits leave at the reservoir's own
  /// average spectrum; pickups arrive with the *picked* spectrum, preserving
  /// the hue of whatever the brush dragged through.
  TransferReceipt _buildReceipt(
    OilStampExchange exchange,
    BrushReservoirSnapshot reservoir,
    TransferOffer offer,
  ) {
    final acceptedOut = math.min(
      offer.maximumOutflow,
      exchange.depositedVolume * volumeToReservoir,
    );
    final pigmentOut = reservoir.carrierVolume <= 0
        ? 0.0
        : reservoir.pigmentLoad *
              (acceptedOut / reservoir.carrierVolume).clamp(0.0, 1.0);

    final acceptedIn = math.min(
      offer.maximumInflow,
      exchange.pickedVolume * volumeToReservoir,
    );
    var pigmentIn = exchange.pickedLoad * pigmentPickupScale;
    if (pigmentIn > pigmentPickupCap) pigmentIn = pigmentPickupCap;
    final pickScale = exchange.pickedLoad <= 1e-9
        ? 0.0
        : pigmentIn / exchange.pickedLoad;

    return TransferReceipt(
      medium: MediumFamily.oil,
      acceptedOutflow: acceptedOut,
      acceptedInflow: acceptedIn,
      pigmentOut: pigmentOut,
      pigmentIn: pigmentIn,
      kOut: List<double>.generate(
        8,
        (band) => reservoir.kAverage[band] * pigmentOut,
        growable: false,
      ),
      sOut: List<double>.generate(
        8,
        (band) => reservoir.sAverage[band] * pigmentOut,
        growable: false,
      ),
      kIn: List<double>.generate(
        8,
        (band) => exchange.pickedK[band] * pickScale,
        growable: false,
      ),
      sIn: List<double>.generate(
        8,
        (band) => exchange.pickedS[band] * pickScale,
        growable: false,
      ),
      granulationOut: reservoir.granulationAverage * pigmentOut,
      granulationIn: exchange.pickedGran * pickScale,
      stainingOut: 0.0,
      stainingIn: 0.0,
    );
  }

  /// Advance the rheology [frames] steps (§7 B/D).
  void tick([int frames = 1]) {
    for (var i = 0; i < frames; i++) {
      simulation.step();
    }
  }

  OilFieldSnapshot snapshot() => field.snapshot();

  void restore(OilFieldSnapshot snapshot) => field.restore(snapshot);

  void clear() => field.clear();

  /// Set the ground the paint sits on (glazes read against this color).
  void setSubstrateColor(ui.Color color) {
    simulation.setSubstrate(
      _srgbToLinear(color.r),
      _srgbToLinear(color.g),
      _srgbToLinear(color.b),
    );
  }

  static double _srgbToLinear(double c) {
    final x = c.clamp(0.0, 1.0);
    return x <= 0.04045
        ? x / 12.92
        : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Composite the lit paint into a reusable straight-alpha RGBA8 buffer of
  /// [displaySize]² pixels.
  Uint8List compositePixels([Uint8List? into]) {
    final out = into ?? Uint8List(displaySize * displaySize * 4);
    simulation.compositeToRgba(out, displayScale: displayScale);
    return out;
  }

  /// Composite and decode into a [ui.Image] for the canvas painter.
  Future<ui.Image> compositeImage() {
    final pixels = compositePixels();
    premultiplyRgba8888(pixels);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      displaySize,
      displaySize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
