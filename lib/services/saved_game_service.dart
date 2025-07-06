import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';

class SavedGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  /// Saves a game to Firestore.
  Future<void> saveGame(SavedGame game) async {
    try {
      await _firestore
          .collection(Constants.gameHistoryCollection)
          .doc(game.gameId)
          .set(game.toMap());
      _logger.i('Game saved successfully: ${game.gameId}');
    } catch (e) {
      _logger.e('Error saving game: $e');
      throw Exception('Failed to save game.');
    }
  }

  /// Retrieves a list of saved games for a specific user.
  Future<List<SavedGame>> getSavedGamesForUser(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(Constants.gameHistoryCollection)
              .where(Constants.fieldUserId, isEqualTo: userId)
              .orderBy(Constants.fieldCreatedAt, descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => SavedGame.fromMap(doc.data()))
          .toList();
    } catch (e) {
      _logger.e('Error getting saved games for user $userId: $e');
      throw Exception('Failed to retrieve saved games.');
    }
  }

  /// Retrieves a single saved game by its ID.
  Future<SavedGame?> getSavedGameById(String gameId) async {
    try {
      final docSnapshot =
          await _firestore
              .collection(Constants.gameHistoryCollection)
              .doc(gameId)
              .get();

      if (docSnapshot.exists) {
        return SavedGame.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting saved game by ID $gameId: $e');
      throw Exception('Failed to retrieve saved game by ID.');
    }
  }
}
