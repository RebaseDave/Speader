import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'scoreboard_models.dart';
import 'scoreboard_shared.dart';

class WizardScoreboardState {
  final ScoreboardGame? game;
  final List<ScoreboardRound> rounds;
  final bool isLoading;

  const WizardScoreboardState({
    this.game,
    this.rounds = const [],
    this.isLoading = false,
  });

  WizardScoreboardState copyWith({
    ScoreboardGame? game,
    List<ScoreboardRound>? rounds,
    bool? isLoading,
  }) =>
      WizardScoreboardState(
        game: game ?? this.game,
        rounds: rounds ?? this.rounds,
        isLoading: isLoading ?? this.isLoading,
      );

  int get totalRounds => game != null ? 60 ~/ game!.playerNames.length : 0;

  List<int> get scores {
    if (game == null) return [];
    final n = game!.playerNames.length;
    final totals = List<int>.filled(n, 0);
    for (final r in rounds) {
      final bids = List<dynamic>.from(r.data['bids'] as List);
      final tricks = List<dynamic>.from(r.data['tricks'] as List);
      for (int i = 0; i < n && i < bids.length; i++) {
        final b = (bids[i] as num).toInt();
        final t = (tricks[i] as num).toInt();
        totals[i] += b == t ? 20 + t * 10 : (b - t).abs() * -10;
      }
    }
    return totals;
  }

  bool get isGameOver {
    if (game == null || rounds.length < totalRounds) return false;
    final s = scores;
    final max = s.reduce((a, b) => a > b ? a : b);
    return s.where((v) => v == max).length == 1;
  }
}

class WizardScoreboardNotifier extends AsyncNotifier<WizardScoreboardState> {
  late ScoreboardRepository _repo;

  @override
  Future<WizardScoreboardState> build() async {
    _repo = ref.read(scoreboardRepositoryProvider);
    return const WizardScoreboardState();
  }

  Future<void> loadGame(int id) async {
    final current = state.value ?? const WizardScoreboardState();
    state = AsyncData(current.copyWith(isLoading: true));
    final game = await _repo.getGame(id);
    final rounds = await _repo.getRounds(id);
    state =
        AsyncData(current.copyWith(game: game, rounds: rounds, isLoading: false));
  }

  Future<void> addRound(List<int> bids, List<int> tricks) async {
    final current = state.value;
    final g = current?.game;
    if (g == null) return;
    await _repo.addRound(g.id!, current!.rounds.length + 1, {
      'bids': bids,
      'tricks': tricks,
    });
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

final wizardScoreboardProvider =
    AsyncNotifierProvider<WizardScoreboardNotifier, WizardScoreboardState>(
        WizardScoreboardNotifier.new);