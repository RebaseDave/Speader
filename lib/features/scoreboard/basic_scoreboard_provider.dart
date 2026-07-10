import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'scoreboard_models.dart';
import 'scoreboard_shared.dart';

class BasicScoreboardState {
  final ScoreboardGame? game;
  final List<ScoreboardRound> rounds;
  final bool isLoading;

  const BasicScoreboardState({
    this.game,
    this.rounds = const [],
    this.isLoading = false,
  });

  BasicScoreboardState copyWith({
    ScoreboardGame? game,
    List<ScoreboardRound>? rounds,
    bool? isLoading,
  }) =>
      BasicScoreboardState(
        game: game ?? this.game,
        rounds: rounds ?? this.rounds,
        isLoading: isLoading ?? this.isLoading,
      );

  List<int> get scores {
    if (game == null) return [];
    final n = game!.playerNames.length;
    final totals = List<int>.filled(n, 0);
    for (final r in rounds) {
      final list = List<dynamic>.from(r.data['scores'] as List);
      for (int i = 0; i < n && i < list.length; i++) {
        totals[i] += (list[i] as num).toInt();
      }
    }
    return totals;
  }

  bool get isGameOver {
    if (game == null || rounds.isEmpty) return false;
    final target = game!.scoreTarget;
    if (target == null) return false;
    final s = scores;
    final max = s.reduce((a, b) => a > b ? a : b);
    if (max < target) return false;
    return s.where((v) => v == max).length == 1;
  }
}

class BasicScoreboardNotifier extends AsyncNotifier<BasicScoreboardState> {
  late ScoreboardRepository _repo;

  @override
  Future<BasicScoreboardState> build() async {
    _repo = ref.read(scoreboardRepositoryProvider);
    return const BasicScoreboardState();
  }

  Future<void> loadGame(int id) async {
    final current = state.value ?? const BasicScoreboardState();
    state = AsyncData(current.copyWith(isLoading: true));
    final game = await _repo.getGame(id);
    final rounds = await _repo.getRounds(id);
    state =
        AsyncData(current.copyWith(game: game, rounds: rounds, isLoading: false));
  }

  Future<void> addRound(List<int> scores) async {
    final current = state.value;
    final g = current?.game;
    if (g == null) return;
    await _repo.addRound(g.id!, current!.rounds.length + 1, {'scores': scores});
    final rounds = await _repo.getRounds(g.id!);
    final next = current.copyWith(rounds: rounds);
    state = AsyncData(next);
    if (next.isGameOver) {
      await _repo.finishGame(g.copyWith(isFinished: true));
    }
  }

  Future<void> deleteLastRound() async {
    final current = state.value;
    if (current == null || current.game == null) return;
    await _repo.deleteLastRound(current.rounds);
    final rounds = await _repo.getRounds(current.game!.id!);
    state = AsyncData(current.copyWith(rounds: rounds));
  }

  Future<ScoreboardGame> restartGame() => _repo.restartGame(state.value!.game!);
}

final basicScoreboardProvider =
    AsyncNotifierProvider<BasicScoreboardNotifier, BasicScoreboardState>(
        BasicScoreboardNotifier.new);