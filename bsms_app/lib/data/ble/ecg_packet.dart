class EcgPacket {
  final DateTime timestamp;
  final int heartRate;
  final int flags;
  final List<int> samples;

  EcgPacket({
    required this.timestamp,
    required this.heartRate,
    required this.flags,
    required this.samples,
  });
}
