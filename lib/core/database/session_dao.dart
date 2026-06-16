import 'package:sqflite/sqflite.dart';
import '../models/read_session.dart';
import 'database_helper.dart';

class SessionDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const _mergeThresholdSeconds = 300;

  // Filter: nur echte Bücher (≥ 20.000 Wörter, kein Explain/Manual)
  static const _isBookFilter = '''
    INNER JOIN books ON read_sessions.book_id = books.id
    WHERE books.total_words >= 20000
      AND (books.series IS NULL OR books.series NOT IN ('__erklaerung__', '__manuell__'))
  ''';

  Future<void> insertSession(ReadSession session) async {
    if (session.wordsRead < 10) return;
    final db = await _db;

    final recent = await db.query(
      'read_sessions',
      where: 'book_id = ?',
      whereArgs: [session.bookId],
      orderBy: 'started_at DESC',
      limit: 1,
    );

    if (recent.isNotEmpty) {
      final last = ReadSession.fromMap(recent.first);
      final lastEnd = last.startedAt.add(Duration(seconds: last.durationSec));
      final gap = session.startedAt.difference(lastEnd).inSeconds.abs();
      if (gap <= _mergeThresholdSeconds) {
        final merged = ReadSession(
          id: last.id,
          bookId: last.bookId,
          startedAt: last.startedAt,
          durationSec: last.durationSec + session.durationSec,
          wordsRead: last.wordsRead + session.wordsRead,
        );
        await db.update(
          'read_sessions',
          merged.toMap(),
          where: 'id = ?',
          whereArgs: [last.id],
        );
        return;
      }
    }

    await db.insert('read_sessions', session.toMap());
  }

  Future<List<ReadSession>> getSessionsByBookId(int bookId) async {
    final db = await _db;
    final maps = await db.query(
      'read_sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'started_at DESC',
    );
    return maps.map((m) => ReadSession.fromMap(m)).toList();
  }

  Future<void> deleteSession(int sessionId) async {
    final db = await _db;
    await db.delete('read_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<List<ReadSession>> getAllSessions() async {
    final db = await _db;
    final maps = await db.query('read_sessions', orderBy: 'started_at DESC');
    return maps.map((m) => ReadSession.fromMap(m)).toList();
  }

  // ── Gefilterte Stats-Queries (nur isBook) ─────────────────────────────────

  Future<Map<String, int>> getAggregatedStats() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT
        SUM(read_sessions.words_read) as total_words,
        SUM(read_sessions.duration_sec) as total_seconds
      FROM read_sessions
      $_isBookFilter
    ''');
    return {
      'total_words': (result.first['total_words'] as int?) ?? 0,
      'total_seconds': (result.first['total_seconds'] as int?) ?? 0,
    };
  }

  Future<List<ReadSession>> getCurrentWeekSessions() async {
    final db = await _db;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);

    final maps = await db.rawQuery('''
      SELECT read_sessions.*
      FROM read_sessions
      $_isBookFilter
        AND read_sessions.started_at >= ?
      ORDER BY read_sessions.started_at DESC
    ''', [mondayStart.toIso8601String()]);
    return maps.map((m) => ReadSession.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getPastWeeksSummaries() async {
    final db = await _db;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);

    return await db.rawQuery('''
      SELECT
        date(read_sessions.started_at, 'weekday 0', '-6 days') as week_monday,
        SUM(read_sessions.words_read) as total_words,
        SUM(read_sessions.duration_sec) as total_seconds,
        date(read_sessions.started_at, 'weekday 0', '-6 days') as week_num
      FROM read_sessions
      $_isBookFilter
        AND read_sessions.started_at < ?
      GROUP BY week_num
      ORDER BY week_monday DESC
    ''', [mondayStart.toIso8601String()]);
  }

  Future<List<ReadSession>> getTodaySessions() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final maps = await db.rawQuery('''
      SELECT read_sessions.*
      FROM read_sessions
      $_isBookFilter
        AND read_sessions.started_at >= ?
      ORDER BY read_sessions.started_at DESC
    ''', [todayStart.toIso8601String()]);
    return maps.map((m) => ReadSession.fromMap(m)).toList();
  }

  Future<Map<int, int>> getTotalDurationPerBook() async {
    // Kein isBook-Filter: zeigt Zeit für alle Buch-Typen in der Library
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT book_id, SUM(duration_sec) as total_seconds
      FROM read_sessions
      GROUP BY book_id
    ''');
    return {
      for (final row in result)
        row['book_id'] as int: (row['total_seconds'] as int?) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getWeeklyWpmHistory({int weeks = 8}) async {
    final db = await _db;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final cutoff = DateTime(monday.year, monday.month, monday.day)
        .subtract(Duration(days: (weeks - 1) * 7));

    return await db.rawQuery('''
      SELECT
        date(read_sessions.started_at, 'weekday 0', '-6 days') as week_monday,
        SUM(read_sessions.words_read) as total_words,
        SUM(read_sessions.duration_sec) as total_seconds
      FROM read_sessions
      $_isBookFilter
        AND read_sessions.started_at >= ?
      GROUP BY week_monday
      ORDER BY week_monday ASC
    ''', [cutoff.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getDailyWordCounts({int days = 365}) async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(Duration(days: days));

    return await db.rawQuery('''
      SELECT
        date(read_sessions.started_at) as day,
        SUM(read_sessions.words_read) as total_words
      FROM read_sessions
      $_isBookFilter
        AND read_sessions.started_at >= ?
      GROUP BY day
      ORDER BY day ASC
    ''', [cutoff.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getHourlyWordCounts() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT
        strftime('%H', read_sessions.started_at) as hour,
        SUM(read_sessions.words_read) as total_words
      FROM read_sessions
      $_isBookFilter
      GROUP BY hour
      ORDER BY hour ASC
    ''');
  }

  Future<ReadSession?> getLongestSession() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT read_sessions.*
      FROM read_sessions
      $_isBookFilter
      ORDER BY read_sessions.words_read DESC
      LIMIT 1
    ''');
    if (maps.isEmpty) return null;
    return ReadSession.fromMap(maps.first);
  }

  Future<int> getBestStreak() async {
    final maps = await getDailyWordCounts(days: 3650);
    if (maps.isEmpty) return 0;

    final goalDays = <String>{};
    for (final row in maps) {
      if ((row['total_words'] as int? ?? 0) >= 5000) {
        goalDays.add(row['day'] as String);
      }
    }

    int best = 0;
    int current = 0;
    final now = DateTime.now();
    DateTime cursor = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 3650; i++) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (goalDays.contains(key)) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return best;
  }

  // Kein isBook-Filter: WPM-Kalibrierung nutzt alle Lesedaten
  Future<({double wpm, int count})?> getHistoricalWpm({int limit = 10}) async {
    final db = await _db;
    final maps = await db.query(
      'read_sessions',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    if (maps.isEmpty) return null;
    final sessions = maps.map((m) => ReadSession.fromMap(m)).toList();
    final totalWords = sessions.fold<int>(0, (sum, s) => sum + s.wordsRead);
    final totalSec = sessions.fold<int>(0, (sum, s) => sum + s.durationSec);
    if (totalSec == 0) return null;
    return (wpm: totalWords / totalSec * 60, count: sessions.length);
  }

  Future<({double wpm, int count})?> getHistoricalWpmForBook(
    int bookId, {
    int limit = 10,
  }) async {
    final db = await _db;
    final maps = await db.query(
      'read_sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    if (maps.isEmpty) return null;
    final sessions = maps.map((m) => ReadSession.fromMap(m)).toList();
    final totalWords = sessions.fold<int>(0, (sum, s) => sum + s.wordsRead);
    final totalSec = sessions.fold<int>(0, (sum, s) => sum + s.durationSec);
    if (totalSec == 0) return null;
    return (wpm: totalWords / totalSec * 60, count: sessions.length);
  }

  Future<List<Map<String, dynamic>>> getPastDaysThisWeek() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);

    return await db.rawQuery('''
      SELECT
        date(read_sessions.started_at) as day,
        MIN(read_sessions.started_at) as day_start,
        SUM(read_sessions.words_read) as total_words,
        SUM(read_sessions.duration_sec) as total_seconds
      FROM read_sessions
      $_isBookFilter
        AND read_sessions.started_at >= ?
        AND read_sessions.started_at < ?
      GROUP BY day
      ORDER BY day DESC
    ''', [mondayStart.toIso8601String(), todayStart.toIso8601String()]);
  }
}