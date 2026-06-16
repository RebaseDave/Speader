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
  });

  bool get isImage => raw.startsWith('__IMAGE__:');
  String get imageKey => isImage ? raw.substring('__IMAGE__:'.length) : '';

  bool get isCountable =>
      !isChapterTitle &&
      !isImage &&
      normalized.isNotEmpty &&
      !RegExp(r'^[–—«»?!.,;…\s]+$').hasMatch(normalized);

  bool get isBlank => normalized == '__BLANK__';
}