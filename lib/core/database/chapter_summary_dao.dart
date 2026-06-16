import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ChapterSummaryDao {
  Future<String?> getSummary(int bookId, int chapterIndex) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'chapter_summaries',
      columns: ['summary'],
      where: 'book_id = ? AND chapter_index = ?',
      whereArgs: [bookId, chapterIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['summary'] as String;
  }

  Future<void> saveSummary(int bookId, int chapterIndex, String summary) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'chapter_summaries',
      {
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'summary': summary,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSummary(int bookId, int chapterIndex) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'chapter_summaries',
      where: 'book_id = ? AND chapter_index = ?',
      whereArgs: [bookId, chapterIndex],
    );
  }

  Future<void> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('chapter_summaries');
  }

  Future<Set<int>> getCachedChapterIndices(int bookId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'chapter_summaries',
      columns: ['chapter_index'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return rows.map((r) => r['chapter_index'] as int).toSet();
  }

  Future<void> deleteForBook(int bookId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'chapter_summaries',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}