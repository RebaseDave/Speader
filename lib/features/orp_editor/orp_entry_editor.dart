import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/orp_entry.dart';
import 'orp_editor_provider.dart';
import '../../core/theme/app_colors.dart';

class OrpEntryEditor extends ConsumerWidget {
  final OrpEntry entry;
  const OrpEntryEditor({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final word = entry.word;
    final orpIndex = entry.orpIndex.clamp(0, word.length - 1);

    // Live Vorschau
    final before = word.substring(0, orpIndex);
    final focus = orpIndex < word.length
        ? word.substring(orpIndex, orpIndex + 1)
        : '';
    final after = orpIndex + 1 < word.length
        ? word.substring(orpIndex + 1)
        : '';

    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Vorschau
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: before,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    TextSpan(
                      text: focus,
                      style: TextStyle(
                        color: context.colors.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: after,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            // Manuell-Badge
            if (entry.isManual)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'M',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 10,
                  ),
                ),
              ),

            // ORP Index +/-
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.white54, size: 20),
              onPressed: orpIndex > 0
                  ? () => ref
                        .read(orpEditorProvider.notifier)
                        .updateOrpIndex(word, orpIndex - 1)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Text(
              '$orpIndex',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white54, size: 20),
              onPressed: orpIndex < word.length - 1
                  ? () => ref
                        .read(orpEditorProvider.notifier)
                        .updateOrpIndex(word, orpIndex + 1)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
