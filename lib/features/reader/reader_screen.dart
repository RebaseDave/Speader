import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/book.dart';
import '../../core/models/word_token.dart';
import '../../core/services/settings_service.dart';
import 'reader_provider.dart';
import 'rsvp_display.dart';
import 'reader_overlay.dart';
import 'chapter_navigator.dart';
import 'reader_settings_sheet.dart';
import '../library/library_provider.dart';
import '../../rsvp/rsvp_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:async';
import '../settings/settings_provider.dart';
import '../../core/services/streak_service.dart';
import '../../core/database/session_dao.dart';
import 'goal_celebration_overlay.dart';
import '../library/streak_provider.dart';
import 'paragraph_reader.dart';
import '../companions/companion_levelup_overlay.dart';
import '../companions/companion_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  bool _overlayVisible = true;
  WordToken? _currentToken;
  bool _wasPlayingBeforeSwipe = false;
  bool _isSwiping = false;
  bool _ignoreTaps = false;
  Timer? _ignoreTapsTimer;
  double _swipeAccumulator = 0;
  bool _brightnessMode = false;
  double _currentBrightness = 0.5;
  Timer? _brightnessIndicatorTimer;
  double _brightnessStartValue = 0.5;
  DateTime _now = DateTime.now();
  bool _showGoalCelebration = false;
  bool _showLevelUp = false;
  int _levelUpSlot = 0;
  int _levelUpLevel = 0;
  bool _paragraphModeVisible = false;
  ParagraphData? _paragraphData;
  int _celebrationStreakDays = 0;
  Timer? _clockTimer;

  static const _volumeChannel = MethodChannel(
    'com.example.rsvp_reader/volume_keys',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerProvider.notifier).loadBook(widget.book);
    });

    _volumeChannel.setMethodCallHandler((call) async {
      if (SettingsService.instance.paragraphMode) {
        if (call.method == 'volumeUp') {
          ref.read(readerProvider.notifier).nextParagraph();
        } else if (call.method == 'volumeDown') {
          ref.read(readerProvider.notifier).prevParagraph();
        }
      } else {
        if (call.method == 'volumeUp') {
          ref.read(readerProvider.notifier).adjustWpm(5);
          ref.read(settingsProvider.notifier).reload();
        } else if (call.method == 'volumeDown') {
          ref.read(readerProvider.notifier).adjustWpm(-5);
          ref.read(settingsProvider.notifier).reload();
        }
      }
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _brightnessIndicatorTimer?.cancel();
    _ignoreTapsTimer?.cancel();
    ScreenBrightness.instance.resetScreenBrightness();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(readerProvider.notifier).stop();
    }
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
    ).whenComplete(_startIgnoreTaps);
  }

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ReaderSettingsSheet(),
    ).whenComplete(_startIgnoreTaps);
  }

  void _handleSwipeStart(DragStartDetails details) {
    _isSwiping = true;
    final reader = ref.read(readerProvider);
    _wasPlayingBeforeSwipe = reader.rsvpState == RsvpState.playing;
    _swipeAccumulator = 0;
    if (_wasPlayingBeforeSwipe) {
      ref.read(readerProvider.notifier).pauseForSwipe();
    }
  }

  void _handleSwipeUpdate(DragUpdateDetails details) {
    _swipeAccumulator += details.delta.dx;

    // Pro 20px = 1 Wort
    final words = (_swipeAccumulator.abs() / 20).floor();
    if (words >= 1) {
      if (_swipeAccumulator < 0) {
        ref.read(readerProvider.notifier).skipForwardWords(words);
      } else {
        ref.read(readerProvider.notifier).skipBackwardWords(words);
      }
      // Nur die verbrauchten Pixel abziehen
      final usedPixels = words * 20;
      if (_swipeAccumulator < 0) {
        _swipeAccumulator += usedPixels;
      } else {
        _swipeAccumulator -= usedPixels;
      }
    }
  }

  void _handleSwipeEnd(DragEndDetails details) {
    setState(() => _isSwiping = false);
    if (_wasPlayingBeforeSwipe) {
      final reader = ref.read(readerProvider);
      final idx = reader.currentIndex.clamp(0, reader.tokens.length - 1);
      final isOnImage = reader.tokens.isNotEmpty && reader.tokens[idx].isImage;
      if (!isOnImage) {
        ref.read(readerProvider.notifier).resumeAfterSwipe();
      }
      // Bei Bild: pausiert bleiben → isShowingImage zeigt Pfeil-Button automatisch
    }
    _swipeAccumulator = 0;
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

  void _startIgnoreTaps() {
    _ignoreTapsTimer?.cancel();
    setState(() => _ignoreTaps = true);
    _ignoreTapsTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _ignoreTaps = false);
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _brightnessIndicatorTimer?.cancel();
    _brightnessIndicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _brightnessMode = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reader = ref.watch(readerProvider);
    final settings = SettingsService.instance;
    final settingsState = ref.watch(settingsProvider);

    // Aktuelles Token tracken
    if (reader.tokens.isNotEmpty) {
      _currentToken =
          reader.tokens[reader.currentIndex.clamp(0, reader.tokens.length - 1)];
    }

    final isShowingImage =
        (_currentToken?.isImage ?? false) &&
        reader.rsvpState == RsvpState.paused &&
        !_isSwiping;
    // Overlay automatisch einklappen wenn ein Bild angezeigt wird
    final overlayVisible = _overlayVisible && !isShowingImage;

    ref.listen(readerProvider.select((s) => s.rsvpState), (
      previous,
      next,
    ) async {
      // Ziel-Check bei Pause oder Fertig
      if ((next == RsvpState.paused || next == RsvpState.finished) &&
          previous == RsvpState.playing) {
        // Kein Goal-Check bei automatischer Bild-Pause
        final rs = ref.read(readerProvider);
        if (rs.tokens.isNotEmpty) {
          final tok = rs.tokens[rs.currentIndex.clamp(0, rs.tokens.length - 1)];
          if (tok.isImage) return;
        }
        final streak = await StreakService(SessionDao()).load();
        if (streak.goalReachedToday &&
            context.mounted &&
            !SettingsService.instance.goalCelebrationShownToday) {
          await SettingsService.instance.markGoalCelebrationShown();
          setState(() {
            _showGoalCelebration = true;
            _celebrationStreakDays = streak.streakDays;
          });
          Timer(const Duration(milliseconds: 2500), () {
            if (mounted) setState(() => _showGoalCelebration = false);
          });
        }
      }

      if (next == RsvpState.finished) {
        await Future.delayed(const Duration(seconds: 1));
        if (!context.mounted) return;
        await ref.read(readerProvider.notifier).closeBook();
        if (!context.mounted) return;
        Navigator.of(context).pop();
      }
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

    if (reader.isLoading) {
      return Scaffold(
        backgroundColor: settings.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Buch wird geladen...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    if (settingsState.paragraphMode) {
      return ParagraphReader(book: widget.book);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await ref.read(readerProvider.notifier).closeBook();
        ref.invalidate(libraryProvider);
        ref.invalidate(streakProvider);
        ref.invalidate(bookDurationsProvider);
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: settings.backgroundColor,
        body: Stack(
          children: [
            // RSVP Display
            Positioned.fill(
              child: isShowingImage
                  ? RsvpDisplay(
                      token: _currentToken,
                      settings: settings,
                      imageBasePath: reader.imageBasePath,
                    )
                  : GestureDetector(
                      onTap: () async {
                        if (_ignoreTaps) return;
                        final r = ref.read(readerProvider);
                        if (r.rsvpState == RsvpState.playing) {
                          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
                          await ref.read(readerProvider.notifier).stop();
                          setState(() => _overlayVisible = true);
                        } else if (r.rsvpState == RsvpState.finished) {
                          setState(() => _overlayVisible = !_overlayVisible);
                        } else {
                          if (_overlayVisible) {
                            ref.read(readerProvider.notifier).play();
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                            setState(() => _overlayVisible = false);
                          } else {
                            setState(() => _overlayVisible = true);
                          }
                        }
                      },
                      onLongPressStart: _onLongPressStart,
                      onLongPressMoveUpdate: _onLongPressMoveUpdate,
                      onLongPressEnd: _onLongPressEnd,
                      onHorizontalDragStart: _handleSwipeStart,
                      onHorizontalDragUpdate: _handleSwipeUpdate,
                      onHorizontalDragEnd: _handleSwipeEnd,
                      child: RsvpDisplay(
                        token: _currentToken,
                        settings: settings,
                        imageBasePath: reader.imageBasePath,
                      ),
                    ),
            ),

            // Pfeil-Button bei Bild-Anzeige
            if ((_currentToken?.isImage ?? false) &&
                reader.rsvpState == RsvpState.paused)
              Positioned(
                bottom: 40,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    ref.read(readerProvider.notifier).resumeAfterSwipe();
                    setState(() => _overlayVisible = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 26,
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

            // Absatz-Modus Overlay
            if (_paragraphModeVisible && _paragraphData != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _paragraphModeVisible = false),
                  child: Container(
                    color: SettingsService.instance.backgroundColor,
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 48,
                                  ),
                                  child: Center(
                                    child: Builder(
                                      builder: (context) {
                                        final data = _paragraphData!;
                                        final s = SettingsService.instance;
                                        final word = data.current;
                                        final orpIdx = word.isEmpty
                                            ? 0
                                            : data.orpIndex.clamp(
                                                0,
                                                word.length - 1,
                                              );

                                        final baseStyle = TextStyle(
                                          fontFamily: s.fontFamily,
                                          fontSize: s.fontSize * 0.55,
                                          height: 1.7,
                                        );

                                        final List<InlineSpan> wordSpans = [];
                                        if (word.isNotEmpty) {
                                          if (orpIdx > 0) {
                                            wordSpans.add(
                                              TextSpan(
                                                text: word.substring(0, orpIdx),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          }
                                          wordSpans.add(
                                            TextSpan(
                                              text: word.substring(
                                                orpIdx,
                                                orpIdx + 1,
                                              ),
                                              style: TextStyle(
                                                color: s.orpColor,
                                                fontWeight: s.orpBold
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          );
                                          if (orpIdx + 1 < word.length) {
                                            wordSpans.add(
                                              TextSpan(
                                                text: word.substring(
                                                  orpIdx + 1,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          }
                                        }

                                        return RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(
                                            style: baseStyle.copyWith(
                                              color: Colors.white54,
                                            ),
                                            children: [
                                              if (data.pre.isNotEmpty)
                                                TextSpan(text: '${data.pre} '),
                                              ...wordSpans,
                                              if (data.post.isNotEmpty)
                                                TextSpan(text: ' ${data.post}'),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ),

            // Overlay - Taps werden NICHT weitergegeben
            if (overlayVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                      ReaderOverlay(
                        bookId: widget.book.id ?? 0,
                        onParagraphTap: () {
                          setState(() {
                            _paragraphData = ref
                                .read(readerProvider.notifier)
                                .currentParagraph();
                            _paragraphModeVisible = true;
                          });
                        },
                        onSheetClosed: _startIgnoreTaps,
                      ),
                    ],
                  ),
                ),
              ),

            // Zurück-Button
            if (overlayVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: GestureDetector(
                  onTap: () {},
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () async {
                      await ref.read(readerProvider.notifier).closeBook();
                      ref.invalidate(libraryProvider);
                      ref.invalidate(streakProvider);
                      ref.invalidate(bookDurationsProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ),
            // Uhrzeit oben rechts
            if (overlayVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Text(
                  '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
    );
  }
}
