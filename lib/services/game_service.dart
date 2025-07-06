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

  /// Creates a private game room for a friend challenge.
  Future<GameRoom> createPrivateGameRoom({
    required String gameMode,
    required String player1Id,
    required String player2Id,
    required String player1DisplayName,
    String? player1PhotoUrl,
    required int player1Rating,
    required int initialWhitesTime,
    required int initialBlacksTime,
  }) async {
    final String gameId = _uuid.v4();
    final Timestamp now = Timestamp.now();

    final GameRoom newGameRoom = GameRoom(
      gameId: gameId,
      gameMode: gameMode,
      player1Id: player1Id,
      player2Id: player2Id, // Invited friend
      player1DisplayName: player1DisplayName,
      player1PhotoUrl: player1PhotoUrl,
      player1Color: Squares.white,
      status: Constants.statusWaiting, // Waiting for friend to accept
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: [],
      createdAt: now,
      lastMoveAt: now,
      player1Rating: player1Rating,
      ratingBasedSearch: false, // Not for public matchmaking
      initialWhitesTime: initialWhitesTime,
      initialBlacksTime: initialBlacksTime,
      whitesTimeRemaining: initialWhitesTime,
      blacksTimeRemaining: initialBlacksTime,
      player1Score: 0,
      player2Score: 0,
      isPrivate: true, // Mark as private
      spectatorLink: 'https://yourdomain.com/spectate?gameId=$gameId',
    );

    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .set(newGameRoom.toMap());
      _logger.i('Private game room created: $gameId');
      return newGameRoom;
    } catch (e) {
      _logger.e('Error creating private game room: $e');
      rethrow;
    }
  }

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
    int player1Score = 0, // Default to 0
    int player2Score = 0, // Default to 0
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
      whitesTimeRemaining: initialWhitesTime, // Set initial remaining time
      blacksTimeRemaining: initialBlacksTime, // Set initial remaining time
      player1Score: player1Score,
      player2Score: player2Score,
      isPrivate: false,
      spectatorLink: 'https://yourdomain.com/spectate?gameId=$gameId',
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
    required String currentUserId, // Add this parameter
  }) async {
    _logger.i('Finding available game for mode: $gameMode');

    try {
      Query query = _firestore
          .collection(Constants.gameRoomsCollection)
          .where(Constants.fieldGameMode, isEqualTo: gameMode)
          .where(Constants.fieldStatus, isEqualTo: Constants.statusWaiting)
          .where(
            Constants.fieldIsPrivate,
            isEqualTo: false,
          ) // Exclude private games
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

        // Filter out games created by the current user
        for (final doc in snapshot.docs) {
          final gameRoom = GameRoom.fromMap(doc.data() as Map<String, dynamic>);
          if (gameRoom.player1Id != currentUserId) {
            return gameRoom;
          }
        }

        _logger.i(
          'No available games found that are not created by current user',
        );
        return null;
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
      _logger.i('Game room $gameId updated with data: $data');
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
          _logger.i('Received snapshot for game room $gameId');
          return GameRoom.fromMap(snapshot.data() as Map<String, dynamic>);
        });
  }

  // Deletes a game room by its ID.
  /// This method is used when a game is completed or cancelled.
  /// It removes the game room document from Firestore.
  Future<void> deleteGameRoom(String gameId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .delete();
      _logger.i('Game room deleted: $gameId');
    } catch (e) {
      _logger.e('Error deleting game room: $e');
    }
  }

  /// Resigns the game, setting the winner and updating the status to completed.
  Future<void> resignGame(String gameId, String winnerId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldWinnerId: winnerId,
            Constants.fieldStatus: Constants.statusCompleted,
          });
      _logger.i('Game $gameId resigned. Winner: $winnerId');
    } catch (e) {
      _logger.e('Error resigning game $gameId: $e');
      rethrow;
    }
  }

  /// Offers a draw in the game.
  Future<void> offerDraw(String gameId, String offeringPlayerId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({Constants.fieldDrawOfferedBy: offeringPlayerId});
      _logger.i('Draw offered in game $gameId by $offeringPlayerId');
    } catch (e) {
      _logger.e('Error offering draw in game $gameId: $e');
      rethrow;
    }
  }

  /// Handles a draw offer (accept or decline).
  Future<void> handleDrawOffer(String gameId, bool accepted) async {
    try {
      if (accepted) {
        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldStatus: Constants.statusCompleted,
              Constants.fieldDrawOfferedBy: null, // Clear the offer
            });
        // Show game over dialog
        _logger.i('Draw accepted for game $gameId');
      } else {
        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldDrawOfferedBy: null, // Clear the offer
            });
        _logger.i('Draw declined for game $gameId');
      }
    } catch (e) {
      _logger.e('Error handling draw offer for game $gameId: $e');
      rethrow;
    }
  }

  /// Offers a rematch after a game.
  Future<void> offerRematch(String gameId, String offeringPlayerId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({Constants.fieldRematchOfferedBy: offeringPlayerId});
      _logger.i('Rematch offered in game $gameId by $offeringPlayerId');
    } catch (e) {
      _logger.e('Error offering rematch in game $gameId: $e');
      rethrow;
    }
  }

  /// Handles a rematch offer (accept or decline).
  Future<void> handleRematch(
    String gameId,
    bool accepted,
    int player1Score,
    int player2Score,
  ) async {
    try {
      if (accepted) {
        // Fetch the current game room to get initial settings
        final doc =
            await _firestore
                .collection(Constants.gameRoomsCollection)
                .doc(gameId)
                .get();
        if (!doc.exists) {
          throw Exception('Game room $gameId not found for rematch');
        }
        final GameRoom currentRoom = GameRoom.fromMap(
          doc.data() as Map<String, dynamic>,
        );

        // Swap colors for the rematch
        final int newPlayer1Color =
            currentRoom.player1Color == Squares.white
                ? Squares.black
                : Squares.white;
        final int newPlayer2Color =
            currentRoom.player2Color == Squares.white
                ? Squares.black
                : Squares.white;

        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldFen:
                  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', // Reset FEN
              Constants.fieldMoves: [], // Clear moves
              Constants.fieldStatus: Constants.statusActive, // Set to active
              Constants.fieldLastMoveAt: Timestamp.now(),
              Constants.fieldWinnerId: null, // Clear winner
              Constants.fieldDrawOfferedBy: null, // Clear draw offer
              Constants.fieldRematchOfferedBy: null, // Clear rematch offer
              Constants.fieldPlayer1Color: newPlayer1Color, // Swap colors
              Constants.fieldPlayer2Color: newPlayer2Color, // Swap colors
              Constants.fieldWhitesTimeRemaining:
                  currentRoom.initialWhitesTime, // Reset times
              Constants.fieldBlacksTimeRemaining:
                  currentRoom.initialBlacksTime, // Reset times
              Constants.fieldPlayer1Score: player1Score, // Update scores
              Constants.fieldPlayer2Score: player2Score, // Update scores
            });
        _logger.i(
          'Rematch accepted for game $gameId. Game reset with swapped colors.',
        );
      } else {
        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldRematchOfferedBy: null, // Clear the offer
            });
        _logger.i('Rematch declined for game $gameId');
      }
    } catch (e) {
      _logger.e('Error handling rematch offer for game $gameId: $e');
      rethrow;
    }
  }

  Future<GameRoom?> getCurrentGameForUser(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection(Constants.gameRoomsCollection)
              .where(Constants.fieldStatus, isEqualTo: Constants.statusActive)
              .where(Constants.fieldPlayer1Id, isEqualTo: userId)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return GameRoom.fromMap(snapshot.docs.first.data());
      }

      final snapshot2 =
          await _firestore
              .collection(Constants.gameRoomsCollection)
              .where(Constants.fieldStatus, isEqualTo: Constants.statusActive)
              .where(Constants.fieldPlayer2Id, isEqualTo: userId)
              .get();

      if (snapshot2.docs.isNotEmpty) {
        return GameRoom.fromMap(snapshot2.docs.first.data());
      }

      return null;
    } catch (e) {
      _logger.e('Error getting current game for user $userId: $e');
      return null;
    }
  }

  /// Updates only the scores for a given game room.
  Future<void> updateGameScores(
    String gameId,
    int player1Score,
    int player2Score,
  ) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldPlayer1Score: player1Score,
            Constants.fieldPlayer2Score: player2Score,
          });
      _logger.i(
        'Scores updated for game $gameId: P1: $player1Score, P2: $player2Score',
      );
    } catch (e) {
      _logger.e('Error updating scores for game $gameId: $e');
      // We might not want to rethrow here to avoid crashing the app if score update fails
    }
  }
}
