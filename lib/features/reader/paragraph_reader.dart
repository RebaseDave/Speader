import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/database/session_dao.dart';
import '../settings/settings_provider.dart';
import 'reader_provider.dart';
import '../library/library_provider.dart';
import '../library/streak_provider.dart';
import 'chapter_navigator.dart';
import 'reader_settings_sheet.dart';
import 'dictionary_sheet.dart';
import 'goal_celebration_overlay.dart';
import '../../core/models/book.dart';
import '../companions/companion_levelup_overlay.dart';
import '../companions/companion_provider.dart';

class ParagraphReader extends ConsumerStatefulWidget {
  final Book book;
  const ParagraphReader({super.key, required this.book});

  @override
  ConsumerState<ParagraphReader> createState() => _ParagraphReaderState();
}

class _ParagraphReaderState extends ConsumerState<ParagraphReader> {
  ParagraphData? _data;
  bool _overlayVisible = true;

  // Lesezeit-Tracking
  DateTime? _sessionStart;
  DateTime? _readingStart;
  int _accumulatedSeconds = 0;

  // Tagesziel-Celebration
  bool _showGoalCelebration = false;
  int _celebrationStreakDays = 0;

  // Uhr
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  // Helligkeit
  bool _brightnessMode = false;
  double _currentBrightness = 0.5;
  double _brightnessStartValue = 0.5;
  Timer? _brightnessIndicatorTimer;

  bool _showLevelUp = false;
  int _levelUpSlot = 0;
  int _levelUpLevel = 0;

  double? _dragStartY;
  int _activeSentenceIndex = 0;
  bool _pendingLastSentence = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerProvider.notifier).snapToParaStart();
      _refresh();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _brightnessIndicatorTimer?.cancel();
    ScreenBrightness.instance.resetScreenBrightness();
    super.dispose();
  }

  Future<void> _saveSession() async {
    if (_readingStart != null) {
      _accumulatedSeconds += DateTime.now()
          .difference(_readingStart!)
          .inSeconds;
      _readingStart = null;
    }
    await ref
        .read(readerProvider.notifier)
        .saveParagraphSession(
          _accumulatedSeconds,
          startedAt: _sessionStart ?? DateTime.now(),
        );
    _accumulatedSeconds = 0;
    _sessionStart = null;
  }

  Future<void> _checkGoal() async {
    final streak = await StreakService(SessionDao()).load();
    if (streak.goalReachedToday &&
        mounted &&
        !SettingsService.instance.goalCelebrationShownToday) {
      await SettingsService.instance.markGoalCelebrationShown();
      if (!mounted) return;
      setState(() {
        _showGoalCelebration = true;
        _celebrationStreakDays = streak.streakDays;
      });
      Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showGoalCelebration = false);
      });
    }
  }

  void _refresh() {
    if (!mounted) return;
    final newData = ref.read(readerProvider.notifier).currentParagraph();
    setState(() {
      _data = newData;
      if (_pendingLastSentence) {
        _activeSentenceIndex = (newData.sentences.length - 1).clamp(0, 9999);
        _pendingLastSentence = false;
      } else {
        _activeSentenceIndex = 0;
      }
    });
  }

  void _nextSentence() {
    final sentences = _data?.sentences ?? [];
    if (sentences.isEmpty) {
      ref.read(readerProvider.notifier).nextParagraph();
      return;
    }
    if (_activeSentenceIndex < sentences.length - 1) {
      setState(() => _activeSentenceIndex++);
    } else {
      ref.read(readerProvider.notifier).nextParagraph();
    }
  }

  void _prevSentence() {
    final sentences = _data?.sentences ?? [];
    if (sentences.isEmpty) {
      ref.read(readerProvider.notifier).prevParagraph();
      return;
    }
    if (_activeSentenceIndex > 0) {
      setState(() => _activeSentenceIndex--);
    } else {
      final prevIdx = ref.read(readerProvider).currentIndex;
      _pendingLastSentence = true;
      ref.read(readerProvider.notifier).prevParagraph();
      if (ref.read(readerProvider).currentIndex == prevIdx) {
        _pendingLastSentence = false;
      }
    }
  }

  Future<void> _showOverlay() async {
    if (_overlayVisible) return;
    if (_readingStart != null) {
      _accumulatedSeconds += DateTime.now()
          .difference(_readingStart!)
          .inSeconds;
      _readingStart = null;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    setState(() => _overlayVisible = true);
    await _saveSession();
    await _checkGoal();
  }

  void _hideOverlay() {
    if (!_overlayVisible) return;
    _readingStart = DateTime.now();
    _sessionStart ??= _readingStart;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _overlayVisible = false);
  }

  void _showChapterNavigator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: const ChapterNavigator(),
      ),
    ).whenComplete(() {
      ref.read(readerProvider.notifier).snapToParaStart();
    });
  }

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ReaderSettingsSheet(paragraphMode: true),
    );
  }

  void _showDictionaryInput() async {
    final controller = TextEditingController();
    String? word;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Wörterbuch', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white70,
          decoration: const InputDecoration(
            hintText: 'Wort eingeben...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
          ),
          onSubmitted: (val) {
            word = val.trim();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              word = controller.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Suchen',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (word != null && word!.isNotEmpty && mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => DictionarySheet(word: word!),
      );
    }
  }

  void _onLongPressStart(LongPressStartDetails details) async {
    final brightness = await ScreenBrightness.instance.current;
    setState(() {
      _brightnessMode = true;
      _currentBrightness = brightness;
    });
    _brightnessStartValue = brightness;
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) async {
    final dy = details.localOffsetFromOrigin.dy;
    final newBrightness = (_brightnessStartValue - dy / 500).clamp(0.0, 1.0);
    await ScreenBrightness.instance.setScreenBrightness(newBrightness);
    if (mounted) setState(() => _currentBrightness = newBrightness);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _brightnessIndicatorTimer?.cancel();
    _brightnessIndicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _brightnessMode = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final reader = ref.watch(readerProvider);
    final s = SettingsService.instance;

    final totalWords = reader.tokens.length;
    final currentIndex = reader.currentIndex;
    final bookPercent = totalWords > 0
        ? (currentIndex / totalWords * 100).toStringAsFixed(1)
        : '0.0';
    final currentChapterIndex = reader.tokens.isNotEmpty
        ? reader.tokens[currentIndex.clamp(0, totalWords - 1)].chapterIndex
        : 0;
    double chapterProgress = 0.0;
    String chapterPercent = '0%';
    if (reader.chapters.isNotEmpty && totalWords > 0) {
      final chapterIdx = reader.chapters.indexWhere(
        (c) => c.indexInBook == currentChapterIndex,
      );
      final chapter = chapterIdx >= 0
          ? reader.chapters[chapterIdx]
          : reader.chapters.last;
      final chapterEnd =
          chapterIdx >= 0 && chapterIdx < reader.chapters.length - 1
          ? reader.chapters[chapterIdx + 1].startWord
          : totalWords;
      final chapterSpan = chapterEnd - chapter.startWord;
      if (chapterSpan > 0) {
        chapterProgress = ((currentIndex - chapter.startWord) / chapterSpan)
            .clamp(0.0, 1.0);
        chapterPercent = '${(chapterProgress * 100).round()}%';
      }
    }

    // Auto-refresh wenn currentIndex sich ändert (Volume Keys etc.)
    ref.listen(readerProvider.select((st) => st.currentIndex), (_, __) {
      _refresh();
    });

    // Session speichern wenn Modus wechselt
    ref.listen(settingsProvider.select((s) => s.paragraphMode), (prev, next) {
      if (prev == true && next == false) _saveSession();
    });

    ref.listen(companionProvider, (_, next) {
      final levelUp = next.value?.pendingLevelUp;
      if (levelUp != null && !_showLevelUp) {
        setState(() {
          _showLevelUp = true;
          _levelUpSlot = levelUp.slot;
          _levelUpLevel = levelUp.newLevel;
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _saveSession();
        await ref.read(readerProvider.notifier).closeBook();
        ref.invalidate(libraryProvider);
        ref.invalidate(streakProvider);
        ref.invalidate(bookDurationsProvider);
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: settings.backgroundColor,
        body: GestureDetector(
          onTapUp: _overlayVisible
              ? null
              : (details) {
                  final half = MediaQuery.of(context).size.width / 2;
                  if (settings.sentenceFocusEnabled) {
                    if (details.globalPosition.dx > half) {
                      _nextSentence();
                    } else {
                      _prevSentence();
                    }
                  } else {
                    if (details.globalPosition.dx > half) {
                      ref.read(readerProvider.notifier).nextParagraph();
                    } else {
                      ref.read(readerProvider.notifier).prevParagraph();
                    }
                  }
                },
          onVerticalDragStart: (details) {
            _dragStartY = details.globalPosition.dy;
          },
          onVerticalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            final screenHeight = MediaQuery.of(context).size.height;
            final startedInBottomZone =
                (_dragStartY ?? 0) >= screenHeight - 160;

            if (v < -300 && startedInBottomZone) {
              _showOverlay();
            } else if (v > 300) {
              _hideOverlay();
            }
            _dragStartY = null;
          },
          onLongPressStart: _overlayVisible ? null : _onLongPressStart,
          onLongPressMoveUpdate: _overlayVisible
              ? null
              : _onLongPressMoveUpdate,
          onLongPressEnd: _overlayVisible ? null : _onLongPressEnd,

          child: Stack(
            children: [
              // Absatz-Text (immer fullscreen)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 80,
                        ),
                        child: Center(
                          child: _data == null
                              ? const SizedBox.shrink()
                              : _data!.isTitlePage
                              ? Text(
                                  _data!.chapterTitle ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: s.fontFamily,
                                    fontSize: s.paragraphFontSize * 1.2,
                                    fontWeight: FontWeight.bold,
                                    color: s.textColor,
                                    height: 1.4,
                                  ),
                                )
                              : _data!.isImagePage
                              ? Image.file(
                                  File(
                                    '${reader.imageBasePath}/${_data!.imageKey}',
                                  ),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color: s.textColor.withValues(alpha: 0.3),
                                    size: 64,
                                  ),
                                )
                              : settings.sentenceFocusEnabled &&
                                      _data!.sentences.isNotEmpty
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _data!.sentences
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final isActive =
                                            entry.key == _activeSentenceIndex;
                                        return Opacity(
                                          opacity: isActive ? 1.0 : 0.25,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: Text(
                                              entry.value,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: s.fontFamily,
                                                fontSize: s.paragraphFontSize,
                                                height: s.paragraphLineHeight,
                                                color: s.textColor,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  : RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontFamily: s.fontFamily,
                                          fontSize: s.paragraphFontSize,
                                          height: s.paragraphLineHeight,
                                          color: s.textColor,
                                        ),
                                        text: [
                                          if (_data!.pre.isNotEmpty)
                                            _data!.pre.endsWith('-')
                                                ? _data!.pre
                                                : '${_data!.pre} ',
                                          _data!.current,
                                          if (_data!.post.isNotEmpty)
                                            _data!.current.endsWith('-')
                                                ? _data!.post
                                                : ' ${_data!.post}',
                                        ].join(''),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Overlay
              if (_overlayVisible) ...[
                // Zurück (oben links)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {},
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () async {
                        await _saveSession();
                        await ref.read(readerProvider.notifier).closeBook();
                        ref.invalidate(libraryProvider);
                        ref.invalidate(streakProvider);
                        ref.invalidate(bookDurationsProvider);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ),

                // Uhrzeit (oben rechts)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Text(
                      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // Bottom: Fortschritt + Buttons (transparent)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kapitel + Darstellung
                        Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: _showChapterNavigator,
                                icon: const Icon(
                                  Icons.list,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Kapitel',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showDisplaySettings,
                                icon: const Icon(
                                  Icons.tune,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Darstellung',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Fortschritt
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$bookPercent%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: chapterProgress,
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
                                chapterPercent,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ParagraphButton(
                              icon: Icons.arrow_back_ios,
                              label: 'Absatz',
                              onTap: () => ref
                                  .read(readerProvider.notifier)
                                  .prevParagraph(countWords: false),
                            ),
                            _ParagraphButton(
                              icon: Icons.text_decrease,
                              label: 'Schrift',
                              onTap: () async {
                                final newSize = (s.paragraphFontSize - 1).clamp(
                                  12.0,
                                  40.0,
                                );
                                await s.setParagraphFontSize(newSize);
                                ref.read(settingsProvider.notifier).reload();
                              },
                            ),
                            _ParagraphButton(
                              icon: Icons.menu_book_outlined,
                              label: 'Wörterb.',
                              onTap: _showDictionaryInput,
                            ),
                            _ParagraphButton(
                              icon: Icons.text_increase,
                              label: 'Schrift',
                              onTap: () async {
                                final newSize = (s.paragraphFontSize + 1).clamp(
                                  12.0,
                                  40.0,
                                );
                                await s.setParagraphFontSize(newSize);
                                ref.read(settingsProvider.notifier).reload();
                              },
                            ),
                            _ParagraphButton(
                              icon: Icons.arrow_forward_ios,
                              label: 'Absatz',
                              onTap: () => ref
                                  .read(readerProvider.notifier)
                                  .nextParagraph(countWords: false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],

              // Tagesziel-Celebration
              if (_showGoalCelebration)
                Positioned.fill(
                  child: IgnorePointer(
                    child: GoalCelebrationOverlay(
                      streakDays: _celebrationStreakDays,
                    ),
                  ),
                ),

              // Companion Level-Up
              if (_showLevelUp)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CompanionLevelUpOverlay(
                      slot: _levelUpSlot,
                      newLevel: _levelUpLevel,
                      onDone: () {
                        if (mounted) setState(() => _showLevelUp = false);
                        ref
                            .read(companionProvider.notifier)
                            .clearPendingLevelUp();
                      },
                    ),
                  ),
                ),

              // Helligkeitsindikator
              if (_brightnessMode)
                Positioned(
                  top: MediaQuery.of(context).size.height / 3 - 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.brightness_6,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(_currentBrightness * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParagraphButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ParagraphButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
