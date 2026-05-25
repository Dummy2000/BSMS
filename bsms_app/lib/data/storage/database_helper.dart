import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _dbName = 'bsms.db';
  static const _dbVersion = 1;

  static Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(dbPath, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE persons (
        id   TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age  INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT ""
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id                      TEXT PRIMARY KEY,
        person_id               TEXT,
        source_file             TEXT NOT NULL,
        recorded_at             TEXT NOT NULL,
        duration_ms             INTEGER NOT NULL DEFAULT 0,
        sample_count            INTEGER NOT NULL DEFAULT 0,
        skipped_packets         INTEGER NOT NULL DEFAULT 0,
        file_path               TEXT,
        hr_file_path            TEXT,
        r_peaks_file_path       TEXT,
        first_sample_ts_ms      INTEGER NOT NULL DEFAULT 0,
        lead_off_json           TEXT NOT NULL DEFAULT "[]",
        disconnect_json         TEXT NOT NULL DEFAULT "[]",
        FOREIGN KEY (person_id) REFERENCES persons (id) ON DELETE SET NULL
      )
    ''');
  }
}
