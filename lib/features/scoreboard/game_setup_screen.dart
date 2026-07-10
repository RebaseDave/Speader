import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'scoreboard_models.dart';
import 'scoreboard_shared.dart';
import '../../core/theme/app_colors.dart';

class GameSetupScreen extends ConsumerStatefulWidget {
  final GameType gameType;
  const GameSetupScreen({super.key, required this.gameType});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final List<TextEditingController> _playerControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _hasTarget = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    for (final c in _playerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_playerControllers.length >= 8) return;
    setState(() => _playerControllers.add(TextEditingController()));
  }

  void _removePlayer(int i) {
    if (_playerControllers.length <= 2) return;
    setState(() {
      _playerControllers[i].dispose();
      _playerControllers.removeAt(i);
    });
  }

  Future<void> _start() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spielname eingeben')),
      );
      return;
    }
    final players = _playerControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens 2 Spieler')),
      );
      return;
    }

    int? target;
    if (widget.gameType == GameType.basic && _hasTarget) {
      target = int.tryParse(_targetController.text.trim());
    }

    final game = await ref.read(scoreboardRepositoryProvider).createGame(
          ScoreboardGame(
            gameType: widget.gameType,
            name: name,
            playerNames: players,
            scoreTarget: target,
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    context.pushReplacement(scoreboardTypeRoute(game));
  }

  @override
  Widget build(BuildContext context) {
    final isWizard = widget.gameType == GameType.wizard;
    final isPingpong = widget.gameType == GameType.pingpong;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        title: Text(
          isWizard
              ? 'Wizard Setup'
              : isPingpong
                  ? 'Tischtennis Setup'
                  : 'Basis Setup',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Spielname
          const _SectionLabel('Spielname'),
          const SizedBox(height: 8),
          _TextField(controller: _nameController, hint: 'z.B. Spieleabend'),
          const SizedBox(height: 24),

          // Spieler / Seiten
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(isPingpong ? 'Seiten' : 'Spieler'),
              if (!isPingpong)
                TextButton.icon(
                  onPressed:
                      _playerControllers.length < 8 ? _addPlayer : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Hinzufügen'),
                  style: TextButton.styleFrom(foregroundColor: primary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_playerControllers.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TextField(
                        controller: _playerControllers[i],
                        hint: isPingpong ? 'Seite ${i + 1}' : 'Spieler ${i + 1}',
                        autofocus: i == 0,
                        onSubmitted: (_) {
                          if (i < _playerControllers.length - 1) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                      ),
                    ),
                    if (!isPingpong && _playerControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white38, size: 20),
                        onPressed: () => _removePlayer(i),
                      ),
                  ],
                ),
              )),

          // Punkteziel (nur Basic)
          if (!isWizard && !isPingpong) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Punkteziel (optional)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: _hasTarget,
                  onChanged: (v) => setState(() => _hasTarget = v),
                  activeTrackColor: primary,
                ),
                const SizedBox(width: 8),
                const Text('Spiel endet wenn Spieler Ziel erreicht',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            if (_hasTarget) ...[
              const SizedBox(height: 8),
              _TextField(
                controller: _targetController,
                hint: 'z.B. 200',
                keyboardType: TextInputType.number,
              ),
            ],
          ],

          // Wizard Info
          if (isWizard) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.purpleAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.purpleAccent.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wizard Regeln',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  SizedBox(height: 4),
                  Text(
                    '• Ansage erfüllt: 20 + Stiche × 10\n'
                    '• Ansage verfehlt: |Differenz| × −10\n'
                    '• Runden: 60 ÷ Spieleranzahl',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.6),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Spiel starten',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.white54, fontSize: 12, letterSpacing: 1),
      );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _TextField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white),
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: context.colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}
