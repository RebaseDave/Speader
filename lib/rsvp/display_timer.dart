import 'dart:math';
import '../core/services/settings_service.dart';
import '../core/models/word_token.dart';

class DisplayTimer {
  final SettingsService _settings;

  DisplayTimer(this._settings);

  int calculateMs(WordToken token) {
    if (token.isImage) return 0;

    if (token.isChapterTitle) {
      return _settings.chapterPauseMs;
    }

    if (token.isBlank) {
      return (60000 / _settings.wpm * 0.5).round().clamp(80, 300);
    }

    int base = (60000 / _settings.wpm).round();

    // Längenskalierung (Wurzelfunktion ab Threshold)
    final len = token.normalized.length;
    final threshold = _settings.lengthScaleThreshold;
    if (len > threshold) {
      final excess = (len - threshold).toDouble();
      final factor = _settings.lengthScaleFactor * 0.1;
      base = (base * (1.0 + sqrt(excess) * factor)).round();
    }

    int total = base.clamp(_settings.minDisplayMs, 10000);

    final scaling = _settings.scalingEnabled
        ? _settings.referenceWpm / _settings.wpm
        : 1.0;

    if (token.isParagraphEnd) {
      total += (_settings.paragraphMs * scaling).round();
    } else if (token.isSentenceEnd) {
      total += (_settings.sentenceMs * scaling).round();
    } else if (token.isCommaEnd || token.isDashEnd) {
      total += (_settings.commaMs * scaling).round();
    }

    return total;
  }
}