import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import 'scoreboard_dao.dart';
import 'scoreboard_models.dart';
import '../../core/theme/app_colors.dart';

// ── Repository: DB-Grundfunktionen, typ-unabhängig ─────────────────────────

class ScoreboardRepository {
  Future<ScoreboardDao> _dao() async =>
      ScoreboardDao(await DatabaseHelper.instance.database);

  Future<List<ScoreboardGame>> getActiveGames() async =>
      (await _dao()).getActiveGames();

  Future<List<ScoreboardGame>> getFinishedGames() async =>
      (await _dao()).getFinishedGames();

  Future<ScoreboardGame?> getGame(int id) async => (await _dao()).getGame(id);

  Future<List<ScoreboardRound>> getRounds(int gameId) async =>
      (await _dao()).getRounds(gameId);

  Future<ScoreboardGame> createGame(ScoreboardGame game) async {
    final dao = await _dao();
    final id = await dao.insertGame(game);
    return game.copyWith(id: id);
  }

  /// Neues Spiel mit identischen Stammdaten (für "Neues Spiel"-Button).
  Future<ScoreboardGame> restartGame(ScoreboardGame oldGame) => createGame(
        ScoreboardGame(
          gameType: oldGame.gameType,
          name: oldGame.name,
          playerNames: oldGame.playerNames,
          scoreTarget: oldGame.scoreTarget,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> deleteGame(int id) async => (await _dao()).deleteGame(id);

  Future<int> addRound(
    int gameId,
    int roundNumber,
    Map<String, dynamic> data,
  ) async {
    final dao = await _dao();
    return dao.insertRound(
      ScoreboardRound(gameId: gameId, roundNumber: roundNumber, data: data),
    );
  }

  Future<void> deleteLastRound(List<ScoreboardRound> rounds) async {
    if (rounds.isEmpty) return;
    final dao = await _dao();
    await dao.deleteRound(rounds.last.id!);
  }

  Future<void> finishGame(ScoreboardGame game) async {
    final dao = await _dao();
    await dao.updateGame(game.copyWith(isFinished: true));
  }
}

final scoreboardRepositoryProvider =
    Provider<ScoreboardRepository>((ref) => ScoreboardRepository());

// ── Typ-unabhängige Spielliste (Übersicht + Historie) ───────────────────────

class ScoreboardListState {
  final List<ScoreboardGame> activeGames;
  final List<ScoreboardGame> finishedGames;

  const ScoreboardListState({
    this.activeGames = const [],
    this.finishedGames = const [],
  });

  ScoreboardListState copyWith({
    List<ScoreboardGame>? activeGames,
    List<ScoreboardGame>? finishedGames,
  }) =>
      ScoreboardListState(
        activeGames: activeGames ?? this.activeGames,
        finishedGames: finishedGames ?? this.finishedGames,
      );
}

class ScoreboardListNotifier extends AsyncNotifier<ScoreboardListState> {
  late ScoreboardRepository _repo;

  @override
  Future<ScoreboardListState> build() async {
    _repo = ref.read(scoreboardRepositoryProvider);
    final active = await _repo.getActiveGames();
    return ScoreboardListState(activeGames: active);
  }

  Future<void> refreshActive() async {
    final active = await _repo.getActiveGames();
    final current = state.value ?? const ScoreboardListState();
    state = AsyncData(current.copyWith(activeGames: active));
  }

  Future<void> loadFinished() async {
    final finished = await _repo.getFinishedGames();
    final current = state.value ?? const ScoreboardListState();
    state = AsyncData(current.copyWith(finishedGames: finished));
  }

  Future<void> deleteGame(int id) async {
    await _repo.deleteGame(id);
    final current = state.value ?? const ScoreboardListState();
    state = AsyncData(current.copyWith(
      activeGames: current.activeGames.where((g) => g.id != id).toList(),
      finishedGames: current.finishedGames.where((g) => g.id != id).toList(),
    ));
  }
}

final scoreboardListProvider =
    AsyncNotifierProvider<ScoreboardListNotifier, ScoreboardListState>(
        ScoreboardListNotifier.new);

// ── Typ-Metadaten (Icon/Farbe/Route) ────────────────────────────────────────

Color scoreboardTypeColor(BuildContext context, GameType type) =>
    switch (type) {
      GameType.wizard => context.colors.purpleAccent,
      GameType.pingpong => context.colors.warning,
      GameType.basic => Theme.of(context).colorScheme.primary,
    };

IconData scoreboardTypeIcon(GameType type) => switch (type) {
      GameType.wizard => Icons.auto_awesome,
      GameType.pingpong => Icons.sports_tennis,
      GameType.basic => Icons.add_chart,
    };

String scoreboardTypeRoute(ScoreboardGame game) => switch (game.gameType) {
      GameType.wizard => '/scoreboard/wizard/${game.id}',
      GameType.pingpong => '/scoreboard/pingpong/${game.id}',
      GameType.basic => '/scoreboard/basic/${game.id}',
    };

// ── Score-Berechnung für Read-Only-Anzeigen (Historie) ──────────────────────
// Die drei Live-Provider haben jeweils ihre EIGENE Score-Logik — das hier ist
// nur für die Historie gedacht, die beliebige Spieltypen nur anzeigt, ohne
// selbst Runden hinzuzufügen.

List<int> scoreboardComputeScores(
  ScoreboardGame game,
  List<ScoreboardRound> rounds,
) {
  final n = game.playerNames.length;
  final totals = List<int>.filled(n, 0);
  switch (game.gameType) {
    case GameType.basic:
      for (final r in rounds) {
        final scores = List<dynamic>.from(r.data['scores'] as List);
        for (int i = 0; i < n && i < scores.length; i++) {
          totals[i] += (scores[i] as num).toInt();
        }
      }
    case GameType.wizard:
      for (final r in rounds) {
        final bids = List<dynamic>.from(r.data['bids'] as List);
        final tricks = List<dynamic>.from(r.data['tricks'] as List);
        for (int i = 0; i < n && i < bids.length; i++) {
          final b = (bids[i] as num).toInt();
          final t = (tricks[i] as num).toInt();
          totals[i] += b == t ? 20 + t * 10 : (b - t).abs() * -10;
        }
      }
    case GameType.pingpong:
      for (final r in rounds) {
        final side = r.data['side'] as int;
        final delta = (r.data['delta'] as num?)?.toInt() ?? 1;
        if (side >= 0 && side < n) totals[side] += delta;
      }
  }
  return totals;
}

String scoreboardWinnerLabel(ScoreboardGame game, List<int> scores) {
  if (scores.isEmpty) return '';
  final max = scores.reduce((a, b) => a > b ? a : b);
  final winners = <int>[
    for (int i = 0; i < scores.length; i++)
      if (scores[i] == max) i,
  ];
  if (winners.length > 1) return 'Unentschieden';
  return '🏆 ${game.playerNames[winners.first]}';
}

// ── Gemeinsame UI-Bausteine ──────────────────────────────────────────────

class ScoreboardWinnerBanner extends StatelessWidget {
  final Color color;
  final String message;
  final VoidCallback onNewGame;

  const ScoreboardWinnerBanner({
    super.key,
    required this.color,
    required this.message,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.15),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onNewGame,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Neues Spiel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreboardUndoAction extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;
  const ScoreboardUndoAction({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.undo, color: Colors.white70),
      tooltip: 'Letzten Punkt zurücknehmen',
      onPressed: onPressed,
    );
  }
}