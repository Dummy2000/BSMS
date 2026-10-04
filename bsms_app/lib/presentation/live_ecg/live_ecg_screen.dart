import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../data/ble/ble_recording_service.dart';
import '../../data/ble/ecg_ble_service.dart';
import '../../data/ble/ecg_packet.dart';
import '../../data/storage/person_repository.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/person.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_ext.dart';
import '../history/imported_session_screen.dart';
import '../persons/person_form.dart';

/// Connection status, mapped to a localized label at display time.
enum LiveStatus { notConnected, searching, connected, connectionLost, disconnected }

String _statusLabel(AppLocalizations l, LiveStatus s) => switch (s) {
      LiveStatus.notConnected   => l.statusNotConnected,
      LiveStatus.searching      => l.statusSearching,
      LiveStatus.connected      => l.statusConnected,
      LiveStatus.connectionLost => l.statusConnectionLost,
      LiveStatus.disconnected   => l.statusDisconnected,
    };

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
  LiveStatus _status = LiveStatus.notConnected;
  int _lastPacketHr = 0; // HR reported by ESP firmware, shown outside recording
  int _leadOffFlags = 0; // bit0=LO+, bit1=LO- ; 0 = both electrodes attached
  bool _espActive = false; // ESP measuring (true) vs. standby (false)

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
        _status = connected ? LiveStatus.connected : LiveStatus.connectionLost;
        // The ESP stays in standby after connecting — it is started explicitly
        // via the power button. So it is never active just from connecting.
        _espActive = false;
        if (!connected) {
          // Clear stale samples so the chart starts clean on reconnect.
          _liveBuffer.clear();
          _lastPacketHr = 0;
          _leadOffFlags = 0;
        }
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
    if (packet.heartRate > 0) _lastPacketHr = packet.heartRate;

    // Lead-off (electrode contact loss) — update immediately on change so the
    // warning banner pops up without waiting for the throttled chart refresh.
    final lo = packet.flags & 0x03;
    if (lo != _leadOffFlags) {
      _leadOffFlags = lo;
      if (mounted) setState(() {});
    }

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
    setState(() => _status = LiveStatus.searching);
    await widget.bleService.start();
  }

  Future<void> _stopBle() async {
    if (widget.recordingService.isRecording) await _stopRecording();
    await widget.bleService.stop();
    setState(() {
      _bleConnected = false;
      _status = LiveStatus.disconnected;
      _espActive = false;
    });
  }

  /// Toggle the ESP between active measurement and standby.
  Future<void> _toggleEsp() async {
    if (_espActive) {
      // Going to standby — stop any recording first (no data will follow).
      if (widget.recordingService.isRecording) await _stopRecording();
      await widget.bleService.standby();
      setState(() => _espActive = false);
    } else {
      await widget.bleService.startMeasurement();
      setState(() {
        _espActive = true;
        _liveBuffer.clear(); // clean chart on resume
      });
    }
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
    final l = context.l10n;
    final isRecording = widget.recordingService.isRecording;
    final visible = List<EcgSample>.from(_liveBuffer);

    // X-axis labelling: leftmost tick shows the wall-clock time, others show the
    // offset (ms) from that tick. firstTick = first 1 s multiple at/after the
    // left edge of the visible buffer.
    const axisIntervalMs = 1000;
    final windowStartX = visible.isNotEmpty ? visible.first.timestampMs : 0;
    final firstTick = (windowStartX / axisIntervalMs).ceil() * axisIntervalMs;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.liveEcgTitle),
        actions: [
          // ESP start / standby (only meaningful while connected)
          if (_bleConnected)
            IconButton(
              icon: Icon(_espActive
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline),
              tooltip: _espActive ? l.espStandby : l.espStart,
              onPressed: _toggleEsp,
            ),
          // BLE connect / disconnect
          _bleConnected
              ? IconButton(
                  icon: const Icon(Icons.bluetooth_disabled),
                  tooltip: l.bleDisconnectTooltip,
                  onPressed: _stopBle,
                )
              : IconButton(
                  icon: const Icon(Icons.bluetooth_searching),
                  tooltip: l.bleConnectTooltip,
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
            liveHr: _lastPacketHr,
            formatElapsed: _formatElapsed,
          ),

          // Lead-off warning banner
          if (_leadOffFlags != 0) _LeadOffBanner(flags: _leadOffFlags),

          // Live ECG chart / standby screen
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: !_bleConnected
                  ? Center(
                      child: Text(
                        l.noBleDevice,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : !_espActive
                      ? _StandbyView(onStart: _toggleEsp)
                  : visible.isEmpty
                  ? Center(
                      child: Text(
                        l.waitingForData,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : SfCartesianChart(
                      primaryXAxis: NumericAxis(
                        interval: axisIntervalMs.toDouble(),
                        axisLabelFormatter: (AxisLabelRenderDetails d) {
                          final v = d.value.round();
                          if (v > firstTick) {
                            return ChartAxisLabel('${v - firstTick} ms', d.textStyle);
                          }
                          // Leftmost tick → Vienna wall-clock time.
                          const utcOffsetMs = 2 * 3600 * 1000; // Vienna UTC+2
                          final dayMs = (v + utcOffsetMs) % 86400000;
                          final h = dayMs ~/ 3600000;
                          final m = ((dayMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
                          final s = ((dayMs % 60000) ~/ 1000).toString().padLeft(2, '0');
                          return ChartAxisLabel('$h:$m:$s', d.textStyle);
                        },
                      ),
                      primaryYAxis: NumericAxis(title: AxisTitle(text: 'ADC')),
                      series: <CartesianSeries>[
                        LineSeries<EcgSample, int>(
                          dataSource: visible,
                          xValueMapper: (s, _) => s.timestampMs,
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
                      l.recordStop +
                          (_recStatus != null
                              ? '  (${_formatElapsed(_recStatus!.elapsed)})'
                              : ''),
                    ),
                    onPressed: _stopRecording,
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.fiber_manual_record),
                    label: Text(l.recordStart),
                    onPressed:
                        _bleConnected && _espActive ? _startRecording : null,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Standby screen (ESP connected but not measuring) ────────────────────────────

class _StandbyView extends StatelessWidget {
  final VoidCallback onStart;
  const _StandbyView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big tappable power symbol → starts the measurement.
          InkWell(
            onTap: onStart,
            customBorder: const CircleBorder(),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
              ),
              child: Icon(Icons.power_settings_new, size: 64, color: color),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.espStandby,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l.espStart,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ── Lead-off warning banner ─────────────────────────────────────────────────────

class _LeadOffBanner extends StatelessWidget {
  final int flags; // bit0 = LO+, bit1 = LO-
  const _LeadOffBanner({required this.flags});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final both = (flags & 0x03) == 0x03;
    final plus = (flags & 0x01) != 0;
    final detail = both
        ? l.leadOffDetailBoth
        : l.leadOffDetailOne(plus ? 'LO+' : 'LO−');

    return Container(
      width: double.infinity,
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.leadOffTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                Text(
                  l.leadOffHint(detail),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final LiveStatus status;
  final bool connected;
  final RecordingStatus? recStatus;
  final int liveHr;
  final String Function(Duration) formatElapsed;

  const _StatusBar({
    required this.status,
    required this.connected,
    required this.recStatus,
    required this.liveHr,
    required this.formatElapsed,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isRecording = recStatus != null;
    final hrToShow = isRecording ? recStatus!.currentHr : liveHr;

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
          Expanded(
              child: Text(_statusLabel(l, status),
                  style: const TextStyle(fontSize: 13))),
          if (isRecording) ...[
            const Icon(Icons.circle, size: 10, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              formatElapsed(recStatus!.elapsed),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
          ],
          if (hrToShow > 0)
            Text(
              l.bpm(hrToShow),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          // Live HRV (RMSSD) during recording, parallel to HR.
          if (isRecording && recStatus!.rmssd != null) ...[
            const SizedBox(width: 10),
            Text(
              l.hrv(recStatus!.rmssd!.round()),
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
    final l = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.personPickTitle,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (persons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l.personNoneYet),
            ),
          ...persons.map((p) => ListTile(
                leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
                title: Text(p.name),
                subtitle: Text(l.personAge(p.age)),
                onTap: () => onSelected(p),
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: Text(l.personCreateNew),
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
