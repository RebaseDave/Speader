import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'companion.dart';
import 'companion_definition.dart';
import 'companion_provider.dart';

class CompanionCollectionSheet extends ConsumerWidget {
  const CompanionCollectionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(companionProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          const SizedBox(height: 65),
          const Text(
            'Sammlung',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncState.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (state) => GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: 11,
                itemBuilder: (context, index) {
                  final slot = index + 1;
                  final companion = state.companions
                      .firstWhere((c) => c.slot == slot);
                  return _CompanionCell(
                    companion: companion,
                    onTap: companion.isUnlocked
                        ? () async {
                            await ref
                                .read(companionProvider.notifier)
                                .setActive(slot);
                            if (context.mounted) Navigator.pop(context);
                          }
                        : null,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CompanionCell extends StatelessWidget {
  final Companion companion;
  final VoidCallback? onTap;

  const _CompanionCell({required this.companion, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = companion.isUnlocked;
    final isActive = companion.isActive;
    final isPrestige = companion.showPrestigeStyle;
    final levelColor =
        isPrestige ? const Color(0xFFFFD700) : const Color(0xFF00B4D8);
    final levelText = isPrestige
        ? '★${companion.level - 100}'
        : 'Lv. ${companion.level}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF112240),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00B4D8)
                : Colors.white12,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  const BoxShadow(
                    color: Color(0x3300B4D8),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon / Fragezeichen
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? Colors.white10
                    : Colors.white.withValues(alpha: 0.04),
              ),
              child: isUnlocked
                  ? Image.asset(
                      'assets/${CompanionDefinition.forSlot(companion.slot).assetKey}.png',
                      fit: BoxFit.contain,
                    )
                  : const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              isUnlocked
                  ? CompanionDefinition.forSlot(companion.slot).name
                  : '???',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isUnlocked ? Colors.white : Colors.white24,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Level
            if (isUnlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPrestige) ...[
                    const Icon(
                      Icons.workspace_premium,
                      size: 10,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    levelText,
                    style: TextStyle(fontSize: 11, color: levelColor),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}