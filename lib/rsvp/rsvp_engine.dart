import 'dart:async';
import '../core/models/word_token.dart';
import '../core/services/settings_service.dart';
import '../core/database/book_dao.dart';
import '../core/database/session_dao.dart';
import '../core/models/read_session.dart';
import 'display_timer.dart';

enum RsvpState { idle, playing, paused, finished }

class RsvpEngine {
  final BookDao _bookDao;
  final SessionDao _sessionDao;
  final DisplayTimer _displayTimer;

  RsvpEngine(SettingsService settings, this._bookDao, this._sessionDao)
    : _displayTimer = DisplayTimer(settings);

  List<WordToken> _tokens = [];
  int _currentIndex = 0;
  int _bookId = 0;
  RsvpState _state = RsvpState.idle;
  Timer? _timer;

  // Session tracking
  DateTime? _sessionStart;
  int _wordsReadCounter = 0;
  Duration _accumulatedPlayTime = Duration.zero;
  DateTime? _currentPlayStart;
  bool _wpmChangedDuringSession = false;

  // Fokus-Pause nach Bild
  bool _prevWasImage = false;

  // Callbacks
  Function(WordToken token, int index)? onWord;
  Function(RsvpState state)? onStateChange;
  Function(int wordsRead)? onSessionSaved;

  RsvpState get state => _state;
  int get currentIndex => _currentIndex;
  int get totalWords => _tokens.length;

  void load(List<WordToken> tokens, int bookId, int startIndex) {
    _timer?.cancel();
    _tokens = tokens;
    _bookId = bookId;
    _state = RsvpState.idle;
    _sessionStart = null;
    _wordsReadCounter = 0;
    _accumulatedPlayTime = Duration.zero;
    _currentPlayStart = null;
    _wpmChangedDuringSession = false;
    _prevWasImage = false;
    _currentIndex = startIndex.clamp(
      0,
      tokens.isNotEmpty ? tokens.length - 1 : 0,
    );
  }

  void play() {
    if (_tokens.isEmpty) return;
    if (_state == RsvpState.playing) return;
    if (_state == RsvpState.finished) return;

    _state = RsvpState.playing;

    if (_sessionStart == null) {
      _sessionStart = DateTime.now();
      _wordsReadCounter = 0;
      _accumulatedPlayTime = Duration.zero;
      _wpmChangedDuringSession = false;
    }
    _currentPlayStart = DateTime.now();

    onStateChange?.call(_state);
    _scheduleNext();
  }

  Future<void> pause() async {
    _timer?.cancel();
    _accumulatePlayTime();
    _state = RsvpState.paused;
    onStateChange?.call(_state);
    await _saveSession();
  }

  void pauseForSwipe() {
    _timer?.cancel();
    _accumulatePlayTime();
    _state = RsvpState.paused;
    onStateChange?.call(_state);
    // Kein _saveSession() - Session läuft weiter
  }

  Future<void> stop() async {
    _timer?.cancel();
    _accumulatePlayTime();
    _state = RsvpState.paused;
    onStateChange?.call(_state);
    await _saveSession();
    await _saveProgress();
  }

  void skipForward([int words = 10]) {
    _timer?.cancel();
    int i = (_currentIndex + 1).clamp(0, _tokens.length - 1);
    while (i < _tokens.length - 1 && !_isHardSentenceEnd(_tokens[i])) {
      i++;
    }
    if (_tokens[i].isChapterTitle) {
      _currentIndex = i;
    } else {
      _currentIndex = (i + 1).clamp(0, _tokens.length - 1);
    }
    // Bild-Tokens überspringen
    while (_currentIndex < _tokens.length - 1 &&
        _tokens[_currentIndex].isImage) {
      _currentIndex++;
    }
    if (_tokens.isNotEmpty) {
      onWord?.call(_tokens[_currentIndex], _currentIndex);
    }
    if (_state == RsvpState.playing) {
      _scheduleNext();
    }
  }

  void skipBackward([int words = 10]) {
    _timer?.cancel();

    // Zuerst Bilder am Startpunkt rückwärts überspringen
    int i = (_currentIndex - 1).clamp(0, _tokens.length - 1);
    while (i > 0 && _tokens[i].isImage) {
      i--;
    }

    // Satzanfang suchen – Bilder als Grenze behandeln
    while (i > 0 &&
        !_isHardSentenceEnd(_tokens[i - 1]) &&
        !_tokens[i - 1].isImage) {
      i--;
    }
    if (i > 0 && _tokens[i - 1].isChapterTitle) {
      i = i - 1;
    }

    _currentIndex = i;
    if (_tokens.isNotEmpty) {
      onWord?.call(_tokens[_currentIndex], _currentIndex);
    }
    if (_state == RsvpState.playing) {
      _scheduleNext();
    }
  }

  void skipForwardWords(int words) {
    _timer?.cancel();
    _currentIndex = (_currentIndex + words).clamp(0, _tokens.length - 1);
    if (_tokens.isNotEmpty) {
      onWord?.call(_tokens[_currentIndex], _currentIndex);
    }
    if (_state == RsvpState.playing) {
      _scheduleNext();
    }
  }

  void skipBackwardWords(int words) {
    _timer?.cancel();
    _currentIndex = (_currentIndex - words).clamp(0, _tokens.length - 1);
    if (_tokens.isNotEmpty) {
      onWord?.call(_tokens[_currentIndex], _currentIndex);
    }
    if (_state == RsvpState.playing) {
      _scheduleNext();
    }
  }

  void notifyWpmChanged() {
    _wpmChangedDuringSession = true;
  }

  /// Nach Swipe: wenn auf Bild gelandet, direkt zum nächsten Wort – kein Pause
  void resumeAfterSwipe() {
    while (_currentIndex < _tokens.length - 1 &&
        _tokens[_currentIndex].isImage) {
      _currentIndex++;
    }
    play();
  }

  bool _isHardSentenceEnd(WordToken token) {
    // Kapitelüberschriften gelten als Satzgrenze
    if (token.isChapterTitle) return true;
    if (!token.isSentenceEnd) return false;
    // Schließende Anführungszeichen/Klammern nach Satzzeichen entfernen
    final stripped = token.raw.replaceAll(RegExp(r'[»"")\]]+$'), '');
    return stripped.endsWith('.') ||
        stripped.endsWith('!') ||
        stripped.endsWith('?');
  }

  void jumpToWord(int index) {
    _timer?.cancel();
    _currentIndex = index.clamp(0, _tokens.length - 1);
    // Sofort aktuelles Wort anzeigen
    if (_tokens.isNotEmpty) {
      onWord?.call(_tokens[_currentIndex], _currentIndex);
    }
    if (_state == RsvpState.playing) {
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    if (_currentIndex >= _tokens.length) {
      _finish();
      return;
    }

    final token = _tokens[_currentIndex];
    onWord?.call(token, _currentIndex);

    // Bild-Token: direkt pausieren, Engine wartet auf play()
    if (token.isImage) {
      _accumulatePlayTime();
      _prevWasImage = true;
      _currentIndex++;
      _state = RsvpState.paused;
      onStateChange?.call(_state);
      return;
    }

    // Kapiteltitel: Zeit läuft nicht in Playtime
    if (token.isChapterTitle) {
      _accumulatePlayTime();
      final ms = _displayTimer.calculateMs(token);
      _timer = Timer(Duration(milliseconds: ms), () {
        _currentPlayStart = DateTime.now();
        _currentIndex++;
        _scheduleNext();
      });
      return;
    }

    if (!token.isBlank && token.isCountable) _wordsReadCounter++;

    var duration = _displayTimer.calculateMs(token);
    if (_prevWasImage) {
      duration += 600;
      _prevWasImage = false;
    }
    _timer = Timer(Duration(milliseconds: duration), () {
      _currentIndex++;
      _scheduleNext();
    });
  }

  Future<void> _finish() async {
    _accumulatePlayTime();
    _state = RsvpState.finished;
    onStateChange?.call(_state);
    await _saveSession();
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    if (_bookId == 0 || _tokens.isEmpty) return;
    final chapterIndex =
        _tokens[_currentIndex.clamp(0, _tokens.length - 1)].chapterIndex;
    await _bookDao.updateProgress(_bookId, _currentIndex, chapterIndex);
  }

  void _accumulatePlayTime() {
    if (_currentPlayStart != null) {
      _accumulatedPlayTime += DateTime.now().difference(_currentPlayStart!);
      _currentPlayStart = null;
    }
  }

  Future<void> _saveSession() async {
    if (_sessionStart == null) return;
    if (_wordsReadCounter == 0) return;
    final duration = _accumulatedPlayTime.inSeconds;
    if (duration == 0) return;

    await _sessionDao.insertSession(
      ReadSession(
        bookId: _bookId,
        startedAt: _sessionStart!,
        durationSec: duration,
        wordsRead: _wordsReadCounter,
      ),
    );

    // Kalibrierung: nur wenn WPM nicht geändert, >= 500 Wörter, noch kein Overhead
    if (!_wpmChangedDuringSession &&
        _wordsReadCounter >= 500) {
      final settings = SettingsService.instance;
      final settingsWpm = settings.wpm.toDouble();
      final scaling = settings.scalingEnabled
          ? settings.referenceWpm / settingsWpm
          : 1.0;
      final gemesseneWpm = _wordsReadCounter / (duration / 60);
      final overheadReal = (60000.0 / gemesseneWpm) - (60000.0 / settingsWpm);
      if (overheadReal > 0 && overheadReal < 200) {
        final neuerOverhead = overheadReal / scaling;
        final alterOverhead = SettingsService.instance.bookBaseOverhead(_bookId);
        final gemittelterOverhead = alterOverhead == null
            ? neuerOverhead
            : alterOverhead * 0.7 + neuerOverhead * 0.3;
        await SettingsService.instance.setBookBaseOverhead(_bookId, gemittelterOverhead);
      }
    }

    _sessionStart = null;
    onSessionSaved?.call(_wordsReadCounter);
    _wordsReadCounter = 0;
    _accumulatedPlayTime = Duration.zero;
    _currentPlayStart = null;
    _wpmChangedDuringSession = false;
  }

  void dispose() {
    _timer?.cancel();
  }
}
