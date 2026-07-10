import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/session_dao.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/models/read_session.dart';
import '../../core/theme/app_colors.dart';

class StatsSheet extends ConsumerStatefulWidget {
  const StatsSheet({super.key});

  @override
  ConsumerState<StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends ConsumerState<StatsSheet> {
  Map<String, int>? _aggregated;
  List<Map<String, dynamic>>? _dailyCounts;
  List<Map<String, dynamic>>? _hourlyData;
  StreakData? _streak;
  ReadSession? _longestSession;
  int _bestStreak = 0;
  Map<String, int> _currentWeekByDay = {};
  late DateTime _calendarMonth;
  Map<String, List<Map<String, dynamic>>>? _wpmHistoryByMode;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    final dao = SessionDao();
    final results = await Future.wait([
      dao.getAggregatedStats(),
      dao.getCurrentWeekSessions(),
      dao.getDailyWordCounts(),
      StreakService(dao).load(),
      dao.getHourlyWordCounts(),
      dao.getLongestSession(),
      dao.getBestStreak(),
      dao.getWeeklyWpmHistoryByMode(),
    ]);

    if (!mounted) return;
    setState(() {
      _aggregated = results[0] as Map<String, int>;
      final weekSessions = results[1] as List<ReadSession>;
      _dailyCounts = results[2] as List<Map<String, dynamic>>;
      _streak = results[3] as StreakData;
      _hourlyData = results[4] as List<Map<String, dynamic>>;
      _longestSession = results[5] as ReadSession?;
      _bestStreak = results[6] as int;
      _wpmHistoryByMode = results[7] as Map<String, List<Map<String, dynamic>>>;

      // Wörter pro Tag dieser Woche aggregieren
      final weekMap = <String, int>{};
      for (final s in weekSessions) {
        final key = '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}';
        weekMap[key] = (weekMap[key] ?? 0) + s.wordsRead;
      }
      _currentWeekByDay = weekMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Statistiken',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _aggregated == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildOverview(primary),
                      const SizedBox(height: 24),
                      _buildWeekBar(primary),
                      const SizedBox(height: 24),
                      _buildRecords(primary),
                      const SizedBox(height: 24),
                      _buildStreakCalendar(primary),
                      const SizedBox(height: 24),
                      _buildHourlyChart(primary),
                      const SizedBox(height: 24),
                      _buildDailyWordsChart(primary),
                      const SizedBox(height: 24),
                      _buildWpmChart(primary),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── SCHNELLÜBERSICHT ──────────────────────────────────────────────────────

  Widget _buildOverview(Color primary) {
    final totalWords = _aggregated!['total_words'] ?? 0;
    final totalSeconds = _aggregated!['total_seconds'] ?? 0;
    final books = SettingsService.instance.booksReadCount;

    final totalHours = totalSeconds / 3600;
    final timeStr = '${totalHours.toStringAsFixed(1)}h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gesamt'),
        const SizedBox(height: 12),
        Row(
          children: [
            _BigStat(label: 'Wörter', value: '$totalWords', primary: primary),
            const SizedBox(width: 12),
            _BigStat(label: 'Zeit', value: timeStr.trim(), primary: primary),
            const SizedBox(width: 12),
            _BigStat(label: 'Bücher', value: '$books', primary: primary),
          ],
        ),
      ],
    );
  }

  // ── WOCHENBALKEN ─────────────────────────────────────────────────────────

  Widget _buildWeekBar(Color primary) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const goal = kDailyGoalWords;

    final days = List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      final words = _currentWeekByDay[key] ?? 0;
      return (day: day, words: words, label: weekdays[i]);
    });

    final maxWords = days.map((d) => d.words).fold(0, (a, b) => a > b ? a : b);
    final barMax = maxWords < goal ? goal.toDouble() : maxWords.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Diese Woche'),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final isToday =
                  d.day.day == now.day &&
                  d.day.month == now.month &&
                  d.day.year == now.year;
              final isFuture = d.day.isAfter(now);
              final reached = d.words >= goal;
              final barHeight = isFuture
                  ? 0.0
                  : d.words == 0
                  ? 2.0
                  : (d.words / barMax * 110).clamp(2.0, 110.0);

              final barColor = reached
                  ? context.colors.success
                  : isToday
                  ? primary
                  : Colors.white24;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isFuture && d.words > 0)
                      Text(
                        _formatK(d.words),
                        style: TextStyle(
                          color: reached
                              ? context.colors.success
                              : Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.label,
                      style: TextStyle(
                        color: isToday ? primary : Colors.white38,
                        fontSize: 11,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.colors.success,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Tagesziel: ${_formatK(goal)} Wörter',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  // ── STREAK KALENDER ───────────────────────────────────────────────────────

  Widget _buildStreakCalendar(Color primary) {
    if (_dailyCounts == null) return const SizedBox();

    final dayWords = <String, int>{
      for (final row in _dailyCounts!)
        row['day'] as String: row['total_words'] as int? ?? 0,
    };

    final now = DateTime.now();
    final isCurrentMonth =
        _calendarMonth.year == now.year && _calendarMonth.month == now.month;

    const monthNames = [
      '',
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('Streak'),
            const Spacer(),
            Icon(
              Icons.local_fire_department,
              color: (_streak?.streakDays ?? 0) > 0
                  ? context.colors.warning
                  : Colors.white24,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${_streak?.streakDays ?? 0} Tage',
              style: TextStyle(
                color: (_streak?.streakDays ?? 0) > 0
                    ? context.colors.warning
                    : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Monats-Navigation
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.chevron_left,
                color: Colors.white38,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() {
                _calendarMonth = DateTime(
                  _calendarMonth.year,
                  _calendarMonth.month - 1,
                  1,
                );
              }),
            ),
            const SizedBox(width: 8),
            Text(
              '${monthNames[_calendarMonth.month]} ${_calendarMonth.year}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: isCurrentMonth ? Colors.white12 : Colors.white38,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: isCurrentMonth
                  ? null
                  : () => setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month + 1,
                        1,
                      );
                    }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildMonthCalendar(_calendarMonth, dayWords, primary, now),
      ],
    );
  }

  Widget _buildMonthCalendar(
    DateTime month,
    Map<String, int> dayWords,
    Color primary,
    DateTime now,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mo, 7=So

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: (startWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startWeekday - 1) return const SizedBox();
            final day = index - (startWeekday - 1) + 1;
            final date = DateTime(month.year, month.month, day);
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final words = dayWords[key] ?? 0;
            final isToday =
                date.day == now.day &&
                date.month == now.month &&
                date.year == now.year;
            final isFuture = date.isAfter(now);
            final heat = _heatColor(words);
            final hasData = words >= kDailyGoalWords;

            return Container(
              decoration: BoxDecoration(
                color: isFuture ? Colors.transparent : heat,
                borderRadius: BorderRadius.circular(4),
                border: isToday ? Border.all(color: primary, width: 1.5) : null,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        color: isFuture
                            ? Colors.white12
                            : hasData
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    if (!isFuture && words > 0)
                      Text(
                        _formatK(words),
                        style: TextStyle(
                          color: hasData ? Colors.white70 : Colors.white38,
                          fontSize: 7,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Heatmap-Farbe: unter Tagesziel = neutrales Grau (kein Grün verdient).
  /// Ab Ziel wird's grün, bis 500% Ziel zusätzlich dunkler/satter.
  Color _heatColor(int words) {
    if (words < kDailyGoalWords) return Colors.white12;
    final goalColor = context.colors.success;
    final overColor = context.colors.successDark;
    final overRatio = (((words / kDailyGoalWords) - 1.0) / 4.0).clamp(0.0, 1.0);
    return Color.lerp(goalColor, overColor, overRatio)!;
  }

  // ── WPM VERLAUF ───────────────────────────────────────────────────────────

  Widget _buildWpmChart(Color primary) {
    final rsvpData = _wpmHistoryByMode?['rsvp'] ?? [];
    final paraData = _wpmHistoryByMode?['paragraph'] ?? [];

    if (rsvpData.isEmpty && paraData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('WPM-Verlauf'),
          const SizedBox(height: 12),
          const Text(
            'Noch nicht genug Daten.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    List<int> toPoints(List<Map<String, dynamic>> data) => data.map((row) {
          final words = row['total_words'] as int? ?? 0;
          final secs = row['total_seconds'] as int? ?? 0;
          return secs > 0 ? (words / secs * 60).round() : 0;
        }).toList();

    final rsvpPoints = toPoints(rsvpData);
    final paraPoints = toPoints(paraData);

    final allPoints = [...rsvpPoints, ...paraPoints];
    final maxWpm = allPoints.fold<int>(0, (a, b) => a > b ? a : b);
    final minWpm = allPoints.fold<int>(maxWpm, (a, b) => a < b ? a : b);
    final range = (maxWpm - minWpm).toDouble();
    final midWpm = ((maxWpm + minWpm) / 2).round();

    final paraColor = context.colors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('WPM-Verlauf'),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(width: 12, height: 2, color: primary),
            const SizedBox(width: 6),
            const Text('RSVP', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(width: 16),
            Container(width: 12, height: 2, color: paraColor),
            const SizedBox(width: 6),
            const Text('Absatz', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$maxWpm', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                    Text('$midWpm', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                    Text('$minWpm', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _DualWpmLinePainter(
                    rsvpPoints: rsvpPoints,
                    paraPoints: paraPoints,
                    rsvpColor: primary,
                    paraColor: paraColor,
                    minWpm: minWpm.toDouble(),
                    range: range,
                  ),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── REKORDE ───────────────────────────────────────────────────────────────

  Widget _buildRecords(Color primary) {
    final longestWords = _longestSession?.wordsRead ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Rekorde'),
        const SizedBox(height: 12),
        Row(
          children: [
            _BigStat(
              label: 'Längste Session',
              value: '$longestWords Wörter',
              primary: primary,
            ),
            const SizedBox(width: 12),
            _BigStat(
              label: 'Beste Streak',
              value: '$_bestStreak Tage',
              primary: primary,
            ),
          ],
        ),
      ],
    );
  }

  // ── STUNDEN-BALKEN ────────────────────────────────────────────────────────

  Widget _buildHourlyChart(Color primary) {
    if (_hourlyData == null || _hourlyData!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Lieblingszeit'),
          const SizedBox(height: 12),
          const Text(
            'Noch keine Daten.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      );
    }

    // Stunden zu 4 Zonen bündeln
    final zones = {'Morgens': 0, 'Mittags': 0, 'Abends': 0, 'Nachts': 0};
    for (final row in _hourlyData!) {
      final hour = int.tryParse(row['hour'] as String? ?? '') ?? 0;
      final words = row['total_words'] as int? ?? 0;
      if (hour >= 5 && hour < 12) {
        zones['Morgens'] = zones['Morgens']! + words;
      } else if (hour >= 12 && hour < 17) {
        zones['Mittags'] = zones['Mittags']! + words;
      } else if (hour >= 17 && hour < 22) {
        zones['Abends'] = zones['Abends']! + words;
      } else {
        zones['Nachts'] = zones['Nachts']! + words;
      }
    }

    final totalWords = zones.values.fold<int>(0, (a, b) => a + b);
    final peakZone = zones.entries
        .fold<MapEntry<String, int>>(
          const MapEntry('', 0),
          (a, b) => b.value > a.value ? b : a,
        )
        .key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Lieblingszeit'),
        const SizedBox(height: 4),
        Text(
          'Am aktivsten: $peakZone',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: zones.entries.map((entry) {
              final isPeak = entry.key == peakZone;
              final percent = totalWords > 0
                  ? (entry.value / totalWords * 100).round()
                  : 0;
              final barHeight = totalWords > 0
                  ? (entry.value / totalWords * 80).clamp(2.0, 80.0)
                  : 2.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (entry.value > 0)
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: isPeak ? primary : Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isPeak ? primary : Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: isPeak ? primary : Colors.white38,
                          fontSize: 11,
                          fontWeight: isPeak
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── WÖRTER PRO TAG LINIENDIAGRAMM ─────────────────────────────────────────

  Widget _buildDailyWordsChart(Color primary) {
    if (_dailyCounts == null || _dailyCounts!.isEmpty) {
      return const SizedBox();
    }

    // Letzte 30 Tage
    final recent = _dailyCounts!.length > 30
        ? _dailyCounts!.sublist(_dailyCounts!.length - 30)
        : _dailyCounts!;

    final points = recent.map((row) {
      return row['total_words'] as int? ?? 0;
    }).toList();

    final maxWords = points.fold<int>(0, (a, b) => a > b ? a : b);
    final avgWords = points.isEmpty
        ? 0
        : (points.reduce((a, b) => a + b) / points.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Wörter pro Tag'),
        const SizedBox(height: 4),
        Text(
          'Ø $avgWords Wörter · letzte 30 Tage',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatK(maxWords),
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      _formatK(maxWords ~/ 2),
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                      ),
                    ),
                    const Text(
                      '0',
                      style: TextStyle(color: Colors.white24, fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _LinePainter(
                    points: points,
                    color: primary,
                    goalLine: kDailyGoalWords,
                    maxValue: maxWords.toDouble(),
                    goalColor: context.colors.success,
                  ),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                recent.first['day'] as String? ?? '',
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
              const Text(
                'Heute',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── HILFSMETHODEN ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  String _formatK(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── WPM LINE PAINTER ──────────────────────────────────────────────────────────
class _DualWpmLinePainter extends CustomPainter {
  final List<int> rsvpPoints;
  final List<int> paraPoints;
  final Color rsvpColor;
  final Color paraColor;
  final double minWpm;
  final double range;

  _DualWpmLinePainter({
    required this.rsvpPoints,
    required this.paraPoints,
    required this.rsvpColor,
    required this.paraColor,
    required this.minWpm,
    required this.range,
  });

  void _drawLine(Canvas canvas, Size size, List<int> points, Color color) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * i / (points.length - 1);
      final normalized = range == 0 ? 0.5 : (points[i] - minWpm) / range;
      final y = size.height * (1 - normalized * 0.8 - 0.1);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawLine(canvas, size, rsvpPoints, rsvpColor);
    _drawLine(canvas, size, paraPoints, paraColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LinePainter extends CustomPainter {
  final List<int> points;
  final Color color;
  final int goalLine;
  final double maxValue;
  final Color goalColor;

  _LinePainter({
    required this.points,
    required this.color,
    required this.goalLine,
    required this.maxValue,
    required this.goalColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final goalY = maxValue > 0
        ? size.height * (1 - goalLine / maxValue * 0.8 - 0.1)
        : size.height / 2;

    // Ziel-Linie gestrichelt
    final goalPaint = Paint()
      ..color = goalColor.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, goalY),
        Offset(x + dashWidth, goalY),
        goalPaint,
      );
      x += dashWidth + dashSpace;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final px = size.width * i / (points.length - 1);
      final normalized = maxValue > 0 ? points[i] / maxValue : 0.0;
      final py = size.height * (1 - normalized * 0.8 - 0.1);

      if (i == 0) {
        path.moveTo(px, py);
        fillPath.moveTo(px, size.height);
        fillPath.lineTo(px, py);
      } else {
        path.lineTo(px, py);
        fillPath.lineTo(px, py);
      }

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(px, py), 2, dotPaint);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── BIG STAT CARD ─────────────────────────────────────────────────────────────

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color primary;

  const _BigStat({
    required this.label,
    required this.value,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
