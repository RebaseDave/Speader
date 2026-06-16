import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/book_dao.dart';
import '../../core/models/book.dart';
import '../../core/database/orp_dao.dart';
import '../../core/database/session_dao.dart';
import '../../core/database/chapter_summary_dao.dart';

final aggregatedStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  return SessionDao().getAggregatedStats();
});

final orpDaoProvider = Provider<OrpDao>((ref) => OrpDao());
final bookDaoProvider = Provider<BookDao>((ref) => BookDao());

final bookDurationsProvider = FutureProvider<Map<int, int>>((ref) async {
  return SessionDao().getTotalDurationPerBook();
});

final libraryProvider = FutureProvider<List<Book>>((ref) async {
  final dao = ref.watch(bookDaoProvider);
  return dao.getAllBooks();
});

final historicalWpmProvider = FutureProvider<({double wpm, int count})?>((ref) async {
  return SessionDao().getHistoricalWpm();
});

final bookWpmProvider = FutureProvider.family<({double wpm, int count})?, int>((ref, bookId) async {
  return SessionDao().getHistoricalWpmForBook(bookId);
});

final cachedSummaryIndicesProvider =
    FutureProvider.family<Set<int>, int>((ref, bookId) async {
  return ChapterSummaryDao().getCachedChapterIndices(bookId);
});