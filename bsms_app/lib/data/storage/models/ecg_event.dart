import '../../../domain/ecg_event_type.dart';

class EcgEvent {
  final EcgEventType type;
  final int timestampMs;
  final int? durationMs;
  final Map<String, dynamic>? metadata;

  EcgEvent({
    required this.type,
    required this.timestampMs,
    this.durationMs,
    this.metadata,
  });
}
