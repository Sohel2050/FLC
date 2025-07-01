import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:squares/squares.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  /// Creates a new game room in Firestore.
  Future<GameRoom> createGameRoom({
    required String gameMode,
    required String player1Id,
    required String player1DisplayName,
    String? player1PhotoUrl,
    required int player1Rating,
    required bool ratingBasedSearch,
    required int initialWhitesTime,
    required int initialBlacksTime,
  }) async {
    final String gameId = _uuid.v4();
    final Timestamp now = Timestamp.now();

    // Player 1 always starts as White when creating a new game
    final GameRoom newGameRoom = GameRoom(
      gameId: gameId,
      gameMode: gameMode,
      player1Id: player1Id,
      player1DisplayName: player1DisplayName,
      player1PhotoUrl: player1PhotoUrl,
      player1Color: Squares.white,
      status: Constants.statusWaiting,
      fen:
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', // Initial FEN
      moves: [], // Empty list of move strings
      createdAt: now,
      lastMoveAt: now,
      player1Rating: player1Rating,
      ratingBasedSearch: ratingBasedSearch,
      initialWhitesTime: initialWhitesTime,
      initialBlacksTime: initialBlacksTime,
    );

    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .set(newGameRoom.toMap());
      _logger.i('Game room created: $gameId');
      return newGameRoom;
    } catch (e) {
      _logger.e('Error creating game room: $e');
      rethrow;
    }
  }

  /// Finds an available game room based on game mode and rating.
  Future<GameRoom?> findAvailableGame({
    required String gameMode,
    required int userRating,
    required bool ratingBasedSearch,
  }) async {
    try {
      Query query = _firestore
          .collection(Constants.gameRoomsCollection)
          .where(Constants.fieldGameMode, isEqualTo: gameMode)
          .where(Constants.fieldStatus, isEqualTo: Constants.statusWaiting)
          .orderBy(
            Constants.fieldCreatedAt,
            descending: false,
          ); // Join oldest game first

      if (ratingBasedSearch) {
        // Define a rating range (e.g., +/- 200 points)
        const int ratingTolerance = 200;
        final int minRating = userRating - ratingTolerance;
        final int maxRating = userRating + ratingTolerance;

        query = query
            .where(
              Constants.fieldPlayer1Rating,
              isGreaterThanOrEqualTo: minRating,
            )
            .where(
              Constants.fieldPlayer1Rating,
              isLessThanOrEqualTo: maxRating,
            );
      }

      final QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _logger.i('Found ${snapshot.docs.length} available games.');
        return GameRoom.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
        );
      } else {
        _logger.i('No available games found for mode: $gameMode');
        return null;
      }
    } catch (e) {
      _logger.e('Error finding available game: $e');
      return null;
    }
  }

  /// Joins an existing game room.
  Future<void> joinGameRoom({
    required String gameId,
    required String player2Id,
    required String player2DisplayName,
    String? player2PhotoUrl,
    required int player2Rating,
  }) async {
    try {
      // Player 2 always plays as Black when joining an existing game
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldPlayer2Id: player2Id,
            Constants.fieldPlayer2DisplayName: player2DisplayName,
            Constants.fieldPlayer2PhotoUrl: player2PhotoUrl,
            Constants.fieldPlayer2Color: Squares.black,
            Constants.fieldPlayer2Rating: player2Rating,
            Constants.fieldStatus: Constants.statusActive,
            Constants.fieldLastMoveAt: Timestamp.now(),
          });
      _logger.i('Player $player2DisplayName joined game room: $gameId');
    } catch (e) {
      _logger.e('Error joining game room: $e');
      rethrow;
    }
  }

  /// Updates a game room with new data.
  Future<void> updateGameRoom(String gameId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update(data);
      _logger.i('Game room $gameId updated.');
    } catch (e) {
      _logger.e('Error updating game room $gameId: $e');
      rethrow;
    }
  }

  /// Streams real-time updates for a specific game room.
  Stream<GameRoom> streamGameRoom(String gameId) {
    return _firestore
        .collection(Constants.gameRoomsCollection)
        .doc(gameId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            _logger.w('Game room $gameId does not exist for streaming.');
            throw Exception('Game room does not exist');
          }
          return GameRoom.fromMap(snapshot.data() as Map<String, dynamic>);
        });
  }
}
