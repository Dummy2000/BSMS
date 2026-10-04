import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/imported_session.dart';
import '../../domain/processing/ecg_filter.dart';

/// Reads ECG samples from a 51-byte-block binary file on demand.
///
/// Never loads the full file into memory — suitable for 12-hour recordings.
/// Uses Flutter's [compute] to run file I/O and filtering in a background
/// isolate so the UI thread is never blocked.
class SessionReader {
  final String filePath;

  /// Absolute Unix timestamp (ms) of sample index 0 in the file.
  /// Returned samples have timestamps relative to this value.
  final int firstSampleTimestampMs;

  const SessionReader({
    required this.filePath,
    required this.firstSampleTimestampMs,
  });

  factory SessionReader.fromSession(ImportedSession session) {
    assert(session.isFileBacked, 'SessionReader requires a file-backed session');
    return SessionReader(
      filePath: session.filePath!,
      firstSampleTimestampMs: session.firstSampleTimestampMs,
    );
  }

  /// Total number of samples in the file.
  Future<int> getTotalSampleCount() async {
    final len = await File(filePath).length();
    return (len ~/ 51) * 20;
  }

  /// Returns [count] filtered samples starting at [startIdx].
  ///
  /// Pre-warms the filter with the 500 samples before [startIdx] to avoid
  /// transients at window boundaries. Runs entirely in a background isolate.
  Future<List<EcgSample>> readFilteredWindow({
    required int startIdx,
    required int count,
  }) async {
    final pairs = await compute(_isolateReadFiltered, {
      'filePath': filePath,
      'firstTs': firstSampleTimestampMs,
      'startIdx': startIdx,
      'count': count,
    });
    return pairs
        .map((p) => EcgSample(value: p[0], timestampMs: p[1]))
        .toList();
  }

  /// Returns [count] raw (unfiltered) samples starting at [startIdx].
  Future<List<EcgSample>> readRawWindow({
    required int startIdx,
    required int count,
  }) async {
    final pairs = await compute(_isolateReadRaw, {
      'filePath': filePath,
      'firstTs': firstSampleTimestampMs,
      'startIdx': startIdx,
      'count': count,
    });
    return pairs
        .map((p) => EcgSample(value: p[0], timestampMs: p[1]))
        .toList();
  }
}

// ── Top-level isolate functions ───────────────────────────────────────────────

/// Returns List<[value, relativeTimestampMs]> for the requested window,
/// after running the full bandpass + notch filter pipeline with pre-warming.
List<List<int>> _isolateReadFiltered(Map<String, dynamic> args) {
  const warmup = 500; // 1 s at 500 Hz
  final filePath = args['filePath'] as String;
  final firstTs  = args['firstTs']  as int;
  final startIdx = args['startIdx'] as int;
  final count    = args['count']    as int;

  final readStart = math.max(0, startIdx - warmup);
  final readCount = count + (startIdx - readStart); // extra warmup prefix

  final raw = readRawPairs(filePath, firstTs, readStart, readCount);

  // Reconstruct EcgSample list for bandpass filter
  final allSamples = raw
      .map((p) => EcgSample(value: p[0], timestampMs: p[1]))
      .toList();

  final filtered = EcgFilter.bandpass(allSamples);

  // Drop the warmup prefix, return exactly [count] samples
  final drop = startIdx - readStart;
  return filtered
      .skip(drop)
      .take(count)
      .map((s) => [s.value, s.timestampMs])
      .toList();
}

/// Returns raw (unfiltered) pairs for the requested window.
List<List<int>> _isolateReadRaw(Map<String, dynamic> args) {
  final filePath = args['filePath'] as String;
  final firstTs  = args['firstTs']  as int;
  final startIdx = args['startIdx'] as int;
  final count    = args['count']    as int;
  return readRawPairs(filePath, firstTs, startIdx, count);
}

/// Synchronous file reader — call only from a background isolate.
/// Returns pairs [value, relativeTimestampMs] for samples [startIdx .. startIdx+count).
List<List<int>> readRawPairs(
    String filePath, int firstTs, int startIdx, int count) {
  const packetSize = 51;
  const samplesPerPacket = 20;
  const sampleIntervalMs = 2;

  final startPacket = startIdx ~/ samplesPerPacket;
  final endIdx      = startIdx + count;
  final endPacket   = (endIdx + samplesPerPacket - 1) ~/ samplesPerPacket;

  final file = File(filePath);
  final raf  = file.openSync();
  final result = <List<int>>[];

  try {
    raf.setPositionSync(startPacket * packetSize);
    final bytesToRead = (endPacket - startPacket) * packetSize;
    final bytes = raf.readSync(bytesToRead);
    if (bytes.isEmpty) return result;

    final bd           = ByteData.sublistView(Uint8List.fromList(bytes));
    final packetsRead  = bytes.length ~/ packetSize;

    for (int p = 0; p < packetsRead; p++) {
      final pOff  = p * packetSize;
      final ptsMs = bd.getInt64(pOff, Endian.little); // absolute Unix ms

      for (int s = 0; s < samplesPerPacket; s++) {
        final globalIdx = (startPacket + p) * samplesPerPacket + s;
        if (globalIdx < startIdx || globalIdx >= endIdx) continue;

        final value  = bd.getUint16(pOff + 11 + s * 2, Endian.little);
        final relTs  = (ptsMs + s * sampleIntervalMs - firstTs).toInt();
        result.add([value, relTs]);
      }
    }
  } finally {
    raf.closeSync();
  }

  return result;
}
