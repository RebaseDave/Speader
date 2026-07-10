import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'book_dao.dart';
import 'orp_dao.dart';
import 'session_dao.dart';
import '../models/book.dart';
import '../models/read_session.dart';
import '../services/settings_service.dart';
import '../../features/companions/companion_dao.dart';

class BackupResult {
  final int sessionsImported;
  final int phantomBooksCreated;
  final int companionsMerged;
  final int abbreviationsMerged;
  final List<String> errors;

  const BackupResult({
    this.sessionsImported = 0,
    this.phantomBooksCreated = 0,
    this.companionsMerged = 0,
    this.abbreviationsMerged = 0,
    this.errors = const [],
  });
}

class BackupService {
  final BookDao _bookDao = BookDao();
  final SessionDao _sessionDao = SessionDao();
  final CompanionDao _companionDao = CompanionDao();
  final OrpDao _orpDao = OrpDao();

  // ── EXPORT ──────────────────────────────────────────────────────────

  Future<void> exportBackup() async {
    // Buch-Metadaten (auch soft-gelöschte!) — nur was die Stats-JOIN-
    // Bedingung braucht, keine EPUB-Bytes.
    final books = await _bookDao.getAllBooksForBackup();
    final booksJson = books
        .where((b) => b.id != null)
        .map((b) => {
              'old_id': b.id,
              'file_name': p.basename(b.filePath),
              'title': b.title,
              'author': b.author,
              'total_words': b.totalWords,
              'series': b.series,
            })
        .toList();

    final sessions = await _sessionDao.getAllSessions();
    final sessionsJson = sessions
        .map((s) => {
              'old_book_id': s.bookId,
              'started_at': s.startedAt.toIso8601String(),
              'duration_sec': s.durationSec,
              'words_read': s.wordsRead,
              'mode': s.mode,
            })
        .toList();

    final companions = await _companionDao.getAll();

    final data = {
      'version': 3,
      'created_at': DateTime.now().toIso8601String(),
      'books': booksJson,
      'sessions': sessionsJson,
      'companions': companions.map((c) => c.toMap()).toList(),
      'abbreviations': await _orpDao.getAllAbbreviations(),
      'settings': SettingsService.instance.exportRaw(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      'speader_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await File(path).writeAsString(jsonStr);

    await Share.shareXFiles([XFile(path)], text: 'Speader Backup');
  }

  // ── IMPORT ──────────────────────────────────────────────────────────

  Future<BackupResult?> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final content = await File(result.files.single.path!).readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    // Settings wiederherstellen (überschreibt bestehende Werte)
    final settingsMap = data['settings'] as Map<String, dynamic>? ?? {};
    await SettingsService.instance.importRaw(settingsMap);

    // Bücher: vorhandene per Dateiname matchen (auch soft-gelöschte),
    // sonst Phantom-Buch anlegen (nur Metadaten, sofort als gelöscht markiert).
    final booksJson = List<Map<String, dynamic>>.from(
        (data['books'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));

    final existingAll = await _bookDao.getAllBooksForBackup();
    final existingByFileName = {
      for (final b in existingAll) p.basename(b.filePath): b,
    };

    final bookIdMap = <int, int>{};
    int phantomBooksCreated = 0;
    final errors = <String>[];

    for (final entry in booksJson) {
      final oldId = entry['old_id'] as int?;
      final fileName = entry['file_name'] as String;

      final existing = existingByFileName[fileName];
      if (existing != null && existing.id != null) {
        if (oldId != null) bookIdMap[oldId] = existing.id!;
        continue;
      }

      try {
        final phantom = Book(
          title: entry['title'] as String? ?? fileName,
          author: entry['author'] as String?,
          filePath: p.join('__phantom__', fileName),
          totalWords: entry['total_words'] as int? ?? 0,
          currentWord: 0,
          currentChapter: 0,
          importedAt: DateTime.now(),
          series: entry['series'] as String?,
        );
        final newId = await _bookDao.insertBookDeleted(phantom);
        if (oldId != null) bookIdMap[oldId] = newId;
        phantomBooksCreated++;
      } catch (e) {
        errors.add('Phantom-Buch für $fileName: $e');
      }
    }

    // Sessions mergen (Dedupe über exakten Abgleich, kein Merge-Threshold)
    int sessionsImported = 0;
    final sessionsJson = List<Map<String, dynamic>>.from(
        (data['sessions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
    for (final entry in sessionsJson) {
      final oldBookId = entry['old_book_id'] as int;
      final newBookId = bookIdMap[oldBookId];
      if (newBookId == null) continue;

      final startedAt = DateTime.parse(entry['started_at'] as String);
      final durationSec = entry['duration_sec'] as int;
      final wordsRead = entry['words_read'] as int;

      final exists = await _sessionDao.sessionExists(
          newBookId, startedAt, durationSec, wordsRead);
      if (exists) continue;

      await _sessionDao.insertSessionRaw(ReadSession(
        bookId: newBookId,
        startedAt: startedAt,
        durationSec: durationSec,
        wordsRead: wordsRead,
        mode: entry['mode'] as String? ?? 'rsvp',
      ));
      sessionsImported++;
    }

    // Companions mergen: höherer XP-Stand gewinnt, Unlock wird vereinigt
    int companionsMerged = 0;
    final companionsJson = List<Map<String, dynamic>>.from(
        (data['companions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
    for (final entry in companionsJson) {
      final slot = entry['slot'] as int;
      final backupXp = entry['current_xp'] as int;
      final backupUnlocked = (entry['is_unlocked'] as int) == 1;
      final local = await _companionDao.getBySlot(slot);
      if (local == null) continue;
      var changed = false;
      if (backupXp > local.currentXp) {
        await _companionDao.addXp(slot, backupXp - local.currentXp);
        changed = true;
      }
      if (backupUnlocked && !local.isUnlocked) {
        await _companionDao.unlock(slot);
        changed = true;
      }
      if (changed) companionsMerged++;
    }

    // Abbreviations mergen (Duplikate werden vom DAO ignoriert)
    final existingAbbr = (await _orpDao.getAllAbbreviations()).toSet();
    final abbreviations =
        List<String>.from(data['abbreviations'] as List? ?? []);
    int abbreviationsMerged = 0;
    for (final abbr in abbreviations) {
      if (!existingAbbr.contains(abbr)) abbreviationsMerged++;
      await _orpDao.insertAbbreviation(abbr);
    }

    return BackupResult(
      sessionsImported: sessionsImported,
      phantomBooksCreated: phantomBooksCreated,
      companionsMerged: companionsMerged,
      abbreviationsMerged: abbreviationsMerged,
      errors: errors,
    );
  }
}