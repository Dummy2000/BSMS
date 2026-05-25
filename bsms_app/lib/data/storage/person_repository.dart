import 'package:sqflite/sqflite.dart';
import '../../domain/models/person.dart';
import 'database_helper.dart';

class PersonRepository {
  final DatabaseHelper _db;

  PersonRepository(this._db);

  Future<List<Person>> getAll() async {
    final db = await _db.db;
    final rows = await db.query('persons', orderBy: 'name ASC');
    return rows.map(Person.fromMap).toList();
  }

  Future<Person?> getById(String id) async {
    final db = await _db.db;
    final rows = await db.query('persons', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Person.fromMap(rows.first);
  }

  Future<void> insert(Person person) async {
    final db = await _db.db;
    await db.insert('persons', person.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Person person) async {
    final db = await _db.db;
    await db.update('persons', person.toMap(),
        where: 'id = ?', whereArgs: [person.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.db;
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }
}
