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

  static const List<Map<String, dynamic>> gameModes = [
    {'title': 'Classical', 'timeControl': '60 sec/move', 'icon': Icons.timer},
    {'title': 'Blitz', 'timeControl': '5 min + 3 sec', 'icon': Icons.bolt},
    {'title': 'Tempo', 'timeControl': '20 sec/move', 'icon': Icons.speed},
    {'title': 'Quick Blitz', 'timeControl': '3 min', 'icon': Icons.flash_on},
  ];
}
