import 'dart:convert';

enum GameType { basic, wizard, pingpong }

class ScoreboardGame {
  final int? id;
  final GameType gameType;
  final String name;
  final List<String> playerNames;
  final int? scoreTarget;
  final DateTime createdAt;
  final bool isFinished;

  const ScoreboardGame({
    this.id,
    required this.gameType,
    required this.name,
    required this.playerNames,
    this.scoreTarget,
    required this.createdAt,
    this.isFinished = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'game_type': gameType.name,
        'name': name,
        'player_names': jsonEncode(playerNames),
        'score_target': scoreTarget,
        'created_at': createdAt.toIso8601String(),
        'is_finished': isFinished ? 1 : 0,
      };

  factory ScoreboardGame.fromMap(Map<String, dynamic> m) => ScoreboardGame(
        id: m['id'] as int?,
        gameType: GameType.values.byName(m['game_type'] as String),
        name: m['name'] as String,
        playerNames:
            List<String>.from(jsonDecode(m['player_names'] as String)),
        scoreTarget: m['score_target'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
        isFinished: (m['is_finished'] as int) == 1,
      );

  ScoreboardGame copyWith({
    int? id,
    GameType? gameType,
    String? name,
    List<String>? playerNames,
    int? scoreTarget,
    bool clearScoreTarget = false,
    DateTime? createdAt,
    bool? isFinished,
  }) =>
      ScoreboardGame(
        id: id ?? this.id,
        gameType: gameType ?? this.gameType,
        name: name ?? this.name,
        playerNames: playerNames ?? this.playerNames,
        scoreTarget:
            clearScoreTarget ? null : (scoreTarget ?? this.scoreTarget),
        createdAt: createdAt ?? this.createdAt,
        isFinished: isFinished ?? this.isFinished,
      );
}

class ScoreboardRound {
  final int? id;
  final int gameId;
  final int roundNumber;
  final Map<String, dynamic> data;

  const ScoreboardRound({
    this.id,
    required this.gameId,
    required this.roundNumber,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'game_id': gameId,
        'round_number': roundNumber,
        'data': jsonEncode(data),
      };

  factory ScoreboardRound.fromMap(Map<String, dynamic> m) => ScoreboardRound(
        id: m['id'] as int?,
        gameId: m['game_id'] as int,
        roundNumber: m['round_number'] as int,
        data: jsonDecode(m['data'] as String) as Map<String, dynamic>,
      );

  ScoreboardRound copyWith({Map<String, dynamic>? data}) => ScoreboardRound(
        id: id,
        gameId: gameId,
        roundNumber: roundNumber,
        data: data ?? this.data,
      );
}
