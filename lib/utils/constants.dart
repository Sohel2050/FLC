import 'package:flutter/material.dart';

class Constants {
  static const String uid = 'uid';
  static const String email = 'email';
  static const String displayName = 'displayName';
  static const String photoUrl = 'photoUrl';
  static const String classicalRating = 'classicalRating';
  static const String blitzRating = 'blitzRating';
  static const String tempoRating = 'tempoRating';
  static const String gamesPlayed = 'gamesPlayed';
  static const String gamesWon = 'gamesWon';
  static const String gamesLost = 'gamesLost';
  static const String gamesDraw = 'gamesDraw';
  static const String achievements = 'achievements';
  static const String friends = 'friends';
  static const String isOnline = 'isOnline';
  static const String lastSeen = 'lastSeen';
  static const String isGuest = 'isGuest';
  static const String winStreak = 'winStreak';
  static const String savedGames = 'savedGames';
  static const String preferences = 'preferences';

  // For the guest user's display name
  static const String guestDisplayName = 'Guest';

  static const String timeControl = 'timeControl';
  static const String title = 'title';
  static const String icon = 'icon';

  static const String white = 'White';
  static const String black = 'Black';
  static const name = 'name';
  static const level = 'level';
  static const description = 'description';
  static const String gameId = 'gameId';
  static const String gameMode = 'gameMode';
  static const String difficulty = 'difficulty';

  // Database collection names
  static const String usersCollection = 'users';
  static const String gamesCollection = 'games';
  static const String friendsCollection = 'friends';
  static const String achievementsCollection = 'achievements';
  static const String gameRoomsCollection = 'gameRooms';
  static const String gameHistoryCollection = 'gameHistory';

  // Firestore fields
  static const String fieldPlayer1Id = 'player1Id';
  static const String fieldPlayer2Id = 'player2Id';
  static const String fieldPlayer1DisplayName = 'player1DisplayName';
  static const String fieldPlayer2DisplayName = 'player2DisplayName';
  static const String fieldPlayer1PhotoUrl = 'player1PhotoUrl';
  static const String fieldPlayer2PhotoUrl = 'player2PhotoUrl';
  static const String fieldPlayer1Color = 'player1Color';
  static const String fieldPlayer2Color = 'player2Color';
  static const String fieldStatus = 'status';
  static const String fieldFen = 'fen';
  static const String fieldMoves = 'moves';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldLastMoveAt = 'lastMoveAt';
  static const String fieldPlayer1Rating = 'player1Rating';
  static const String fieldPlayer2Rating = 'player2Rating';
  static const String fieldRatingBasedSearch = 'ratingBasedSearch';
  static const String fieldInitialWhitesTime = 'initialWhitesTime';
  static const String fieldInitialBlacksTime = 'initialBlacksTime';
  static const String fieldWinnerId = 'winnerId';
  static const String fieldDrawOfferedBy = 'drawOfferedBy';
  static const String fieldRematchOfferedBy = 'rematchOfferedBy';

  static const String fieldWhitesTimeRemaining = 'whitesTimeRemaining';
  static const String fieldBlacksTimeRemaining = 'blacksTimeRemaining';
  static const String fieldPlayer1Score = 'player1Score';
  static const String fieldPlayer2Score = 'player2Score';

  // Saved Game fields
  static const String fieldUserId = 'userId';
  static const String fieldOpponentId = 'opponentId';
  static const String fieldOpponentDisplayName = 'opponentDisplayName';
  static const String fieldInitialFen = 'initialFen';
  static const String fieldResult = 'result';
  static const String fieldWinnerColor = 'winnerColor';
  static const String fieldFinalWhitesTime = 'finalWhitesTime';
  static const String fieldFinalBlacksTime = 'finalBlacksTime';

  static const String fieldGameId = 'gameId';
  static const String fieldGameMode = 'gameMode';
  static const String fieldDifficulty = 'difficulty';

  // "waiting", "active", "completed", "aborted"
  static const String statusWaiting = 'waiting';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusAborted = 'aborted';

  // Game results
  static const String win = 'win';
  static const String loss = 'loss';
  static const String draw = 'draw';
  static const String none = 'none';

  static const String classical = 'Classical';
  static const String blitz = 'Blitz';
  static const String tempo = 'Tempo';
  static const String quickBlitz = 'Quick Blitz';

  // Map game modes to rating types
  static const Map<String, String> gameModeToRatingType = {
    '60 sec/move': classicalRating,
    '5 min + 3 sec': blitzRating,
    '20 sec/move': tempoRating,
    '3 min': blitzRating, // Quick Blitz also uses Blitz rating
  };

  static const List<Map<String, dynamic>> gameModes = [
    {'title': 'Classical', 'timeControl': '60 sec/move', 'icon': Icons.timer},
    {'title': 'Blitz', 'timeControl': '5 min + 3 sec', 'icon': Icons.bolt},
    {'title': 'Tempo', 'timeControl': '20 sec/move', 'icon': Icons.speed},
    {'title': 'Quick Blitz', 'timeControl': '3 min', 'icon': Icons.flash_on},
  ];

  static const List<Map<String, dynamic>> difficulties = [
    {
      'name': 'Easy',
      'level': 1,
      'description': 'Good for beginners',
      'icon': Icons.sentiment_satisfied,
    },
    {
      'name': 'Normal',
      'level': 2,
      'description': 'Balanced gameplay',
      'icon': Icons.sentiment_neutral,
    },
    {
      'name': 'Hard',
      'level': 3,
      'description': 'Challenging opponent',
      'icon': Icons.sentiment_very_dissatisfied,
    },
  ];
}
