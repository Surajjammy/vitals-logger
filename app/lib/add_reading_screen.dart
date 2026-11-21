import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'device/bp_decoder.dart';
import 'device/vital_limits.dart';
import 'providers.dart';

class AddReadingScreen extends ConsumerStatefulWidget {
  const AddReadingScreen({super.key});

  @override
  ConsumerState<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends ConsumerState<AddReadingScreen> {
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _pulse = TextEditingController();
  final _temp = TextEditingController();
  final _decoder = BpPacketDecoder();

  StreamSubscription<BpMeasurement>? _deviceSub;
  bool _measuring = false;

  /// Set after the first out-of-range save attempt. A second save goes through.
  String? _warning;

  @override
  void initState() {
    super.initState();
    // Editing a value means the earlier warning no longer applies: check again.
    for (final c in [_sys, _dia, _pulse, _temp]) {
      c.addListener(() {
        if (_warning != null) setState(() => _warning = null);
      });
    }
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    for (final c in [_sys, _dia, _pulse, _temp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _readFromDevice() {
    final cuff = ref.read(bpCuffProvider);
    setState(() => _measuring = true);
    _deviceSub?.cancel();
    _deviceSub = cuff.packets
        .map(_decoder.decode) // short live-pressure packets become null...
        .where((m) => m != null) // ...and are dropped here
        .cast<BpMeasurement>()
        .take(1) // one result only; take() also cancels the subscription
        .listen((m) {
          _sys.text = '${m.systolic}';
          _dia.text = '${m.diastolic}';
          _pulse.text = '${m.pulse}';
          setState(() => _measuring = false);
        });
    cuff.startMeasurement();
  }

  Future<void> _save() async {
    final sys = int.tryParse(_sys.text);
    final dia = int.tryParse(_dia.text);
    final pulse = int.tryParse(_pulse.text);
    final temp = double.tryParse(_temp.text);
    final hasBp = sys != null && dia != null && pulse != null;
    if (!hasBp && temp == null) return;

    final problems = VitalLimits.check(
      sys: sys,
      dia: dia,
      pulseBpm: pulse,
      tempF: temp,
    );
    if (problems.isNotEmpty && _warning == null) {
      setState(
        () => _warning =
            'Check the reading again: ${problems.join(', ')}. Press Save again to keep it.',
      );
      return;
    }

    final repo = ref.read(readingsRepositoryProvider);
    final now = DateTime.now();
    if (hasBp) {
      await repo.addReading(
        type: 'bp',
        systolic: sys,
        diastolic: dia,
        pulse: pulse,
        measuredAt: now,
      );
    }
    if (temp != null) {
      await repo.addReading(
        type: 'temperature',
        temperatureF: temp,
        measuredAt: now,
      );
    }
    // Not awaited: saving never waits for the network.
    ref.read(syncServiceProvider).syncNow();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('New reading')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _measuring ? null : _readFromDevice,
            icon: const Icon(Icons.bluetooth),
            label: Text(_measuring ? 'Measuring...' : 'Read from device'),
          ),
          const SizedBox(height: 16),
          field(_sys, 'Systolic (mmHg)'),
          field(_dia, 'Diastolic (mmHg)'),
          field(_pulse, 'Pulse (bpm)'),
          field(_temp, 'Temperature (°F)'),
          if (_warning != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _warning!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
