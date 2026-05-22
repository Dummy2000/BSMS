import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/ecg_event_type.dart';
import '../../domain/models/imported_session.dart';
import '../../domain/processing/ecg_filter.dart';
import '../../domain/processing/r_peak_detector.dart';
import '../../domain/processing/event_detection_service.dart';

class ImportedSessionScreen extends StatefulWidget {
  final ImportedSession session;

  const ImportedSessionScreen({super.key, required this.session});

  @override
  State<ImportedSessionScreen> createState() => _ImportedSessionScreenState();
}

class _ImportedSessionScreenState extends State<ImportedSessionScreen> {
  static const int _windowSize = 2500; // 5 s at 500 Hz

  late final List<EcgSample> _filtered;
  late final List<int> _rPeaks;
  late final List<DetectedEvent> _events;
  late final double _meanBpm;

  int _windowStart = 0;
  bool _showFiltered = true;

  @override
  void initState() {
    super.initState();
    _filtered = EcgFilter.bandpass(widget.session.samples);
    _rPeaks = RPeakDetector.detect(_filtered);
    _events = EventDetectionService.detect(widget.session.samples, _rPeaks);
    _meanBpm = EventDetectionService.meanHeartRate(widget.session.samples, _rPeaks);
  }

  List<EcgSample> get _visibleSamples {
    final source = _showFiltered ? _filtered : widget.session.samples;
    final end = (_windowStart + _windowSize).clamp(0, source.length);
    return source.sublist(_windowStart, end);
  }

  /// R-peak indices that fall within the current scroll window.
  List<EcgSample> get _visibleRPeaks {
    final source = _showFiltered ? _filtered : widget.session.samples;
    final end = (_windowStart + _windowSize).clamp(0, source.length);
    return _rPeaks
        .where((idx) => idx >= _windowStart && idx < end)
        .map((idx) => source[idx])
        .toList();
  }

  int get _maxStart =>
      (widget.session.samples.length - _windowSize).clamp(0, widget.session.samples.length);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final visible = _visibleSamples;
    final origin = visible.isNotEmpty ? visible.first.timestampMs : 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.sourceFile, style: const TextStyle(fontSize: 16)),
            Text(
              '${session.samples.length} Samples · ${_formatDuration(session.duration)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showFiltered ? 'Roh anzeigen' : 'Gefiltert anzeigen',
            icon: Icon(_showFiltered ? Icons.filter_alt : Icons.filter_alt_off),
            onPressed: () => setState(() => _showFiltered = !_showFiltered),
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryBar(meanBpm: _meanBpm, rPeakCount: _rPeaks.length, events: _events),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SfCartesianChart(
                primaryXAxis: NumericAxis(
                  title: AxisTitle(text: 'Zeit (ms)'),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  maximum: 4095,
                  title: AxisTitle(text: 'ADC'),
                ),
                series: <CartesianSeries>[
                  LineSeries<EcgSample, int>(
                    dataSource: visible,
                    xValueMapper: (s, _) => s.timestampMs - origin,
                    yValueMapper: (s, _) => s.value,
                    animationDuration: 0,
                    width: 1.2,
                    color: _showFiltered
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  ScatterSeries<EcgSample, int>(
                    dataSource: _visibleRPeaks,
                    xValueMapper: (s, _) => s.timestampMs - origin,
                    yValueMapper: (s, _) => s.value,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 8,
                      width: 8,
                      color: Colors.red,
                      borderWidth: 0,
                    ),
                    animationDuration: 0,
                  ),
                ],
              ),
            ),
          ),
          if (_maxStart > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _msToTime(session.samples[_windowStart].timestampMs -
                        session.samples.first.timestampMs),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: _windowStart.toDouble(),
                      min: 0,
                      max: _maxStart.toDouble(),
                      onChanged: (v) => setState(() => _windowStart = v.toInt()),
                    ),
                  ),
                  Text(
                    _formatDuration(session.duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (_events.isNotEmpty) _EventList(events: _events),
          if (session.skippedPackets > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${session.skippedPackets} fehlerhafte Pakete übersprungen',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$min:$sec';
  }

  String _msToTime(int ms) => _formatDuration(Duration(milliseconds: ms));
}

// ---------------------------------------------------------------------------

class _SummaryBar extends StatelessWidget {
  final double meanBpm;
  final int rPeakCount;
  final List<DetectedEvent> events;

  const _SummaryBar({
    required this.meanBpm,
    required this.rPeakCount,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final tachy = events.where((e) => e.type == EcgEventType.tachycardia).length;
    final brady = events.where((e) => e.type == EcgEventType.bradycardia).length;
    final pauses = events.where((e) => e.type == EcgEventType.pause).length;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: 'Ø HR', value: '${meanBpm.round()} bpm'),
          _Stat(label: 'R-Peaks', value: '$rPeakCount'),
          if (tachy > 0) _Stat(label: 'Tachy', value: '$tachy', color: Colors.orange),
          if (brady > 0) _Stat(label: 'Brady', value: '$brady', color: Colors.blue),
          if (pauses > 0) _Stat(label: 'Pausen', value: '$pauses', color: Colors.red),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color ?? Theme.of(context).colorScheme.onSurface)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _EventList extends StatelessWidget {
  final List<DetectedEvent> events;

  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 0, 2),
            child: Text('Ereignisse',
                style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: events.length,
              itemBuilder: (context, i) => _EventChip(event: events[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final DetectedEvent event;

  const _EventChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (event.type) {
      EcgEventType.tachycardia => ('Tachy\n${event.metadata?['bpm']} bpm', Colors.orange),
      EcgEventType.bradycardia => ('Brady\n${event.metadata?['bpm']} bpm', Colors.blue),
      EcgEventType.pause => ('Pause\n${event.durationMs} ms', Colors.red),
      _ => (event.type.name, Colors.grey),
    };

    final ts = Duration(milliseconds: event.timestampMs);
    final timeStr =
        '${ts.inMinutes.remainder(60).toString().padLeft(2, '0')}:${ts.inSeconds.remainder(60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: color.withAlpha(40),
        side: BorderSide(color: color, width: 1),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            Text(timeStr, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
