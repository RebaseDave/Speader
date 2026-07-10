class WordToken {
  final String raw;
  final String normalized;
  final int orpIndex;
  final bool isSentenceEnd;
  final bool isCommaEnd;
  final bool isParagraphEnd;
  final bool isDashEnd;
  final bool isChapterTitle;
  final int chapterIndex;
  final bool isItalic;

  const WordToken({
    required this.raw,
    required this.normalized,
    required this.orpIndex,
    required this.isSentenceEnd,
    required this.isCommaEnd,
    required this.isParagraphEnd,
    required this.isDashEnd,
    required this.isChapterTitle,
    required this.chapterIndex,
    this.isItalic = false,
  });

  bool get isImage => raw.startsWith('__IMAGE__:');
  String get imageKey => isImage ? raw.substring('__IMAGE__:'.length) : '';

  /// Markiert einen leeren Absatz (doppelter Zeilenumbruch) im Original –
  /// wird im Paragraph-Modus als eigene "Szenenwechsel"-Seite angezeigt.
  bool get isSceneBreak => raw == '__SCENE_BREAK__';

  bool get isCountable =>
      !isChapterTitle &&
      !isImage &&
      !isSceneBreak &&
      normalized.isNotEmpty &&
      !RegExp(r'^[–—«»?!.,;…\s]+$').hasMatch(normalized);

  bool get isBlank => normalized == '__BLANK__';
}