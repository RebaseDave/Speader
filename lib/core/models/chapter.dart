class Chapter {
  final int? id;
  final int bookId;
  final int indexInBook;
  final String? title;
  final int startWord;
  final int wordCount;

  const Chapter({
    this.id,
    required this.bookId,
    required this.indexInBook,
    this.title,
    required this.startWord,
    required this.wordCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'index_in_book': indexInBook,
      'title': title,
      'start_word': startWord,
      'word_count': wordCount,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      indexInBook: map['index_in_book'] as int,
      title: map['title'] as String?,
      startWord: map['start_word'] as int,
      wordCount: map['word_count'] as int,
    );
  }
}