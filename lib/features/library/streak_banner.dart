import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'streak_provider.dart';
import '../../core/services/streak_service.dart';

class StreakBanner extends ConsumerWidget {
  const StreakBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);

    return streakAsync.when(
      loading: () => const SizedBox(height: 56),
      error: (_, __) => const SizedBox(),
      data: (data) => _Banner(data: data),
    );
  }
}

class _Banner extends StatelessWidget {
  final StreakData data;
  const _Banner({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.goalReachedToday
        ? const Color(0xFF4CAF50)
        : Theme.of(context).colorScheme.primary;

    final wordsLeft = kDailyGoalWords - data.todayWords;
    final label = data.goalReachedToday
        ? 'Tagesziel erreicht!'
        : '${_format(wordsLeft)} Wörter bis zum Ziel';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Streak-Flamme
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: data.goalReachedToday
                    ? Colors.orange
                    : data.isPending
                    ? Colors.white38
                    : Colors.white24,
                size: 22,
              ),
              const SizedBox(width: 4),
              Text(
                '${data.displayStreak}',
                style: TextStyle(
                  color: data.goalReachedToday
                      ? Colors.orange
                      : data.isPending
                      ? Colors.white38
                      : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Fortschrittsbalken + Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: data.goalReachedToday ? color : Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.progress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Heute-Zahl
          Text(
            '${_format(data.todayWords)} / ${_format(kDailyGoalWords)}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
