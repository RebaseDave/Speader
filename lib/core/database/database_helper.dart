import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../features/companions/companion_definition.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rsvp_reader.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        title           TEXT NOT NULL,
        file_path       TEXT NOT NULL,
        total_words     INTEGER NOT NULL,
        current_word    INTEGER NOT NULL DEFAULT 0,
        current_chapter INTEGER NOT NULL DEFAULT 0,
        imported_at     TEXT NOT NULL,
        is_archived     INTEGER NOT NULL DEFAULT 0,
        series          TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id        INTEGER NOT NULL,
        index_in_book  INTEGER NOT NULL,
        title          TEXT,
        start_word     INTEGER NOT NULL,
        word_count     INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orp_entries (
        word         TEXT PRIMARY KEY,
        orp_index    INTEGER NOT NULL,
        is_manual    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE token_cache (
        book_id          INTEGER NOT NULL,
        word_index       INTEGER NOT NULL,
        raw              TEXT NOT NULL,
        normalized       TEXT NOT NULL,
        orp_index        INTEGER NOT NULL,
        is_sentence_end  INTEGER NOT NULL DEFAULT 0,
        is_comma_end     INTEGER NOT NULL DEFAULT 0,
        is_dash_end      INTEGER NOT NULL DEFAULT 0,
        is_paragraph_end INTEGER NOT NULL DEFAULT 0,
        is_chapter_title INTEGER NOT NULL DEFAULT 0,
        chapter_index    INTEGER NOT NULL,
        PRIMARY KEY (book_id, word_index)
      )
    ''');

    await db.execute('''
      CREATE TABLE abbreviations (
        abbreviation TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE chapter_summaries (
        book_id       INTEGER NOT NULL,
        chapter_index INTEGER NOT NULL,
        summary       TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        PRIMARY KEY (book_id, chapter_index)
      )
    ''');

    await db.execute('''
      CREATE TABLE read_sessions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id      INTEGER NOT NULL,
        started_at   TEXT NOT NULL,
        duration_sec INTEGER NOT NULL,
        words_read   INTEGER NOT NULL,
        mode         TEXT NOT NULL DEFAULT 'rsvp',
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE companions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        slot         INTEGER NOT NULL UNIQUE,
        current_xp   INTEGER NOT NULL DEFAULT 0,
        is_unlocked  INTEGER NOT NULL DEFAULT 0,
        is_active    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _insertDefaultCompanions(db);
    await _insertDefaultAbbreviations(db);
  }

  Future<void> seedMissingAbbreviations() async {
    final db = await database;
    await _insertDefaultAbbreviations(db);
  }

  Future<void> _insertDefaultAbbreviations(Database db) async {
    const abbreviations = [
      // Deutsche Titel & Anreden
      'Dr.',
      'Prof.',
      'Hr.',
      'Fr.',
      'Ing.',
      'Dipl.',
      'Mag.',
      'Dir.',
      'Doz.',
      // Englische Titel & Anreden
      'Mr.',
      'Mrs.',
      'Ms.',
      'Jr.',
      'Sr.',
      'Rev.',
      'Gov.',
      'Sen.',
      'Rep.',
      'Pres.',
      'St.',
      // Militär
      'Lt.',
      'Sgt.',
      'Capt.',
      'Gen.',
      'Col.',
      'Maj.',
      'Pvt.',
      'Cpl.',
      'Adm.',
      // Deutsche Abkürzungen
      'bzw.',
      'usw.',
      'etc.',
      'ca.',
      'z.B.',
      'd.h.',
      'u.a.',
      'o.ä.',
      'u.ä.',
      'u.U.',
      'z.T.',
      'i.d.R.',
      'o.g.',
      'n.Chr.',
      'v.Chr.',
      'ggf.',
      'evtl.',
      'inkl.',
      'exkl.',
      'bzgl.',
      'vgl.',
      'ebd.',
      'lt.',
      'sog.',
      'mind.',
      'max.',
      'min.',
      'vs.',
      // Maße & Einheiten
      'Nr.',
      'Str.',
      'Tel.',
      'Std.',
      'Sek.',
      'Min.',
      'Mio.',
      'Mrd.',
      // Wissenschaft & Literatur
      'Hrsg.',
      'Aufl.',
      'Bd.',
      'Jh.',
      'Abs.',
      'Art.',
      'Kap.',
      // Englisch allgemein
      'No.',
      'Vol.',
      'i.e.',
      'e.g.',
      // Monate
      'Jan.',
      'Feb.',
      'Mär.',
      'Apr.',
      'Jun.',
      'Jul.',
      'Aug.',
      'Sep.',
      'Okt.',
      'Nov.',
      'Dez.',
      '...',
    ];
    final batch = db.batch();
    for (final abbr in abbreviations) {
      batch.insert(
        'abbreviations',
        {'abbreviation': abbr},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _insertDefaultCompanions(Database db) async {
    final batch = db.batch();
    for (final def in CompanionDefinition.all) {
      batch.insert('companions', {
        'slot': def.slot,
        'current_xp': 0,
        'is_unlocked': def.slot == 1 ? 1 : 0,
        'is_active': def.slot == 1 ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }
}
