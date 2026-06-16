import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_provider.dart';
import 'summary_provider.dart';
import 'summary_sheet.dart';
import '../../core/models/chapter.dart';
import '../library/library_provider.dart';

class ChapterNavigator extends ConsumerStatefulWidget {
  const ChapterNavigator({super.key});

  @override
  ConsumerState<ChapterNavigator> createState() => _ChapterNavigatorState();
}

class _ChapterNavigatorState extends ConsumerState<ChapterNavigator> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    final reader = ref.read(readerProvider);
    final chapters = reader.chapters;
    if (chapters.isEmpty) return;

    final currentChapterIndex = reader.tokens.isNotEmpty
        ? reader.tokens[reader.currentIndex.clamp(0, reader.tokens.length - 1)]
            .chapterIndex
        : 0;

    final activeIndex = chapters.indexWhere(
      (c) => c.indexInBook == currentChapterIndex,
    );
    if (activeIndex < 0) return;

    const itemHeight = 72.0;
    final listHeight = _scrollController.position.viewportDimension;
    final targetOffset =
        (activeIndex * itemHeight) - (listHeight / 2) + (itemHeight / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reader = ref.watch(readerProvider);
    final chapters = reader.chapters;
    final currentChapterIndex = reader.tokens.isNotEmpty
        ? reader.tokens[reader.currentIndex.clamp(0, reader.tokens.length - 1)]
            .chapterIndex
        : 0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Kapitel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final isActive = chapter.indexInBook == currentChapterIndex;

                return ListTile(
                  leading: Icon(
                    Icons.bookmark,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white24,
                    size: 20,
                  ),
                  title: Text(
                    chapter.title ?? 'Kapitel ${index + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${chapter.wordCount} Wörter',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final cached = ref
                              .watch(
                                cachedSummaryIndicesProvider(chapter.bookId),
                              )
                              .valueOrNull ??
                          {};
                      final hasSummary =
                          cached.contains(chapter.indexInBook);
                      return IconButton(
                        icon: Icon(
                          hasSummary
                              ? Icons.task_alt
                              : Icons.auto_awesome,
                          color: hasSummary
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.6)
                              : Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        tooltip: hasSummary
                            ? 'Zusammenfassung ansehen'
                            : 'Zusammenfassung erstellen',
                        onPressed: () =>
                            _showSummary(context, ref, chapter, index),
                      );
                    },
                  ),
                  onTap: () {
                    final tokens = reader.tokens;
                    int jumpIdx = chapter.startWord;
                    for (int i = 0; i < tokens.length; i++) {
                      if (tokens[i].isChapterTitle &&
                          tokens[i].chapterIndex == chapter.indexInBook) {
                        jumpIdx = i;
                        break;
                      }
                    }
                    ref.read(readerProvider.notifier).jumpToWord(jumpIdx);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSummary(
    BuildContext context,
    WidgetRef ref,
    Chapter chapter,
    int displayIndex,
  ) {
    final readerNotifier = ref.read(readerProvider.notifier);
    ref.read(summaryProvider.notifier).loadSummary(
          bookId: chapter.bookId,
          chapterIndex: chapter.indexInBook,
          chapterTitle: chapter.title ?? 'Kapitel ${displayIndex + 1}',
          chapterTextBuilder: () =>
              readerNotifier.chapterText(chapter.indexInBook),
          wordCount: chapter.wordCount,
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SummarySheet(),
    );
  }
}