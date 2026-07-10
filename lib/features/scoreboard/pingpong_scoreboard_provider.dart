import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'scoreboard_models.dart';
import 'scoreboard_shared.dart';

class PingPongScoreboardState {
  final ScoreboardGame? game;
  final List<ScoreboardRound> rounds;
  final bool isLoading;

  const PingPongScoreboardState({
    this.game,
    this.rounds = const [],
    this.isLoading = false,
  });

  PingPongScoreboardState copyWith({
    ScoreboardGame? game,
    List<ScoreboardRound>? rounds,
    bool? isLoading,
  }) =>
      PingPongScoreboardState(
        game: game ?? this.game,
        rounds: rounds ?? this.rounds,
        isLoading: isLoading ?? this.isLoading,
      );

  List<int> get scores {
    if (game == null) return [];
    final n = game!.playerNames.length;
    final totals = List<int>.filled(n, 0);
    for (final r in rounds) {
      final side = r.data['side'] as int;
      final delta = (r.data['delta'] as num?)?.toInt() ?? 1;
      if (side >= 0 && side < n) totals[side] += delta;
    }
    return totals;
  }
}

class PingPongScoreboardNotifier
    extends AsyncNotifier<PingPongScoreboardState> {
  late ScoreboardRepository _repo;

  @override
  Future<PingPongScoreboardState> build() async {
    _repo = ref.read(scoreboardRepositoryProvider);
    return const PingPongScoreboardState();
  }

  Future<void> loadGame(int id) async {
    final current = state.value ?? const PingPongScoreboardState();
    state = AsyncData(current.copyWith(isLoading: true));
    final game = await _repo.getGame(id);
    final rounds = await _repo.getRounds(id);
    state =
        AsyncData(current.copyWith(game: game, rounds: rounds, isLoading: false));
  }

  Future<void> point(int side, int delta) async {
    final current = state.value;
    final g = current?.game;
    if (g == null) return;
    await _repo.addRound(
        g.id!, current!.rounds.length + 1, {'side': side, 'delta': delta});
    final rounds = await _repo.getRounds(g.id!);
    state = AsyncData(current.copyWith(rounds: rounds));
  }

  Future<void> deleteLastRound() async {
    final current = state.value;
    if (current == null || current.game == null) return;
    await _repo.deleteLastRound(current.rounds);
    final rounds = await _repo.getRounds(current.game!.id!);
    state = AsyncData(current.copyWith(rounds: rounds));
  }

  Future<void> finish() async {
    final g = state.value?.game;
    if (g == null) return;
    final updated = g.copyWith(isFinished: true);
    await _repo.finishGame(updated);
    state = AsyncData(state.value!.copyWith(game: updated));
  }

  Future<ScoreboardGame> restartGame() => _repo.restartGame(state.value!.game!);
}

final pingpongScoreboardProvider =
    AsyncNotifierProvider<PingPongScoreboardNotifier, PingPongScoreboardState>(
        PingPongScoreboardNotifier.new);