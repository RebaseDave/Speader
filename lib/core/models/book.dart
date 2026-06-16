class Book {
  final int? id;
  final String title;
  final String filePath;
  final int totalWords;
  final int currentWord;
  final int currentChapter;
  final DateTime importedAt;
  final bool isArchived;
  final String? series;

  bool get isBook => totalWords >= 20000;
  bool get isDeep => totalWords >= 6000 && totalWords < 20000;
  bool get isExplain => series == '__erklaerung__';
  bool get isManual => series == '__manuell__';

  const Book({
    this.id,
    required this.title,
    required this.filePath,
    required this.totalWords,
    required this.currentWord,
    required this.currentChapter,
    required this.importedAt,
    this.isArchived = false,
    this.series,
  });

  Book copyWith({
    int? id,
    String? title,
    String? filePath,
    int? totalWords,
    int? currentWord,
    int? currentChapter,
    DateTime? importedAt,
    bool? isArchived,
    Object? series = _sentinel,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      totalWords: totalWords ?? this.totalWords,
      currentWord: currentWord ?? this.currentWord,
      currentChapter: currentChapter ?? this.currentChapter,
      importedAt: importedAt ?? this.importedAt,
      isArchived: isArchived ?? this.isArchived,
      series: series == _sentinel ? this.series : series as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file_path': filePath,
      'total_words': totalWords,
      'current_word': currentWord,
      'current_chapter': currentChapter,
      'imported_at': importedAt.toIso8601String(),
      'is_archived': isArchived ? 1 : 0,
      'series': series,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      totalWords: map['total_words'] as int,
      currentWord: map['current_word'] as int,
      currentChapter: map['current_chapter'] as int,
      importedAt: DateTime.parse(map['imported_at'] as String),
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      series: map['series'] as String?,
    );
  }
}

const Object _sentinel = Object();