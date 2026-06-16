import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/streak_service.dart';
import '../../core/database/session_dao.dart';

final streakProvider = FutureProvider<StreakData>((ref) async {
  final dao = SessionDao();
  return StreakService(dao).load();
});