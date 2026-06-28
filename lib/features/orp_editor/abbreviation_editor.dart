import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orp_editor_provider.dart';
import '../../core/database/token_cache_dao.dart';

class AbbreviationEditor extends ConsumerStatefulWidget {
  const AbbreviationEditor({super.key});

  @override
  ConsumerState<AbbreviationEditor> createState() =>
      _AbbreviationEditorState();
}

class _AbbreviationEditorState extends ConsumerState<AbbreviationEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orpEditorProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Neue Ausnahme',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (_controller.text.trim().isNotEmpty) {
                    await ref
                        .read(orpEditorProvider.notifier)
                        .addAbbreviation(_controller.text.trim());
                    await TokenCacheDao().deleteAllCaches();
                    _controller.clear();
                  }
                },
                child: const Text('Hinzufügen',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: state.abbreviations.length,
                  itemBuilder: (context, index) {
                    final abbr = state.abbreviations[index];
                    return ListTile(
                      title: Text(abbr,
                          style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => ref
                            .read(orpEditorProvider.notifier)
                            .deleteAbbreviation(abbr),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}