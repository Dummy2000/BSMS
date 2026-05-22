import '../ecg_sample.dart';
import '../ecg_event_type.dart';

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
}
