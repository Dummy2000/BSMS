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
  /// Returns a list of events sorted by timestamp.
  static List<DetectedEvent> detect(
    List<EcgSample> samples,
    List<int> rPeakIndices,
  ) {
    final events = <DetectedEvent>[];
    if (rPeakIndices.length < 2) return events;

    for (int i = 1; i < rPeakIndices.length; i++) {
      final prevTs = samples[rPeakIndices[i - 1]].timestampMs;
      final currTs = samples[rPeakIndices[i]].timestampMs;
      final rrMs = currTs - prevTs;
      if (rrMs <= 0) continue;

      final bpm = (60000 / rrMs).round();

      if (rrMs > _pauseThresholdMs) {
        events.add(DetectedEvent(
          type: EcgEventType.pause,
          timestampMs: prevTs,
          durationMs: rrMs,
          metadata: {'rrMs': rrMs},
        ));
      } else if (bpm > _tachyThresholdBpm) {
        events.add(DetectedEvent(
          type: EcgEventType.tachycardia,
          timestampMs: currTs,
          metadata: {'bpm': bpm},
        ));
      } else if (bpm < _bradyThresholdBpm) {
        events.add(DetectedEvent(
          type: EcgEventType.bradycardia,
          timestampMs: currTs,
          metadata: {'bpm': bpm},
        ));
      }
    }

    return events;
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
  static List<DetectedEvent> detectFromPeakIndices(List<int> rPeakIndices) {
    if (rPeakIndices.length < 2) return [];
    final events = <DetectedEvent>[];

    for (int i = 1; i < rPeakIndices.length; i++) {
      final prevTs = rPeakIndices[i - 1] * 2;
      final currTs = rPeakIndices[i] * 2;
      final rrMs = currTs - prevTs;
      if (rrMs <= 0) continue;

      final bpm = (60000 / rrMs).round();
      if (rrMs > _pauseThresholdMs) {
        events.add(DetectedEvent(
          type: EcgEventType.pause,
          timestampMs: prevTs,
          durationMs: rrMs,
          metadata: {'rrMs': rrMs},
        ));
      } else if (bpm > _tachyThresholdBpm) {
        events.add(DetectedEvent(
          type: EcgEventType.tachycardia,
          timestampMs: currTs,
          metadata: {'bpm': bpm},
        ));
      } else if (bpm < _bradyThresholdBpm) {
        events.add(DetectedEvent(
          type: EcgEventType.bradycardia,
          timestampMs: currTs,
          metadata: {'bpm': bpm},
        ));
      }
    }
    return events;
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
