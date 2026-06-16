import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'explain_provider.dart';
import 'explain_sheet.dart';

Future<void> showExplainDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      title: const Text(
        'Thema erklären',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Erkläre: ',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          counterStyle: const TextStyle(color: Colors.white38),
        ),
        onSubmitted: (_) => Navigator.pop(ctx, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Erklären',
            style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || controller.text.trim().isEmpty) return;
  if (!context.mounted) return;

  ref.read(explainProvider.notifier).explain(controller.text.trim());
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const ExplainSheet(),
  ).whenComplete(() => ref.read(explainProvider.notifier).reset());
}
