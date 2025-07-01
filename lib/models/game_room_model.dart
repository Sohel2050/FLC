import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squares/squares.dart';

class GameRoom {
  final String gameId;
  final String gameMode;
  final String player1Id;
  final String? player2Id;
  final String player1DisplayName;
  final String? player2DisplayName;
  final String? player1PhotoUrl;
  final String? player2PhotoUrl;
  final int player1Color; // Squares.white or Squares.black
  final int? player2Color; // Squares.white or Squares.black
  final String status; // "waiting", "active", "completed", "aborted"
  final String fen;
  final List<String> moves; // List of move strings
  final Timestamp createdAt;
  final Timestamp lastMoveAt;
  final int player1Rating;
  final int? player2Rating;
  final bool ratingBasedSearch;
  final int initialWhitesTime; // in milliseconds
  final int initialBlacksTime; // in milliseconds
  final String? winnerId;
  final String? drawOfferedBy; // UID of the player who offered a draw

  GameRoom({
    required this.gameId,
    required this.gameMode,
    required this.player1Id,
    this.player2Id,
    required this.player1DisplayName,
    this.player2DisplayName,
    this.player1PhotoUrl,
    this.player2PhotoUrl,
    required this.player1Color,
    this.player2Color,
    required this.status,
    required this.fen,
    required this.moves,
    required this.createdAt,
    required this.lastMoveAt,
    required this.player1Rating,
    this.player2Rating,
    required this.ratingBasedSearch,
    required this.initialWhitesTime,
    required this.initialBlacksTime,
    this.winnerId,
    this.drawOfferedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'gameMode': gameMode,
      'player1Id': player1Id,
      'player2Id': player2Id,
      'player1DisplayName': player1DisplayName,
      'player2DisplayName': player2DisplayName,
      'player1PhotoUrl': player1PhotoUrl,
      'player2PhotoUrl': player2PhotoUrl,
      'player1Color': player1Color,
      'player2Color': player2Color,
      'status': status,
      'fen': fen,
      'moves': moves,
      'createdAt': createdAt,
      'lastMoveAt': lastMoveAt,
      'player1Rating': player1Rating,
      'player2Rating': player2Rating,
      'ratingBasedSearch': ratingBasedSearch,
      'initialWhitesTime': initialWhitesTime,
      'initialBlacksTime': initialBlacksTime,
      'winnerId': winnerId,
      'drawOfferedBy': drawOfferedBy,
    };
  }

  factory GameRoom.fromMap(Map<String, dynamic> map) {
    return GameRoom(
      gameId: map['gameId'] as String,
      gameMode: map['gameMode'] as String,
      player1Id: map['player1Id'] as String,
      player2Id: map['player2Id'] as String?,
      player1DisplayName: map['player1DisplayName'] as String,
      player2DisplayName: map['player2DisplayName'] as String?,
      player1PhotoUrl: map['player1PhotoUrl'] as String?,
      player2PhotoUrl: map['player2PhotoUrl'] as String?,
      player1Color: map['player1Color'] as int,
      player2Color: map['player2Color'] as int?,
      status: map['status'] as String,
      fen: map['fen'] as String,
      moves: List<String>.from(map['moves'] as List),
      createdAt: map['createdAt'] as Timestamp,
      lastMoveAt: map['lastMoveAt'] as Timestamp,
      player1Rating: map['player1Rating'] as int,
      player2Rating: map['player2Rating'] as int?,
      ratingBasedSearch: map['ratingBasedSearch'] as bool,
      initialWhitesTime: map['initialWhitesTime'] as int,
      initialBlacksTime: map['initialBlacksTime'] as int,
      winnerId: map['winnerId'] as String?,
      drawOfferedBy: map['drawOfferedBy'] as String?,
    );
  }

  GameRoom copyWith({
    String? gameId,
    String? gameMode,
    String? player1Id,
    String? player2Id,
    String? player1DisplayName,
    String? player2DisplayName,
    String? player1PhotoUrl,
    String? player2PhotoUrl,
    int? player1Color,
    int? player2Color,
    String? status,
    String? fen,
    List<String>? moves,
    Timestamp? createdAt,
    Timestamp? lastMoveAt,
    int? player1Rating,
    int? player2Rating,
    bool? ratingBasedSearch,
    int? initialWhitesTime,
    int? initialBlacksTime,
    String? winnerId,
    String? drawOfferedBy,
  }) {
    return GameRoom(
      gameId: gameId ?? this.gameId,
      gameMode: gameMode ?? this.gameMode,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      player1DisplayName: player1DisplayName ?? this.player1DisplayName,
      player2DisplayName: player2DisplayName ?? this.player2DisplayName,
      player1PhotoUrl: player1PhotoUrl ?? this.player1PhotoUrl,
      player2PhotoUrl: player2PhotoUrl ?? this.player2PhotoUrl,
      player1Color: player1Color ?? this.player1Color,
      player2Color: player2Color ?? this.player2Color,
      status: status ?? this.status,
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      createdAt: createdAt ?? this.createdAt,
      lastMoveAt: lastMoveAt ?? this.lastMoveAt,
      player1Rating: player1Rating ?? this.player1Rating,
      player2Rating: player2Rating ?? this.player2Rating,
      ratingBasedSearch: ratingBasedSearch ?? this.ratingBasedSearch,
      initialWhitesTime: initialWhitesTime ?? this.initialWhitesTime,
      initialBlacksTime: initialBlacksTime ?? this.initialBlacksTime,
      winnerId: winnerId ?? this.winnerId,
      drawOfferedBy: drawOfferedBy ?? this.drawOfferedBy,
    );
  }
}
