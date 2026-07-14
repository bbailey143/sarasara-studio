import '../../models/brush.dart';

enum MediumFamily { watercolor, oil, ink, gouache, other }

/// Conserved extensive material state carried by one physical brush.
class BrushReservoir {
  BrushReservoir({
    required this.capacity,
    required this.tipCapacityFraction,
    this.medium = MediumFamily.watercolor,
    double initialFill = 1.0,
  }) : tipVolume = capacity * tipCapacityFraction * initialFill,
       bellyVolume = capacity * (1.0 - tipCapacityFraction) * initialFill,
       kSum = List<double>.filled(8, 0.0),
       sSum = List<double>.filled(8, 0.0);

  factory BrushReservoir.forBrush(Brush brush) => BrushReservoir(
    capacity: brush.reservoirCapacity,
    tipCapacityFraction: brush.tipCapacityFraction,
    initialFill: brush.paintLoad,
  );

  final double capacity;
  final double tipCapacityFraction;
  MediumFamily medium;
  double tipVolume;
  double bellyVolume;
  double pigmentLoad = 0.0;
  final List<double> kSum;
  final List<double> sSum;
  double granulationWeight = 0.0;
  double stainingWeight = 0.0;

  double get totalVolume => tipVolume + bellyVolume;
  double get fill =>
      capacity <= 0 ? 0 : (totalVolume / capacity).clamp(0.0, 1.0);

  TransferOffer offer({
    required double contact,
    required double dtSeconds,
    required Brush brush,
  }) {
    final outflow = brush.releaseConductance * contact * fill * dtSeconds;
    final inflow = brush.pickupConductance * contact * (1.0 - fill) * dtSeconds;
    return TransferOffer(
      maximumOutflow: outflow.clamp(0.0, totalVolume),
      maximumInflow: inflow.clamp(0.0, capacity - totalVolume),
    );
  }

  /// The medium is authoritative: only its accepted receipt mutates the tool.
  void applyReceipt(TransferReceipt receipt) {
    if (receipt.medium != medium) {
      throw StateError('A brush cannot silently mix incompatible media.');
    }
    final deposited = receipt.acceptedOutflow.clamp(0.0, totalVolume);
    final fromTip = deposited.clamp(0.0, tipVolume);
    tipVolume -= fromTip;
    bellyVolume -= (deposited - fromTip).clamp(0.0, bellyVolume);

    final room = (capacity - totalVolume).clamp(0.0, capacity);
    final picked = receipt.acceptedInflow.clamp(0.0, room);
    tipVolume += picked;
    pigmentLoad = (pigmentLoad - receipt.pigmentOut + receipt.pigmentIn).clamp(
      0.0,
      double.infinity,
    );
    for (var band = 0; band < 8; band++) {
      kSum[band] = (kSum[band] - receipt.kOut[band] + receipt.kIn[band]).clamp(
        0.0,
        double.infinity,
      );
      sSum[band] = (sSum[band] - receipt.sOut[band] + receipt.sIn[band]).clamp(
        0.0,
        double.infinity,
      );
    }
    granulationWeight =
        (granulationWeight - receipt.granulationOut + receipt.granulationIn)
            .clamp(0.0, double.infinity);
    stainingWeight = (stainingWeight - receipt.stainingOut + receipt.stainingIn)
        .clamp(0.0, double.infinity);
  }

  void rebalance(double dtSeconds, {double conductance = 2.0}) {
    final total = totalVolume;
    final tipCapacity = capacity * tipCapacityFraction;
    final desiredTip = total * tipCapacityFraction;
    final flow = (desiredTip - tipVolume) * conductance * dtSeconds;
    tipVolume = (tipVolume + flow).clamp(0.0, tipCapacity);
    bellyVolume = (total - tipVolume).clamp(0.0, capacity - tipCapacity);
  }
}

class TransferOffer {
  const TransferOffer({
    required this.maximumOutflow,
    required this.maximumInflow,
  });
  final double maximumOutflow;
  final double maximumInflow;
}

class BrushReservoirSnapshot {
  BrushReservoirSnapshot.from(BrushReservoir reservoir)
    : fill = reservoir.fill,
      carrierVolume = reservoir.totalVolume,
      pigmentLoad = reservoir.pigmentLoad,
      kAverage = List<double>.generate(
        8,
        (band) => reservoir.pigmentLoad <= 0
            ? 0
            : reservoir.kSum[band] / reservoir.pigmentLoad,
      ),
      sAverage = List<double>.generate(
        8,
        (band) => reservoir.pigmentLoad <= 0
            ? 0
            : reservoir.sSum[band] / reservoir.pigmentLoad,
      ),
      granulationAverage = reservoir.pigmentLoad <= 0
          ? 0
          : reservoir.granulationWeight / reservoir.pigmentLoad,
      stainingAverage = reservoir.pigmentLoad <= 0
          ? 0
          : reservoir.stainingWeight / reservoir.pigmentLoad;

  final double fill;
  final double carrierVolume;
  final double pigmentLoad;
  final List<double> kAverage;
  final List<double> sAverage;
  final double granulationAverage;
  final double stainingAverage;
}

class TransferReceipt {
  TransferReceipt({
    required this.medium,
    this.acceptedOutflow = 0.0,
    this.acceptedInflow = 0.0,
    this.pigmentOut = 0.0,
    this.pigmentIn = 0.0,
    List<double>? kOut,
    List<double>? kIn,
    List<double>? sOut,
    List<double>? sIn,
    this.granulationOut = 0.0,
    this.granulationIn = 0.0,
    this.stainingOut = 0.0,
    this.stainingIn = 0.0,
  }) : kOut = kOut ?? List<double>.filled(8, 0.0),
       kIn = kIn ?? List<double>.filled(8, 0.0),
       sOut = sOut ?? List<double>.filled(8, 0.0),
       sIn = sIn ?? List<double>.filled(8, 0.0) {
    if (this.kOut.length != 8 ||
        this.kIn.length != 8 ||
        this.sOut.length != 8 ||
        this.sIn.length != 8) {
      throw ArgumentError(
        'Transfer receipts require exactly 8 spectral bands.',
      );
    }
  }

  final MediumFamily medium;
  final double acceptedOutflow;
  final double acceptedInflow;
  final double pigmentOut;
  final double pigmentIn;
  final List<double> kOut;
  final List<double> kIn;
  final List<double> sOut;
  final List<double> sIn;
  final double granulationOut;
  final double granulationIn;
  final double stainingOut;
  final double stainingIn;
}
