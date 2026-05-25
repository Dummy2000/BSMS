import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../data/ble/ble_recording_service.dart';
import '../../data/ble/ecg_ble_service.dart';
import '../../data/ble/ecg_packet.dart';
import '../../data/storage/person_repository.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/person.dart';
import '../history/imported_session_screen.dart';
import '../persons/person_form.dart';

class LiveEcgScreen extends StatefulWidget {
  final EcgBleService bleService;
  final BleRecordingService recordingService;
  final PersonRepository personRepository;

  const LiveEcgScreen({
    super.key,
    required this.bleService,
    required this.recordingService,
    required this.personRepository,
  });

  @override
  State<LiveEcgScreen> createState() => _LiveEcgScreenState();
}

class _LiveEcgScreenState extends State<LiveEcgScreen> {
  static const int _liveWindowSamples = 2500; // 5 s at 500 Hz
  static const int _chartUpdateEvery  = 5;    // packets → ~200 ms refresh

  final List<EcgSample> _liveBuffer = [];
  int _packetsSinceUpdate = 0;
  bool _bleConnected = false;
  String _status = 'Nicht verbunden';

  RecordingStatus? _recStatus;
  StreamSubscription<EcgPacket>? _packetSub;
  StreamSubscription<bool>?      _connSub;
  StreamSubscription<RecordingStatus>? _recSub;

  @override
  void initState() {
    super.initState();
    _connSub = widget.bleService.connectionState.listen((connected) {
      setState(() {
        _bleConnected = connected;
        _status = connected ? 'Verbunden' : 'Verbindung getrennt';
      });
    });
    _packetSub = widget.bleService.ecgPackets.listen(_onPacket, onError: (_) {});
    _recSub = widget.recordingService.status.listen((s) {
      if (mounted) setState(() => _recStatus = s);
    });
  }

  @override
  void dispose() {
    _packetSub?.cancel();
    _connSub?.cancel();
    _recSub?.cancel();
    super.dispose();
  }

  void _onPacket(EcgPacket packet) {
    final base = packet.timestamp.millisecondsSinceEpoch;
    for (int i = 0; i < packet.samples.length; i++) {
      _liveBuffer.add(EcgSample(
        value: packet.samples[i],
        timestampMs: base + i * 2,
      ));
    }
    while (_liveBuffer.length > _liveWindowSamples) {
      _liveBuffer.removeAt(0);
    }
    _packetsSinceUpdate++;
    if (_packetsSinceUpdate >= _chartUpdateEvery) {
      _packetsSinceUpdate = 0;
      if (mounted) setState(() {});
    }
  }

  // ── BLE ───────────────────────────────────────────────────────────────────

  Future<void> _startBle() async {
    setState(() => _status = 'Suche Gerät …');
    await widget.bleService.start();
  }

  Future<void> _stopBle() async {
    if (widget.recordingService.isRecording) await _stopRecording();
    await widget.bleService.stop();
    setState(() { _bleConnected = false; _status = 'Getrennt'; });
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final person = await _pickPerson();
    if (person == null) return;
    await widget.recordingService.startRecording(person);
    setState(() {});
  }

  Future<void> _stopRecording() async {
    final session = await widget.recordingService.stopRecording();
    setState(() => _recStatus = null);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImportedSessionScreen(session: session)),
    );
  }

  Future<Person?> _pickPerson() async {
    final persons = await widget.personRepository.getAll();

    if (!mounted) return null;
    return showModalBottomSheet<Person>(
      context: context,
      builder: (ctx) => _PersonPickerSheet(
        persons: persons,
        repository: widget.personRepository,
        onCreated: (p) => Navigator.pop(ctx, p),
        onSelected: (p) => Navigator.pop(ctx, p),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.recordingService.isRecording;
    final visible = List<EcgSample>.from(_liveBuffer);
    final origin  = visible.isNotEmpty ? visible.first.timestampMs : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live EKG'),
        actions: [
          // BLE connect / disconnect
          _bleConnected
              ? IconButton(
                  icon: const Icon(Icons.bluetooth_disabled),
                  tooltip: 'BLE trennen',
                  onPressed: _stopBle,
                )
              : IconButton(
                  icon: const Icon(Icons.bluetooth_searching),
                  tooltip: 'BLE verbinden',
                  onPressed: _startBle,
                ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          _StatusBar(
            status: _status,
            connected: _bleConnected,
            recStatus: _recStatus,
            formatElapsed: _formatElapsed,
          ),

          // Live ECG chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        _bleConnected
                            ? 'Warte auf Daten …'
                            : 'Kein BLE-Gerät verbunden',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : SfCartesianChart(
                      primaryXAxis: NumericAxis(isVisible: false),
                      primaryYAxis: NumericAxis(title: AxisTitle(text: 'ADC')),
                      series: <CartesianSeries>[
                        LineSeries<EcgSample, int>(
                          dataSource: visible,
                          xValueMapper: (s, _) => s.timestampMs - origin,
                          yValueMapper: (s, _) => s.value,
                          animationDuration: 0,
                          width: 1.2,
                          color: isRecording
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
            ),
          ),

          // Recording controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: isRecording
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.stop),
                    label: Text(
                      'Aufnahme stoppen'
                      '${_recStatus != null ? "  (${_formatElapsed(_recStatus!.elapsed)})" : ""}',
                    ),
                    onPressed: _stopRecording,
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Aufnahme starten'),
                    onPressed: _bleConnected ? _startRecording : null,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String status;
  final bool connected;
  final RecordingStatus? recStatus;
  final String Function(Duration) formatElapsed;

  const _StatusBar({
    required this.status,
    required this.connected,
    required this.recStatus,
    required this.formatElapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 18,
            color: connected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(status, style: const TextStyle(fontSize: 13))),
          if (recStatus != null) ...[
            Icon(Icons.circle, size: 10, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              '${formatElapsed(recStatus!.elapsed)}'
              '  ${recStatus!.currentHr > 0 ? "${recStatus!.currentHr} bpm" : ""}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Person picker bottom sheet ────────────────────────────────────────────────

class _PersonPickerSheet extends StatelessWidget {
  final List<Person> persons;
  final PersonRepository repository;
  final ValueChanged<Person> onCreated;
  final ValueChanged<Person> onSelected;

  const _PersonPickerSheet({
    required this.persons,
    required this.repository,
    required this.onCreated,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Person auswählen',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (persons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Noch keine Personen — bitte zuerst anlegen.'),
            ),
          ...persons.map((p) => ListTile(
                leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
                title: Text(p.name),
                subtitle: Text('${p.age} Jahre'),
                onTap: () => onSelected(p),
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Neue Person anlegen'),
            onTap: () async {
              final result = await Navigator.push<Person>(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonFormScreen(repository: repository),
                ),
              );
              if (result != null) onCreated(result);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
