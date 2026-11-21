import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals_logger/device/bp_decoder.dart';
import 'package:vitals_logger/device/fake_bp_cuff.dart';
import 'package:vitals_logger/device/vital_limits.dart';

// Sample packets as a real capture would look (hex dumps written as byte lists).
final inflating = Uint8List.fromList([0xFE, 0x01, 65, 0x00]); // 4 bytes: live pressure
final inflatingMore = Uint8List.fromList([0xFE, 0x01, 140, 0x00]);
final nineBytes = Uint8List.fromList([0xFF, 0x02, 120, 0x00, 80, 0x00, 0x00, 0x00, 70]); // exactly 9: still "short"
final normal = Uint8List.fromList([0xFF, 0x02, 118, 0x00, 76, 0x00, 0x00, 0x00, 68, 0x00]);
final highReading = Uint8List.fromList([0xFF, 0x02, 255, 0x00, 160, 0x00, 0x00, 0x00, 20, 0x00]);

void main() {
  final decoder = BpPacketDecoder();

  group('BpPacketDecoder', () {
    test('short live-pressure packets are ignored', () {
      expect(decoder.decode(inflating), isNull);
      expect(decoder.decode(inflatingMore), isNull);
      expect(decoder.decode(Uint8List(0)), isNull);
    });

    test('a 9-byte packet is still too short, 10 bytes is the result', () {
      expect(decoder.decode(nineBytes), isNull);
      expect(decoder.decode(normal), isNotNull);
    });

    test('reads systolic, diastolic and pulse from bytes 2, 4 and 8', () {
      final m = decoder.decode(normal)!;
      expect((m.systolic, m.diastolic, m.pulse), (118, 76, 68));
    });

    test('decodes out-of-range values as they are; limits decide what to do', () {
      final m = decoder.decode(highReading)!;
      expect((m.systolic, m.diastolic, m.pulse), (255, 160, 20));
      final problems = VitalLimits.check(sys: m.systolic, dia: m.diastolic, pulseBpm: m.pulse);
      expect(problems.length, 3);
    });
  });

  group('VitalLimits', () {
    test('in-range values give no problems, edges included', () {
      expect(VitalLimits.check(sys: 70, dia: 150, pulseBpm: 30, tempF: 106.0), isEmpty);
    });

    test('one value just outside the range is reported', () {
      expect(VitalLimits.check(sys: 69), hasLength(1));
      expect(VitalLimits.check(tempF: 106.1), hasLength(1));
    });

    test('missing values are not checked', () {
      expect(VitalLimits.check(), isEmpty);
    });
  });

  group('FakeBpCuff', () {
    test('emits short packets first, then exactly one result packet', () {
      fakeAsync((time) {
        final cuff = FakeBpCuff(interval: const Duration(milliseconds: 100));
        final received = <Uint8List>[];
        cuff.packets.listen(received.add);

        cuff.startMeasurement();
        time.elapse(const Duration(seconds: 5));

        expect(received.length, 6);
        expect(received.take(5).every((p) => p.length <= 9), isTrue);
        expect(received.last.length, greaterThan(9));
        cuff.dispose();
      });
    });

    test('screen-style pipeline takes one reading and then stops listening', () {
      fakeAsync((time) {
        final cuff = FakeBpCuff(interval: const Duration(milliseconds: 100));
        final results = <BpMeasurement>[];
        var cancelled = false;
        cuff.packets
            .map(decoder.decode)
            .where((m) => m != null)
            .cast<BpMeasurement>()
            .take(1)
            .listen(results.add, onDone: () => cancelled = true);

        cuff.startMeasurement();
        time.elapse(const Duration(seconds: 5));
        cuff.startMeasurement(); // a second measurement must not reach the old listener
        time.elapse(const Duration(seconds: 5));

        expect(results.length, 1);
        expect(cancelled, isTrue);
        cuff.dispose();
      });
    });
  });
}
