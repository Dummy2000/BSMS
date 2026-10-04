import '../ecg_sample.dart';
import '../ecg_event_type.dart';
import '../models/imported_session.dart';

class DetectedEvent {
  final EcgEventType type;
  final int timestampMs;
  final int? durationMs;
  final Map<String, dynamic>? metadata;

  const DetectedEvent({
    required this.type,
    required this.timestampMs,
    this.durationMs,
    this.metadata,
  });
}

/// Derives cardiac events from detected R-peak positions.
///
/// Computes RR intervals and classifies each interval as tachycardia,
/// bradycardia, or pause based on standard clinical thresholds.
class EventDetectionService {
  static const int _tachyThresholdBpm = 100;
  static const int _bradyThresholdBpm = 60;
  static const int _pauseThresholdMs = 2000; // > 2 s gap

  /// Runs event detection on [samples] using the pre-detected [rPeakIndices].
  ///
  /// Returns a list of episodes sorted by timestamp. A tachy/brady episode ends
  /// as soon as more than one consecutive normal beat follows (see
  /// [_buildEpisodes]). Pauses are emitted individually.
  static List<DetectedEvent> detect(
    List<EcgSample> samples,
    List<int> rPeakIndices,
  ) {
    if (rPeakIndices.length < 2) return [];

    final pauses = <DetectedEvent>[];
    final beats  = <({int ts, int? bpm})>[];

    for (int i = 1; i < rPeakIndices.length; i++) {
      final prevTs = samples[rPeakIndices[i - 1]].timestampMs;
      final currTs = samples[rPeakIndices[i]].timestampMs;
      final rrMs = currTs - prevTs;
      if (rrMs <= 0) continue;

      final bpm = (60000 / rrMs).round();
      if (bpm < 20 || bpm > 300) continue; // physiologically impossible — skip

      if (rrMs > _pauseThresholdMs) {
        pauses.add(DetectedEvent(
          type: EcgEventType.pause,
          timestampMs: prevTs,
          durationMs: rrMs,
          metadata: {'rrMs': rrMs},
        ));
        beats.add((ts: currTs, bpm: null)); // pause → hard break for episodes
      } else {
        beats.add((ts: currTs, bpm: bpm));
      }
    }

    return [..._buildEpisodes(beats), ...pauses]
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
  }

  /// Average heart rate over the whole session (beats/min).
  static double meanHeartRate(List<EcgSample> samples, List<int> rPeakIndices) {
    if (rPeakIndices.length < 2) return 0;
    final totalMs =
        samples[rPeakIndices.last].timestampMs - samples[rPeakIndices.first].timestampMs;
    if (totalMs <= 0) return 0;
    final beats = rPeakIndices.length - 1;
    return beats * 60000.0 / totalMs;
  }

  /// Derives tachycardia / bradycardia events from transmitted [hrData].
  ///
  /// Emits one event per episode (state transition), so a continuous
  /// tachycardia stretch produces exactly one event at its onset.
  /// Pauses are not derivable from HR data and must still come from R-peaks.
  static List<DetectedEvent> detectFromHrData(List<HrDataPoint> hrData) {
    final events = <DetectedEvent>[];
    EcgEventType? lastState;

    for (final point in hrData) {
      if (point.bpm == 0) continue;

      final state = point.bpm > _tachyThresholdBpm
          ? EcgEventType.tachycardia
          : point.bpm < _bradyThresholdBpm
              ? EcgEventType.bradycardia
              : null;

      if (state != lastState && state != null) {
        events.add(DetectedEvent(
          type: state,
          timestampMs: point.timestampMs,
          metadata: {'bpm': point.bpm},
        ));
      }
      lastState = state;
    }

    return events;
  }

  /// Mean BPM computed from transmitted [hrData] (ignores zero values).
  static double meanFromHrData(List<HrDataPoint> hrData) {
    final valid = hrData.where((p) => p.bpm > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.fold<int>(0, (sum, p) => sum + p.bpm) / valid.length;
  }

  /// Detect events from R-peak indices only (no sample list needed).
  ///
  /// Sample timestamps are derived as [peakIdx * 2] ms (500 Hz = 2 ms/sample).
  /// Use this for file-backed sessions where loading all samples is impractical.
  /// A tachy/brady episode ends as soon as more than one consecutive normal
  /// beat follows (see [_buildEpisodes]). Pauses are emitted individually.
  static List<DetectedEvent> detectFromPeakIndices(List<int> rPeakIndices) {
    if (rPeakIndices.length < 2) return [];

    final pauses = <DetectedEvent>[];
    final beats  = <({int ts, int? bpm})>[];

    for (int i = 1; i < rPeakIndices.length; i++) {
      final prevTs = rPeakIndices[i - 1] * 2;
      final currTs = rPeakIndices[i] * 2;
      final rrMs = currTs - prevTs;
      if (rrMs <= 0) continue;

      final bpm = (60000 / rrMs).round();
      if (bpm > 300) continue; // artefact — two R-peaks stored < 200 ms apart

      if (rrMs > _pauseThresholdMs) {
        pauses.add(DetectedEvent(
          type: EcgEventType.pause,
          timestampMs: prevTs,
          durationMs: rrMs,
          metadata: {'rrMs': rrMs},
        ));
        beats.add((ts: currTs, bpm: null)); // pause → hard break for episodes
      } else {
        beats.add((ts: currTs, bpm: bpm));
      }
    }

    return [..._buildEpisodes(beats), ...pauses]
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
  }

  // ── Lead-off handling ──────────────────────────────────────────────────────

  /// Removes tachy/brady/pause events that overlap a lead-off interval (no
  /// reliable signal there) and injects one [EcgEventType.leadOff] event per
  /// interval instead.
  ///
  /// [recordingEndMs] resolves intervals whose `endMs == -1` (lead-off that
  /// persisted until the end of the recording). All timestamps must share the
  /// same basis as the events (recording-relative ms).
  static List<DetectedEvent> applyLeadOff(
    List<DetectedEvent> events,
    List<LeadOffInterval> leadOffIntervals,
    int recordingEndMs,
  ) {
    if (leadOffIntervals.isEmpty) return events;

    // Resolve open-ended intervals to concrete [start, end] pairs.
    final intervals = leadOffIntervals
        .map((iv) => (
              start: iv.startMs,
              end: iv.endMs == -1 ? recordingEndMs : iv.endMs,
            ))
        .toList();

    bool overlapsLeadOff(DetectedEvent e) {
      final eStart = e.timestampMs;
      final eEnd   = e.timestampMs + (e.durationMs ?? 0);
      return intervals.any((iv) => eStart <= iv.end && eEnd >= iv.start);
    }

    // Drop events that overlap any lead-off interval.
    final result = events.where((e) => !overlapsLeadOff(e)).toList();

    // Inject one lead-off event per interval.
    for (final iv in intervals) {
      final dur = iv.end - iv.start;
      result.add(DetectedEvent(
        type: EcgEventType.leadOff,
        timestampMs: iv.start,
        durationMs: dur > 0 ? dur : null,
      ));
    }

    result.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return result;
  }

  // ── Episode building ────────────────────────────────────────────────────────

  /// Builds tachy/brady episodes from a per-beat sequence.
  ///
  /// Each entry is `(ts, bpm)`; a `null` bpm is a hard break (e.g. a pause) that
  /// always ends an open episode.
  ///
  /// An open episode is extended by every matching abnormal beat. A single
  /// normal beat is tolerated (the rhythm may briefly recover), but the **second
  /// consecutive** normal beat ends the episode. The episode end is the
  /// timestamp of the last *abnormal* beat — trailing normal beats are not
  /// counted — so the duration reflects the actual low/high-HR stretch.
  ///
  /// The emitted event carries:
  ///   • `timestampMs` = first abnormal beat of the episode
  ///   • `durationMs`  = last − first abnormal beat (null for single-beat events)
  ///   • `metadata['bpm']` = most severe BPM (highest for tachy, lowest for brady)
  static List<DetectedEvent> _buildEpisodes(List<({int ts, int? bpm})> beats) {
    final result = <DetectedEvent>[];

    EcgEventType? curType;
    int episodeStart = 0, episodeEnd = 0, peakBpm = 0, normalRun = 0, beatCount = 0;

    void close() {
      // Only emit episodes with more than one beat past the threshold — a single
      // outlier beat is treated as noise and not shown as an event.
      if (curType != null && beatCount > 1) {
        final dur = episodeEnd - episodeStart;
        result.add(DetectedEvent(
          type: curType!,
          timestampMs: episodeStart,
          durationMs: dur > 0 ? dur : null,
          metadata: {'bpm': peakBpm},
        ));
      }
      curType = null;
    }

    for (final b in beats) {
      // Hard break (pause): always ends an open episode.
      if (b.bpm == null) {
        close();
        normalRun = 0;
        continue;
      }

      final bpm = b.bpm!;
      final type = bpm > _tachyThresholdBpm
          ? EcgEventType.tachycardia
          : bpm < _bradyThresholdBpm
              ? EcgEventType.bradycardia
              : null;

      if (type == null) {
        // Normal beat: tolerate one; the second consecutive ends the episode.
        if (curType != null && ++normalRun > 1) close();
        continue;
      }

      if (type == curType) {
        episodeEnd = b.ts;
        normalRun = 0;
        beatCount++;
        final moreSevere = type == EcgEventType.tachycardia
            ? bpm > peakBpm
            : bpm < peakBpm;
        if (moreSevere) peakBpm = bpm;
      } else {
        close();
        curType = type;
        episodeStart = episodeEnd = b.ts;
        peakBpm = bpm;
        normalRun = 0;
        beatCount = 1;
      }
    }
    close();

    return result;
  }

  /// Compute HR data points from R-peak indices for chart display.
  ///
  /// Returns one [HrDataPoint] per consecutive peak pair, timestamped at the
  /// second peak position. Filters physiologically implausible values.
  static List<HrDataPoint> hrFromPeakIndices(List<int> rPeakIndices) {
    final result = <HrDataPoint>[];
    for (int i = 1; i < rPeakIndices.length; i++) {
      final rrMs = (rPeakIndices[i] - rPeakIndices[i - 1]) * 2;
      if (rrMs <= 0) continue;
      final bpm = (60000 / rrMs).round();
      if (bpm >= 30 && bpm <= 220) {
        result.add(HrDataPoint(
          timestampMs: rPeakIndices[i] * 2,
          bpm: bpm,
        ));
      }
    }
    return result;
  }

  /// Mean BPM from R-peak indices for file-backed sessions.
  static double meanFromPeakIndices(List<int> rPeakIndices) {
    if (rPeakIndices.length < 2) return 0;
    final totalMs =
        (rPeakIndices.last - rPeakIndices.first) * 2;
    if (totalMs <= 0) return 0;
    return (rPeakIndices.length - 1) * 60000.0 / totalMs;
  }
}
