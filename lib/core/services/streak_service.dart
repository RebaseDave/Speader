import '../database/session_dao.dart';

const int kDailyGoalWords = 3000;

class StreakData {
  final int todayWords;
  final int streakDays;
  final int pendingStreak;
  final bool goalReachedToday;

  const StreakData({
    required this.todayWords,
    required this.streakDays,
    required this.pendingStreak,
    required this.goalReachedToday,
  });

  double get progress => (todayWords / kDailyGoalWords).clamp(0.0, 1.0);

  /// Angezeigter Streak-Wert: aktiv wenn Ziel erreicht, pending wenn nicht
  int get displayStreak => goalReachedToday ? streakDays : pendingStreak;

  /// Grau anzeigen wenn Ziel heute noch nicht erreicht
  bool get isPending => !goalReachedToday && pendingStreak > 0;
}

class StreakService {
  final SessionDao _dao;
  StreakService(this._dao);

  Future<StreakData> load() async {
    // Heutige Wörter (nur isBook, gefiltert)
    final todaySessions = await _dao.getTodaySessions();
    final todayWords = todaySessions.fold<int>(0, (sum, s) => sum + s.wordsRead);

    // Tages-Aggregat für Streak (nur isBook, gefiltert)
    final dailyCounts = await _dao.getDailyWordCounts(days: 3650);
    final wordsByDay = <String, int>{
      for (final row in dailyCounts)
        row['day'] as String: row['total_words'] as int? ?? 0,
    };

    // Streak: rückwärts von heute
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    int streak = 0;
    DateTime cursor = todayStart;
    while (true) {
      if ((wordsByDay[_dayKey(cursor)] ?? 0) >= kDailyGoalWords) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Pending Streak: Streak ab gestern (falls heute noch nicht erreicht)
    int pendingStreak = 0;
    if (todayWords < kDailyGoalWords) {
      DateTime cursor2 = todayStart.subtract(const Duration(days: 1));
      while (true) {
        if ((wordsByDay[_dayKey(cursor2)] ?? 0) >= kDailyGoalWords) {
          pendingStreak++;
          cursor2 = cursor2.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    return StreakData(
      todayWords: todayWords,
      streakDays: streak,
      pendingStreak: pendingStreak,
      goalReachedToday: todayWords >= kDailyGoalWords,
    );
  }

  // Zero-padded um mit SQLite date()-Format übereinzustimmen (YYYY-MM-DD)
  String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}