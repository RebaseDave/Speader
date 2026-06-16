import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/database/book_dao.dart';
import '../core/database/orp_dao.dart';
import '../core/models/book.dart';
import '../core/models/chapter.dart';
import '../epub/text_tokenizer.dart';
import '../epub/sentence_detector.dart';
import '../epub/orp_seeder.dart';

class TextImporter {
  final BookDao _bookDao;
  final OrpDao _orpDao;

  TextImporter(this._bookDao, this._orpDao);

  Future<Book?> importText(String title, String text, {String? series = '__manuell__'}) async {
    // Text in Datei speichern
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.txt';
    final filePath = p.join(booksDir.path, fileName);
    await File(filePath).writeAsString(text);

    // Text in Absätze aufteilen
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Tokens aufbauen
    final abbreviations = await _orpDao.getAllAbbreviations();
    final detector = SentenceDetector(abbreviations);
    final tokenizer = TextTokenizer(detector);

    final rawTokens = <String>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final words = paragraphs[i]
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty);
      rawTokens.addAll(words);
      if (i < paragraphs.length - 1) {
        rawTokens.add('__PARAGRAPH__');
      }
    }

    final tokens = tokenizer.tokenize(rawTokens, 0);

    // Buch in DB speichern
    final book = Book(
      title: title.trim().isEmpty ? 'Unbenannter Text' : title.trim(),
      filePath: filePath,
      totalWords: tokens.length,
      currentWord: 0,
      currentChapter: 0,
      importedAt: DateTime.now(),
      series: series,
    );

    final bookId = await _bookDao.insertBook(book);

    // Ein einzelnes Kapitel
    await _bookDao.insertChapters([
      Chapter(
        bookId: bookId,
        indexInBook: 0,
        title: title.trim().isEmpty ? 'Text' : title.trim(),
        startWord: 0,
        wordCount: tokens.length,
      ),
    ]);

    // ORP Seeding
    final seeder = OrpSeeder(_orpDao);
    await seeder.seedFromTokens(tokens);

    return book.copyWith(id: bookId);
  }

  /// Statische Hilfsmethode für direkte Nutzung ohne manuelle Dependency-Injection
  static Future<Book?> importFromString({
    required String title,
    required String text,
    String? series,
  }) async {
    final importer = TextImporter(BookDao(), OrpDao());
    return await importer.importText(title, text, series: series);
  }
}
