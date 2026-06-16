import '../core/database/orp_dao.dart';
import '../core/models/orp_entry.dart';
import '../core/models/word_token.dart';
import '../rsvp/orp_calculator.dart';

class OrpSeeder {
  final OrpDao _orpDao;

  OrpSeeder(this._orpDao);

  Future<void> seedFromTokens(List<WordToken> tokens) async {
    // Unique normalisierte Wörter extrahieren
    final uniqueWords = tokens
        .where((t) => !t.isChapterTitle)
        .map((t) => t.normalized)
        .where((w) => w.isNotEmpty)
        .toSet();

    // Alle existierenden Wörter in einem Query laden
    final existing = await _orpDao.getAllEntries();
    final existingWords = existing.map((e) => e.word).toSet();

    // Nur neue Wörter eintragen
    final newEntries = uniqueWords
        .where((word) => !existingWords.contains(word))
        .map((word) => OrpEntry(
              word: word,
              orpIndex: OrpCalculator.calculate(word),
              isManual: false,
            ))
        .toList();

    if (newEntries.isNotEmpty) {
      await _orpDao.insertEntries(newEntries);
    }
  }
}