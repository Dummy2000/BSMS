import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../data/storage/session_reader.dart';
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
  static const int _minWindowSize     = 250;
  static const int _maxWindowSize     = 10000;
  static const int _defaultWindowSize = 2500;

  // ── In-memory session state (SD imports) ─────────────────────────────────
  late final List<EcgSample> _filtered; // empty for file-backed
  late final List<int>        _rPeaks;  // empty for file-backed; use session.rPeakIndices

  // ── File-backed session state (BLE recordings) ────────────────────────────
  List<EcgSample> _filteredCache = [];
  int  _cacheStart     = 0;
  bool _isCacheLoading = false;
  int  _totalSamples   = 0;

  // ── Shared ────────────────────────────────────────────────────────────────
  /// Timestamp (ms) of the very first sample, used to convert absolute
  /// sample timestamps to recording-relative X-axis values.
  /// 0 for file-backed (SessionReader already returns relative timestamps).
  late final int _recordingOrigin;
  late final List<DetectedEvent> _events;

  /// Effective HR data: session.hrData for SD imports, peaks→bpm for BLE.
  late final List<HrDataPoint> _effectiveHrData;

  int  _windowStart     = 0;
  int  _windowSize      = _defaultWindowSize;
  bool _showFiltered    = true;
  bool _showHr          = true;
  bool _showLeadOff     = true;
  bool _showDisconnect  = true;
  bool _showRPeaks      = true;

  bool get _isFileBacked => widget.session.isFileBacked;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final session = widget.session;

    if (_isFileBacked) {
      _filtered        = const [];
      _rPeaks          = const [];
      _totalSamples    = session.totalSampleCount;
      _recordingOrigin = 0; // SessionReader returns timestamps relative to recording start
      _effectiveHrData =
          EventDetectionService.hrFromPeakIndices(session.rPeakIndices);
      _events =
          EventDetectionService.detectFromPeakIndices(session.rPeakIndices);
      _loadCacheAround(0);
    } else {
      _totalSamples    = 0;
      _recordingOrigin = 0; // raw Unix epoch ms used directly as X values
      _filtered        = EcgFilter.bandpass(session.samples);
      _rPeaks       = RPeakDetector.detect(_filtered);

      if (session.hrData.isNotEmpty) {
        _effectiveHrData = session.hrData;
        final hrEvents = EventDetectionService.detectFromHrData(session.hrData);
        final pauses   = EventDetectionService
            .detect(session.samples, _rPeaks)
            .where((e) => e.type == EcgEventType.pause)
            .toList();
        _events = [...hrEvents, ...pauses]
          ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      } else {
        _effectiveHrData = const [];
        _events = EventDetectionService.detect(session.samples, _rPeaks);
      }
    }
  }

  // ── Cache management (file-backed only) ───────────────────────────────────

  Future<void> _loadCacheAround(int centerIdx) async {
    if (!_isFileBacked || _isCacheLoading) return;
    setState(() => _isCacheLoading = true);

    const halfCache = 15000; // 30 s each side → 60 s total in memory
    final start = math.max(0, centerIdx - halfCache);
    final count = math.min(halfCache * 2, _totalSamples - start);
    if (count <= 0) { setState(() => _isCacheLoading = false); return; }

    try {
      final reader = SessionReader.fromSession(widget.session);
      final window = await reader.readFilteredWindow(
          startIdx: start, count: count);
      if (!mounted) return;
      setState(() {
        _cacheStart      = start;
        _filteredCache   = window;
        _isCacheLoading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isCacheLoading = false);
    }
  }

  void _onWindowMoved(int newStart) {
    setState(() => _windowStart = newStart);
    if (!_isFileBacked || _filteredCache.isEmpty) return;
    const margin = 3750; // 7.5 s — refresh before hitting cache edge
    final cacheEnd = _cacheStart + _filteredCache.length;
    if (newStart < _cacheStart + margin ||
        newStart + _windowSize > cacheEnd - margin) {
      _loadCacheAround(newStart + _windowSize ~/ 2);
    }
  }

  // ── Visible data helpers ──────────────────────────────────────────────────

  List<EcgSample> get _visibleSamples {
    if (_isFileBacked) {
      if (_filteredCache.isEmpty) return const [];
      final localStart = _windowStart - _cacheStart;
      if (localStart < 0 || localStart >= _filteredCache.length) return const [];
      final localEnd =
          (localStart + _windowSize).clamp(0, _filteredCache.length);
      return _filteredCache.sublist(localStart, localEnd);
    }
    final source = _showFiltered ? _filtered : widget.session.samples;
    final end    = (_windowStart + _windowSize).clamp(0, source.length);
    return source.sublist(_windowStart, end);
  }

  List<EcgSample> get _visibleRPeaks {
    if (_isFileBacked) {
      if (_filteredCache.isEmpty) return const [];
      final cacheEnd = _cacheStart + _filteredCache.length;
      return widget.session.rPeakIndices
          .where((idx) =>
              idx >= _windowStart &&
              idx < _windowStart + _windowSize &&
              idx >= _cacheStart &&
              idx < cacheEnd)
          .map((idx) => _filteredCache[idx - _cacheStart])
          .toList();
    }
    final source = _showFiltered ? _filtered : widget.session.samples;
    final end    = (_windowStart + _windowSize).clamp(0, source.length);
    return _rPeaks
        .where((idx) => idx >= _windowStart && idx < end)
        .map((idx) => source[idx])
        .toList();
  }

  List<HrDataPoint> _visibleHrPoints(int originMs) {
    if (!_showHr || _effectiveHrData.isEmpty) return const [];
    final windowEndMs = originMs + _windowSize * 2;
    return _effectiveHrData
        .where((p) =>
            p.bpm > 0 &&
            p.timestampMs >= originMs &&
            p.timestampMs <= windowEndMs)
        .toList();
  }

  List<PlotBand> _leadOffBands() {
    if (!_showLeadOff || widget.session.leadOffIntervals.isEmpty) return const [];
    final visible = _visibleSamples;
    if (visible.isEmpty) return const [];
    final winStart = visible.first.timestampMs;
    final winEnd   = visible.last.timestampMs;
    final recEnd   = _isFileBacked
        ? _totalSamples * 2
        : (widget.session.samples.isNotEmpty
            ? widget.session.samples.last.timestampMs
            : winEnd);

    return widget.session.leadOffIntervals
        .where((iv) {
          final end = iv.endMs == -1 ? recEnd : iv.endMs;
          return end >= winStart && iv.startMs <= winEnd;
        })
        .map((iv) {
          final end = iv.endMs == -1 ? recEnd : iv.endMs;
          return PlotBand(
            start: (iv.startMs - _recordingOrigin).toDouble(),
            end:   (end        - _recordingOrigin).toDouble(),
            color: Colors.red.withAlpha(45),
            borderColor: Colors.red.withAlpha(80),
            borderWidth: 1,
          );
        })
        .toList();
  }

  List<PlotBand> _disconnectBands() {
    if (!_showDisconnect || widget.session.disconnectIntervals.isEmpty) {
      return const [];
    }
    final visible = _visibleSamples;
    if (visible.isEmpty) return const [];
    final winStart = visible.first.timestampMs;
    final winEnd   = visible.last.timestampMs;

    return widget.session.disconnectIntervals
        .where((iv) {
          final end = iv.endMs == -1 ? winEnd + 1 : iv.endMs;
          return end >= winStart && iv.startMs <= winEnd;
        })
        .map((iv) {
          final end = iv.endMs == -1 ? winEnd : iv.endMs;
          return PlotBand(
            start: (iv.startMs - _recordingOrigin).toDouble(),
            end:   (end        - _recordingOrigin).toDouble(),
            color: Colors.red.withAlpha(100),
            borderColor: Colors.red,
            borderWidth: 1.5,
          );
        })
        .toList();
  }

  static const int _utcOffsetMs = 2 * 3600 * 1000; // Vienna UTC+2 (CEST)

  String _formatAsViennaTime(int ms) {
    final dayMs = (ms + _utcOffsetMs) % 86400000;
    final h = dayMs ~/ 3600000;
    final m = ((dayMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((dayMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatWindowPosition() {
    if (!_isFileBacked && widget.session.samples.isNotEmpty) {
      final rawMs = widget.session.samples.first.timestampMs + _windowStart * 2;
      return _formatAsViennaTime(rawMs);
    }
    return _msToTime(_windowStart * 2);
  }

  int get _axisIntervalMs {
    final durationMs = _windowSize * 2;
    if (durationMs <= 5000)  return 1000;
    if (durationMs <= 10000) return 2000;
    return 5000;
  }

  int get _maxStart {
    final total = _isFileBacked ? _totalSamples : widget.session.samples.length;
    return (total - _windowSize).clamp(0, total);
  }

  double get _localMeanBpm {
    const halfWindow = 2500; // 5 s each side
    final center = _windowStart + _windowSize ~/ 2;

    if (_isFileBacked) {
      final rng0 = (center - halfWindow).clamp(0, _totalSamples - 1);
      final rng1 = (center + halfWindow).clamp(0, _totalSamples - 1);
      final local = widget.session.rPeakIndices
          .where((i) => i >= rng0 && i <= rng1)
          .toList();
      if (local.length < 2) return 0;
      final durationMs = (local.last - local.first) * 2;
      return durationMs > 0 ? (local.length - 1) * 60000.0 / durationMs : 0;
    }

    final session = widget.session;
    if (session.samples.isEmpty) return 0;
    final rng0 = (center - halfWindow).clamp(0, session.samples.length - 1);
    final rng1 = (center + halfWindow).clamp(0, session.samples.length - 1);

    if (_effectiveHrData.isNotEmpty) {
      final startMs = session.samples[rng0].timestampMs;
      final endMs   = session.samples[rng1].timestampMs;
      final pts = _effectiveHrData
          .where((p) => p.bpm > 0 && p.timestampMs >= startMs && p.timestampMs <= endMs)
          .toList();
      if (pts.isEmpty) return 0;
      return pts.fold<int>(0, (s, p) => s + p.bpm) / pts.length;
    }

    final local = _rPeaks.where((i) => i >= rng0 && i <= rng1).toList();
    return EventDetectionService.meanHeartRate(session.samples, local);
  }

  void _jumpToEvent(DetectedEvent event) {
    final int sampleIdx;
    if (_isFileBacked) {
      sampleIdx = event.timestampMs ~/ 2;
    } else {
      // event.timestampMs is a real Unix epoch ms; convert to sample index
      final originMs = widget.session.samples.isNotEmpty
          ? widget.session.samples.first.timestampMs
          : 0;
      sampleIdx = ((event.timestampMs - originMs) ~/ 2).clamp(0, _maxStart);
    }
    _onWindowMoved((sampleIdx - _windowSize ~/ 2).clamp(0, _maxStart));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session   = widget.session;
    final visible   = _visibleSamples;
    // used only to filter HR points to the visible window
    final hrOrigin  = visible.isNotEmpty ? visible.first.timestampMs : 0;
    final hasHr     = _effectiveHrData.isNotEmpty;
    final hasLo     = session.leadOffIntervals.isNotEmpty;
    final hasDc     = session.disconnectIntervals.isNotEmpty;
    final plotBands = [
      ..._leadOffBands(),
      ..._disconnectBands(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.sourceFile, style: const TextStyle(fontSize: 16)),
            Text(
              '${session.sampleCount} Samples · ${_formatDuration(session.duration)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showRPeaks ? 'R-Peaks ausblenden' : 'R-Peaks anzeigen',
            icon: Icon(Icons.scatter_plot,
                color: _showRPeaks ? Colors.red : null),
            onPressed: () => setState(() => _showRPeaks = !_showRPeaks),
          ),
          if (hasHr)
            IconButton(
              tooltip: _showHr ? 'HR ausblenden' : 'HR anzeigen',
              icon: Icon(Icons.monitor_heart,
                  color: _showHr ? Colors.green : null),
              onPressed: () => setState(() => _showHr = !_showHr),
            ),
          if (hasLo)
            IconButton(
              tooltip: _showLeadOff ? 'Lead-Off ausblenden' : 'Lead-Off anzeigen',
              icon: Icon(Icons.electric_bolt,
                  color: _showLeadOff ? Colors.orange : null),
              onPressed: () => setState(() => _showLeadOff = !_showLeadOff),
            ),
          if (hasDc)
            IconButton(
              tooltip: _showDisconnect ? 'Abbrüche ausblenden' : 'Abbrüche anzeigen',
              icon: Icon(Icons.bluetooth_disabled,
                  color: _showDisconnect ? Colors.red : null),
              onPressed: () => setState(() => _showDisconnect = !_showDisconnect),
            ),
          if (!_isFileBacked)
            IconButton(
              tooltip: _showFiltered ? 'Roh anzeigen' : 'Gefiltert anzeigen',
              icon: Icon(
                  _showFiltered ? Icons.filter_alt : Icons.filter_alt_off),
              onPressed: () => setState(() => _showFiltered = !_showFiltered),
            ),
        ],
      ),
      body: Column(
        children: [
          _SummaryBar(
            session: session,
            meanBpm: _localMeanBpm,
            rPeakCount: _isFileBacked
                ? session.rPeakIndices.length
                : _rPeaks.length,
            events: _events,
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (_maxStart == 0) return;
                          final spp = _windowSize / constraints.maxWidth;
                          final delta =
                              -(details.primaryDelta! * spp).round();
                          _onWindowMoved(
                              (_windowStart + delta).clamp(0, _maxStart));
                        },
                        child: SfCartesianChart(
                          primaryXAxis: NumericAxis(
                            title: AxisTitle(text: 'Zeit'),
                            interval: _axisIntervalMs.toDouble(),
                            axisLabelFormatter: (AxisLabelRenderDetails d) {
                              if (!_isFileBacked) {
                                return ChartAxisLabel(
                                  _formatAsViennaTime(d.value.toInt()),
                                  d.textStyle,
                                );
                              }
                              final dur = Duration(milliseconds: d.value.toInt());
                              final h = dur.inHours;
                              final m = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
                              final s = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
                              return ChartAxisLabel(
                                h > 0 ? '$h:$m:$s' : '$m:$s',
                                d.textStyle,
                              );
                            },
                            plotBands: plotBands,
                          ),
                          primaryYAxis:
                              NumericAxis(title: AxisTitle(text: 'ADC')),
                          axes: _showHr && hasHr
                              ? <ChartAxis>[
                                  NumericAxis(
                                    name: 'hrAxis',
                                    opposedPosition: true,
                                    minimum: 30,
                                    maximum: 220,
                                    interval: 30,
                                    title: AxisTitle(text: 'HR (bpm)'),
                                  ),
                                ]
                              : const [],
                          series: <CartesianSeries>[
                            LineSeries<EcgSample, int>(
                              dataSource: visible,
                              xValueMapper: (s, _) =>
                                  s.timestampMs - _recordingOrigin,
                              yValueMapper: (s, _) => s.value,
                              animationDuration: 0,
                              width: 1.2,
                              color: _showFiltered
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            if (_showRPeaks)
                              ScatterSeries<EcgSample, int>(
                                dataSource: _visibleRPeaks,
                                xValueMapper: (s, _) =>
                                    s.timestampMs - _recordingOrigin,
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
                            if (_showHr && hasHr)
                              LineSeries<HrDataPoint, int>(
                                dataSource: _visibleHrPoints(hrOrigin),
                                xValueMapper: (p, _) =>
                                    p.timestampMs - _recordingOrigin,
                                yValueMapper: (p, _) => p.bpm,
                                yAxisName: 'hrAxis',
                                animationDuration: 0,
                                width: 1.5,
                                color: Colors.green,
                                markerSettings: const MarkerSettings(
                                  isVisible: true,
                                  height: 5,
                                  width: 5,
                                  color: Colors.green,
                                  borderWidth: 0,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Cache-loading overlay for file-backed sessions
                if (_isCacheLoading)
                  const Positioned(
                    top: 8,
                    right: 16,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          _buildControls(session),
          if (_events.isNotEmpty)
            _EventList(events: _events, onTap: _jumpToEvent),
          if (session.skippedPackets > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${session.skippedPackets} fehlerhafte Pakete übersprungen',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(ImportedSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            iconSize: 20,
            tooltip: 'Vergrößern',
            onPressed: _windowSize > _minWindowSize
                ? () => setState(() {
                      _windowSize =
                          (_windowSize ~/ 2).clamp(_minWindowSize, _maxWindowSize);
                      _windowStart = _windowStart.clamp(0, _maxStart);
                    })
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            iconSize: 20,
            tooltip: 'Verkleinern',
            onPressed: _windowSize < _maxWindowSize
                ? () => setState(() {
                      _windowSize =
                          (_windowSize * 2).clamp(_minWindowSize, _maxWindowSize);
                      _windowStart = _windowStart.clamp(0, _maxStart);
                    })
                : null,
          ),
          Text(
            '${(_windowSize / 500).toStringAsFixed(1)}s',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_maxStart > 0) ...[
            const SizedBox(width: 4),
            Text(
              _formatWindowPosition(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Expanded(
              child: Slider(
                value: _windowStart.toDouble(),
                min: 0,
                max: _maxStart.toDouble(),
                onChanged: (v) => _onWindowMoved(v.toInt()),
              ),
            ),
            Text(
              _formatDuration(session.duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            const Spacer(),
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

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final ImportedSession session;
  final double meanBpm;
  final int rPeakCount;
  final List<DetectedEvent> events;

  const _SummaryBar({
    required this.session,
    required this.meanBpm,
    required this.rPeakCount,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final tachy   = events.where((e) => e.type == EcgEventType.tachycardia).length;
    final brady   = events.where((e) => e.type == EcgEventType.bradycardia).length;
    final pauses  = events.where((e) => e.type == EcgEventType.pause).length;
    final loCount = session.leadOffIntervals.length;
    final dcCount = session.disconnectIntervals.length;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: 'Ø HR', value: '${meanBpm.round()} bpm'),
          _Stat(label: 'R-Peaks', value: '$rPeakCount'),
          if (tachy  > 0) _Stat(label: 'Tachy',    value: '$tachy',   color: Colors.orange),
          if (brady  > 0) _Stat(label: 'Brady',    value: '$brady',   color: Colors.blue),
          if (pauses > 0) _Stat(label: 'Pausen',   value: '$pauses',  color: Colors.red),
          if (loCount > 0) _Stat(label: 'Lead-Off', value: '$loCount×', color: Colors.orange.shade800),
          if (dcCount > 0) _Stat(label: 'Abbrüche', value: '$dcCount×', color: Colors.red),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
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

// ── Event list ────────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<DetectedEvent> events;
  final void Function(DetectedEvent)? onTap;

  const _EventList({required this.events, this.onTap});

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
              itemBuilder: (_, i) =>
                  _EventChip(event: events[i], onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final DetectedEvent event;
  final void Function(DetectedEvent)? onTap;

  const _EventChip({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (event.type) {
      EcgEventType.tachycardia =>
        ('Tachy\n${event.metadata?['bpm']} bpm', Colors.orange),
      EcgEventType.bradycardia =>
        ('Brady\n${event.metadata?['bpm']} bpm', Colors.blue),
      EcgEventType.pause =>
        ('Pause\n${event.durationMs} ms', Colors.red),
      _ => (event.type.name, Colors.grey),
    };

    final ts      = Duration(milliseconds: event.timestampMs);
    final timeStr =
        '${ts.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${ts.inSeconds.remainder(60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap != null ? () => onTap!(event) : null,
        child: Chip(
          backgroundColor: color.withAlpha(40),
          side: BorderSide(color: color, width: 1),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold)),
              Text(timeStr, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
