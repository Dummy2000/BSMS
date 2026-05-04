class SessionMetadata {
  final String id;
  final int startTimestampMs;
  final int endTimestampMs;
  final int sampleCount;
  final int eventCount;

  SessionMetadata({
    required this.id,
    required this.startTimestampMs,
    required this.endTimestampMs,
    required this.sampleCount,
    required this.eventCount,
  });
}
