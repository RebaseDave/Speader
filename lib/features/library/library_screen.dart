import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/book.dart';
import '../../core/database/book_dao.dart';
import '../../epub/epub_importer.dart';
import '../../core/database/orp_dao.dart';
import 'library_provider.dart';
import '../../core/models/read_session.dart';
import '../../epub/text_importer.dart';
import 'package:flutter/services.dart';
import '../../core/database/session_dao.dart';
import 'explain_provider.dart';
import 'explain_dialog.dart';
import '../../core/services/settings_service.dart';
import 'streak_banner.dart';
import 'streak_provider.dart';
import '../reader/reader_provider.dart';
import 'stats_sheet.dart';
import '../library/archive_screen.dart';
import 'dart:math';
import '../companions/companion_provider.dart';
import '../../core/theme/app_colors.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

enum _SortOrder { recent, title, author }

final librarySelectionProvider = StateProvider<Set<int>>((ref) => const {});

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _speaderTapCount = 0;
  DateTime? _lastTap;
  final _SortOrder _sortOrder = _SortOrder.recent;

  void _onSpeaderTap() {
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 1)) {
      _speaderTapCount = 1;
    } else {
      _speaderTapCount++;
    }
    _lastTap = now;
    if (_speaderTapCount >= 3) {
      _speaderTapCount = 0;
      context.push('/scoreboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);

    ref.listen(readerProvider, (previous, next) {
      if (previous?.rsvpState != next.rsvpState) {
        ref.invalidate(streakProvider);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: GestureDetector(
          onTap: _onSpeaderTap,
          child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Sp',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              TextSpan(
                text: 'e',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const TextSpan(
                text: 'ader',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: () => context.push('/settings'),
            tooltip: 'Einstellungen',
          ),
          
          IconButton(
            icon: const Icon(Icons.pets, color: Colors.white),
            onPressed: () => context.push('/companions'),
            tooltip: 'Begleiter',
          ),
          Consumer(
            builder: (context, ref, _) {
              final isLoading =
                  ref.watch(explainProvider).status == ExplainStatus.loading;
              return IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.white),
                onPressed: isLoading
                    ? null
                    : () => showExplainDialog(context, ref),
                tooltip: 'Thema erklären',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const StatsSheet(),
            ),
            tooltip: 'Statistiken',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => _showHistory(context, ref),
            tooltip: 'Historie',
          ),
        ],
      ),
      body: Column(
        children: [
          const StreakBanner(),
          Expanded(
            child: libraryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (books) => books.isEmpty
                  ? const _EmptyLibrary()
                  : _BookList(books: books, sortOrder: _sortOrder),
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final selection = ref.watch(librarySelectionProvider);
          if (selection.isNotEmpty) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'clear_selection',
                  backgroundColor: Theme.of(context).cardColor,
                  onPressed: () => ref.read(librarySelectionProvider.notifier).state = const {},
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: Text('${selection.length} abwählen',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'set_series',
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () async {
                    await _showSeriesDialogMultiple(context, selection.toList(), ref);
                    ref.read(librarySelectionProvider.notifier).state = const {};
                  },
                  icon: const Icon(Icons.folder_outlined, color: Colors.white),
                  label: Text('Reihe festlegen (${selection.length})',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'text_import',
                backgroundColor: Theme.of(context).cardColor,
                onPressed: () => _showTextImportDialog(context, ref),
                icon: const Icon(Icons.content_paste, color: Colors.white),
                label: const Text('Text einfügen',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'epub_import',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () => _importEpubs(context, ref),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('EPUB importieren',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importEpubs(BuildContext context, WidgetRef ref) async {
    final importer = EpubImporter(BookDao(), OrpDao());
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Fortschritts-Dialog
    int done = 0;
    int total = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text('Importiere...',
                style: TextStyle(color: Colors.white)),
            content: total == 0
                ? const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: done / total,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Text('$done / $total',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
          );
        },
      ),
    );

    try {
      final (books, errors) = await importer.importMultipleEpubs(
        onProgress: (d, t) {
          done = d;
          total = t;
        },
      );
      if (context.mounted) Navigator.of(context).pop();
      ref.invalidate(libraryProvider);
      if (errors.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text(
              '${books.length} importiert · ${errors.length} Fehler',
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: errors.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    errors[i],
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (books.isNotEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${books.length} importiert'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Fehler beim Import: $e')),
      );
    }
  }

  Future<void> _showTextImportDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final textController = TextEditingController();
    final titleController = TextEditingController();

    // Clipboard automatisch einfügen
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      textController.text = clipboardData!.text!;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Text einfügen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Titel',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'Text hier einfügen...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (textController.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        final importer = TextImporter(BookDao(), OrpDao());
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final book = await importer.importText(
                          titleController.text,
                          textController.text,
                        );
                        if (book != null) {
                          ref.invalidate(libraryProvider);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('„${book.title}" importiert!'),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Importieren',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    ref.invalidate(aggregatedStatsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _HistorySheet(),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'Keine Bücher vorhanden',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Importiere ein EPUB um zu beginnen',
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;
  final _SortOrder sortOrder;
  const _BookList({required this.books, required this.sortOrder});

  List<Book> _sorted(List<Book> list) {
    final copy = [...list];
    if (sortOrder == _SortOrder.title) {
      copy.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (sortOrder == _SortOrder.author) {
      copy.sort((a, b) {
        final aA = a.author?.toLowerCase() ?? 'zzz';
        final bA = b.author?.toLowerCase() ?? 'zzz';
        final cmp = aA.compareTo(bA);
        return cmp != 0 ? cmp : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = books
        .where((b) => b.currentWord > 0)
        .toList();

    final unstarted = books.where((b) => b.currentWord == 0).toList();

    final unstartedBooks = unstarted.where((b) => b.isBook).toList();
    final unstartedManuals = unstarted.where((b) => b.isManual).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        ...inProgress.map((b) => _BookCard(book: b)),
        if (inProgress.isNotEmpty &&
            (unstartedManuals.isNotEmpty || unstartedBooks.isNotEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white12),
          ),
        ...unstartedManuals.map((b) => _BookCard(book: b)),
        if (unstartedBooks.isNotEmpty)
          _BooksFolder(books: _sorted(unstartedBooks)),
      ],
    );
  }
}

class _BooksFolder extends StatefulWidget {
  final List<Book> books;
  const _BooksFolder({required this.books});

  @override
  State<_BooksFolder> createState() => _BooksFolderState();
}

class _BooksFolderState extends State<_BooksFolder> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Books',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '(${widget.books.length})',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          ..._buildAuthorGroups(widget.books),
        ],
      ],
    );
  }

  List<Widget> _buildAuthorGroups(List<Book> books) {
    final authorMap = <String, List<Book>>{};
    final noAuthor = <Book>[];
    for (final b in books) {
      final a = b.author?.isNotEmpty == true ? b.author : null;
      if (a != null) {
        authorMap.putIfAbsent(a, () => []).add(b);
      } else {
        noAuthor.add(b);
      }
    }
    final sorted = authorMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      ...sorted.map((a) => _AuthorFolder(author: a, books: authorMap[a]!)),
      ..._seriesAndBooks(noAuthor, isArchive: false),
    ];
  }

  static List<Widget> _seriesAndBooks(List<Book> books,
      {required bool isArchive}) {
    final seriesMap = <String, List<Book>>{};
    final noSeries = <Book>[];
    for (final b in books) {
      final s = b.series?.isNotEmpty == true &&
              b.series != '__erklaerung__' &&
              b.series != '__manuell__'
          ? b.series
          : null;
      if (s != null) {
        seriesMap.putIfAbsent(s, () => []).add(b);
      } else {
        noSeries.add(b);
      }
    }
    return [
      ...seriesMap.entries.map(
          (e) => _SeriesFolder(name: e.key, books: e.value, isArchive: isArchive)),
      ...noSeries.map((b) => _BookCard(book: b)),
    ];
  }
}

class _AuthorFolder extends StatefulWidget {
  final String author;
  final List<Book> books;
  const _AuthorFolder({required this.author, required this.books});

  @override
  State<_AuthorFolder> createState() => _AuthorFolderState();
}

class _AuthorFolderState extends State<_AuthorFolder> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4, left: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.author,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ),
                Text('(${widget.books.length})',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ..._BooksFolderState._seriesAndBooks(widget.books,
              isArchive: false),
      ],
    );
  }
}

class _SeriesFolder extends StatefulWidget {
  final String name;
  final List<Book> books;
  final bool isArchive;
  const _SeriesFolder({
    required this.name,
    required this.books,
    required this.isArchive,
  });

  @override
  State<_SeriesFolder> createState() => _SeriesFolderState();
}

class _SeriesFolderState extends State<_SeriesFolder> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '(${widget.books.length})',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.books.map((b) => _BookCard(book: b)),
      ],
    );
  }
}

class _DeepFolder extends StatefulWidget {
  final List<Book> books;
  final bool isArchive;
  const _DeepFolder({required this.books, required this.isArchive});

  @override
  State<_DeepFolder> createState() => _DeepFolderState();
}

class _DeepFolderState extends State<_DeepFolder> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Deeps',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '(${widget.books.length})',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.books.map((b) => _BookCard(book: b)),
      ],
    );
  }
}

class _ShortsFolder extends StatefulWidget {
  final List<Book> books;
  final bool isArchive;
  const _ShortsFolder({required this.books, required this.isArchive});

  @override
  State<_ShortsFolder> createState() => _ShortsFolderState();
}

class _ShortsFolderState extends State<_ShortsFolder> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Shorts',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '(${widget.books.length})',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.books.map((b) => _BookCard(book: b)),
      ],
    );
  }
}

class _BookCard extends ConsumerWidget {
  final Book book;
  const _BookCard({required this.book});

  bool _isSelected(WidgetRef ref) =>
      ref.watch(librarySelectionProvider).contains(book.id);

  bool _inSelectionMode(WidgetRef ref) =>
      ref.watch(librarySelectionProvider).isNotEmpty;

  void _toggleSelection(WidgetRef ref) {
    final notifier = ref.read(librarySelectionProvider.notifier);
    final current = Set<int>.from(notifier.state);
    if (current.contains(book.id)) {
      current.remove(book.id);
    } else {
      if (book.id != null) current.add(book.id!);
    }
    notifier.state = current;
  }

  String _estimateRemaining(Book book) {
    if (book.currentWord <= 0 || book.totalWords <= 0) return '';
    final wordsLeft = book.totalWords - book.currentWord;
    if (wordsLeft <= 0) return '';

    final s = SettingsService.instance;
    final settingsWpm = s.wpm.toDouble();
    final scaling = s.scalingEnabled ? s.referenceWpm / settingsWpm : 1.0;
    final baseOverhead = s.bookBaseOverhead(book.id ?? 0);
    final double effectiveWpm;
    if (baseOverhead != null) {
      effectiveWpm = 60000.0 / (60000.0 / settingsWpm + baseOverhead * scaling);
    } else {
      final overhead =
          (s.sentenceMs * scaling / 12.0) +
          (s.commaMs * scaling / 9.0) +
          (s.paragraphMs * scaling / 65.0) +
          (sqrt(4.0) * s.lengthScaleFactor * 0.1 *
              (60000.0 / s.wpm) * 0.08);
      effectiveWpm = 60000.0 / (60000.0 / settingsWpm + overhead);
    }

    if (effectiveWpm <= 0) return '';
    final minutes = (wordsLeft / effectiveWpm).round();
    if (minutes <= 0) return '';
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '~${h}h ${m}min verbleibend' : '~${h}h verbleibend';
    }
    return '~$minutes Min verbleibend';
  }

  void _showBookMenu(BuildContext context, Book book, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.archive_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Archivieren',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await BookDao().setArchived(book.id!, true);
                ref.invalidate(libraryProvider);
                ref.invalidate(archivedBooksProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: Colors.white70),
              title: const Text(
                'Reihe festlegen',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSeriesDialogStatic(context, book, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = book.totalWords > 0
        ? (book.currentWord / book.totalWords * 100).toStringAsFixed(1)
        : '0.0';
    final hasAuthor = book.author != null && book.author!.isNotEmpty;

    final durationsAsync = ref.watch(bookDurationsProvider);
    final totalSeconds = durationsAsync.valueOrNull?[book.id] ?? 0;
    final durationStr = totalSeconds >= 3600
        ? '${totalSeconds ~/ 3600}h ${(totalSeconds % 3600) ~/ 60}m'
        : totalSeconds >= 60
        ? '${totalSeconds ~/ 60}m'
        : '${totalSeconds}s';

    return Dismissible(
      key: Key('book_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.colors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text(
              'Buch entfernen',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '„${book.title}" entfernen?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Entfernen',
                  style: TextStyle(color: context.colors.danger),
                ),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await BookDao().deleteBook(book.id!);
          await SettingsService.instance.removeBookBaseOverhead(book.id!);
          ref.invalidate(libraryProvider);
          ref.invalidate(aggregatedStatsProvider);
          ref.invalidate(bookDurationsProvider);
        }
        return false;
      },
      child: Card(
        color: Theme.of(context).cardColor,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (_inSelectionMode(ref)) {
              _toggleSelection(ref);
              return;
            }
            final freshBook = await BookDao().getBookById(book.id!);
            if (freshBook == null || !context.mounted) return;
            context.push('/reader/${freshBook.id}', extra: freshBook);
          },
          onLongPress: () {
            if (_inSelectionMode(ref)) {
              _showBookMenu(context, book, ref);
            } else {
              _toggleSelection(ref);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.book,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    if (_isSelected(ref))
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.check_circle,
                          color: Colors.white70, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasAuthor)
                            Text(
                              book.author!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: book.totalWords > 0
                        ? book.currentWord / book.totalWords
                        : 0,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white24,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          durationStr,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (book.currentWord > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    _estimateRemaining(book),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet();

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  List<ReadSession>? _todaySessions;
  List<Map<String, dynamic>>? _pastDaysThisWeek;
  List<Map<String, dynamic>>? _pastWeeks;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final dao = SessionDao();
    final today = await dao.getTodaySessions();
    final pastDays = await dao.getPastDaysThisWeek();
    final pastWeeks = await dao.getPastWeeksSummaries();
    if (mounted) {
      setState(() {
        _todaySessions = today;
        _pastDaysThisWeek = pastDays;
        _pastWeeks = pastWeeks;
      });
    }
  }

  Future<void> _deleteSession(ReadSession session) async {
    await ref.read(companionProvider.notifier).removeXpForWords(session.wordsRead);
    await SessionDao().deleteSession(session.id!);
    ref.invalidate(aggregatedStatsProvider);
    ref.invalidate(bookDurationsProvider);
    ref.invalidate(streakProvider);
    if (mounted) {
      setState(() => _todaySessions?.remove(session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Spacer(),
                const Text(
                  'Historie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.archive_outlined,
                    color: Colors.white54,
                  ),
                  tooltip: 'Archiv',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/archive');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          Expanded(
            child: _todaySessions == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      // Heute
                      _sectionHeader('Heute'),
                      if (_todaySessions!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Keine Sessions heute',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._todaySessions!.map(
                          (s) => _SessionTile(
                            session: s,
                            onDelete: () => _deleteSession(s),
                          ),
                        ),

                      // Andere Tage dieser Woche
                      if (_pastDaysThisWeek != null &&
                          _pastDaysThisWeek!.isNotEmpty) ...[
                        const Divider(color: Colors.white12),
                        ..._pastDaysThisWeek!.map((day) {
                          final dayStart = DateTime.parse(
                            day['day_start'] as String,
                          );
                          final yesterday = now.subtract(
                            const Duration(days: 1),
                          );
                          final isYesterday =
                              dayStart.day == yesterday.day &&
                              dayStart.month == yesterday.month;
                          final label = isYesterday
                              ? 'Gestern'
                              : _formatDate(dayStart);
                          final totalWords = day['total_words'] as int? ?? 0;
                          final totalSeconds =
                              day['total_seconds'] as int? ?? 0;
                          final effectiveWpm = totalSeconds > 0
                              ? (totalWords / totalSeconds * 60).round()
                              : 0;

                          return ListTile(
                            leading: const Icon(
                              Icons.today,
                              color: Colors.white24,
                              size: 18,
                            ),
                            title: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$totalWords Wörter',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatDuration(totalSeconds),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      '$effectiveWpm WPM',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Vergangene Wochen
                      if (_pastWeeks != null && _pastWeeks!.isNotEmpty) ...[
                        const Divider(color: Colors.white12),
                        ..._pastWeeks!.map((week) {
                          final weekStart = DateTime.parse(
                            week['week_monday'] as String,
                          );
                          final weekEnd = weekStart.add(
                            const Duration(days: 6),
                          );
                          final totalWords = week['total_words'] as int? ?? 0;
                          final totalSeconds =
                              week['total_seconds'] as int? ?? 0;
                          final effectiveWpm = totalSeconds > 0
                              ? (totalWords / totalSeconds * 60).round()
                              : 0;

                          return ListTile(
                            leading: const Icon(
                              Icons.date_range,
                              color: Colors.white24,
                              size: 18,
                            ),
                            title: Text(
                              '${_formatDate(weekStart)} – ${_formatDate(weekEnd)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$totalWords Wörter',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatDuration(totalSeconds),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      '$effectiveWpm WPM',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h >= 10) return '${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _SessionTile extends StatelessWidget {
  final ReadSession session;
  final VoidCallback onDelete;

  const _SessionTile({required this.session, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final duration = session.durationSec;
    final durationStr = duration >= 60
        ? '${duration ~/ 60}m ${duration % 60}s'
        : '${duration}s';
    final effectiveWpm = session.durationSec > 0
        ? (session.wordsRead / session.durationSec * 60).round()
        : 0;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: context.colors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.colors.surfaceElevated,
            title: const Text(
              'Session löschen',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Diese Session aus der Historie entfernen?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Löschen',
                  style: TextStyle(color: context.colors.danger),
                ),
              ),
            ],
          ),
        );
        if (confirm == true) {
          onDelete();
        }
        return false;
      },
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.menu_book, color: Colors.white24, size: 18),
        title: Text(
          '$dateStr $timeStr',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${session.wordsRead} Wörter',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  durationStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const Text(
                  ' · ',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
                Text(
                  '$effectiveWpm WPM',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSeriesDialogMultiple(
  BuildContext context,
  List<int> bookIds,
  WidgetRef ref,
) async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text('Reihe für ${bookIds.length} Bücher',
          style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () async {
            final series = controller.text.trim().isEmpty
                ? null
                : controller.text.trim();
            for (final id in bookIds) {
              await BookDao().setSeries(id, series);
            }
            ref.invalidate(libraryProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text('Speichern',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary)),
        ),
      ],
    ),
  );
}

Future<void> _showSeriesDialogStatic(
  BuildContext context,
  Book book,
  WidgetRef ref,
) async {
  final controller = TextEditingController(text: book.series ?? '');
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text(
        'Reihe festlegen',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () async {
            final series = controller.text.trim().isEmpty
                ? null
                : controller.text.trim();
            await BookDao().setSeries(book.id!, series);
            ref.invalidate(libraryProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(
            'Speichern',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}
