class SentenceDetector {
  final Set<String> _abbreviations;

  SentenceDetector(List<String> abbreviations)
      : _abbreviations = abbreviations.toSet();

  /// Prüft ob nach diesem Token eine Satzpause folgen soll
  bool isSentenceEnd(String raw) {
    final stripped = raw
        .replaceAll(RegExp(r'[»«\)\]]+$'), '')
        .replaceAll('"', '')
        .replaceAll('"', '')
        .replaceAll('\u2019', '');
    if (stripped.endsWith('...') || stripped.endsWith('…')) return true;
    if (!RegExp(r'[.!?:;]$').hasMatch(stripped)) return false;
    for (final abbr in _abbreviations) {
      if (stripped.toLowerCase() == abbr.toLowerCase()) return false;
      if (stripped.endsWith(abbr)) return false;
    }
    return true;
  }

  bool isCommaEnd(String raw) {
    return raw.endsWith(',');
  }

  bool isEllipsis(String raw) {
    return raw.contains('...') || raw.contains('…');
  }

  bool isDashEnd(String raw) {
    return raw.endsWith('—') || raw.endsWith('–');
  }

  static bool isDashToken(String raw) {
    return raw == '—' || raw == '–';
  }

  /// Prüft ob ein Raw-String ein Absatzende-Marker ist
  static bool isParagraphMarker(String raw) {
    return raw == '\n\n' || raw == '__PARAGRAPH__';
  }

  /// Prüft ob ein Raw-String ein Kapitelanfang-Marker ist
  static bool isChapterMarker(String raw) {
    return raw.startsWith('__CHAPTER__:');
  }

  /// Extrahiert den Kapiteltitel aus einem Kapitel-Marker
  static String extractChapterTitle(String raw) {
    return raw.replaceFirst('__CHAPTER__:', '').trim();
  }
}