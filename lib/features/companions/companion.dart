class Companion {
  final int id;
  final int slot;
  final int currentXp;
  final bool isUnlocked;
  final bool isActive;

  const Companion({
    required this.id,
    required this.slot,
    required this.currentXp,
    required this.isUnlocked,
    required this.isActive,
  });

  static const int xpPerLevel = 5000;
  static const int maxLevel = 100;

  bool get isPrestige => slot == 11;

  int get level {
    final l = currentXp ~/ xpPerLevel;
    return isPrestige ? l : l.clamp(0, maxLevel);
  }

  int get xpInCurrentLevel => currentXp % xpPerLevel;
  int get xpToNextLevel => xpPerLevel - xpInCurrentLevel;

  /// Gibt true zurück wenn dieses Level neu erreicht wurde
  bool didLevelUp(int previousXp) {
    final prevLevel = (previousXp ~/ xpPerLevel).clamp(0, isPrestige ? 999999 : maxLevel);
    return level > prevLevel;
  }

  bool get showPrestigeStyle => isPrestige && level >= maxLevel;

  Companion copyWith({int? currentXp, bool? isUnlocked, bool? isActive}) {
    return Companion(
      id: id,
      slot: slot,
      currentXp: currentXp ?? this.currentXp,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Companion.fromMap(Map<String, dynamic> map) {
    return Companion(
      id: map['id'] as int,
      slot: map['slot'] as int,
      currentXp: map['current_xp'] as int,
      isUnlocked: (map['is_unlocked'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slot': slot,
      'current_xp': currentXp,
      'is_unlocked': isUnlocked ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }
}