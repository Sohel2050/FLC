import 'package:flutter_chess_app/utils/constants.dart';

class ChessUser {
  final String? uid;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final int classicalRating;
  final int blitzRating;
  final int tempoRating;
  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final int gamesDraw;
  final List<String> achievements;
  final List<String> friends;
  final bool isOnline;
  final DateTime lastSeen;
  final bool isGuest;
  final Map<String, int> winStreak;
  final List<String> savedGames;
  final Map<String, String> preferences;

  ChessUser({
    this.uid,
    this.email,
    required this.displayName,
    this.photoUrl,
    this.classicalRating = 1200,
    this.blitzRating = 1200,
    this.tempoRating = 1200,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.gamesDraw = 0,
    this.achievements = const [],
    this.friends = const [],
    this.isOnline = false,
    DateTime? lastSeen,
    this.isGuest = false,
    this.winStreak = const {},
    this.savedGames = const [],
    this.preferences = const {},
  }) : this.lastSeen = lastSeen ?? DateTime.now();

  factory ChessUser.guest() {
    return ChessUser(displayName: Constants.guestDisplayName, isGuest: true);
  }

  Map<String, dynamic> toMap() {
    return {
      Constants.uid: uid,
      Constants.email: email,
      Constants.displayName: displayName,
      Constants.photoUrl: photoUrl,
      Constants.classicalRating: classicalRating,
      Constants.blitzRating: blitzRating,
      Constants.tempoRating: tempoRating,
      Constants.gamesPlayed: gamesPlayed,
      Constants.gamesWon: gamesWon,
      Constants.gamesLost: gamesLost,
      Constants.gamesDraw: gamesDraw,
      Constants.achievements: achievements,
      Constants.friends: friends,
      Constants.isOnline: isOnline,
      Constants.lastSeen: lastSeen.toIso8601String(),
      Constants.isGuest: isGuest,
      Constants.winStreak: winStreak,
      Constants.savedGames: savedGames,
      Constants.preferences: preferences,
    };
  }

  factory ChessUser.fromMap(Map<String, dynamic> map) {
    return ChessUser(
      uid: map[Constants.uid] ?? '',
      email: map[Constants.email] ?? '',
      displayName: map[Constants.displayName] ?? '',
      photoUrl: map[Constants.photoUrl] ?? '',
      classicalRating: map[Constants.classicalRating] ?? 1200,
      blitzRating: map[Constants.blitzRating] ?? 1200,
      tempoRating: map[Constants.tempoRating] ?? 1200,
      gamesPlayed: map[Constants.gamesPlayed] ?? 0,
      gamesWon: map[Constants.gamesWon] ?? 0,
      gamesLost: map[Constants.gamesLost] ?? 0,
      gamesDraw: map[Constants.gamesDraw] ?? 0,
      achievements: List<String>.from(map[Constants.achievements] ?? []),
      friends: List<String>.from(map[Constants.friends] ?? []),
      isOnline: map[Constants.isOnline] ?? false,
      lastSeen: DateTime.parse(
        map[Constants.lastSeen] ?? DateTime.now().toIso8601String(),
      ),
      isGuest: map[Constants.isGuest] ?? false,
      winStreak: Map<String, int>.from(map[Constants.winStreak] ?? {}),
      savedGames: List<String>.from(map[Constants.savedGames] ?? []),
      preferences: Map<String, String>.from(map[Constants.preferences] ?? {}),
    );
  }
}
