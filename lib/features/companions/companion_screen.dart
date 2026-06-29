import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'companion.dart';
import 'companion_definition.dart';
import 'companion_provider.dart';
import 'companion_collection_sheet.dart';
import '../library/streak_provider.dart';

class CompanionScreen extends ConsumerWidget {
  const CompanionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(companionProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('Begleiter')),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (state) {
          final active = state.active;
          if (active == null) {
            return const Center(child: Text('Kein Begleiter aktiv'));
          }
          return _CompanionBody(companion: active);
        },
      ),
    );
  }
}

class _CompanionBody extends ConsumerWidget {
  final Companion companion;
  const _CompanionBody({required this.companion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = CompanionDefinition.forSlot(companion.slot);
    final isPrestige = companion.showPrestigeStyle;
    final levelColor = isPrestige
        ? const Color(0xFFFFD700)
        : const Color(0xFF00B4D8);
    final levelText = isPrestige
        ? '★${companion.level - 100}'
        : 'Level ${companion.level}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Glow unter dem Companion
                Container(
                  width: 180,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: levelColor.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                // Companion Bild
                Image.asset('assets/${def.assetKey}.png', fit: BoxFit.contain),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Name
          Text(
            def.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // Level
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPrestige) ...[
                const Icon(
                  Icons.workspace_premium,
                  size: 18,
                  color: Color(0xFFFFD700),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                levelText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: levelColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          // XP Bar
          _XpBar(companion: companion, levelColor: levelColor),

          const SizedBox(height: 16),
          const _BonusInfo(),

          const Spacer(flex: 3),

          // Sammlung Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const CompanionCollectionSheet(),
              ),
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: const Text('Sammlung'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00B4D8),
                side: const BorderSide(color: Color(0xFF00B4D8)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 65),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final Companion companion;
  final Color levelColor;
  const _XpBar({required this.companion, required this.levelColor});

  @override
  Widget build(BuildContext context) {
    final isAtCap =
        !companion.isPrestige && companion.level >= Companion.maxLevel;
    final progress = isAtCap
        ? 1.0
        : companion.xpInCurrentLevel / Companion.xpPerLevel;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAtCap ? 'MAX' : '${companion.xpInCurrentLevel} XP',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
            Text(
              isAtCap ? '' : '${Companion.xpPerLevel - companion.xpInCurrentLevel} bis Level ${companion.level + 1}',
              style: const TextStyle(fontSize: 13, color: Colors.white38),
            ),
            Text(
              isAtCap ? '' : '${Companion.xpPerLevel} XP',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
      ],
    );
  }
}

class _BonusInfo extends ConsumerWidget {
  const _BonusInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(companionProvider);
    return asyncState.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        final level50Count = state.companions
            .where((c) => c.isUnlocked && c.level >= 50)
            .length;
        final level50Bonus = level50Count * 10;

        final streakDays = ref.watch(streakProvider).value?.displayStreak ?? 0;
        final streakBonus = (streakDays * 1).clamp(0, 50).toInt();

        final totalBonus = level50Bonus + streakBonus;
        if (totalBonus == 0) return const SizedBox.shrink();

        return Text(
          'Bonus: +$totalBonus%',
          style: const TextStyle(fontSize: 13, color: Colors.white38),
        );
      },
    );
  }
}
