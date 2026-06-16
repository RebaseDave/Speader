import 'package:sqflite/sqflite.dart';
import '../models/word_token.dart';
import 'database_helper.dart';

class TokenCacheDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<bool> hasCache(int bookId) async {
    final db = await _db;
    final result = await db.query(
      'token_cache',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<WordToken>> loadCache(int bookId) async {
    final db = await _db;
    final maps = await db.query(
      'token_cache',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'word_index ASC',
    );

    return maps.map((m) => WordToken(
      raw: m['raw'] as String,
      normalized: m['normalized'] as String,
      orpIndex: m['orp_index'] as int,
      isSentenceEnd: (m['is_sentence_end'] as int) == 1,
      isCommaEnd: (m['is_comma_end'] as int) == 1,
      isDashEnd: (m['is_dash_end'] as int) == 1,
      isParagraphEnd: (m['is_paragraph_end'] as int) == 1,
      isChapterTitle: (m['is_chapter_title'] as int) == 1,
      chapterIndex: m['chapter_index'] as int,
    )).toList();
  }

  Future<void> saveCache(int bookId, List<WordToken> tokens) async {
    final db = await _db;
    final batch = db.batch();

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      batch.insert(
        'token_cache',
        {
          'book_id': bookId,
          'word_index': i,
          'raw': token.raw,
          'normalized': token.normalized,
          'orp_index': token.orpIndex,
          'is_sentence_end': token.isSentenceEnd ? 1 : 0,
          'is_comma_end': token.isCommaEnd ? 1 : 0,
          'is_dash_end': token.isDashEnd ? 1 : 0,
          'is_paragraph_end': token.isParagraphEnd ? 1 : 0,
          'is_chapter_title': token.isChapterTitle ? 1 : 0,
          'chapter_index': token.chapterIndex,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> deleteAllCaches() async {
    final db = await _db;
    await db.delete('token_cache');
  }

  Future<void> deleteCache(int bookId) async {
    final db = await _db;
    await db.delete(
      'token_cache',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}