import 'dart:typed_data';

class BpMeasurement {
  const BpMeasurement({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
  });
  final int systolic;
  final int diastolic;
  final int pulse;
}

/// Turns raw cuff packets into a measurement.
///
/// Packet layout (simulated device): live-pressure packets are short; the
/// final result packet is longer than 9 bytes with
/// byte[2] = systolic, byte[4] = diastolic, byte[8] = pulse.
class BpPacketDecoder {
  /// Returns null for packets that are not the final result.
  /// It does not judge the values: range checks belong to the clinic limits.
  BpMeasurement? decode(Uint8List packet) {
    if (packet.length <= 9) return null;
    return BpMeasurement(
      systolic: packet[2],
      diastolic: packet[4],
      pulse: packet[8],
    );
  }
}
