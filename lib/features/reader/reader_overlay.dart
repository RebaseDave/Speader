import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_provider.dart';
import '../settings/settings_provider.dart';
import 'dictionary_sheet.dart';
import 'dart:async';
import '../../core/services/settings_service.dart';
import 'dart:math';

class ReaderOverlay extends ConsumerWidget {
  final int bookId;
  final VoidCallback? onParagraphTap;
  final VoidCallback? onSheetClosed;
  const ReaderOverlay({
    super.key,
    required this.bookId,
    this.onParagraphTap,
    this.onSheetClosed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reader = ref.watch(readerProvider);
    final settings = ref.watch(settingsProvider);

    final totalWords = reader.tokens.length;
    final currentIndex = reader.currentIndex;
    final percent = totalWords > 0
        ? (currentIndex / totalWords * 100).toStringAsFixed(1)
        : '0.0';

    final currentChapterIndex = reader.tokens.isNotEmpty
        ? reader.tokens[currentIndex.clamp(0, totalWords - 1)].chapterIndex
        : 0;

    // Effektive WPM – kalibriert oder Schätzformel
    final settingsWpm = settings.wpm.toDouble();
    final scaling = settings.scalingEnabled
        ? settings.referenceWpm / settingsWpm
        : 1.0;
    final baseOverhead = SettingsService.instance.bookBaseOverhead(bookId);
    final bool isCalibrated = baseOverhead != null;
    final double effectiveWpm;
    if (baseOverhead != null) {
      effectiveWpm = 60000.0 / (60000.0 / settingsWpm + baseOverhead * scaling);
    } else {
      final overhead =
          (settings.sentenceMs * scaling / 12.0) +
          (settings.commaMs * scaling / 9.0) +
          (settings.paragraphMs * scaling / 65.0) +
          (sqrt(4.0) *
              settings.lengthScaleFactor *
              0.1 *
              (60000.0 / settings.wpm) *
              0.08);
      effectiveWpm = 60000.0 / (60000.0 / settingsWpm + overhead);
    }

    // Restzeit bis Kapitelende
    String remainingTime = '';
    if (reader.chapters.isNotEmpty && totalWords > 0) {
      final chapterIdx = reader.chapters
          .indexWhere((c) => c.indexInBook == currentChapterIndex);
      final chapter = chapterIdx >= 0
          ? reader.chapters[chapterIdx]
          : reader.chapters.last;
      final chapterEnd = chapterIdx >= 0 &&
              chapterIdx < reader.chapters.length - 1
          ? reader.chapters[chapterIdx + 1].startWord
          : totalWords;
      final chapterSpan = chapterEnd - chapter.startWord;
      final wordsLeft = chapterEnd - currentIndex;
      if (wordsLeft > 0 && settings.wpm > 0 && chapterSpan > 0) {
        final secondsLeft = (wordsLeft / effectiveWpm * 60).round();
        final minutes = secondsLeft ~/ 60;
        final chapterPercent =
            ((currentIndex - chapter.startWord) / chapterSpan * 100)
                .round()
                .clamp(0, 100);
        remainingTime = '$chapterPercent% · ~${minutes}m';
      }
    }

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fortschrittsbalken
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '$percent%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: () {
                          if (reader.chapters.isEmpty || totalWords == 0) {
                            return 0.0;
                          }
                          final chapter = reader.chapters.firstWhere(
                            (c) => c.indexInBook == currentChapterIndex,
                            orElse: () => reader.chapters.last,
                          );
                          final chapterProgress =
                              currentIndex - chapter.startWord;
                          return (chapterProgress / chapter.wordCount).clamp(
                            0.0,
                            1.0,
                          );
                        }(),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remainingTime,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // WPM Anzeige
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${settings.wpm} WPM  ',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                if (isCalibrated)
                  Text(
                    '(~${effectiveWpm.round()} effektiv)',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        color: Colors.white24,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '(~${effectiveWpm.round()} · kalibriert sich)',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Hauptbuttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // WPM -
                _OverlayButton(
                  icon: Icons.remove,
                  label: 'WPM -',
                  onTap: () {
                    ref.read(readerProvider.notifier).adjustWpm(-10);
                    ref.read(settingsProvider.notifier).reload();
                  },
                ),

                // Letzter Satzanfang
                _RepeatSkipButton(
                  icon: Icons.fast_rewind,
                  label: 'Satz -',
                  onTap: () {
                    ref.read(readerProvider.notifier).skipBackward();
                  },
                ),

                // Absatz-Modus
                _OverlayButton(
                  icon: Icons.subject,
                  label: 'Absatz',
                  onTap: () => onParagraphTap?.call(),
                ),

                // Nächster Satzanfang
                _RepeatSkipButton(
                  icon: Icons.fast_forward,
                  label: 'Satz +',
                  onTap: () {
                    ref.read(readerProvider.notifier).skipForward();
                  },
                ),

                // WPM +
                _OverlayButton(
                  icon: Icons.add,
                  label: 'WPM +',
                  onTap: () {
                    ref.read(readerProvider.notifier).adjustWpm(10);
                    ref.read(settingsProvider.notifier).reload();
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Wörterbuch-Button
            GestureDetector(
              onTap: () {
                final reader = ref.read(readerProvider);
                if (reader.tokens.isEmpty) return;
                final index = reader.currentIndex.clamp(
                  0,
                  reader.tokens.length - 1,
                );
                final token = reader.tokens[index];

                // Vollständiges Wort bei Silbentrennung rekonstruieren
                final word = token.raw.isNotEmpty
                    ? token.raw
                    : token.normalized;
                if (word.isEmpty) return;

                // Satz rekonstruieren: rückwärts zum letzten Satzende, vorwärts zum nächsten
                final tokens = reader.tokens;
                int start = index;
                while (start > 0 &&
                    !tokens[start - 1].isSentenceEnd &&
                    !tokens[start - 1].isChapterTitle) {
                  start--;
                }
                int end = index;
                while (end < tokens.length - 1 &&
                    !tokens[end].isSentenceEnd &&
                    !tokens[end].isChapterTitle) {
                  end++;
                }
                final sentence = tokens
                    .sublist(start, end + 1)
                    .where((t) => !t.isBlank && !t.isSceneBreak && t.raw.isNotEmpty)
                    .map((t) => t.raw)
                    .join(' ');

                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      DictionarySheet(word: word, sentence: sentence),
                ).whenComplete(() => onSheetClosed?.call());
              },
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      color: Colors.white38,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Wörterbuch',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatSkipButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RepeatSkipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_RepeatSkipButton> createState() => _RepeatSkipButtonState();
}

class _RepeatSkipButtonState extends State<_RepeatSkipButton> {
  Timer? _repeatTimer;

  void _startRepeating() {
    widget.onTap();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      widget.onTap();
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _startRepeating(),
      onLongPressEnd: (_) => _stopRepeating(),
      onLongPressCancel: _stopRepeating,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: Colors.white.withValues(alpha: 0.6),
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
