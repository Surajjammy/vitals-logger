import 'dart:async';
import 'dart:typed_data';

abstract class BpCuff {
  /// Raw packets. Broadcast, so several listeners are allowed.
  Stream<Uint8List> get packets;

  /// Starts one measurement; packets arrive on [packets].
  void startMeasurement();
}

/// Simulates a BLE cuff: a few short "live pressure" packets while inflating,
/// then one final result packet.
class FakeBpCuff implements BpCuff {
  FakeBpCuff({
    this.systolic = 118,
    this.diastolic = 76,
    this.pulse = 68,
    this.interval = const Duration(milliseconds: 300),
  });

  final int systolic;
  final int diastolic;
  final int pulse;
  final Duration interval;

  final _controller = StreamController<Uint8List>.broadcast();
  Timer? _timer;

  @override
  Stream<Uint8List> get packets => _controller.stream;

  @override
  void startMeasurement() {
    _timer?.cancel();
    var tick = 0;
    _timer = Timer.periodic(interval, (timer) {
      tick++;
      if (tick <= 5) {
        // Short packet: [header, type, live pressure, 0]
        _controller.add(Uint8List.fromList([0xFE, 0x01, 40 + tick * 25, 0x00]));
      } else {
        // Final packet, 10 bytes. Bytes 0, 1, 3, 5, 6, 7 are filler/status.
        _controller.add(Uint8List.fromList([0xFF, 0x02, systolic, 0x00, diastolic, 0x00, 0x00, 0x00, pulse, 0x00]));
        timer.cancel();
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
