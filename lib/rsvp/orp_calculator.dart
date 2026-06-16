class OrpCalculator {
  static int calculate(String normalizedWord) {
    final length = normalizedWord.length;
    if (length <= 1) return 0;
    if (RegExp(r'^[0-9]+$').hasMatch(normalizedWord)) return 0;

    final raw = (length * 0.25).round();
    return raw.clamp(1, length <= 5 ? length - 1 : 4);
  }

  static String normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'^[^a-zA-ZäöüÄÖÜß0-9]+'), '')
        .replaceAll(RegExp(r'[^a-zA-ZäöüÄÖÜß0-9]+$'), '');
  }

  static int rawIndex(String raw, String normalized, int normalizedIndex) {
    if (raw == normalized) return normalizedIndex;
    final lowerRaw = raw.toLowerCase();
    final lowerNorm = normalized.toLowerCase();
    final offset = lowerRaw.indexOf(lowerNorm.isNotEmpty ? lowerNorm[0] : '');
    if (offset < 0) return normalizedIndex;
    return (offset + normalizedIndex).clamp(0, raw.length - 1);
  }
}