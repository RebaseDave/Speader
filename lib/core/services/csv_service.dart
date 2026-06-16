import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../database/orp_dao.dart';
import '../models/orp_entry.dart';
import '../database/token_cache_dao.dart';

class CsvService {
  final OrpDao _orpDao;

  CsvService(this._orpDao);

  Future<Directory> get _downloadsDir async {
    final dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _requestPermission() async {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  // ── ORP Export ──────────────────────────────────────────────
  Future<String?> exportOrpCsv() async {
    try {
      await _requestPermission();
      final entries = await _orpDao.getAllEntries();

      final rows = [
        ['word', 'orp_index', 'is_manual'],
        ...entries.map((e) => [e.word, e.orpIndex, e.isManual ? 1 : 0]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await _downloadsDir;
      final path = p.join(dir.path, 'orp_database.csv');
      await File(path).writeAsString(csv);
      return path;
    } catch (e) {
      return null;
    }
  }

  // ── ORP Import ──────────────────────────────────────────────
  Future<bool> importOrpCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return false;

      final content = await File(result.files.single.path!).readAsString();
      final rows = const CsvToListConverter().convert(content);
      if (rows.length < 2) return false;

      final entries = rows.skip(1).map((row) {
        return OrpEntry(
          word: row[0].toString(),
          orpIndex: int.tryParse(row[1].toString()) ?? 0,
          isManual: row[2].toString() == '1',
        );
      }).toList();

      await _orpDao.replaceAllEntries(entries);
      await TokenCacheDao().deleteAllCaches();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Abbreviations Export ─────────────────────────────────────
  Future<String?> exportAbbreviationsCsv() async {
    try {
      await _requestPermission();
      final abbreviations = await _orpDao.getAllAbbreviations();

      final rows = [
        ['abbreviation'],
        ...abbreviations.map((a) => [a]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await _downloadsDir;
      final path = p.join(dir.path, 'abbreviations.csv');
      await File(path).writeAsString(csv);
      return path;
    } catch (e) {
      return null;
    }
  }

  // ── Abbreviations Import ─────────────────────────────────────
  Future<bool> importAbbreviationsCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return false;

      final content = await File(result.files.single.path!).readAsString();
      final rows = const CsvToListConverter().convert(content);
      if (rows.length < 2) return false;

      // Alle bestehenden löschen und neu einfügen
      final existing = await _orpDao.getAllAbbreviations();
      for (final a in existing) {
        await _orpDao.deleteAbbreviation(a);
      }

      for (final row in rows.skip(1)) {
        final abbr = row[0].toString().trim();
        if (abbr.isNotEmpty) {
          await _orpDao.insertAbbreviation(abbr);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}