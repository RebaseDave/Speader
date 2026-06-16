import 'companion.dart';
import 'dart:math';

class CompanionService {
  static const double _streakBonusPerDay = 0.01; // 1% pro Tag
  static const double _streakBonusCap = 0.50;     // max 50%
  static const double _level50BonusPerComp = 0.10; // 10% pro Companion

  /// Berechnet den XP-Multiplikator
  double calculateMultiplier(int streakDays, List<Companion> allCompanions) {
    final streakBonus = (streakDays * _streakBonusPerDay)
        .clamp(0.0, _streakBonusCap);
    final level50Count = allCompanions
        .where((c) => c.isUnlocked && c.level >= 50)
        .length;
    final level50Bonus = level50Count * _level50BonusPerComp;
    return 1.0 + streakBonus + level50Bonus;
  }

  /// Berechnet die tatsächlich zu vergebenden XP
  int calculateXp(int words, int streakDays, List<Companion> allCompanions) {
    final multiplier = calculateMultiplier(streakDays, allCompanions);
    return (words * multiplier).round();
  }

  /// Gibt true zurück wenn alle Companions #1–#10 auf Level 100 sind
  bool allRegularAtMaxLevel(List<Companion> allCompanions) {
    return allCompanions
        .where((c) => c.slot >= 1 && c.slot <= 10)
        .every((c) => c.isUnlocked && c.level >= Companion.maxLevel);
  }

  /// Zufälligen noch nicht freigeschalteten Companion wählen (exkl. #11)
  /// Gibt null zurück wenn alle bereits freigeschaltet
  int? pickRandomUnlocked(List<Companion> allCompanions) {
    final locked = allCompanions
        .where((c) => c.slot <= 10 && !c.isUnlocked)
        .toList();
    if (locked.isEmpty) return null;
    if (Random().nextDouble() > 0.6) return null;
    locked.shuffle();
    return locked.first.slot;
  }
}