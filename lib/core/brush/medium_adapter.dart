import 'dart:math' as math;
import 'dart:ui';

import 'brush_contact.dart';
import 'brush_reservoir.dart';

/// Resolves brush-side opportunity and medium controls into a field payload.
/// The live medium engine then replaces any pickup opportunity with the exact
/// material its canvas field actually released before the reservoir updates.
abstract interface class BrushMediumAdapter<T> {
  MediumFamily get medium;
  MediumContactPayload<T> resolve(BrushContactSample contact, T canvasState);
}

class MediumContactPayload<T> {
  const MediumContactPayload({
    required this.canvasState,
    required this.receipt,
    required this.footprint,
  });

  final T canvasState;
  final TransferReceipt receipt;
  final List<MediumFootprintCluster> footprint;
}

class MediumFootprintCluster {
  const MediumFootprintCluster({
    required this.position,
    required this.coverage,
    required this.pressure,
    required this.velocity,
    this.radius = 0.0,
  });
  final Offset position;
  final double coverage;

  /// This cluster's force-preserving share of the whole stylus pressure.
  /// Sibling shares sum to the contact's normalized pressure.
  final double pressure;
  final Offset velocity;

  /// Radius of this physical bristle cluster in canvas units. A zero value is
  /// retained as a compatibility fallback for synthetic test contacts.
  final double radius;
}

class WatercolorContactState {
  const WatercolorContactState({
    this.carrierAcceptance = 1.0,
    this.pigmentAcceptance = 1.0,
    this.pickupAvailability = 1.0,
    this.dragCoupling = 0.12,
  });
  final double carrierAcceptance;
  final double pigmentAcceptance;
  final double pickupAvailability;
  final double dragCoupling;
}

/// Phase-A mapping only. Flow, blooms, granulation and staining remain in the
/// watercolor simulation described by watercolor-engine-spec.md.
class WatercolorBrushAdapter
    implements BrushMediumAdapter<WatercolorContactState> {
  const WatercolorBrushAdapter();

  @override
  MediumFamily get medium => MediumFamily.watercolor;

  @override
  MediumContactPayload<WatercolorContactState> resolve(
    BrushContactSample contact,
    WatercolorContactState canvasState,
  ) {
    final pressure = contact.pressure.clamp(0.0, 1.0).toDouble();
    final available = contact.transferOffer.maximumOutflow;
    // Watercolor expresses carrier and pigment on different pressure curves:
    // a light touch is colour-dense and water-poor; firm pressure releases
    // much more carrier. These accepted quantities are authoritative for both
    // the brush reservoir and the watercolor field.
    final out =
        available *
        canvasState.carrierAcceptance.clamp(0.0, 1.0) *
        math.pow(pressure, 2.0).toDouble();
    final pigmentCarrierEquivalent =
        available *
        canvasState.pigmentAcceptance.clamp(0.0, 1.0) *
        math.pow(pressure, 0.65).toDouble();
    final pigmentOut = contact.reservoir.carrierVolume <= 0
        ? 0.0
        : contact.reservoir.pigmentLoad *
              (pigmentCarrierEquivalent / contact.reservoir.carrierVolume)
                  .clamp(0.0, 1.0);
    final input =
        contact.transferOffer.maximumInflow *
        canvasState.pickupAvailability.clamp(0.0, 1.0);
    return MediumContactPayload(
      canvasState: canvasState,
      receipt: TransferReceipt(
        medium: medium,
        acceptedOutflow: out,
        // This is only the brush's available room. The watercolor field
        // returns the smaller amount it actually released as the live receipt.
        acceptedInflow: input,
        pigmentOut: pigmentOut,
        kOut: List<double>.generate(
          8,
          (band) => contact.reservoir.kAverage[band] * pigmentOut,
        ),
        sOut: List<double>.generate(
          8,
          (band) => contact.reservoir.sAverage[band] * pigmentOut,
        ),
        granulationOut: contact.reservoir.granulationAverage * pigmentOut,
        stainingOut: contact.reservoir.stainingAverage * pigmentOut,
      ),
      footprint: contact.clusters
          .map(
            (c) => MediumFootprintCluster(
              position: c.position,
              coverage: c.contact,
              pressure: c.pressure,
              velocity: c.velocity * canvasState.dragCoupling,
              radius: c.radius,
            ),
          )
          .toList(growable: false),
    );
  }
}

class OilContactState {
  const OilContactState({
    this.depositAcceptance = 1.0,
    this.pickupAvailability = 0.0,
    this.coupling = 0.65,
  });
  final double depositAcceptance;
  final double pickupAvailability;
  final double coupling;
}

/// Phase-A mapping only. Yield, relief, non-diffusive transport and lighting
/// remain in the oil engines described by oil-engine-spec.md.
class OilBrushAdapter implements BrushMediumAdapter<OilContactState> {
  const OilBrushAdapter();

  @override
  MediumFamily get medium => MediumFamily.oil;

  @override
  MediumContactPayload<OilContactState> resolve(
    BrushContactSample contact,
    OilContactState canvasState,
  ) {
    final out =
        contact.transferOffer.maximumOutflow *
        canvasState.depositAcceptance.clamp(0.0, 1.0);
    final input =
        contact.transferOffer.maximumInflow *
        canvasState.pickupAvailability.clamp(0.0, 1.0);
    return MediumContactPayload(
      canvasState: canvasState,
      receipt: TransferReceipt(
        medium: medium,
        acceptedOutflow: out,
        acceptedInflow: input,
      ),
      footprint: contact.clusters
          .map(
            (c) => MediumFootprintCluster(
              position: c.position,
              coverage: c.contact,
              pressure: c.pressure,
              velocity: c.velocity * canvasState.coupling,
              radius: c.radius,
            ),
          )
          .toList(growable: false),
    );
  }
}
