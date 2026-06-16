import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orp_editor_provider.dart';
import 'orp_entry_editor.dart';
import 'abbreviation_editor.dart';
import '../../core/services/csv_service.dart';
import '../../core/database/orp_dao.dart';
import '../../core/database/token_cache_dao.dart';

class OrpEditorScreen extends ConsumerStatefulWidget {
  const OrpEditorScreen({super.key});

  @override
  ConsumerState<OrpEditorScreen> createState() => _OrpEditorScreenState();
}

class _OrpEditorScreenState extends ConsumerState<OrpEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orpEditorProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('ORP Editor',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Importieren',
            color: Theme.of(context).cardColor,
            onSelected: (value) => _handleImport(context, ref, value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'orp',
                child: Text('ORP Datenbank importieren',
                    style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'abbreviations',
                child: Text('Ausnahmen importieren',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Exportieren',
            color: Theme.of(context).cardColor,
            onSelected: (value) => _handleExport(context, value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'orp',
                child: Text('ORP Datenbank exportieren',
                    style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'abbreviations',
                child: Text('Ausnahmen exportieren',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Datenbank zurücksetzen',
            onPressed: () => _resetDatabase(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Wörter'),
            Tab(text: 'Ausnahmen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Wörterliste
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Wort suchen...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white38),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(orpEditorProvider.notifier)
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(orpEditorProvider.notifier).setSearchQuery(v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${state.filteredEntries.length} Einträge',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.searchQuery.length < 2
                        ? const Center(
                            child: Text(
                              'Suche nach einem Wort\num den ORP-Index anzupassen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : state.filteredEntries.isEmpty
                            ? const Center(
                                child: Text(
                                  'Keine Einträge gefunden',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.builder(
                                itemCount: state.filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = state.filteredEntries[index];
                                  return OrpEntryEditor(entry: entry);
                                },
                              ),
              ),
            ],
          ),

          // Tab 2: Ausnahmen
          const AbbreviationEditor(),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, String type) async {
    final service = CsvService(OrpDao());
    final path = type == 'orp'
        ? await service.exportOrpCsv()
        : await service.exportAbbreviationsCsv();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null
            ? 'Exportiert: $path'
            : 'Export fehlgeschlagen'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleImport(
      BuildContext context, WidgetRef ref, String type) async {
    final service = CsvService(OrpDao());
    final success = type == 'orp'
        ? await service.importOrpCsv()
        : await service.importAbbreviationsCsv();
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(orpEditorProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erfolgreich importiert')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import fehlgeschlagen')),
      );
    }
  }

  Future<void> _resetDatabase(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Datenbank zurücksetzen',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Alle ORP-Einträge werden gelöscht und beim nächsten Buchöffnen neu berechnet.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await OrpDao().clearOrpEntries();
              await TokenCacheDao().deleteAllCaches();
              ref.invalidate(orpEditorProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ORP-Datenbank und Cache zurückgesetzt')),
                );
              }
            },
            child: const Text('Zurücksetzen',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}