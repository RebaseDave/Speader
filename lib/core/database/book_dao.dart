import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
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
      WHERE b.is_archived = 0 AND b.is_deleted = 0
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
      WHERE b.is_archived = 1 AND b.is_deleted = 0
      ORDER BY COALESCE(s.last_read, b.imported_at) DESC
    ''');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  /// Alle Bücher inkl. soft-gelöschter — nur für Backup-Export gedacht,
  /// damit auch gelöschte Bücher ihre Stats-Metadaten mitgeben können.
  Future<List<Book>> getAllBooksForBackup() async {
    final db = await _db;
    final maps = await db.query('books');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  /// Sucht ein soft-gelöschtes Buch anhand des Dateinamens (für Reimport-
  /// Wiedererkennung und Phantom-Buch-Matching beim Backup-Import).
  Future<Book?> getDeletedBookByFileName(String fileName) async {
    final db = await _db;
    final maps = await db.query('books', where: 'is_deleted = 1');
    for (final m in maps) {
      final book = Book.fromMap(m);
      if (p.basename(book.filePath) == fileName) return book;
    }
    return null;
  }

  /// Reaktiviert ein soft-gelöschtes Buch mit frischen Metadaten
  /// (behält die bestehende id, damit Sessions/Summaries weiter passen).
  Future<void> reactivateBook(int id, Book book) async {
    final db = await _db;
    final map = book.toMap()..remove('id');
    map['is_deleted'] = 0;
    await db.update('books', map, where: 'id = ?', whereArgs: [id]);
  }

  /// Legt ein "Phantom"-Buch an: nur Metadaten für die Stats-JOIN-Bedingung,
  /// sofort als gelöscht markiert (keine echte Datei vorhanden).
  Future<int> insertBookDeleted(Book book) async {
    final db = await _db;
    final map = book.toMap()..remove('id');
    map['is_deleted'] = 1;
    return await db.insert('books', map);
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
    // Soft-Delete: Zeile bleibt bestehen, damit Stats (INNER JOIN in
    // session_dao.dart) für immer intakt bleiben, egal ob das Buch je
    // wieder importiert wird.
    await db.update(
      'books',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [bookId],
    );
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