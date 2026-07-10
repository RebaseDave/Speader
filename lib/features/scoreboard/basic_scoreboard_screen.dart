import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'basic_scoreboard_provider.dart';
import 'scoreboard_shared.dart';
import '../../core/theme/app_colors.dart';

class BasicScoreboardScreen extends ConsumerStatefulWidget {
  final int gameId;
  const BasicScoreboardScreen({super.key, required this.gameId});

  @override
  ConsumerState<BasicScoreboardScreen> createState() =>
      _BasicScoreboardScreenState();
}

class _BasicScoreboardScreenState
    extends ConsumerState<BasicScoreboardScreen> {
  List<TextEditingController> _inputControllers = [];
  List<FocusNode> _focusNodes = [];
  int? _loadedGameId;

  @override
  void initState() {
    super.initState();
    ref.read(basicScoreboardProvider.notifier).loadGame(widget.gameId);
  }

  void _initInputs(int gameId, int playerCount) {
    if (_loadedGameId == gameId) return;
    for (final c in _inputControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _loadedGameId = gameId;
    _inputControllers = List.generate(playerCount, (_) {
      final c = TextEditingController();
      c.addListener(() => setState(() {}));
      return c;
    });
    _focusNodes = List.generate(playerCount, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _inputControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRound() async {
    final scores =
        _inputControllers.map((c) => int.tryParse(c.text.trim()) ?? 0).toList();
    await ref.read(basicScoreboardProvider.notifier).addRound(scores);
    for (final c in _inputControllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) _focusNodes.first.requestFocus();
  }

  Future<void> _restart() async {
    final newGame =
        await ref.read(basicScoreboardProvider.notifier).restartGame();
    if (!mounted) return;
    context.pushReplacement(scoreboardTypeRoute(newGame));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(basicScoreboardProvider);
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

        final players = game.playerNames;
        _initInputs(game.id!, players.length);
        final totals = s.scores;
        final isOver = s.isGameOver;

        int? winnerIdx;
        if (isOver) {
          int max = totals.reduce((a, b) => a > b ? a : b);
          winnerIdx = totals.indexOf(max);
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
              if (s.rounds.isNotEmpty && !isOver)
                IconButton(
                  icon: const Icon(Icons.replay, color: Colors.white70),
                  tooltip: 'Letzte Eingabe zurückrufen',
                  onPressed: () {
                    final last = s.rounds.last;
                    final scores =
                        List<dynamic>.from(last.data['scores'] as List);
                    ref.read(basicScoreboardProvider.notifier).deleteLastRound();
                    for (int i = 0; i < _inputControllers.length; i++) {
                      _inputControllers[i].text =
                          '${(scores[i] as num).toInt()}';
                    }
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

              // Spielertabelle
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _TableRow(
                        cells: ['#', ...players],
                        isHeader: true,
                        highlight: winnerIdx,
                      ),
                      ...s.rounds.asMap().entries.map((entry) {
                        final i = entry.key;
                        final r = entry.value;
                        final scores =
                            List<dynamic>.from(r.data['scores'] as List);
                        return _TableRow(
                          cells: ['${i + 1}', ...scores.map((v) => '$v')],
                          highlight: winnerIdx,
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Sticky Footer: Totals + Input
              Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: const Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TableRow(
                      cells: ['Σ', ...totals.map((t) => '$t')],
                      isTotals: true,
                      highlight: winnerIdx,
                      primary: primary,
                    ),
                    if (isOver)
                      SizedBox(height: MediaQuery.of(context).padding.bottom),

                    if (!isOver)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            12, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 32,
                              child: Text('→',
                                  style: TextStyle(color: Colors.white38)),
                            ),
                            ...List.generate(
                              players.length,
                              (i) => Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: TextField(
                                    controller: _inputControllers[i],
                                    focusNode: _focusNodes[i],
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
                                      hintText:
                                          players[i].substring(0, 1).toUpperCase(),
                                      hintStyle:
                                          const TextStyle(color: Colors.white24),
                                    ),
                                    onSubmitted: (_) {
                                      if (i < players.length - 1) {
                                        _focusNodes[i + 1].requestFocus();
                                      } else {
                                        _submitRound();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Builder(builder: (context) {
                              final allFilled = _inputControllers
                                  .every((c) => c.text.trim().isNotEmpty);
                              return IconButton(
                                icon: Icon(Icons.check_circle,
                                    color:
                                        allFilled ? primary : Colors.white24),
                                onPressed: allFilled ? _submitRound : null,
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

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  final bool isTotals;
  final int? highlight;
  final Color? primary;

  const _TableRow({
    required this.cells,
    this.isHeader = false,
    this.isTotals = false,
    this.highlight,
    this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: Colors.white10)),
        color: isHeader
            ? context.colors.surface
            : isTotals
                ? context.colors.surfaceSubtle
                : Colors.transparent,
      ),
      child: Row(
        children: cells.asMap().entries.map((entry) {
          final i = entry.key;
          final cell = entry.value;
          final isHighlighted = i > 0 && (i - 1) == highlight;
          final isIndex = i == 0;
          return isIndex
              ? SizedBox(
                  width: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      cell,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isHeader ? Colors.white : Colors.white38,
                        fontSize: 12,
                        fontWeight:
                            isHeader ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                )
              : Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Text(
                      cell,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isHighlighted
                            ? (primary ?? Theme.of(context).colorScheme.primary)
                            : isHeader || isTotals
                                ? Colors.white
                                : Colors.white70,
                        fontSize: isHeader ? 12 : 14,
                        fontWeight: isHeader || isTotals || isHighlighted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
        }).toList(),
      ),
    );
  }
}