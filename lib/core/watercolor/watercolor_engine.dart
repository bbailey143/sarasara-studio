import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../brush/brush_reservoir.dart';
import '../brush/medium_adapter.dart';
import '../rendering/rgba_pixels.dart';
import 'watercolor_field.dart';
import 'watercolor_params.dart';
import 'watercolor_simulation.dart';

/// Facade that connects the shared brush pipeline to the watercolor
/// simulation. It is the concrete home of the spec's "watercolor adapter
/// consuming a brush contact" (§2/§10): brush contacts arrive as
/// [MediumContactPayload]s (footprint clusters in canvas pixels + an accepted
/// [TransferReceipt]); this maps them into Phase-A splats at simulation
/// resolution, advances the per-frame pipeline, and composites to pixels.
///
/// The engine owns no brush rules and no pigment optics of its own — it routes
/// accepted transfer into [WatercolorSimulation] and reads its composite back.
class WatercolorEngine {
  WatercolorEngine({
    int simSize = 256,
    WatercolorParams params = const WatercolorParams(),
    double Function(int x, int y)? paperHeight,
    double Function(int x, int y)? paperCapacity,
  }) : field = WatercolorField(simSize) {
    simulation = WatercolorSimulation(
      field: field,
      params: params,
      paperHeight: paperHeight,
      paperCapacity: paperCapacity,
    );
  }

  final WatercolorField field;
  late final WatercolorSimulation simulation;

  /// Synthetic-scene wetness multiplier. Live wetness is accepted by the
  /// adapter and recorded in the transfer receipt before this engine runs.
  double carrierGain = 1.0;

  /// Synthetic/direct-simulation deposit calibration used by engine tests and
  /// scripted scenes that do not provide a brush receipt. Live canvas contact
  /// always follows the receipt-authoritative path below.
  double depositRate = 5.0;

  /// Synthetic-scene pigment calibration, deliberately separate from carrier
  /// volume. Live colour strength is folded into the fixed receipt conversion.
  double pigmentConcentration = 3.0;

  /// Synthetic/direct-simulation pressure curves. The live adapter applies the
  /// same exponents while constructing its accepted transfer receipt.
  double pigmentPressureExponent = 0.65;
  double pigmentTransferGain = 0.16;
  double carrierPressureExponent = 2.0;
  double carrierTransferGain = 0.18;

  /// Pressure coupling for bristle-imposed motion. This is separate from both
  /// material curves so a feather touch cannot fling an existing puddle.
  double pushPressureExponent = 1.4;

  /// Converts the brush reservoir's normalized physical transfer units into
  /// this CPU reference grid's field units. The accepted receipt remains the
  /// authority: a zero receipt always deposits zero material, and elapsed
  /// contact time is already integrated by the brush reservoir offer.
  static const double receiptPigmentGain = 1200.0;
  static const double receiptCarrierGain = 875.0;

  /// Synthetic-scene carrier volume per unit of deposited pigment.
  double waterRatio = 1.4;

  int get simSize => field.size;

  /// Live simulation levels (§9). Set from the UI without losing the wash.
  WatercolorParams get params => simulation.params;
  set params(WatercolorParams value) => simulation.params = value;

  /// Deposit one brush contact into the wash. [footprint] are physical bristle
  /// clusters in canvas pixels. Live calls supply [receipt], whose spectrum,
  /// properties, carrier, and pigment totals are the sole material authority.
  /// [kBand]/[sBand]/[gran]/[stain] are used only when the receipt is omitted
  /// for an explicit synthetic test or scene.
  TransferReceipt depositContact(
    List<MediumFootprintCluster> footprint,
    ui.Size canvasSize,
    double brushSizePx, {
    required List<double> kBand,
    required List<double> sBand,
    required double gran,
    required double stain,
    TransferReceipt? receipt,
  }) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      return TransferReceipt(medium: MediumFamily.watercolor);
    }
    if (footprint.isEmpty) {
      return TransferReceipt(medium: MediumFamily.watercolor);
    }

    final sx = simSize / canvasSize.width;
    final sy = simSize / canvasSize.height;
    final fallbackRadiusCells = (brushSizePx * sx * 0.5)
        .clamp(1.0, simSize * 0.25)
        .toDouble();
    final clusterScale = math.sqrt(sx * sy);

    final weights = footprint
        .map((c) => c.coverage * c.pressure)
        .toList(growable: false);
    final weightSum = weights.fold<double>(0.0, (sum, value) => sum + value);
    final normalPressure = footprint.fold<double>(
      0.0,
      (sum, cluster) => sum + cluster.pressure,
    ).clamp(0.0, 1.0).toDouble();
    // BrushDynamics divides one stylus force among sibling clusters, so their
    // pressure values are force shares whose sum reconstructs the original
    // stylus pressure. Averaging those shares would make the same touch weaker
    // merely because a brush has more bristles.
    if (weightSum <= 0.0 || normalPressure <= 0.0) {
      return TransferReceipt(medium: MediumFamily.watercolor);
    }
    if (receipt != null && receipt.medium != MediumFamily.watercolor) {
      throw ArgumentError('Watercolor cannot consume a non-watercolor receipt.');
    }
    final receiptPigment = receipt?.pigmentOut ?? 0.0;
    final receiptPigmentInv = receiptPigment > 1e-12
        ? 1.0 / receiptPigment
        : 0.0;
    // A live receipt carries its own exact spectrum and pigment properties.
    // The parallel arguments remain only for the explicit synthetic path;
    // they can never recolour a real accepted transfer.
    final contactK = receipt == null
        ? kBand
        : List<double>.generate(
            WatercolorField.bands,
            (band) => receipt.kOut[band] * receiptPigmentInv,
            growable: false,
          );
    final contactS = receipt == null
        ? sBand
        : List<double>.generate(
            WatercolorField.bands,
            (band) => receipt.sOut[band] * receiptPigmentInv,
            growable: false,
          );
    final contactGran = receipt == null
        ? gran
        : receipt.granulationOut * receiptPigmentInv;
    final contactStain = receipt == null
        ? stain
        : receipt.stainingOut * receiptPigmentInv;
    final totalPigment = receipt == null
        ? depositRate *
              pigmentTransferGain *
              math.pow(normalPressure, pigmentPressureExponent) *
              pigmentConcentration
        : receipt.pigmentOut * receiptPigmentGain;
    final totalCarrier = receipt == null
        ? depositRate *
              carrierTransferGain *
              math.pow(normalPressure, carrierPressureExponent) *
              waterRatio *
              carrierGain
        : receipt.acceptedOutflow * receiptCarrierGain;
    final pushScale = math.pow(normalPressure, pushPressureExponent).toDouble();

    final splats = <WatercolorSplat>[];
    for (var cluster = 0; cluster < footprint.length; cluster++) {
      final c = footprint[cluster];
      final share = weights[cluster] / weightSum;
      final radius = c.radius > 0.0
          ? (c.radius * clusterScale).clamp(0.75, simSize * 0.25).toDouble()
          : fallbackRadiusCells;
      splats.add(
        WatercolorSplat(
          cx: c.position.dx * sx,
          cy: c.position.dy * sy,
          radius: radius,
          // Coverage and normalized transfer already describe quantity.
          // Pressure therefore stays at one inside this raster footprint.
          pressure: 1.0,
          load: totalPigment * share,
          waterAmt: totalCarrier * share,
          impulseX: c.velocity.dx * sx * pushScale,
          impulseY: c.velocity.dy * sy * pushScale,
          dragSpeed: math.sqrt(
            c.velocity.dx * c.velocity.dx * sx * sx +
                c.velocity.dy * c.velocity.dy * sy * sy,
          ),
        ),
      );
    }
    // Pickup is resolved against the pre-contact wash, then the outgoing
    // material lands. The returned receipt therefore contains exactly what
    // left both sides; the brush never guesses what the paper released.
    final pickup = receipt == null
        ? WatercolorPickup()
        : simulation.pickupContact(
            splats: splats,
            maximumCarrier: receipt.acceptedInflow * receiptCarrierGain,
          );
    simulation.splatContact(
      splats: splats,
      contactPressure: normalPressure,
      kBand: contactK,
      sBand: contactS,
      gran: contactGran,
      stain: contactStain,
      amountsAreTotals: receipt != null,
    );
    if (receipt == null) {
      return TransferReceipt(medium: MediumFamily.watercolor);
    }
    return TransferReceipt(
      medium: MediumFamily.watercolor,
      acceptedOutflow: receipt.acceptedOutflow,
      acceptedInflow: pickup.carrier / receiptCarrierGain,
      pigmentOut: receipt.pigmentOut,
      pigmentIn: pickup.pigment / receiptPigmentGain,
      kOut: receipt.kOut,
      kIn: List<double>.generate(
        WatercolorField.bands,
        (band) => pickup.k[band] / receiptPigmentGain,
        growable: false,
      ),
      sOut: receipt.sOut,
      sIn: List<double>.generate(
        WatercolorField.bands,
        (band) => pickup.s[band] / receiptPigmentGain,
        growable: false,
      ),
      granulationOut: receipt.granulationOut,
      granulationIn: pickup.granulation / receiptPigmentGain,
      stainingOut: receipt.stainingOut,
      stainingIn: pickup.staining / receiptPigmentGain,
    );
  }

  /// Advance the wash [frames] steps (§5 B→E).
  void tick([int frames = 1]) {
    for (var i = 0; i < frames; i++) {
      simulation.step();
    }
  }

  /// True only after carrier is gone and the final suspended fraction has been
  /// settled/protected. A zero wet mask by itself may still need one last pass.
  bool get isDry =>
      field.totalWater() <= 1e-6 &&
      field.totalSaturation() <= 1e-6 &&
      field.totalSuspendedLoad() <= 1e-6 &&
      field.totalUnprotectedDepositedLoad() <= 1e-6;

  int get activeWorkCellCount => simulation.debugActiveWorkCellCount;

  WatercolorFieldSnapshot snapshot() => field.snapshot();

  void restore(WatercolorFieldSnapshot snapshot) => field.restore(snapshot);

  /// Sparse-but-exact stroke history used by the live canvas. The full
  /// snapshot above remains available for engine diagnostics and interchange.
  WatercolorHistorySnapshot historySnapshot() => field.historySnapshot();

  void restoreHistory(WatercolorHistorySnapshot snapshot) =>
      field.restoreHistory(snapshot);

  /// Composite the current wash into a reusable RGBA8 pixel buffer.
  Uint8List compositePixels([Uint8List? into]) {
    final out = into ?? Uint8List(field.cellCount * 4);
    simulation.compositeToRgba(out);
    return out;
  }

  /// Composite and decode into a [ui.Image] for the canvas painter.
  Future<ui.Image> compositeImage() {
    final pixels = compositePixels();
    premultiplyRgba8888(pixels);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      simSize,
      simSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Future<ui.Image> wetOverlayImage() {
    final pixels = Uint8List(field.cellCount * 4);
    simulation.wetMaskToRgba(pixels);
    premultiplyRgba8888(pixels);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      simSize,
      simSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Reset to a dry, blank sheet (undo/clear restores dry state per §7).
  void clear() {
    field.velU.fillRange(0, field.velU.length, 0.0);
    field.velV.fillRange(0, field.velV.length, 0.0);
    field.pressure.fillRange(0, field.pressure.length, 0.0);
    field.waterH.fillRange(0, field.waterH.length, 0.0);
    field.waterM.fillRange(0, field.waterM.length, 0.0);
    field.saturation.fillRange(0, field.saturation.length, 0.0);
    field.ksus.fillRange(0, field.ksus.length, 0.0);
    field.ssus.fillRange(0, field.ssus.length, 0.0);
    field.propsSus.fillRange(0, field.propsSus.length, 0.0);
    field.kdep.fillRange(0, field.kdep.length, 0.0);
    field.sdep.fillRange(0, field.sdep.length, 0.0);
    field.propsDep.fillRange(0, field.propsDep.length, 0.0);
    field.kDry.fillRange(0, field.kDry.length, 0.0);
    field.sDry.fillRange(0, field.sDry.length, 0.0);
    field.propsDry.fillRange(0, field.propsDry.length, 0.0);
  }
}
