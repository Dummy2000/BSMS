import '../ecg_sample.dart';

class HrDataPoint {
  final int timestampMs;
  final int bpm; // 0 = not yet calculated by ESP32 firmware

  const HrDataPoint({required this.timestampMs, required this.bpm});
}

/// Time span during which lead-off was detected (electrode contact lost).
/// [endMs] == -1 means the condition persisted until the end of the recording.
class LeadOffInterval {
  final int startMs;
  final int endMs;

  const LeadOffInterval({required this.startMs, required this.endMs});
}

/// Time span during which BLE connection was lost.
/// Samples in this range have value 0 in the binary file.
/// [endMs] == -1 means connection was never re-established.
class DisconnectInterval {
  final int startMs;
  final int endMs;

  const DisconnectInterval({required this.startMs, required this.endMs});
}

class ImportedSession {
  final String id;
  final String sourceFile;
  final DateTime importedAt;
  final int skippedPackets;

  /// Optional: which person this recording belongs to (null = SD import).
  final String? personId;

  // ── In-memory sessions (SD imports) ──────────────────────────────────────
  /// Raw samples. Empty for file-backed sessions — use [SessionReader] instead.
  final List<EcgSample> samples;

  // ── File-backed sessions (BLE recordings) ────────────────────────────────
  /// Path to the 51-byte-per-block binary file. Null for in-memory sessions.
  final String? filePath;

  /// Absolute Unix timestamp (ms) of the very first sample in [filePath].
  /// Used by [SessionReader] to convert absolute file timestamps to relative ones.
  final int firstSampleTimestampMs;

  /// Total sample count for file-backed sessions (0 for in-memory).
  final int totalSampleCount;

  /// Total duration in ms for file-backed sessions (0 for in-memory).
  final int totalDurationMs;

  /// Pre-detected R-peak sample indices (file-backed). Empty = detect on load.
  final List<int> rPeakIndices;

  // ── Shared (both types) ───────────────────────────────────────────────────
  /// HR values from packet headers. Empty for file-backed (use rPeakIndices).
  final List<HrDataPoint> hrData;

  final List<LeadOffInterval> leadOffIntervals;

  final List<DisconnectInterval> disconnectIntervals;

  ImportedSession({
    required this.id,
    required this.sourceFile,
    required this.importedAt,
    required this.skippedPackets,
    this.personId,
    this.samples = const [],
    this.filePath,
    this.firstSampleTimestampMs = 0,
    this.totalSampleCount = 0,
    this.totalDurationMs = 0,
    this.rPeakIndices = const [],
    this.hrData = const [],
    this.leadOffIntervals = const [],
    this.disconnectIntervals = const [],
  });

  bool get isFileBacked => filePath != null;

  int get sampleCount => isFileBacked ? totalSampleCount : samples.length;

  Duration get duration {
    if (isFileBacked) return Duration(milliseconds: totalDurationMs);
    if (samples.isEmpty) return Duration.zero;
    return Duration(
        milliseconds: samples.last.timestampMs - samples.first.timestampMs);
  }
}
