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
import '../../core/theme/app_colors.dart';

class ParagraphReader extends ConsumerStatefulWidget {
  final Book book;
  const ParagraphReader({super.key, required this.book});

  @override
  ConsumerState<ParagraphReader> createState() => ParagraphReaderState();
}

class ParagraphReaderState extends ConsumerState<ParagraphReader> {
  ParagraphData? _data;
  bool _overlayVisible = true;

  /// "Aktiv am Lesen" = Overlay geschlossen (analog zur Zeit-/Wortzählung).
  bool get isActive => !_overlayVisible;

  void nextSentence() => _nextSentence();
  void prevSentence() => _prevSentence();
  void showOverlay() => _showOverlay();
  void hideOverlay() => _hideOverlay();

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

  int _activeSentenceIndex = 0;
  bool _pendingLastSentence = false;
  Timer? _autoTimer;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _sentenceKeys = [];

  // Tap-Timing Tracking
  final List<(int words, double secs)> _tapSamples = [];
  DateTime? _lastTapTime;

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
    _autoTimer?.cancel();
    ref.read(paragraphAutoModeProvider.notifier).state = false;
    _scrollController.dispose();
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
    _sentenceKeys = List.generate(newData.sentences.length, (_) => GlobalKey());
    setState(() {
      _data = newData;
      if (_pendingLastSentence) {
        _activeSentenceIndex = (newData.sentences.length - 1).clamp(0, 9999);
        _pendingLastSentence = false;
      } else {
        _activeSentenceIndex = 0;
      }
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _maybeAutoScroll() {
    if (!SettingsService.instance.paragraphAutoScroll) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 0) return;

    final keyIndex = _activeSentenceIndex.clamp(0, _sentenceKeys.length - 1);
    if (keyIndex >= _sentenceKeys.length) return;
    final ctx = _sentenceKeys[keyIndex].currentContext;
    if (ctx == null) return;

    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final positionY = renderBox.localToGlobal(Offset.zero).dy;

    if (positionY > screenHeight * 0.6) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
      );
    }
  }

  void _activateAuto() {
    if (_tapSamples.length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mindestens 40 Sätze notwendig. Aktuell: ${_tapSamples.length}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    ref.read(paragraphAutoModeProvider.notifier).state = true;
    _scheduleAutoNext();
  }

  void _deactivateAuto() {
    _autoTimer?.cancel();
    ref.read(paragraphAutoModeProvider.notifier).state = false;
    _lastTapTime = null;
  }

  List<TextSpan> _buildParagraphSpans() {
    final data = _data!;
    final spans = <TextSpan>[];

    void addFragments(
      List<ParagraphFragment> frags, {
      String prefixSpace = '',
      String suffixSpace = '',
    }) {
      for (int i = 0; i < frags.length; i++) {
        var text = frags[i].text;
        if (i == 0 && prefixSpace.isNotEmpty) text = '$prefixSpace$text';
        if (i == frags.length - 1) text = '$text$suffixSpace';
        spans.add(
          TextSpan(
            text: text,
            style: frags[i].isItalic
                ? const TextStyle(fontStyle: FontStyle.italic)
                : null,
          ),
        );
      }
    }

    if (data.pre.isNotEmpty) {
      addFragments(
        data.preFragments,
        suffixSpace: data.pre.endsWith('-') ? '' : ' ',
      );
    }
    spans.add(
      TextSpan(
        text: data.current,
        style: data.currentIsItalic
            ? const TextStyle(fontStyle: FontStyle.italic)
            : null,
      ),
    );
    if (data.post.isNotEmpty) {
      addFragments(
        data.postFragments,
        prefixSpace: data.current.endsWith('-') ? '' : ' ',
      );
    }

    return spans;
  }

  void _scheduleAutoNext() {
    _autoTimer?.cancel();
    if (!mounted) return;
    if (!ref.read(paragraphAutoModeProvider)) return;

    final sentences = _data?.sentences ?? [];
    if (sentences.isEmpty) {
      _deactivateAuto();
      return;
    }

    final current = _activeSentenceIndex < sentences.length
        ? sentences[_activeSentenceIndex]
        : '';
    final wordCount = current
        .split(' ')
        .where((w) => w.isNotEmpty)
        .length
        .clamp(1, 999);

    double secs = _calcSecsForWords(wordCount);

    _autoTimer = Timer(Duration(milliseconds: (secs * 1000).round()), () {
      if (!mounted || !ref.read(paragraphAutoModeProvider)) return;
      _nextSentence(recordSample: false);
      _scheduleAutoNext();
    });
  }

  void _recordTapSample() {
    final now = DateTime.now();
    if (_lastTapTime != null && _data != null) {
      final elapsed = now.difference(_lastTapTime!).inMilliseconds / 1000.0;
      if (elapsed < 30.0) {
        final sentences = _data!.sentences;
        if (_activeSentenceIndex < sentences.length) {
          final wordCount = sentences[_activeSentenceIndex]
              .split(' ')
              .where((w) => w.isNotEmpty)
              .length;
          if (wordCount > 0) {
            _tapSamples.add((wordCount, elapsed));
          }
        }
      }
    }
    _lastTapTime = now;
  }

  double _calcSecsForWords(int wordCount) {
    if (_tapSamples.isEmpty) return wordCount / 3.0;

    // Nachbarn: Samples mit wordCount im Bereich [wordCount-2, wordCount+2]
    final neighbors = _tapSamples
        .where((s) => (s.$1 - wordCount).abs() <= 4)
        .toList();

    if (neighbors.length >= 5) {
      // Median statt Durchschnitt um Ausreißer zu reduzieren
      final sorted = neighbors.map((e) => e.$2).toList()..sort();
      return sorted[sorted.length ~/ 2];
    }

    // Lineare Interpolation zwischen nächstem kleineren + größeren Datenpunkt
    final smaller = _tapSamples.where((s) => s.$1 < wordCount).toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    final larger = _tapSamples.where((s) => s.$1 > wordCount).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    if (smaller.isNotEmpty && larger.isNotEmpty) {
      final s = smaller.first;
      final l = larger.first;
      final t = (wordCount - s.$1) / (l.$1 - s.$1);
      return s.$2 + t * (l.$2 - s.$2);
    }

    if (smaller.isNotEmpty) return smaller.first.$2;
    if (larger.isNotEmpty) return larger.first.$2;

    final totalWords = _tapSamples.fold<int>(0, (sum, e) => sum + e.$1);
    final totalSecs = _tapSamples.fold<double>(0, (sum, e) => sum + e.$2);
    return wordCount / (totalWords / totalSecs);
  }

  void _nextSentence({bool recordSample = true}) {
    final sentences = _data?.sentences ?? [];
    if (sentences.isEmpty) {
      ref.read(readerProvider.notifier).nextParagraph();
      return;
    }
    if (recordSample) _recordTapSample();
    if (_activeSentenceIndex < sentences.length - 1) {
      setState(() => _activeSentenceIndex++);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
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
    _deactivateAuto();
    _lastTapTime = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
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
        backgroundColor: context.colors.surfaceElevated,
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
                  if (ref.read(paragraphAutoModeProvider)) {
                    _deactivateAuto();
                    return;
                  }
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
          onHorizontalDragEnd: (details) {
            if (_overlayVisible) return;
            final v = details.primaryVelocity ?? 0;
            if (v > 300) {
              _activateAuto();
            } else if (v < -300) {
              _deactivateAuto();
            }
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
                    controller: _scrollController,
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
                              : _data!.isSceneBreakPage
                              ? Text(
                                  '⁂',
                                  style: TextStyle(
                                    fontSize: s.paragraphFontSize * 1.6,
                                    color: context.colors.accent,
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
                                        final key =
                                            entry.key < _sentenceKeys.length
                                            ? _sentenceKeys[entry.key]
                                            : GlobalKey();
                                        final fragments =
                                            entry.key <
                                                _data!.sentenceFragments.length
                                            ? _data!.sentenceFragments[entry
                                                  .key]
                                            : [
                                                ParagraphFragment(
                                                  entry.value,
                                                  false,
                                                ),
                                              ];
                                        return Opacity(
                                          key: key,
                                          opacity: isActive ? 1.0 : 0.12,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Text.rich(
                                              TextSpan(
                                                style: TextStyle(
                                                  fontFamily: s.fontFamily,
                                                  fontSize: s.paragraphFontSize,
                                                  height: s.paragraphLineHeight,
                                                  color: s.textColor,
                                                ),
                                                children: fragments
                                                    .map(
                                                      (f) => TextSpan(
                                                        text: f.text,
                                                        style: f.isItalic
                                                            ? const TextStyle(
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              )
                                                            : null,
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(),
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
                                    children: _buildParagraphSpans(),
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

              // Auto-Modus Indikator
              if (ref.watch(paragraphAutoModeProvider) && !_overlayVisible)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Auto',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

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
