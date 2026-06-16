import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/database/book_dao.dart';
import '../core/database/orp_dao.dart';
import '../core/models/book.dart';
import '../core/models/chapter.dart';
import 'epub_parser.dart';
import 'text_tokenizer.dart';
import 'sentence_detector.dart';
import 'orp_seeder.dart';
import '../core/models/word_token.dart';

class EpubImporter {
  final BookDao _bookDao;
  final OrpDao _orpDao;

  EpubImporter(this._bookDao, this._orpDao);

  Future<Book?> importEpub() async {
    // Datei auswählen
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null || result.files.single.path == null) return null;
    final sourcePath = result.files.single.path!;

    // Lokal speichern
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final fileName = p.basename(sourcePath);
    final destPath = p.join(booksDir.path, fileName);
    await File(sourcePath).copy(destPath);

    // EPUB parsen
    final parser = EpubParser();
    final parsed = await parser.parse(destPath);

    // Tokens + Kapitel aufbauen
    final abbreviations = await _orpDao.getAllAbbreviations();
    final detector = SentenceDetector(abbreviations);
    final tokenizer = TextTokenizer(detector);

    final allTokens = <WordToken>[];
    final chapters = <Chapter>[];
    int wordIndex = 0;

    for (final parsedChapter in parsed.chapters) {
      final tokens = tokenizer.tokenize(
        parsedChapter.rawTokens,
        parsedChapter.indexInBook,
      );
      final startWord = wordIndex;
      wordIndex += tokens.length;

      chapters.add(
        Chapter(
          bookId: 0, // wird nach insert gesetzt
          indexInBook: parsedChapter.indexInBook,
          title: parsedChapter.title,
          startWord: startWord,
          wordCount: tokens.length,
        ),
      );

      allTokens.addAll(tokens);
    }

    // Buch in DB speichern
    final book = Book(
      title: parsed.title,
      filePath: destPath,
      totalWords: allTokens.length,
      currentWord: 0,
      currentChapter: 0,
      importedAt: DateTime.now(),
    );

    final bookId = await _bookDao.insertBook(book);

    // Kapitel mit bookId speichern
    final chaptersWithId = chapters
        .map(
          (c) => Chapter(
            bookId: bookId,
            indexInBook: c.indexInBook,
            title: c.title,
            startWord: c.startWord,
            wordCount: c.wordCount,
          ),
        )
        .toList();
    await _bookDao.insertChapters(chaptersWithId);

    // ORP Seeding
    final seeder = OrpSeeder(_orpDao);
    await seeder.seedFromTokens(allTokens);

    return book.copyWith(id: bookId);
  }

  Future<Book?> importEpubFromPath(String sourcePath) async {
    // Lokal speichern
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'books'));
    if (!await booksDir.exists()) await booksDir.create(recursive: true);

    final fileName = p.basename(sourcePath);
    final destPath = p.join(booksDir.path, fileName);
    await File(sourcePath).copy(destPath);

    // EPUB parsen
    final parser = EpubParser();
    final parsed = await parser.parse(destPath);

    // Tokens + Kapitel aufbauen
    final abbreviations = await _orpDao.getAllAbbreviations();
    final detector = SentenceDetector(abbreviations);
    final tokenizer = TextTokenizer(detector);

    final allTokens = <WordToken>[];
    final chapters = <Chapter>[];
    int wordIndex = 0;

    for (final parsedChapter in parsed.chapters) {
      final tokens = tokenizer.tokenize(
        parsedChapter.rawTokens,
        parsedChapter.indexInBook,
      );
      final startWord = wordIndex;
      wordIndex += tokens.length;

      chapters.add(
        Chapter(
          bookId: 0,
          indexInBook: parsedChapter.indexInBook,
          title: parsedChapter.title,
          startWord: startWord,
          wordCount: tokens.length,
        ),
      );

      allTokens.addAll(tokens);
    }

    // Buch in DB speichern
    final book = Book(
      title: parsed.title,
      filePath: destPath,
      totalWords: allTokens.length,
      currentWord: 0,
      currentChapter: 0,
      importedAt: DateTime.now(),
    );

    final bookId = await _bookDao.insertBook(book);

    final chaptersWithId = chapters
        .map(
          (c) => Chapter(
            bookId: bookId,
            indexInBook: c.indexInBook,
            title: c.title,
            startWord: c.startWord,
            wordCount: c.wordCount,
          ),
        )
        .toList();
    await _bookDao.insertChapters(chaptersWithId);

    final seeder = OrpSeeder(_orpDao);
    await seeder.seedFromTokens(allTokens);

    return book.copyWith(id: bookId);
  }
}
