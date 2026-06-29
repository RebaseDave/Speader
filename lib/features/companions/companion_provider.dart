import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'companion.dart';
import 'companion_dao.dart';
import 'companion_service.dart';
import '../../core/database/session_dao.dart';
import '../../core/services/streak_service.dart';

class CompanionLevelUp {
  final int slot;
  final int newLevel;
  const CompanionLevelUp({required this.slot, required this.newLevel});
}

class CompanionState {
  final List<Companion> companions;
  final bool isLoading;
  final CompanionLevelUp? pendingLevelUp;

  const CompanionState({
    this.companions = const [],
    this.isLoading = false,
    this.pendingLevelUp,
  });

  Companion? get active =>
      companions.where((c) => c.isActive).firstOrNull;

  List<Companion> get unlocked =>
      companions.where((c) => c.isUnlocked).toList();

  CompanionState copyWith({
    List<Companion>? companions,
    bool? isLoading,
    CompanionLevelUp? pendingLevelUp,
    bool clearLevelUp = false,
  }) {
    return CompanionState(
      companions: companions ?? this.companions,
      isLoading: isLoading ?? this.isLoading,
      pendingLevelUp: clearLevelUp ? null : (pendingLevelUp ?? this.pendingLevelUp),
    );
  }
}

class CompanionNotifier extends AsyncNotifier<CompanionState> {
  final _dao = CompanionDao();
  final _service = CompanionService();

  @override
  Future<CompanionState> build() async {
    final companions = await _dao.getAll();
    return CompanionState(companions: companions);
  }

  Future<void> _reload() async {
    final companions = await _dao.getAll();
    final current = state.value;
    state = AsyncData(
      current!.copyWith(companions: companions),
    );
  }

  /// Wird nach jeder Session aufgerufen
  Future<void> addXpForSession(int words) async {
  final current = state.value;
  if (current == null) return;
  final active = current.active;
  if (active == null) return;

  if (active.slot == 11 && !active.isUnlocked) return;

  final streak = await StreakService(SessionDao()).load();
  final xp = _service.calculateXp(words, streak.displayStreak, current.companions);
    if (xp <= 0) return;

    final previousXp = active.currentXp;
    await _dao.addXp(active.slot, xp);
    await _reload();

    final updated = state.value!.active;
    if (updated == null) return;

    if (updated.didLevelUp(previousXp)) {
      state = AsyncData(
        state.value!.copyWith(
          pendingLevelUp: CompanionLevelUp(
            slot: updated.slot,
            newLevel: updated.level,
          ),
        ),
      );
    }
  }

  /// Wird bei History-Löschung aufgerufen
  Future<void> removeXpForWords(int words) async {
    final current = state.value;
    if (current == null) return;
    final active = current.active;
    if (active == null) return;
    // Kein Multiplier beim Abzug — 1:1 Rückzug
    await _dao.removeXp(active.slot, words);
    await _reload();
  }

  /// Nach Buchabschluss: zufälligen Companion freischalten
  Future<int?> unlockRandomOnBookFinish() async {
    final current = state.value;
    if (current == null) return null;

    final slot = _service.pickRandomUnlocked(current.companions);
    if (slot != null) {
      await _dao.unlock(slot);
    }

    // Prüfen ob #11 freigeschaltet werden soll
    await _reload();
    if (_service.allRegularAtMaxLevel(state.value!.companions)) {
      await _dao.unlock(11);
      await _reload();
    }

    return slot;
  }

  /// User wechselt aktiven Companion
  Future<void> setActive(int slot) async {
    await _dao.setActive(slot);
    await _reload();
  }

  /// Popup wurde angezeigt → Event löschen
  void clearPendingLevelUp() {
    state = AsyncData(state.value!.copyWith(clearLevelUp: true));
  }
}

final companionProvider =
    AsyncNotifierProvider<CompanionNotifier, CompanionState>(
  CompanionNotifier.new,
);