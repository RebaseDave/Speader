import 'package:sqflite/sqflite.dart';
import '../models/orp_entry.dart';
import 'database_helper.dart';

class OrpDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> insertEntries(List<OrpEntry> entries) async {
    final db = await _db;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'orp_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<OrpEntry?> getEntry(String word) async {
    final db = await _db;
    final maps = await db.query(
      'orp_entries',
      where: 'word = ?',
      whereArgs: [word.toLowerCase()],
    );
    if (maps.isEmpty) return null;
    return OrpEntry.fromMap(maps.first);
  }

  Future<void> updateEntry(OrpEntry entry) async {
    final db = await _db;
    await db.update(
      'orp_entries',
      entry.toMap(),
      where: 'word = ?',
      whereArgs: [entry.word],
    );
  }

  Future<List<OrpEntry>> searchEntries(String query) async {
    final db = await _db;
    final maps = await db.query(
      'orp_entries',
      where: 'word LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%'],
      orderBy: 'word ASC',
      limit: 100,
    );
    return maps.map((m) => OrpEntry.fromMap(m)).toList();
  }

  Future<List<OrpEntry>> getAllEntries() async {
    final db = await _db;
    final maps = await db.query('orp_entries', orderBy: 'word ASC');
    return maps.map((m) => OrpEntry.fromMap(m)).toList();
  }

  Future<void> replaceAllEntries(List<OrpEntry> entries) async {
    final db = await _db;
    await db.delete('orp_entries');
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('orp_entries', entry.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getAllAbbreviations() async {
    final db = await _db;
    final maps = await db.query('abbreviations');
    return maps.map((m) => m['abbreviation'] as String).toList();
  }

  Future<void> insertAbbreviation(String abbreviation) async {
    final db = await _db;
    await db.insert(
      'abbreviations',
      {'abbreviation': abbreviation},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteAbbreviation(String abbreviation) async {
    final db = await _db;
    await db.delete(
      'abbreviations',
      where: 'abbreviation = ?',
      whereArgs: [abbreviation],
    );
  }

  Future<void> clearOrpEntries() async {
    final db = await _db;
    await db.delete('orp_entries');
  }
}