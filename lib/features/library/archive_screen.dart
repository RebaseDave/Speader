import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/book.dart';
import '../../core/database/book_dao.dart';
import 'library_provider.dart';
import '../../core/theme/app_colors.dart';

final archivedBooksProvider = FutureProvider<List<Book>>((ref) async {
  return BookDao().getArchivedBooks();
});

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiveAsync = ref.watch(archivedBooksProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Archiv', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: archiveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 80, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'Keine archivierten Bücher',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Bücher ab 95% werden automatisch archiviert',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          return _ArchiveList(
            mainBooks: books.where((b) => b.isBook).toList(),
            deeps: const [],
            shorts: const [],
          );
        },
      ),
    );
  }
}

class _ArchiveList extends StatefulWidget {
  final List<Book> mainBooks;
  final List<Book> deeps;
  final List<Book> shorts;
  const _ArchiveList({
    required this.mainBooks,
    required this.deeps,
    required this.shorts,
  });

  @override
  State<_ArchiveList> createState() => _ArchiveListState();
}

class _ArchiveListState extends State<_ArchiveList> {
  bool _deepsExpanded = false;
  bool _shortsExpanded = false;
  final Map<String, bool> _authorExpanded = {};
  final Map<String, bool> _seriesExpanded = {};

  List<Widget> _buildSeriesAndBooks(List<Book> books) {
    final seriesMap = <String, List<Book>>{};
    final noSeries = <Book>[];
    for (final b in books) {
      final s = b.series?.isNotEmpty == true &&
              b.series != '__erklaerung__' &&
              b.series != '__manuell__'
          ? b.series : null;
      if (s != null) {
        seriesMap.putIfAbsent(s, () => []).add(b);
      } else {
        noSeries.add(b);
      }
    }
    final result = <Widget>[];
    for (final e in seriesMap.entries) {
      final expanded = _seriesExpanded[e.key] ?? false;
      result.add(Column(children: [
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _seriesExpanded[e.key] = !expanded),
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.folder_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 14))),
              Text('(${e.value.length})', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 6),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 16),
            ]),
          ),
        ),
        if (expanded) ...e.value.map((b) => _ArchivedBookCard(book: b)),
      ]));
    }
    result.addAll(noSeries.map((b) => _ArchivedBookCard(book: b)));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final authorMap = <String, List<Book>>{};
    final noAuthor = <Book>[];
    for (final b in widget.mainBooks) {
      final a = b.author?.isNotEmpty == true ? b.author : null;
      if (a != null) {
        authorMap.putIfAbsent(a, () => []).add(b);
      } else {
        noAuthor.add(b);
      }
    }
    final sortedAuthors = authorMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        ...sortedAuthors.map((author) {
          final expanded = _authorExpanded[author] ?? false;
          return Column(children: [
            GestureDetector(
              onTap: () => setState(() => _authorExpanded[author] = !expanded),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.person_outline, color: Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(author, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600))),
                  Text('(${authorMap[author]!.length})', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38),
                ]),
              ),
            ),
            if (expanded) ..._buildSeriesAndBooks(authorMap[author]!),
          ]);
        }),
        ..._buildSeriesAndBooks(noAuthor),

        // Deep
        if (widget.deeps.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _deepsExpanded = !_deepsExpanded),
            child: Container(
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
                      'Deep',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '(${widget.deeps.length})',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _deepsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (_deepsExpanded) ...[
            const SizedBox(height: 8),
            ...widget.deeps.map((book) => _ArchivedBookCard(book: book)),
          ],
        ],

        // Shorts
        if (widget.shorts.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _shortsExpanded = !_shortsExpanded),
            child: Container(
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
                    '(${widget.shorts.length})',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _shortsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (_shortsExpanded) ...[
            const SizedBox(height: 8),
            ...widget.shorts.map((book) => _ArchivedBookCard(book: book)),
          ],
        ],
      ],
    );
  }
}

class _ArchivedBookCard extends ConsumerWidget {
  final Book book;
  const _ArchivedBookCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = book.totalWords > 0
        ? (book.currentWord / book.totalWords * 100).toStringAsFixed(1)
        : '0.0';

    final durationsAsync = ref.watch(bookDurationsProvider);
    final totalSeconds = durationsAsync.valueOrNull?[book.id] ?? 0;
    final durationStr = totalSeconds >= 3600
        ? '${totalSeconds ~/ 3600}h ${(totalSeconds % 3600) ~/ 60}m'
        : totalSeconds >= 60
        ? '${totalSeconds ~/ 60}m'
        : '${totalSeconds}s';

    return Dismissible(
      key: Key('archived_${book.id}'),
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
          ref.invalidate(archivedBooksProvider);
        }
        return false;
      },
      child: Card(
        color: Theme.of(context).cardColor,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _showArchiveOptionsMenu(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.book, color: Colors.white38, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        book.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.archive, color: Colors.white24, size: 18),
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
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$progress% gelesen',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        if (totalSeconds > 0) ...[
                          Text(
                            '⏱ $durationStr',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Text(
                          'Lang drücken zum Zurückholen',
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ],
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

  void _showArchiveOptionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: Colors.white70),
              title: const Text(
                'Reihe festlegen',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSeriesDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.unarchive_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Zurück in Bibliothek',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showUnarchiveDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSeriesDialog(BuildContext context, WidgetRef ref) async {
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
            hintText: 'z.B. Harry Potter (leer = keine Reihe)',
            hintStyle: const TextStyle(color: Colors.white38),
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
              ref.invalidate(archivedBooksProvider);
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

  void _showUnarchiveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text(
          'Zurück in Library',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '„${book.title}" zurück in die Library verschieben?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await BookDao().setArchived(book.id!, false);
              await BookDao().updateProgress(book.id!, 0, 0);
              ref.invalidate(archivedBooksProvider);
              ref.invalidate(libraryProvider);
            },
            child: Text(
              'Zurückholen',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
