import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'wizard_scoreboard_provider.dart';
import 'scoreboard_shared.dart';
import '../../core/theme/app_colors.dart';

class WizardScoreboardScreen extends ConsumerStatefulWidget {
  final int gameId;
  const WizardScoreboardScreen({super.key, required this.gameId});

  @override
  ConsumerState<WizardScoreboardScreen> createState() =>
      _WizardScoreboardScreenState();
}

class _WizardScoreboardScreenState
    extends ConsumerState<WizardScoreboardScreen> {
  int _phase = 0; // 0 = bids, 1 = tricks
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  int? _loadedGameId;
  List<int> _pendingBids = [];

  @override
  void initState() {
    super.initState();
    ref.read(wizardScoreboardProvider.notifier).loadGame(widget.gameId);
  }

  void _initInputs(int gameId, int playerCount) {
    if (_loadedGameId == gameId) return;
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _loadedGameId = gameId;
    _controllers = List.generate(playerCount, (_) {
      final c = TextEditingController();
      c.addListener(() => setState(() {}));
      return c;
    });
    _focusNodes = List.generate(playerCount, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  int currentRoundFromState() =>
      (ref.read(wizardScoreboardProvider).valueOrNull?.rounds.length ?? 0) + 1;

  List<int> _getBidOrder(int n, int dealerIdx) =>
      List.generate(n, (i) => (dealerIdx + 1 + i) % n);

  void _nextField(int i, int playerCount) {
    if (i < playerCount - 1) {
      _focusNodes[i + 1].requestFocus();
    } else {
      _handlePhaseEnd(playerCount, currentRoundFromState());
    }
  }

  void _handlePhaseEnd(int playerCount, int currentRound) {
    if (_phase == 0) {
      final bids =
          _controllers.map((c) => int.tryParse(c.text.trim()) ?? 0).toList();
      final sum = bids.fold(0, (a, b) => a + b);
      if (sum == currentRound) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Summe der Ansagen ($sum) darf nicht gleich der Rundenzahl ($currentRound) sein'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      _pendingBids = bids;
      setState(() => _phase = 1);
      for (final c in _controllers) {
        c.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusNodes.isNotEmpty) _focusNodes.first.requestFocus();
      });
    } else {
      _submitRound();
    }
  }

  Future<void> _submitRound() async {
    final s = ref.read(wizardScoreboardProvider).valueOrNull;
    if (s == null) return;
    final currentRound = s.rounds.length + 1;
    final tricks =
        _controllers.map((c) => int.tryParse(c.text.trim()) ?? 0).toList();
    final trickSum = tricks.fold(0, (a, b) => a + b);
    if (trickSum != currentRound) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Summe der Stiche ($trickSum) muss gleich der Rundenzahl ($currentRound) sein'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    await ref
        .read(wizardScoreboardProvider.notifier)
        .addRound(_pendingBids, tricks);
    _pendingBids = [];
    setState(() => _phase = 0);
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) _focusNodes.first.requestFocus();
  }

  Future<void> _restart() async {
    final newGame =
        await ref.read(wizardScoreboardProvider.notifier).restartGame();
    if (!mounted) return;
    context.pushReplacement(scoreboardTypeRoute(newGame));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardScoreboardProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final purple = context.colors.purpleAccent;

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

        final players = game.playerNames;
        _initInputs(game.id!, players.length);
        final totals = s.scores;
        final totalRounds = s.totalRounds;
        final currentRound = s.rounds.length + 1;
        final isOver = s.isGameOver;

        int? winnerIdx;
        if (isOver) {
          final max = totals.reduce((a, b) => a > b ? a : b);
          winnerIdx = totals.indexOf(max);
        }

        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            backgroundColor: context.colors.background,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                if (!isOver)
                  Text(
                    'Runde $currentRound / $totalRounds · ${_phase == 0 ? 'Ansagen' : 'Stiche eingeben'}',
                    style: TextStyle(color: purple, fontSize: 11),
                  ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (s.rounds.isNotEmpty && !isOver)
                IconButton(
                  icon: const Icon(Icons.replay, color: Colors.white70),
                  tooltip: 'Letzte Eingabe zurückrufen',
                  onPressed: () {
                    final last = s.rounds.last;
                    final bids = List<dynamic>.from(last.data['bids'] as List);
                    ref.read(wizardScoreboardProvider.notifier).deleteLastRound();
                    setState(() {
                      _phase = 0;
                      _pendingBids = [];
                      for (int i = 0; i < _controllers.length; i++) {
                        _controllers[i].text = '${(bids[i] as num).toInt()}';
                      }
                    });
                    if (_focusNodes.isNotEmpty) _focusNodes.last.requestFocus();
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              if (isOver)
                ScoreboardWinnerBanner(
                  color: primary,
                  message:
                      '🏆 ${players[winnerIdx!]} gewinnt mit ${totals[winnerIdx]} Punkten!',
                  onNewGame: _restart,
                ),

              // Header
              Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    Builder(builder: (context) {
                      final n = players.length;
                      final dealerIdx = (n + currentRound - 2) % n;
                      return Row(
                        children: [
                          const SizedBox(width: 36),
                          ...players.asMap().entries.map((e) {
                            final isDealer = e.key == dealerIdx && !isOver;
                            return Expanded(
                              child: Column(
                                children: [
                                  if (isDealer)
                                    const Text('🃏',
                                        style: TextStyle(fontSize: 10),
                                        textAlign: TextAlign.center)
                                  else
                                    const SizedBox(height: 14),
                                  Text(
                                    e.value,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: e.key == winnerIdx
                                          ? primary
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                    Row(
                      children: [
                        const SizedBox(width: 36),
                        ...players.map((_) => const Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('A',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10)),
                                  ),
                                  Expanded(
                                    child: Text('S',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ],
                ),
              ),

              // Runden
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in s.rounds.asMap().entries)
                      Builder(builder: (context) {
                        final i = entry.key;
                        final r = entry.value;
                        final bids = List<dynamic>.from(r.data['bids'] as List);
                        final tricks =
                            List<dynamic>.from(r.data['tricks'] as List);
                        return Container(
                          decoration: const BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: Colors.white10)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text('${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                              ),
                              ...List.generate(players.length, (p) {
                                final b = (bids[p] as num).toInt();
                                final t = tricks.length > p
                                    ? (tricks[p] as num).toInt()
                                    : 0;
                                final correct = b == t;
                                return Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('$b',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13)),
                                      ),
                                      Expanded(
                                        child: Text('$t',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: correct
                                                    ? primary
                                                    : context.colors.danger,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    if (_phase == 1 && _pendingBids.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          border: const Border(
                              bottom: BorderSide(color: Colors.white10)),
                          color: purple.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${s.rounds.length + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                            ),
                            ...List.generate(players.length, (p) => Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('${_pendingBids[p]}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: purple, fontSize: 13)),
                                      ),
                                      const Expanded(
                                        child: Text('—',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white24,
                                                fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Sticky Footer
              Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: const Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 36,
                            child: Text('Σ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          ...totals.asMap().entries.map((e) => Expanded(
                                child: Text(
                                  '${e.value}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: e.key == winnerIdx
                                        ? primary
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                    if (!isOver)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            4, 0, 4, 12 + MediaQuery.of(context).padding.bottom),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                _phase == 0 ? 'A' : 'S',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color:
                                        _phase == 0 ? Colors.white54 : purple,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...List.generate(players.length, (visualIdx) {
                              final n = players.length;
                              final dealerIdx = (n + currentRound - 2) % n;
                              final bidOrder = _getBidOrder(n, dealerIdx);
                              final playerIdx =
                                  _phase == 0 ? bidOrder[visualIdx] : visualIdx;
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: TextField(
                                    controller: _controllers[playerIdx],
                                    focusNode: _focusNodes[visualIdx],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    cursorColor: primary,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: context.colors.surfaceInput,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 8),
                                      hintText: players[playerIdx]
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      hintStyle:
                                          const TextStyle(color: Colors.white24),
                                    ),
                                    onSubmitted: (_) =>
                                        _nextField(visualIdx, n),
                                  ),
                                ),
                              );
                            }),
                            Builder(builder: (context) {
                              final allFilled = _controllers
                                  .every((c) => c.text.trim().isNotEmpty);
                              return IconButton(
                                icon: Icon(
                                  _phase == 0
                                      ? Icons.arrow_forward
                                      : Icons.check_circle,
                                  color: allFilled ? primary : Colors.white24,
                                ),
                                onPressed: allFilled
                                    ? () => _handlePhaseEnd(
                                        players.length, currentRound)
                                    : null,
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}