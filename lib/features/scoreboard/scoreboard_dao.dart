import 'package:sqflite/sqflite.dart';
import 'scoreboard_models.dart';

class ScoreboardDao {
  final Database db;
  ScoreboardDao(this.db);

  Future<int> insertGame(ScoreboardGame game) async =>
      await db.insert('scoreboard_games', game.toMap());

  Future<void> updateGame(ScoreboardGame game) async => await db.update(
        'scoreboard_games',
        game.toMap(),
        where: 'id = ?',
        whereArgs: [game.id],
      );

  Future<void> deleteGame(int id) async {
    await db.delete('scoreboard_rounds', where: 'game_id = ?', whereArgs: [id]);
    await db.delete('scoreboard_games', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScoreboardGame>> getActiveGames() async {
    final rows = await db.query(
      'scoreboard_games',
      where: 'is_finished = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(ScoreboardGame.fromMap).toList();
  }

  Future<List<ScoreboardGame>> getFinishedGames() async {
    final rows = await db.query(
      'scoreboard_games',
      where: 'is_finished = 1',
      orderBy: 'created_at DESC',
    );
    return rows.map(ScoreboardGame.fromMap).toList();
  }

  Future<ScoreboardGame?> getGame(int id) async {
    final rows = await db.query(
      'scoreboard_games',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return ScoreboardGame.fromMap(rows.first);
  }

  Future<int> insertRound(ScoreboardRound round) async =>
      await db.insert('scoreboard_rounds', round.toMap());

  Future<void> updateRound(ScoreboardRound round) async => await db.update(
        'scoreboard_rounds',
        round.toMap(),
        where: 'id = ?',
        whereArgs: [round.id],
      );

  Future<void> deleteRound(int id) async =>
      await db.delete('scoreboard_rounds', where: 'id = ?', whereArgs: [id]);

  Future<List<ScoreboardRound>> getRounds(int gameId) async {
    final rows = await db.query(
      'scoreboard_rounds',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'round_number ASC',
    );
    return rows.map(ScoreboardRound.fromMap).toList();
  }
}
