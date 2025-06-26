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
