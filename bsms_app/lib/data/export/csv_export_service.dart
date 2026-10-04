import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/ecg_sample.dart';
import '../../domain/models/imported_session.dart';
import '../../domain/processing/ecg_filter.dart';
import '../../domain/processing/r_peak_detector.dart';
import '../storage/session_reader.dart';

/// Exports a session as CSV: one row per sample with an R-peak flag.
///
/// Columns: sample_index, timestamp_ms (relative to first sample),
/// ecg_value (raw ADC), is_r_peak (0/1).
/// All work runs in a background isolate; file-backed sessions are streamed
/// in chunks so multi-hour recordings never sit in memory.
class CsvExportService {
  Future<File> export(ImportedSession session) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_fileName(session)}';

    if (session.isFileBacked) {
      await compute(_exportFileBacked, {
        'outPath': path,
        'filePath': session.filePath!,
        'firstTs': session.firstSampleTimestampMs,
        'rPeaks': Int32List.fromList(session.rPeakIndices),
      });
    } else {
      await compute(_exportInMemory, {
        'outPath': path,
        'values': Int32List.fromList(session.samples.map((s) => s.value).toList()),
        'timestamps':
            Int32List.fromList(session.samples.map((s) => s.timestampMs).toList()),
      });
    }
    return File(path);
  }

  static String _fileName(ImportedSession session) {
    final base = session.sourceFile
        .replaceAll(RegExp(r'\.bin$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return '${base}_${session.id}.csv';
  }
}

const _header = 'sample_index,timestamp_ms,ecg_value,is_r_peak\n';
const _chunkSamples = 50000;

/// Same detection path as the session screen: bandpass → Pan-Tompkins.
void _exportInMemory(Map<String, dynamic> args) {
  final values = args['values'] as Int32List;
  final timestamps = args['timestamps'] as Int32List;

  final samples = List<EcgSample>.generate(
    values.length,
    (i) => EcgSample(value: values[i], timestampMs: timestamps[i]),
  );
  final peaks = RPeakDetector.detect(EcgFilter.bandpass(samples)).toSet();

  final out = File(args['outPath'] as String).openSync(mode: FileMode.write);
  try {
    out.writeStringSync(_header);
    final buf = StringBuffer();
    for (int i = 0; i < values.length; i++) {
      buf.write('$i,${timestamps[i]},${values[i]},${peaks.contains(i) ? 1 : 0}\n');
      if (buf.length > 1 << 20) {
        out.writeStringSync(buf.toString());
        buf.clear();
      }
    }
    out.writeStringSync(buf.toString());
  } finally {
    out.closeSync();
  }
}

/// Uses the R-peaks stored at recording time.
void _exportFileBacked(Map<String, dynamic> args) {
  final filePath = args['filePath'] as String;
  final firstTs = args['firstTs'] as int;
  final peaks = (args['rPeaks'] as Int32List).toSet();
  final total = (File(filePath).lengthSync() ~/ 51) * 20;

  final out = File(args['outPath'] as String).openSync(mode: FileMode.write);
  try {
    out.writeStringSync(_header);
    for (int start = 0; start < total; start += _chunkSamples) {
      final pairs = readRawPairs(filePath, firstTs, start, _chunkSamples);
      final buf = StringBuffer();
      for (int j = 0; j < pairs.length; j++) {
        final idx = start + j;
        buf.write('$idx,${pairs[j][1]},${pairs[j][0]},${peaks.contains(idx) ? 1 : 0}\n');
      }
      out.writeStringSync(buf.toString());
    }
  } finally {
    out.closeSync();
  }
}
