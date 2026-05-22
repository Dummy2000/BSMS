import '../ecg_sample.dart';

class ImportedSession {
  final String id;
  final String sourceFile;
  final DateTime importedAt;
  final List<EcgSample> samples;
  final int skippedPackets;

  ImportedSession({
    required this.id,
    required this.sourceFile,
    required this.importedAt,
    required this.samples,
    required this.skippedPackets,
  });

  Duration get duration {
    if (samples.isEmpty) return Duration.zero;
    final ms = samples.last.timestampMs - samples.first.timestampMs;
    return Duration(milliseconds: ms);
  }
}
