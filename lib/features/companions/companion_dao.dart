import '../../core/database/database_helper.dart';
import 'companion.dart';

class CompanionDao {
  Future<List<Companion>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('companions', orderBy: 'slot ASC');
    return maps.map(Companion.fromMap).toList();
  }

  Future<Companion?> getActive() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'companions',
      where: 'is_active = 1',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Companion.fromMap(maps.first);
  }

  Future<void> addXp(int slot, int xp) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate('''
      UPDATE companions
      SET current_xp = current_xp + ?
      WHERE slot = ?
    ''', [xp, slot]);
  }

  Future<void> removeXp(int slot, int xp) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate('''
      UPDATE companions
      SET current_xp = MAX(0, current_xp - ?)
      WHERE slot = ?
    ''', [xp, slot]);
  }

  Future<void> unlock(int slot) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'companions',
      {'is_unlocked': 1},
      where: 'slot = ?',
      whereArgs: [slot],
    );
  }

  Future<void> setActive(int slot) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update('companions', {'is_active': 0});
      await txn.update(
        'companions',
        {'is_active': 1},
        where: 'slot = ?',
        whereArgs: [slot],
      );
    });
  }

  Future<Companion?> getBySlot(int slot) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'companions',
      where: 'slot = ?',
      whereArgs: [slot],
    );
    if (maps.isEmpty) return null;
    return Companion.fromMap(maps.first);
  }
}