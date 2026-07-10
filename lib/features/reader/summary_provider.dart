import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/claude_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/database/chapter_summary_dao.dart';
import 'reader_provider.dart';
import '../library/library_provider.dart';

enum SummaryStatus { idle, loading, done, error }

class SummaryState {
  final SummaryStatus status;
  final String? title;
  final String? summary;
  final String? errorMessage;
  final int? bookId;
  final int? chapterIndex;
  final int estimatedSeconds;
  final int wordCount;
  final DateTime? loadingStartedAt;

  const SummaryState({
    this.status = SummaryStatus.idle,
    this.title,
    this.summary,
    this.errorMessage,
    this.bookId,
    this.chapterIndex,
    this.estimatedSeconds = 30,
    this.wordCount = 5000,
    this.loadingStartedAt,
  });
}

class SummaryNotifier extends Notifier<SummaryState> {
  final _dao = ChapterSummaryDao();

  @override
  SummaryState build() => const SummaryState();

  Future<void> loadSummary({
    required int bookId,
    required int chapterIndex,
    required String chapterTitle,
    required String Function() chapterTextBuilder,
    int wordCount = 5000,
  }) async {
    // Nicht neu starten wenn dasselbe Kapitel bereits lädt
    if (state.status == SummaryStatus.loading &&
        state.bookId == bookId &&
        state.chapterIndex == chapterIndex) {
      return;
    }

    final estimatedSeconds = (wordCount / 60 + 20).clamp(20, 180).round();

    state = SummaryState(
      status: SummaryStatus.loading,
      title: chapterTitle,
      bookId: bookId,
      chapterIndex: chapterIndex,
      estimatedSeconds: estimatedSeconds,
      wordCount: wordCount,
      loadingStartedAt: DateTime.now(),
    );

    // 1. Cache prüfen
    final cached = await _dao.getSummary(bookId, chapterIndex);
    if (cached != null) {
      state = SummaryState(
        status: SummaryStatus.done,
        title: chapterTitle,
        summary: cached,
        bookId: bookId,
        chapterIndex: chapterIndex,
        estimatedSeconds: estimatedSeconds,
      );
      return;
    }

    // 2. API Key prüfen
    final apiKey = SettingsService.instance.claudeApiKey;
    if (apiKey.isEmpty) {
      state = SummaryState(
        status: SummaryStatus.error,
        title: chapterTitle,
        errorMessage: 'Kein API Key hinterlegt.',
        bookId: bookId,
        chapterIndex: chapterIndex,
        estimatedSeconds: estimatedSeconds,
      );
      return;
    }

    // 3. Kapiteltext bauen und an Claude schicken
    final text = chapterTextBuilder();
    final result = await ClaudeService.summarizeChapter(text, apiKey);

    switch (result.status) {
      case ClaudeStatus.success:
        await _dao.saveSummary(bookId, chapterIndex, result.text!);
        ref.invalidate(cachedSummaryIndicesProvider(bookId));
        state = SummaryState(
          status: SummaryStatus.done,
          title: chapterTitle,
          summary: result.text,
          bookId: bookId,
          chapterIndex: chapterIndex,
          estimatedSeconds: estimatedSeconds,
        );
      case ClaudeStatus.noKey:
        state = SummaryState(
          status: SummaryStatus.error,
          title: chapterTitle,
          errorMessage: 'Kein API Key hinterlegt.',
          bookId: bookId,
          chapterIndex: chapterIndex,
          estimatedSeconds: estimatedSeconds,
        );
      case ClaudeStatus.invalidKey:
        state = SummaryState(
          status: SummaryStatus.error,
          title: chapterTitle,
          errorMessage: 'API Key ungültig.',
          bookId: bookId,
          chapterIndex: chapterIndex,
          estimatedSeconds: estimatedSeconds,
        );
      case ClaudeStatus.noInternet:
        state = SummaryState(
          status: SummaryStatus.error,
          title: chapterTitle,
          errorMessage: 'Kein Internet.',
          bookId: bookId,
          chapterIndex: chapterIndex,
          estimatedSeconds: estimatedSeconds,
        );
      case ClaudeStatus.rateLimit:
        state = SummaryState(
          status: SummaryStatus.error,
          title: chapterTitle,
          errorMessage:
              'Tageslimit erreicht (max. 5) – morgen wieder verfügbar.',
          bookId: bookId,
          chapterIndex: chapterIndex,
          estimatedSeconds: estimatedSeconds,
        );
      case ClaudeStatus.error:
        state = SummaryState(
          status: SummaryStatus.error,
          title: chapterTitle,
          errorMessage: result.message ?? 'Fehler bei der Anfrage.',
          bookId: bookId,
          chapterIndex: chapterIndex,
          estimatedSeconds: estimatedSeconds,
        );
    }
  }

  Future<void> regenerate() async {
    final bookId = state.bookId;
    final chapterIndex = state.chapterIndex;
    final title = state.title ?? '';
    final wordCount = state.wordCount;
    if (bookId == null || chapterIndex == null) return;
    await _dao.deleteSummary(bookId, chapterIndex);
    await loadSummary(
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: title,
      chapterTextBuilder: () => ref
          .read(readerProvider)
          .tokens
          .where((t) => t.chapterIndex == chapterIndex)
          .where((t) => !t.isChapterTitle && !t.isImage && !t.isBlank && !t.isSceneBreak)
          .map((t) => t.raw)
          .where((r) => r.isNotEmpty)
          .join(' '),
      wordCount: wordCount,
    );
  }

  void reset() => state = const SummaryState();
}

final summaryProvider = NotifierProvider<SummaryNotifier, SummaryState>(
  SummaryNotifier.new,
);
