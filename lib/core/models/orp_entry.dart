class OrpEntry {
  final String word;
  final int orpIndex;
  final bool isManual;

  const OrpEntry({
    required this.word,
    required this.orpIndex,
    required this.isManual,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'orp_index': orpIndex,
      'is_manual': isManual ? 1 : 0,
    };
  }

  factory OrpEntry.fromMap(Map<String, dynamic> map) {
    return OrpEntry(
      word: map['word'] as String,
      orpIndex: map['orp_index'] as int,
      isManual: (map['is_manual'] as int) == 1,
    );
  }
}