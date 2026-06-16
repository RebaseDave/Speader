import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'explain_provider.dart';

class ExplainSheet extends ConsumerWidget {
  const ExplainSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(explainProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.topic ?? 'Erklärung',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildBody(context, state),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ExplainState state) {
    switch (state.status) {
      case ExplainStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        );
      case ExplainStatus.done:
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Text(
              state.text ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        );
      case ExplainStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white38, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.errorMessage ?? 'Fehler.',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      case ExplainStatus.idle:
        return const SizedBox.shrink();
    }
  }
}