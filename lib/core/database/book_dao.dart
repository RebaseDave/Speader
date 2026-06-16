import 'package:sqflite/sqflite.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'database_helper.dart';

class BookDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insertBook(Book book) async {
    final db = await _db;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getAllBooks() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT b.* FROM books b
      LEFT JOIN (
        SELECT book_id, MAX(started_at) as last_read
        FROM read_sessions
        GROUP BY book_id
      ) s ON b.id = s.book_id
      WHERE b.is_archived = 0
      ORDER BY COALESCE(s.last_read, b.imported_at) DESC
    ''');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  Future<Book?> getBookById(int id) async {
    final db = await _db;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<void> setSeries(int bookId, String? series) async {
    final db = await _db;
    await db.update(
      'books',
      {'series': series},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> setArchived(int bookId, bool archived) async {
    final db = await _db;
    await db.update(
      'books',
      {'is_archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<Book>> getArchivedBooks() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT b.* FROM books b
      LEFT JOIN (
        SELECT book_id, MAX(started_at) as last_read
        FROM read_sessions
        GROUP BY book_id
      ) s ON b.id = s.book_id
      WHERE b.is_archived = 1
      ORDER BY COALESCE(s.last_read, b.imported_at) DESC
    ''');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  Future<void> updateProgress(int bookId, int currentWord, int currentChapter) async {
    final db = await _db;
    await db.update(
      'books',
      {'current_word': currentWord, 'current_chapter': currentChapter},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteBook(int bookId) async {
    final db = await _db;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
    await db.delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
    await db.delete('token_cache', where: 'book_id = ?', whereArgs: [bookId]);
  }

  Future<void> insertChapters(List<Chapter> chapters) async {
    final db = await _db;
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert('chapters', chapter.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chapter>> getChaptersByBookId(int bookId) async {
    final db = await _db;
    final maps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'index_in_book ASC',
    );
    return maps.map((m) => Chapter.fromMap(m)).toList();
  }
}