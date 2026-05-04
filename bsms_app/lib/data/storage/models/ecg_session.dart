import 'ecg_event.dart';

class EcgSession {
  final String id;                // e.g. UUID or database id
  final int startTimestampMs;
  final int endTimestampMs;
  final List<EcgEvent> events;

  EcgSession({
    required this.id,
    required this.startTimestampMs,
    required this.endTimestampMs,
    required this.events,
  });
}
