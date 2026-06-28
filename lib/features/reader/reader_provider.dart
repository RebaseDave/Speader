import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/session_dao.dart';
import '../../core/models/book.dart';
import '../../core/models/word_token.dart';
import '../../core/models/chapter.dart';
import '../../core/services/settings_service.dart';
import '../../epub/epub_parser.dart';
import '../../epub/text_tokenizer.dart';
import '../../epub/sentence_detector.dart';
import '../../rsvp/rsvp_engine.dart';
import '../../features/library/library_provider.dart';
import '../../rsvp/orp_calculator.dart';
import '../../core/database/token_cache_dao.dart';
import '../../epub/orp_seeder.dart';
import '../../features/orp_editor/orp_editor_provider.dart';
import '../../core/database/book_dao.dart';
import '../library/archive_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/models/read_session.dart';
import '../companions/companion_provider.dart';

final sessionDaoProvider = Provider<SessionDao>((ref) => SessionDao());

class ParagraphData {
  final String pre;
  final String current;
  final String post;
  final int orpIndex;
  final String? chapterTitle;
  final bool isTitlePage;
  final bool isImagePage;
  final String imageKey;
  final List<String> sentences;

  const ParagraphData({
    required this.pre,
    required this.current,
    required this.post,
    required this.orpIndex,
    this.chapterTitle,
    this.isTitlePage = false,
    this.isImagePage = false,
    this.imageKey = '',
    this.sentences = const [],
  });
}

class ReaderState {
  final Book? book;
  final List<WordToken> tokens;
  final List<Chapter> chapters;
  final int currentIndex;
  final RsvpState rsvpState;
  final bool isLoading;
  final String? error;
  final String imageBasePath;

  const ReaderState({
    this.book,
    this.tokens = const [],
    this.chapters = const [],
    this.currentIndex = 0,
    this.rsvpState = RsvpState.idle,
    this.isLoading = false,
    this.error,
    this.imageBasePath = '',
  });

  double get progressPercent =>
      tokens.isEmpty ? 0 : currentIndex / tokens.length;

  ReaderState copyWith({
    Book? book,
    List<WordToken>? tokens,
    List<Chapter>? chapters,
    int? currentIndex,
    RsvpState? rsvpState,
    bool? isLoading,
    String? error,
    String? imageBasePath,
  }) {
    return ReaderState(
      book: book ?? this.book,
      tokens: tokens ?? this.tokens,
      chapters: chapters ?? this.chapters,
      currentIndex: currentIndex ?? this.currentIndex,
      rsvpState: rsvpState ?? this.rsvpState,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      imageBasePath: imageBasePath ?? this.imageBasePath,
    );
  }
}

class ReaderNotifier extends Notifier<ReaderState> {
  late RsvpEngine _engine;
  int _paragraphWordsAccumulated = 0;

  @override
  ReaderState build() {
    _engine = RsvpEngine(
      SettingsService.instance,
      ref.read(bookDaoProvider),
      ref.read(sessionDaoProvider),
    );

    _engine.onStateChange = (rsvpState) {
      state = state.copyWith(rsvpState: rsvpState);
    };

    _engine.onWord = (token, index) {
      state = state.copyWith(currentIndex: index);
    };

    _engine.onSessionSaved = (words) {
      ref.read(companionProvider.notifier).addXpForSession(words);
    };

    ref.onDispose(() => _engine.dispose());
    return const ReaderState();
  }

  Future<void> loadBook(Book book) async {
    state = state.copyWith(isLoading: true);
    _paragraphWordsAccumulated = 0;

    try {
      final orpDao = ref.read(orpDaoProvider);
      final bookDao = ref.read(bookDaoProvider);
      final tokenCacheDao = TokenCacheDao();

      List<WordToken> enrichedTokens;
      var parsedImages = <String, List<int>>{};

      // Cache prüfen
      if (await tokenCacheDao.hasCache(book.id!)) {
        enrichedTokens = await tokenCacheDao.loadCache(book.id!);
      } else {
        final abbreviations = await orpDao.getAllAbbreviations();
        final detector = SentenceDetector(abbreviations);
        final tokenizer = TextTokenizer(detector);

        final allTokens = <WordToken>[];

        if (book.filePath.endsWith('.txt')) {
          final text = await File(book.filePath).readAsString();
          final paragraphs = text
              .split(RegExp(r'\n\s*\n'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();

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
          allTokens.addAll(tokenizer.tokenize(rawTokens, 0));
        } else {
          final parser = EpubParser();
          final parsed = await parser.parse(book.filePath);
          parsedImages = parsed.images;
          for (final chapter in parsed.chapters) {
            final tokens = tokenizer.tokenize(
              chapter.rawTokens,
              chapter.indexInBook,
            );
            allTokens.addAll(tokens);
          }
        }

        // ORP-Werte anwenden
        final allEntries = await orpDao.getAllEntries();
        final orpMap = {for (final e in allEntries) e.word: e.orpIndex};

        enrichedTokens = allTokens.map((token) {
          if (token.isChapterTitle) return token;
          if (token.isImage) return token;
          final dbOrpIndex =
              orpMap[token.normalized] ??
              OrpCalculator.calculate(token.normalized);
          final orpIndex = OrpCalculator.rawIndex(
            token.raw,
            token.normalized,
            dbOrpIndex,
          );
          return WordToken(
            raw: token.raw,
            normalized: token.normalized,
            orpIndex: orpIndex,
            isSentenceEnd: token.isSentenceEnd,
            isCommaEnd: token.isCommaEnd,
            isParagraphEnd: token.isParagraphEnd,
            isDashEnd: token.isDashEnd,
            isChapterTitle: token.isChapterTitle,
            chapterIndex: token.chapterIndex,
          );
        }).toList();

        final seeder = OrpSeeder(orpDao);
        await seeder.seedFromTokens(enrichedTokens);
        ref.invalidate(orpEditorProvider);

        await tokenCacheDao.saveCache(book.id!, enrichedTokens);
      }

      // Bilder auf Disk sichern
      String imageBasePath = '';
      if (!book.filePath.endsWith('.txt')) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${appDocDir.path}/book_images/${book.id}');
        imageBasePath = imageDir.path;

        final hasImageTokens = enrichedTokens.any((t) => t.isImage);
        if (hasImageTokens && !await imageDir.exists()) {
          await imageDir.create(recursive: true);
          // Bei Cache-Treffer: EPUB nochmal öffnen; bei Frisch-Parse: parsedImages nutzen
          final images = parsedImages.isNotEmpty
              ? parsedImages
              : await EpubParser().parseImagesOnly(book.filePath);
          for (final entry in images.entries) {
            await File(
              '${imageDir.path}/${entry.key}',
            ).writeAsBytes(entry.value);
          }
        }
      }

      final chapters = await bookDao.getChaptersByBookId(book.id!);

      // Kapitelgrenzen aus tatsächlichen Tokens neu berechnen
      // (verhindert Abweichungen zwischen DB-Werten und Token-Cache)
      final chapterStarts = <int, int>{};
      final chapterEnds = <int, int>{};
      for (int i = 0; i < enrichedTokens.length; i++) {
        final ci = enrichedTokens[i].chapterIndex;
        chapterStarts.putIfAbsent(ci, () => i);
        chapterEnds[ci] = i;
      }
      final recalculatedChapters = chapters.map((ch) {
        final start = chapterStarts[ch.indexInBook];
        final end = chapterEnds[ch.indexInBook];
        if (start == null || end == null) return ch;
        return Chapter(
          id: ch.id,
          bookId: ch.bookId,
          indexInBook: ch.indexInBook,
          title: ch.title,
          startWord: start,
          wordCount: end - start + 1,
        );
      }).toList();

      _engine.load(enrichedTokens, book.id!, book.currentWord);

      state = state.copyWith(
        book: book,
        tokens: enrichedTokens,
        chapters: recalculatedChapters,
        currentIndex: book.currentWord,
        isLoading: false,
        rsvpState: RsvpState.idle,
        imageBasePath: imageBasePath,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void play() => _engine.play();
  Future<void> stop() => _engine.stop();
  void pauseForSwipe() => _engine.pauseForSwipe();
  void skipForward() => _engine.skipForward();
  void skipBackward() => _engine.skipBackward();
  void skipForwardWords(int words) => _engine.skipForwardWords(words);
  void skipBackwardWords(int words) => _engine.skipBackwardWords(words);
  void resumeAfterSwipe() => _engine.resumeAfterSwipe();
  void jumpToWord(int index) => _engine.jumpToWord(index);

  /// Baut den Klartext eines Kapitels aus den bereits geladenen Tokens.
  String chapterText(int chapterIndex) {
    return state.tokens
        .where((t) => t.chapterIndex == chapterIndex)
        .where((t) => !t.isChapterTitle && !t.isImage && !t.isBlank)
        .map((t) => t.raw)
        .where((r) => r.isNotEmpty)
        .join(' ');
  }

  ParagraphData currentParagraph() {
    final tokens = state.tokens;
    if (tokens.isEmpty) {
      return const ParagraphData(pre: '', current: '', post: '', orpIndex: 0);
    }
    final idx = state.currentIndex.clamp(0, tokens.length - 1);
    final currentToken = tokens[idx];

    // Kapiteltitel als eigene Seite anzeigen
    if (currentToken.isChapterTitle) {
      return ParagraphData(
        pre: '',
        current: '',
        post: '',
        orpIndex: 0,
        chapterTitle: currentToken.raw,
        isTitlePage: true,
      );
    }

    // Bild als eigene Seite anzeigen
    if (currentToken.isImage) {
      return ParagraphData(
        pre: '',
        current: '',
        post: '',
        orpIndex: 0,
        isImagePage: true,
        imageKey: currentToken.imageKey,
      );
    }

    int start = idx;
    while (start > 0) {
      final prev = tokens[start - 1];
      if (prev.isParagraphEnd || prev.isChapterTitle) break;
      start--;
    }

    int end = idx;
    while (end < tokens.length - 1 &&
        !tokens[end].isParagraphEnd &&
        !tokens[end].isChapterTitle) {
      end++;
    }

    bool usable(WordToken t) =>
        !t.isBlank && !t.isImage && !t.isChapterTitle && t.raw.isNotEmpty;

    String joinRaw(List<WordToken> list) {
      if (list.isEmpty) return '';
      final buf = StringBuffer();
      for (int i = 0; i < list.length; i++) {
        buf.write(list[i].raw);
        if (i < list.length - 1 && !list[i].raw.endsWith('-')) {
          buf.write(' ');
        }
      }
      return buf.toString();
    }

    final preTokens = tokens.sublist(start, idx).where(usable).toList();
    final postTokens = idx + 1 <= end
        ? tokens.sublist(idx + 1, end + 1).where(usable).toList()
        : <WordToken>[];

    final pre = joinRaw(preTokens);
    final post = joinRaw(postTokens);

    final sentences = _buildSentenceChunks(tokens, start, end);

    return ParagraphData(
      pre: pre,
      current: usable(currentToken) ? currentToken.raw : '',
      post: post,
      orpIndex: currentToken.orpIndex,
      sentences: sentences,
    );
  }

  List<String> _buildSentenceChunks(
      List<WordToken> tokens, int start, int end) {
    bool usable(WordToken t) =>
        !t.isBlank && !t.isImage && !t.isChapterTitle && t.raw.isNotEmpty;

    final rawSentences = <List<WordToken>>[];
    var current = <WordToken>[];
    for (int i = start; i <= end; i++) {
      final t = tokens[i];
      if (!usable(t)) continue;
      current.add(t);
      if (t.isSentenceEnd || t.isParagraphEnd || i == end) {
        if (current.isNotEmpty) {
          rawSentences.add(List<WordToken>.from(current));
          current = [];
        }
      }
    }
    if (current.isNotEmpty) rawSentences.add(current);
    if (rawSentences.isEmpty) return [];

    final chunks = <String>[];
    int i = 0;
    while (i < rawSentences.length) {
      if (rawSentences[i].length < 3) {
        final run = <List<WordToken>>[];
        int j = i;
        while (j < rawSentences.length && rawSentences[j].length < 3) {
          run.add(rawSentences[j]);
          j++;
        }
        if (run.length >= 2) {
          chunks.add(run.map(_joinTokensRaw).join(' '));
        } else {
          chunks.add(_joinTokensRaw(run[0]));
        }
        i = j;
      } else {
        chunks.add(_joinTokensRaw(rawSentences[i]));
        i++;
      }
    }
    return chunks;
  }

  String _joinTokensRaw(List<WordToken> tokens) {
    if (tokens.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < tokens.length; i++) {
      buf.write(tokens[i].raw);
      if (i < tokens.length - 1 && !tokens[i].raw.endsWith('-')) {
        buf.write(' ');
      }
    }
    return buf.toString();
  }

  void adjustWpm(int delta) {
    final settings = SettingsService.instance;
    final newWpm = (settings.wpm + delta).clamp(50, 1000);
    settings.setWpm(newWpm);
    _engine.notifyWpmChanged();
  }

  // Paragraph-Modus Navigation

  void snapToParaStart() {
    final tokens = state.tokens;
    if (tokens.isEmpty) return;
    int idx = state.currentIndex.clamp(0, tokens.length - 1);
    while (idx > 0) {
      final prev = tokens[idx - 1];
      if (prev.isParagraphEnd || prev.isChapterTitle) break;
      idx--;
    }
    // Wenn direkt nach einem Kapiteltitel → einen Schritt zurück auf den Titel
    if (idx > 0 && tokens[idx - 1].isChapterTitle) {
      idx = idx - 1;
    }
    _engine.jumpToWord(idx);
    state = state.copyWith(currentIndex: idx);
  }

  int _paraStart(int idx) {
    final tokens = state.tokens;
    int start = idx;
    while (start > 0) {
      final prev = tokens[start - 1];
      if (prev.isParagraphEnd || prev.isChapterTitle || prev.isImage) break;
      start--;
    }
    return start;
  }

  int _paraEnd(int idx) {
    final tokens = state.tokens;
    int end = idx;
    while (end < tokens.length - 1 &&
        !tokens[end].isParagraphEnd &&
        !tokens[end].isChapterTitle &&
        !tokens[end].isImage) {
      end++;
    }
    return end;
  }


  int _countParaWords(int start, int end) {
    return state.tokens
        .sublist(start, end + 1)
        .where(
          (t) =>
              !t.isBlank && !t.isImage && !t.isChapterTitle && t.raw.isNotEmpty,
        )
        .length;
  }

  void nextParagraph({bool countWords = true}) {
    final tokens = state.tokens;
    if (tokens.isEmpty) return;

    final idx = state.currentIndex.clamp(0, tokens.length - 1);
    final start = _paraStart(idx);
    final end = _paraEnd(idx);

    int nextIdx = end + 1;
    while (nextIdx < tokens.length &&
        tokens[nextIdx].isBlank &&
        !tokens[nextIdx].isChapterTitle) {
      nextIdx++;
    }

    if (nextIdx >= tokens.length) return;

    if (countWords) _paragraphWordsAccumulated += _countParaWords(start, end);

    _engine.jumpToWord(nextIdx);
    state = state.copyWith(currentIndex: nextIdx);
  }

  void prevParagraph({bool countWords = true}) {
    final tokens = state.tokens;
    if (tokens.isEmpty) return;

    final idx = state.currentIndex.clamp(0, tokens.length - 1);
    final currentStart = _paraStart(idx);
    if (currentStart == 0) return;

    int prevEnd = currentStart - 1;
    while (prevEnd > 0 &&
        tokens[prevEnd].isBlank &&
        !tokens[prevEnd].isChapterTitle) {
      prevEnd--;
    }

    final prevStart = _paraStart(prevEnd);

    if (countWords) {
      _paragraphWordsAccumulated =
          (_paragraphWordsAccumulated - _countParaWords(prevStart, prevEnd))
              .clamp(0, 999999);
    }

    _engine.jumpToWord(prevStart);
    state = state.copyWith(currentIndex: prevStart);
  }

  Future<void> saveParagraphSession(
    int estimatedSeconds, {
    DateTime? startedAt,
  }) async {
    if (_paragraphWordsAccumulated == 0) return;
    final book = state.book;
    if (book == null) return;
    await ref
        .read(sessionDaoProvider)
        .insertSession(
          ReadSession(
            bookId: book.id!,
            startedAt: startedAt ?? DateTime.now(),
            durationSec: estimatedSeconds,
            wordsRead: _paragraphWordsAccumulated,
            mode: 'paragraph',
          ),
        );
    final wordsForXp = _paragraphWordsAccumulated;
    _paragraphWordsAccumulated = 0;
    ref.read(companionProvider.notifier).addXpForSession(wordsForXp);
  }

  Future<void> closeBook() async {
    // Nur stoppen wenn nicht bereits fertig (finished ruft _saveSession/_saveProgress schon auf)
    if (_engine.state != RsvpState.finished) {
      await _engine.stop();
    }
    final book = state.book;
    if (book == null || book.totalWords == 0) return;

    final totalWords = state.tokens.isEmpty ? 1 : state.tokens.length;
    final progress = state.currentIndex / totalWords;
    if (progress >= 0.95) {
      if (book.isManual) {
        // Manuelle Texte nach dem Lesen einfach löschen
        await BookDao().deleteBook(book.id!);
        await TokenCacheDao().deleteCache(book.id!);
      } else {
        await BookDao().setArchived(book.id!, true);
        ref.invalidate(archivedBooksProvider);
        if (book.isBook) {
          await SettingsService.instance.incrementBooksRead();
        }
      }
    }

    ref.invalidate(libraryProvider);
    ref.invalidate(bookDurationsProvider);
    ref.invalidate(aggregatedStatsProvider);

    if (progress >= 0.95) {
      await ref.read(companionProvider.notifier).unlockRandomOnBookFinish();
    }
  }
}

final readerProvider = NotifierProvider<ReaderNotifier, ReaderState>(
  ReaderNotifier.new,
);
