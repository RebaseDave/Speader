import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/orp_dao.dart';
import '../../core/models/orp_entry.dart';
import '../library/library_provider.dart';
import '../../core/database/token_cache_dao.dart';

class OrpEditorState {
  final List<OrpEntry> entries;
  final List<String> abbreviations;
  final bool isLoading;
  final String searchQuery;

  const OrpEditorState({
    this.entries = const [],
    this.abbreviations = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<OrpEntry> get filteredEntries {
    if (searchQuery.length < 2) return [];
    return entries
        .where((e) => e.word.contains(searchQuery.toLowerCase()))
        .toList();
  }

  OrpEditorState copyWith({
    List<OrpEntry>? entries,
    List<String>? abbreviations,
    bool? isLoading,
    String? searchQuery,
  }) {
    return OrpEditorState(
      entries: entries ?? this.entries,
      abbreviations: abbreviations ?? this.abbreviations,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class OrpEditorNotifier extends Notifier<OrpEditorState> {
  OrpDao get _dao => ref.read(orpDaoProvider);

  @override
  OrpEditorState build() {
    _load();
    return const OrpEditorState(isLoading: true);
  }

  Future<void> _load() async {
    final entries = await _dao.getAllEntries();
    final abbreviations = await _dao.getAllAbbreviations();
    if (state.isLoading) {
      state = OrpEditorState(
        entries: entries,
        abbreviations: abbreviations,
        isLoading: false,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> updateOrpIndex(String word, int newIndex) async {
    final entry = OrpEntry(word: word, orpIndex: newIndex, isManual: true);
    await _dao.updateEntry(entry);
    await TokenCacheDao().deleteAllCaches();
    final updated = state.entries.map((e) {
      return e.word == word ? entry : e;
    }).toList();
    state = state.copyWith(entries: updated);
  }

  Future<void> addAbbreviation(String abbreviation) async {
    final trimmed = abbreviation.trim();
    if (trimmed.isEmpty) return;
    await _dao.insertAbbreviation(trimmed);
    final updated = [...state.abbreviations, trimmed];
    state = state.copyWith(abbreviations: updated);
  }

  Future<void> deleteAbbreviation(String abbreviation) async {
    await _dao.deleteAbbreviation(abbreviation);
    await TokenCacheDao().deleteAllCaches();
    final updated = state.abbreviations
        .where((a) => a != abbreviation)
        .toList();
    state = state.copyWith(abbreviations: updated);
  }
}

final orpEditorProvider =
    NotifierProvider<OrpEditorNotifier, OrpEditorState>(
  OrpEditorNotifier.new,
);