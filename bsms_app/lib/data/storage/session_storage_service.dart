import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/imported_session.dart';
import 'database_helper.dart';

class SessionStorageService {
  final DatabaseHelper _db;

  SessionStorageService(this._db);

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> saveSession(
    ImportedSession session, {
    String? hrFilePath,
    String? rPeaksFilePath,
  }) async {
    final db = await _db.db;
    await db.insert(
      'sessions',
      {
        'id': session.id,
        'person_id': session.personId,
        'source_file': session.sourceFile,
        'recorded_at': session.importedAt.toIso8601String(),
        'duration_ms': session.totalDurationMs,
        'sample_count': session.totalSampleCount,
        'skipped_packets': session.skippedPackets,
        'file_path': session.filePath,
        'hr_file_path': hrFilePath,
        'r_peaks_file_path': rPeaksFilePath,
        'first_sample_ts_ms': session.firstSampleTimestampMs,
        'lead_off_json': jsonEncode(session.leadOffIntervals
            .map((iv) => {'startMs': iv.startMs, 'endMs': iv.endMs})
            .toList()),
        'disconnect_json': jsonEncode(session.disconnectIntervals
            .map((iv) => {'startMs': iv.startMs, 'endMs': iv.endMs})
            .toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<List<ImportedSession>> loadAll() async {
    final db = await _db.db;
    final rows = await db.query('sessions', orderBy: 'recorded_at DESC');
    return Future.wait(rows.map(_rowToSession));
  }

  Future<List<ImportedSession>> loadByPerson(String personId) async {
    final db = await _db.db;
    final rows = await db.query(
      'sessions',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'recorded_at DESC',
    );
    return Future.wait(rows.map(_rowToSession));
  }

  Future<ImportedSession> _rowToSession(Map<String, dynamic> row) async {
    final rPeaksPath = row['r_peaks_file_path'] as String?;
    final rPeakIndices = rPeaksPath != null ? _loadRPeaks(rPeaksPath) : <int>[];

    final loJson = jsonDecode(row['lead_off_json'] as String) as List;
    final dcJson = jsonDecode(row['disconnect_json'] as String) as List;

    return ImportedSession(
      id: row['id'] as String,
      sourceFile: row['source_file'] as String,
      importedAt: DateTime.parse(row['recorded_at'] as String),
      skippedPackets: row['skipped_packets'] as int,
      personId: row['person_id'] as String?,
      filePath: row['file_path'] as String?,
      firstSampleTimestampMs: row['first_sample_ts_ms'] as int,
      totalSampleCount: row['sample_count'] as int,
      totalDurationMs: row['duration_ms'] as int,
      rPeakIndices: rPeakIndices,
      leadOffIntervals: loJson
          .map((e) => LeadOffInterval(
              startMs: e['startMs'] as int, endMs: e['endMs'] as int))
          .toList(),
      disconnectIntervals: dcJson
          .map((e) => DisconnectInterval(
              startMs: e['startMs'] as int, endMs: e['endMs'] as int))
          .toList(),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    final db = await _db.db;
    final rows = await db.query('sessions',
        where: 'id = ?', whereArgs: [id], columns: ['file_path', 'hr_file_path', 'r_peaks_file_path']);
    if (rows.isNotEmpty) {
      for (final col in ['file_path', 'hr_file_path', 'r_peaks_file_path']) {
        final path = rows.first[col] as String?;
        if (path != null) {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        }
      }
    }
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<int> _loadRPeaks(String path) {
    final file = File(path);
    if (!file.existsSync()) return [];
    final bytes = file.readAsBytesSync();
    final bd = ByteData.sublistView(bytes);
    return List.generate(bytes.length ~/ 4, (i) => bd.getInt32(i * 4, Endian.little));
  }
}
