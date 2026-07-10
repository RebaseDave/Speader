import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'scoreboard_models.dart';
import 'scoreboard_shared.dart';
import '../../core/theme/app_colors.dart';

class ScoreboardScreen extends ConsumerWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scoreboardListProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        title: const Text('Scoreboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            tooltip: 'Spielhistorie',
            onPressed: () => context.push('/scoreboard/history'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Fehler: $e',
                style: const TextStyle(color: Colors.white54))),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (s.activeGames.isNotEmpty) ...[
              const Text('Laufende Spiele',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              ...s.activeGames.map((game) => _ActiveGameCard(game: game)),
              const SizedBox(height: 24),
            ],
            const Text('Neues Spiel',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),
            _GameTypeCard(
              title: 'Basis',
              subtitle: 'Punkte summieren, optionales Ziel',
              icon: Icons.add_chart,
              color: primary,
              onTap: () =>
                  context.push('/scoreboard/setup', extra: GameType.basic),
            ),
            const SizedBox(height: 12),
            _GameTypeCard(
              title: 'Wizard',
              subtitle: 'Stichansage · automatische Punkte',
              icon: Icons.auto_awesome,
              color: context.colors.purpleAccent,
              onTap: () =>
                  context.push('/scoreboard/setup', extra: GameType.wizard),
            ),
            const SizedBox(height: 12),
            _GameTypeCard(
              title: 'Tischtennis',
              subtitle: '2 Seiten · manuelles Spielende',
              icon: Icons.sports_tennis,
              color: context.colors.warning,
              onTap: () =>
                  context.push('/scoreboard/setup', extra: GameType.pingpong),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _ActiveGameCard extends ConsumerWidget {
  final ScoreboardGame game;
  const _ActiveGameCard({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = scoreboardTypeRoute(game);
    final icon = scoreboardTypeIcon(game.gameType);
    final color = scoreboardTypeColor(context, game.gameType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key('game_${game.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: context.colors.danger.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_outline, color: context.colors.danger),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.colors.surfaceElevated,
              title: const Text('Spiel löschen',
                  style: TextStyle(color: Colors.white)),
              content: Text('${game.name} wirklich löschen?',
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Abbrechen')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Löschen',
                        style: TextStyle(color: context.colors.danger))),
              ],
            ),
          );
        },
        onDismissed: (_) =>
            ref.read(scoreboardListProvider.notifier).deleteGame(game.id!),
        child: GestureDetector(
          onTap: () => context.push(route),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(
                        '${game.playerNames.length} Spieler · ${game.playerNames.join(', ')}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}