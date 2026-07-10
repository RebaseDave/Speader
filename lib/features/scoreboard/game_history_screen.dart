import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'scoreboard_models.dart';
import 'scoreboard_shared.dart';
import '../../core/theme/app_colors.dart';

class GameHistoryScreen extends ConsumerStatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> {
  final Map<int, Future<List<ScoreboardRound>>> _roundsFutures = {};

  @override
  void initState() {
    super.initState();
    ref.read(scoreboardListProvider.notifier).loadFinished();
  }

  Future<List<ScoreboardRound>> _roundsFor(int gameId) {
    return _roundsFutures.putIfAbsent(
      gameId,
      () => ref.read(scoreboardRepositoryProvider).getRounds(gameId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scoreboardListProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        title: const Text('Spielhistorie',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Fehler: $e',
                style: const TextStyle(color: Colors.white54))),
        data: (s) {
          if (s.finishedGames.isEmpty) {
            return const Center(
              child: Text('Noch keine beendeten Spiele',
                  style: TextStyle(color: Colors.white38)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: s.finishedGames.length,
            itemBuilder: (context, i) {
              final game = s.finishedGames[i];
              final route = scoreboardTypeRoute(game);
              final icon = scoreboardTypeIcon(game.gameType);
              final color = scoreboardTypeColor(context, game.gameType);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: Key('history_game_${game.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: context.colors.danger.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.delete_outline, color: context.colors.danger),
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
                  onDismissed: (_) => ref
                      .read(scoreboardListProvider.notifier)
                      .deleteGame(game.id!),
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
                                const SizedBox(height: 2),
                                FutureBuilder<List<ScoreboardRound>>(
                                  future: _roundsFor(game.id!),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Text('…',
                                          style: TextStyle(
                                              color: Colors.white24,
                                              fontSize: 12));
                                    }
                                    final scores = scoreboardComputeScores(
                                        game, snapshot.data!);
                                    return Text(
                                      scoreboardWinnerLabel(game, scores),
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}