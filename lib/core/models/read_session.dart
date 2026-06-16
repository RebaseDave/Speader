class ReadSession {
  final int? id;
  final int bookId;
  final DateTime startedAt;
  final int durationSec;
  final int wordsRead;

  const ReadSession({
    this.id,
    required this.bookId,
    required this.startedAt,
    required this.durationSec,
    required this.wordsRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'started_at': startedAt.toIso8601String(),
      'duration_sec': durationSec,
      'words_read': wordsRead,
    };
  }

  factory ReadSession.fromMap(Map<String, dynamic> map) {
    return ReadSession(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      durationSec: map['duration_sec'] as int,
      wordsRead: map['words_read'] as int,
    );
  }
}