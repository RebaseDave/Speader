import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pingpong_scoreboard_provider.dart';
import 'scoreboard_shared.dart';
import '../../core/theme/app_colors.dart';

class PingPongScoreboardScreen extends ConsumerStatefulWidget {
  final int gameId;
  const PingPongScoreboardScreen({super.key, required this.gameId});

  @override
  ConsumerState<PingPongScoreboardScreen> createState() =>
      _PingPongScoreboardScreenState();
}

class _PingPongScoreboardScreenState
    extends ConsumerState<PingPongScoreboardScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(pingpongScoreboardProvider.notifier).loadGame(widget.gameId);
  }

  Future<void> _point(int side, int delta) async {
    await ref.read(pingpongScoreboardProvider.notifier).point(side, delta);
  }

  Future<void> _finish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceElevated,
        title:
            const Text('Spiel beenden', style: TextStyle(color: Colors.white)),
        content: const Text('Spiel wirklich beenden?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Beenden')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pingpongScoreboardProvider.notifier).finish();
    }
  }

  Future<void> _restart() async {
    final newGame =
        await ref.read(pingpongScoreboardProvider.notifier).restartGame();
    if (!mounted) return;
    context.pushReplacement(scoreboardTypeRoute(newGame));
  }

  Widget _buildSide(int i, List<String> sides, List<int> scores, bool isOver,
      int? winnerIdx, Color primary) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(sides[i],
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: isOver ? null : () => _point(i, 1),
            child: Container(
              width: double.infinity,
              color: primary.withValues(alpha: 0.08),
              child: Icon(Icons.add,
                  size: 48, color: isOver ? Colors.white12 : primary),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: context.colors.surface,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('${scores[i]}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: winnerIdx == i ? primary : Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: isOver ? null : () => _point(i, -1),
            child: Container(
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.03),
              child: Icon(Icons.remove,
                  size: 32, color: isOver ? Colors.white12 : Colors.white38),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pingpongScoreboardProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return state.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(
        backgroundColor: context.colors.background,
        body: const SizedBox.shrink(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.colors.background,
        body: Center(
            child: Text('Fehler: $e',
                style: const TextStyle(color: Colors.white54))),
      ),
      data: (s) {
        final game = s.game;
        if (game == null || game.id != widget.gameId) {
          return Scaffold(
            backgroundColor: context.colors.background,
            body: const SizedBox.shrink(),
          );
        }

        final sides = game.playerNames;
        final scores = s.scores;
        final isOver = game.isFinished;

        int? winnerIdx;
        if (isOver && scores[0] != scores[1]) {
          winnerIdx = scores[0] > scores[1] ? 0 : 1;
        }

        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            backgroundColor: context.colors.background,
            title: Text(game.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              ScoreboardUndoAction(
                visible: !isOver && s.rounds.isNotEmpty,
                onPressed: () =>
                    ref.read(pingpongScoreboardProvider.notifier).deleteLastRound(),
              ),
              if (!isOver)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white70),
                  tooltip: 'Spiel beenden',
                  onPressed: _finish,
                ),
            ],
          ),
          body: Column(
            children: [
              if (isOver)
                ScoreboardWinnerBanner(
                  color: primary,
                  message: winnerIdx != null
                      ? '🏆 ${sides[winnerIdx]} gewinnt mit ${scores[winnerIdx]}:${scores[1 - winnerIdx]}!'
                      : 'Unentschieden ${scores[0]}:${scores[1]}',
                  onNewGame: _restart,
                ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                        child: _buildSide(
                            0, sides, scores, isOver, winnerIdx, primary)),
                    const VerticalDivider(color: Colors.white10, width: 1),
                    Expanded(
                        child: _buildSide(
                            1, sides, scores, isOver, winnerIdx, primary)),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}