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
import '../../domain/processing/hrv_calculator.dart';
import '../../app/app_mode.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_ext.dart';

class ImportedSessionScreen extends StatefulWidget {
  final ImportedSession session;

  const ImportedSessionScreen({super.key, required this.session});

  @override
  State<ImportedSessionScreen> createState() => _ImportedSessionScreenState();
}

class _ImportedSessionScreenState extends State<ImportedSessionScreen> {
  // Zoom steps in samples (×2 ms = duration). Extra steps between 0.5/1/2 s.
  // 0.5, 0.75, 1, 1.5, 2, 3, 5, 10, 20 s
  static const List<int> _windowSteps = [
    250, 375, 500, 750, 1000, 1500, 2500, 5000, 10000,
  ];
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
  /// X-axis origin = timestamp (ms) of the left edge of the currently visible
  /// window. The chart plots data relative to this so the axis labels stay
  /// pinned at 0, 500, 1000 … and don't slide when the window is panned.
  /// Recomputed at the start of every [build].
  int _viewOrigin = 0;
  late final List<DetectedEvent> _events;

  /// Effective HR data: session.hrData for SD imports, peaks→bpm for BLE.
  late final List<HrDataPoint> _effectiveHrData;

  /// SDNN (ms) over the whole recording, or null if too few NN intervals.
  late final double? _sdnn;

  /// User-selectable RMSSD: duration of the window and the last computed value.
  int     _rmssdDurationMs = 90000; // default 90 s, changeable in the menu
  double? _rmssdValue;              // last RMSSD created via the menu (null = none)

  int  _windowStart     = 0;
  int  _windowSize      = _defaultWindowSize;
  int  _selectedEvent   = 0; // index into _events for the navigator bar
  bool _showFiltered    = true;
  bool _showHr          = true;
  bool _showLeadOff     = true;
  bool _showDisconnect  = true;
  bool _showRPeaks      = false;

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
      _effectiveHrData =
          EventDetectionService.hrFromPeakIndices(session.rPeakIndices);
      _events = EventDetectionService.applyLeadOff(
        EventDetectionService.detectFromPeakIndices(session.rPeakIndices),
        session.leadOffIntervals,
        session.totalSampleCount * 2,
      );
      _loadCacheAround(0);
      _sdnn = HrvCalculator.sdnn(
          session.rPeakIndices.map((i) => i * 2).toList());
    } else {
      _totalSamples    = 0;
      _filtered        = EcgFilter.bandpass(session.samples);
      _rPeaks       = RPeakDetector.detect(_filtered);

      final int recEndMs = session.samples.isNotEmpty
          ? session.samples.last.timestampMs
          : 0;
      if (session.hrData.isNotEmpty) {
        _effectiveHrData = session.hrData;
        final hrEvents = EventDetectionService.detectFromHrData(session.hrData);
        final pauses   = EventDetectionService
            .detect(session.samples, _rPeaks)
            .where((e) => e.type == EcgEventType.pause)
            .toList();
        final merged = [...hrEvents, ...pauses]
          ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
        _events = EventDetectionService.applyLeadOff(
            merged, session.leadOffIntervals, recEndMs);
      } else {
        _effectiveHrData = const [];
        _events = EventDetectionService.applyLeadOff(
          EventDetectionService.detect(session.samples, _rPeaks),
          session.leadOffIntervals,
          recEndMs,
        );
      }
      _sdnn = HrvCalculator.sdnn(
          _rPeaks.map((i) => session.samples[i].timestampMs).toList());
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
      const minGap = 100; // 200 ms refractory — skip artefact double-peaks
      final result = <EcgSample>[];
      int lastIdx = -minGap;
      for (final idx in widget.session.rPeakIndices) {
        if (idx < _windowStart || idx >= _windowStart + _windowSize) continue;
        if (idx < _cacheStart  || idx >= cacheEnd) continue;
        if (idx - lastIdx < minGap) continue; // too close → artefact
        result.add(_filteredCache[idx - _cacheStart]);
        lastIdx = idx;
      }
      return result;
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
    final pts = _effectiveHrData; // ascending by timestamp

    // Inclusive index bounds of the points inside the window.
    int lo = 0;
    while (lo < pts.length && pts[lo].timestampMs < originMs) {
      lo++;
    }
    int hi = pts.length - 1;
    while (hi >= 0 && pts[hi].timestampMs > windowEndMs) {
      hi--;
    }

    // Extend by one point on each side so the connecting line spans the full
    // width (it gets clipped at the plot edges). This also keeps the line
    // continuous while panning instead of jumping when a point exits the window.
    final start = (lo - 1) < 0 ? 0 : lo - 1;
    final end   = (hi + 1) >= pts.length ? pts.length - 1 : hi + 1;
    if (start > end) return const [];
    return pts.sublist(start, end + 1).where((p) => p.bpm > 0).toList();
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
            start: (iv.startMs - _viewOrigin).toDouble(),
            end:   (end        - _viewOrigin).toDouble(),
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
            start: (iv.startMs - _viewOrigin).toDouble(),
            end:   (end        - _viewOrigin).toDouble(),
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
    if (_isFileBacked) {
      return _formatAsViennaTime(
          _windowStart * 2 + widget.session.firstSampleTimestampMs);
    }
    if (widget.session.samples.isNotEmpty) {
      final rawMs = widget.session.samples.first.timestampMs + _windowStart * 2;
      return _formatAsViennaTime(rawMs);
    }
    return _msToTime(_windowStart * 2);
  }

  /// Formats an event timestamp (recording-relative for file-backed, absolute
  /// sample ms for in-memory) as real Vienna wall-clock time.
  String _eventTimeFmt(int ms) => _formatAsViennaTime(
      ms + (_isFileBacked ? widget.session.firstSampleTimestampMs : 0));

  List<PlotBand> _episodeBands() {
    if (_events.isEmpty) return const [];
    final visible = _visibleSamples;
    if (visible.isEmpty) return const [];
    final winStart = visible.first.timestampMs;
    final winEnd   = visible.last.timestampMs;

    final bands = <PlotBand>[];
    for (final e in _events) {
      if (e.type != EcgEventType.tachycardia &&
          e.type != EcgEventType.bradycardia) {
        continue;
      }

      final start = e.timestampMs - _viewOrigin;
      // Use actual episode duration; fall back to 1 s for onset-only events.
      final end = (e.durationMs != null && e.durationMs! > 0)
          ? start + e.durationMs!
          : start + 1000;

      if (end < winStart - _viewOrigin || start > winEnd - _viewOrigin) {
        continue;
      }

      final isTachy = e.type == EcgEventType.tachycardia;
      bands.add(PlotBand(
        start: start.toDouble(),
        end:   end.toDouble(),
        color:       (isTachy ? Colors.orange : Colors.blue).withAlpha(35),
        borderColor: (isTachy ? Colors.orange : Colors.blue).withAlpha(100),
        borderWidth: 1,
      ));
    }
    return bands;
  }

  /// Index of the zoom step nearest to the current window size.
  int get _stepIndex {
    int best = 0, bestDiff = 1 << 30;
    for (int i = 0; i < _windowSteps.length; i++) {
      final diff = (_windowSteps[i] - _windowSize).abs();
      if (diff < bestDiff) { bestDiff = diff; best = i; }
    }
    return best;
  }

  /// delta = -1 zooms in (smaller window), +1 zooms out (larger).
  void _zoom(int delta) {
    final idx = (_stepIndex + delta).clamp(0, _windowSteps.length - 1);
    setState(() {
      _windowSize  = _windowSteps[idx];
      _windowStart = _windowStart.clamp(0, _maxStart);
    });
  }

  /// Window size as a clean seconds label (e.g. "0.75s", "1.5s", "5s").
  String get _scaleLabel {
    final s = _windowSize / 500;
    final str = s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString();
    return '${str}s';
  }

  int get _axisIntervalMs {
    final durationMs = _windowSize * 2;
    if (durationMs <= 1500)  return 250;   // very close zoom → 250 ms ticks
    if (durationMs <= 3000)  return 500;   // closer than ~2.5 s → 500 ms ticks
    if (durationMs <= 6000)  return 1000;  // → 1 s
    if (durationMs <= 12000) return 2000;  // → 2 s
    return 4000;                           // 20 s window → 0,4,8,12,16,20 s
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

  // ── Event navigation ────────────────────────────────────────────────────────

  void _selectEvent(int index) {
    if (_events.isEmpty) return;
    final i = index.clamp(0, _events.length - 1);
    setState(() => _selectedEvent = i);
    _jumpToEvent(_events[i]);
  }

  Future<void> _openEventMenu() async {
    if (_events.isEmpty) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _EventMenuSheet(
        events: _events,
        selectedIndex: _selectedEvent,
        timeFmt: _eventTimeFmt,
      ),
    );
    if (picked != null) _selectEvent(picked);
  }

  // ── RMSSD (user-selectable window) ──────────────────────────────────────────

  /// All R-peak timestamps as ms elapsed from the start of the recording.
  List<int> _peaksElapsedMs() {
    if (_isFileBacked) {
      return widget.session.rPeakIndices.map((i) => i * 2).toList();
    }
    if (widget.session.samples.isEmpty) return const [];
    final base = widget.session.samples.first.timestampMs;
    return _rPeaks.map((i) => widget.session.samples[i].timestampMs - base).toList();
  }

  /// Start of the currently visible window, in ms elapsed from recording start.
  int get _currentElapsedMs {
    if (_isFileBacked) return _windowStart * 2;
    if (widget.session.samples.isEmpty) return 0;
    return widget.session.samples[_windowStart].timestampMs -
        widget.session.samples.first.timestampMs;
  }

  /// Total recording length in ms.
  int get _totalElapsedMs {
    if (_isFileBacked) return _totalSamples * 2;
    if (widget.session.samples.isEmpty) return 0;
    return widget.session.samples.last.timestampMs -
        widget.session.samples.first.timestampMs;
  }

  /// Computes RMSSD over [startMs, startMs+durationMs] (elapsed-ms basis).
  ({double? rmssd, int beats}) _computeRmssd(int startMs, int durationMs) {
    final endMs = startMs + durationMs;
    final peaks = _peaksElapsedMs()
        .where((t) => t >= startMs && t <= endMs)
        .toList();
    return (rmssd: HrvCalculator.rmssdForSeries(peaks), beats: peaks.length);
  }

  Future<void> _openRmssdMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _RmssdMenuSheet(
        currentStartMs: _currentElapsedMs,
        totalMs:        _totalElapsedMs,
        initialDurationMs: _rmssdDurationMs,
        lastResult:     _rmssdValue,
        compute:        _computeRmssd,
        onDurationChanged: (d) => _rmssdDurationMs = d,
        onResult: (v) => setState(() => _rmssdValue = v),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l         = context.l10n;
    final session   = widget.session;
    final visible   = _visibleSamples;
    // used only to filter HR points to the visible window
    final hrOrigin  = visible.isNotEmpty ? visible.first.timestampMs : 0;
    // Use absolute (stable) x values for ALL series so the waveform line and the
    // overlay markers (R-peaks, HR dots) share the exact same time→pixel
    // transform. Rebasing per frame shifted every point's x each pan, which made
    // the markers drift / leave stale dots. Stable round labels are instead
    // achieved by anchoring the axis minimum to the window's left edge:
    // Syncfusion places ticks at minimum, minimum+interval, … so the offset from
    // the minimum is always 0, 500, 1000 …
    _viewOrigin = 0; // data plotted at absolute timestamps
    final int axisMinMs = visible.isNotEmpty ? visible.first.timestampMs : 0;
    final double? axisMinD = visible.isNotEmpty ? axisMinMs.toDouble() : null;
    final double? axisMaxD =
        visible.isNotEmpty ? visible.last.timestampMs.toDouble() : null;
    final hasHr     = _effectiveHrData.isNotEmpty;
    final hasLo     = session.leadOffIntervals.isNotEmpty;
    final hasDc     = session.disconnectIntervals.isNotEmpty;
    final plotBands = [
      ..._leadOffBands(),
      ..._disconnectBands(),
      ..._episodeBands(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.sourceFile, style: const TextStyle(fontSize: 16)),
            Text(
              l.sessionHeaderSub(
                  session.sampleCount, _formatDuration(session.duration)),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showRPeaks ? l.tooltipRPeaksHide : l.tooltipRPeaksShow,
            icon: Icon(Icons.scatter_plot,
                color: _showRPeaks ? Colors.red : null),
            onPressed: () => setState(() => _showRPeaks = !_showRPeaks),
          ),
          if (hasHr)
            IconButton(
              tooltip: _showHr ? l.tooltipHrHide : l.tooltipHrShow,
              icon: Icon(Icons.monitor_heart,
                  color: _showHr ? Colors.green : null),
              onPressed: () => setState(() => _showHr = !_showHr),
            ),
          if (hasLo)
            IconButton(
              tooltip: _showLeadOff ? l.tooltipLeadOffHide : l.tooltipLeadOffShow,
              icon: Icon(Icons.electric_bolt,
                  color: _showLeadOff ? Colors.orange : null),
              onPressed: () => setState(() => _showLeadOff = !_showLeadOff),
            ),
          if (hasDc)
            IconButton(
              tooltip: _showDisconnect ? l.tooltipDisconnectHide : l.tooltipDisconnectShow,
              icon: Icon(Icons.bluetooth_disabled,
                  color: _showDisconnect ? Colors.red : null),
              onPressed: () => setState(() => _showDisconnect = !_showDisconnect),
            ),
          if (!_isFileBacked)
            IconButton(
              tooltip: _showFiltered ? l.tooltipShowRaw : l.tooltipShowFiltered,
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
            sdnn: _sdnn,
            rmssd: _rmssdValue,
            onRmssdTap: _openRmssdMenu,
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
                            title: AxisTitle(text: '${l.axisTime} (ms)'),
                            interval: _axisIntervalMs.toDouble(),
                            minimum: axisMinD,
                            maximum: axisMaxD,
                            // Right-align each label (incl. the start-time label)
                            // to its tick gridline; no edge shifting so the
                            // leftmost label also stays right-aligned.
                            labelAlignment: LabelAlignment.end,
                            axisLabelFormatter: (AxisLabelRenderDetails d) {
                              // Ticks run from the axis minimum (window's left
                              // edge) in steps of the interval → offset is always
                              // 0, 500, 1000 … (stable while panning). The
                              // leftmost (offset 0) shows the wall-clock time.
                              final off = d.value.round() - axisMinMs;
                              if (off <= 0) {
                                return ChartAxisLabel(
                                    _eventTimeFmt(axisMinMs), d.textStyle);
                              }
                              return ChartAxisLabel('$off', d.textStyle);
                            },
                            plotBands: plotBands,
                          ),
                          primaryYAxis: NumericAxis(
                            title: AxisTitle(text: l.axisAdc),
                            // Keep labels on the left, but raise them so each
                            // number sits on its gridline instead of being
                            // vertically centred on it.
                            labelAlignment: LabelAlignment.end,
                          ),
                          axes: _showHr && hasHr
                              ? <ChartAxis>[
                                  NumericAxis(
                                    name: 'hrAxis',
                                    opposedPosition: true,
                                    minimum: 30,
                                    maximum: 220,
                                    interval: 30,
                                    title: AxisTitle(text: l.axisHr),
                                  ),
                                ]
                              : const [],
                          series: <CartesianSeries>[
                            LineSeries<EcgSample, int>(
                              dataSource: visible,
                              xValueMapper: (s, _) =>
                                  s.timestampMs - _viewOrigin,
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
                                    s.timestampMs - _viewOrigin,
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
                                    p.timestampMs - _viewOrigin,
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
            _EventNavigatorBar(
              events: _events,
              selectedIndex: _selectedEvent.clamp(0, _events.length - 1),
              onPrev: () => _selectEvent(_selectedEvent - 1),
              onNext: () => _selectEvent(_selectedEvent + 1),
              onMenu: _openEventMenu,
              onTapDisplay: () => _selectEvent(_selectedEvent),
              timeFmt: _eventTimeFmt,
            ),
          if (session.skippedPackets > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l.skippedPackets(session.skippedPackets),
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
            tooltip: context.l10n.zoomIn,
            onPressed: _stepIndex > 0 ? () => _zoom(-1) : null,
          ),
          Text(
            _scaleLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            iconSize: 20,
            tooltip: context.l10n.zoomOut,
            onPressed:
                _stepIndex < _windowSteps.length - 1 ? () => _zoom(1) : null,
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
  final double? sdnn;
  final double? rmssd;
  final VoidCallback onRmssdTap;
  final List<DetectedEvent> events;

  const _SummaryBar({
    required this.session,
    required this.meanBpm,
    required this.sdnn,
    required this.rmssd,
    required this.onRmssdTap,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final l       = context.l10n;
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
          _Stat(label: l.statAvgHr, value: '${meanBpm.round()} bpm'),
          _Stat(
            label: l.statSdnn,
            value: sdnn != null ? '${sdnn!.round()} ms' : '—',
          ),
          // Tappable → opens the RMSSD menu.
          InkWell(
            onTap: onRmssdTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: _Stat(
                label: l.statRmssd,
                value: rmssd != null ? '${rmssd!.round()} ms' : l.rmssdOpen,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (tachy  > 0) _Stat(label: l.statTachy,  value: '$tachy',   color: Colors.orange),
          if (brady  > 0) _Stat(label: l.statBrady,  value: '$brady',   color: Colors.blue),
          if (pauses > 0) _Stat(label: l.statPauses, value: '$pauses',  color: Colors.red),
          if (loCount > 0) _Stat(label: l.statLeadOff, value: '$loCount×', color: Colors.orange.shade800),
          if (dcCount > 0) _Stat(label: l.statDisconnects, value: '$dcCount×', color: Colors.red),
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
    // The pixel font is much wider — shrink the summary stats in pixel mode so
    // the top row doesn't overflow.
    final pixel = pixelModeEnabled.value;
    final valueSize = pixel ? 9.0 : 16.0;
    final labelSize = pixel ? 7.0 : 11.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: valueSize,
                color: color ?? Theme.of(context).colorScheme.onSurface)),
        Text(label, style: TextStyle(fontSize: labelSize)),
      ],
    );
  }
}

// ── Event formatting helpers (shared) ──────────────────────────────────────────

String _fmtEventTs(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _fmtEventDuration(int ms) {
  if (ms >= 60000) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    return '${m}m ${s}s';
  }
  return '${ms ~/ 1000}s';
}

({String title, Color color, String detail, String time}) _eventVisuals(
    AppLocalizations l, DetectedEvent e, {String Function(int)? timeFmt}) {
  final dur = e.durationMs;
  final bpm = e.metadata?['bpm'];
  final fmt = timeFmt ?? _fmtEventTs;

  final (title, color) = switch (e.type) {
    EcgEventType.tachycardia => (l.evtTachycardia, Colors.orange),
    EcgEventType.bradycardia => (l.evtBradycardia, Colors.blue),
    EcgEventType.pause       => (l.evtPause, Colors.red),
    EcgEventType.leadOff     => (l.evtLeadOff, Colors.orange.shade800),
    _                        => (e.type.name, Colors.grey),
  };

  final time = (dur != null && dur > 0)
      ? '${fmt(e.timestampMs)} – ${fmt(e.timestampMs + dur)}'
      : fmt(e.timestampMs);

  final detail = switch (e.type) {
    EcgEventType.pause   => '${e.durationMs} ms',
    EcgEventType.leadOff => dur != null ? _fmtEventDuration(dur) : l.evtContactLoss,
    _ => [
        if (bpm != null) '$bpm bpm',
        if (dur != null && dur > 0) _fmtEventDuration(dur),
      ].join(' · '),
  };

  return (title: title, color: color, detail: detail, time: time);
}

// ── Event navigator bar (prev / display / next / menu) ──────────────────────────

class _EventNavigatorBar extends StatelessWidget {
  final List<DetectedEvent> events;
  final int selectedIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onMenu;
  final VoidCallback onTapDisplay;
  final String Function(int) timeFmt;

  const _EventNavigatorBar({
    required this.events,
    required this.selectedIndex,
    required this.onPrev,
    required this.onNext,
    required this.onMenu,
    required this.onTapDisplay,
    required this.timeFmt,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = events[selectedIndex];
    final v = _eventVisuals(l, e, timeFmt: timeFmt);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l.prevEvent,
            onPressed: selectedIndex > 0 ? onPrev : null,
          ),
          Expanded(
            child: InkWell(
              onTap: onTapDisplay,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: v.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            v.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: v.color,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.detail}  ·  ${v.time}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      l.eventCounter(selectedIndex + 1, events.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l.nextEvent,
            onPressed: selectedIndex < events.length - 1 ? onNext : null,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: l.eventListTooltip,
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}

// ── Event menu (bottom sheet with full list) ────────────────────────────────────

class _EventMenuSheet extends StatelessWidget {
  final List<DetectedEvent> events;
  final int selectedIndex;
  final String Function(int) timeFmt;

  const _EventMenuSheet({
    required this.events,
    required this.selectedIndex,
    required this.timeFmt,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Text(l.eventsTitle(events.length),
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                itemCount: events.length,
                itemBuilder: (_, i) {
                  final v = _eventVisuals(l, events[i], timeFmt: timeFmt);
                  return ListTile(
                    selected: i == selectedIndex,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: v.color, shape: BoxShape.circle),
                    ),
                    title: Text(v.title,
                        style: TextStyle(
                            color: v.color, fontWeight: FontWeight.bold)),
                    subtitle: Text('${v.detail}  ·  ${v.time}'),
                    onTap: () => Navigator.pop(context, i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── RMSSD menu (bottom sheet: compute over a chosen window) ─────────────────────

class _RmssdMenuSheet extends StatefulWidget {
  /// Start of the currently visible window (ms elapsed from recording start).
  final int currentStartMs;

  /// Total recording length in ms.
  final int totalMs;

  /// Initial window duration in ms (default 90 s).
  final int initialDurationMs;

  /// Last RMSSD computed in a previous session of this menu (ms), or null.
  final double? lastResult;

  /// Computes RMSSD over [startMs, startMs+durationMs].
  final ({double? rmssd, int beats}) Function(int startMs, int durationMs) compute;

  final void Function(int durationMs) onDurationChanged;
  final void Function(double?) onResult;

  const _RmssdMenuSheet({
    required this.currentStartMs,
    required this.totalMs,
    required this.initialDurationMs,
    required this.lastResult,
    required this.compute,
    required this.onDurationChanged,
    required this.onResult,
  });

  @override
  State<_RmssdMenuSheet> createState() => _RmssdMenuSheetState();
}

class _RmssdMenuSheetState extends State<_RmssdMenuSheet> {
  late final TextEditingController _durationCtrl;
  late final TextEditingController _startCtrl;

  double? _result;
  int     _resultBeats   = 0;
  int?    _resultStartMs;
  int?    _resultDurMs;

  @override
  void initState() {
    super.initState();
    _durationCtrl =
        TextEditingController(text: (widget.initialDurationMs ~/ 1000).toString());
    _startCtrl =
        TextEditingController(text: (widget.currentStartMs ~/ 1000).toString());
    _result = widget.lastResult;
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  int? get _durationMs {
    final s = int.tryParse(_durationCtrl.text.trim());
    if (s == null || s <= 0) return null;
    return s * 1000;
  }

  int? get _manualStartMs {
    final s = int.tryParse(_startCtrl.text.trim());
    if (s == null || s < 0) return null;
    return s * 1000;
  }

  bool _fits(int startMs, int durationMs) =>
      startMs >= 0 && startMs + durationMs <= widget.totalMs;

  void _run(int startMs) {
    final durMs = _durationMs;
    if (durMs == null || !_fits(startMs, durMs)) return;
    final r = widget.compute(startMs, durMs);
    widget.onDurationChanged(durMs);
    widget.onResult(r.rmssd);
    setState(() {
      _result        = r.rmssd;
      _resultBeats   = r.beats;
      _resultStartMs = startMs;
      _resultDurMs   = durMs;
    });
  }

  static String _fmtMmSs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l            = context.l10n;
    final durMs        = _durationMs;
    final canCreateHere = durMs != null && _fits(widget.currentStartMs, durMs);
    final manualStart  = _manualStartMs;
    final canCreateCustom = durMs != null &&
        manualStart != null &&
        _fits(manualStart, durMs);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 4,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l.rmssdTitle, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l.close,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // ── Result ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resultStartMs == null
                        ? l.rmssdNotComputed
                        : _result != null
                            ? '${_result!.round()} ms'
                            : l.rmssdNa,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (_resultStartMs != null)
                    Text(
                      _result != null
                          ? l.rmssdResultDetail(
                              _fmtMmSs(_resultStartMs!),
                              _resultDurMs! ~/ 1000,
                              _resultBeats)
                          : l.rmssdTooFewBeats(_resultBeats),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Duration ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: Text(l.rmssdWindowLength)),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      suffixText: 's',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Create at current position ───────────────────────────────────
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.add_chart),
              label: Text(l.rmssdCreateHere(_fmtMmSs(widget.currentStartMs))),
              onPressed: canCreateHere ? () => _run(widget.currentStartMs) : null,
            ),
            if (durMs != null && !canCreateHere)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.rmssdNotEnoughAfter(durMs ~/ 1000),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error),
                ),
              ),

            const Divider(height: 28),

            // ── Custom range ─────────────────────────────────────────────────
            Text(l.rmssdCustomRange,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l.rmssdStartTime)),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _startCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      suffixText: 's',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.timeline),
              label: Text(l.rmssdComputeRange),
              onPressed:
                  canCreateCustom ? () => _run(manualStart) : null,
            ),
            if (durMs != null && manualStart != null && !canCreateCustom)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.rmssdOutOfRange(_fmtMmSs(widget.totalMs)),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
