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
    required String playerFlag,
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
      player1Flag: playerFlag,
      player2Flag: '',
      player1Color: Squares.white,
      status: Constants.statusWaiting,
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: [],
      createdAt: now,
      lastMoveAt: now,
      player1Rating: player1Rating,
      ratingBasedSearch: false,
      initialWhitesTime: initialWhitesTime,
      initialBlacksTime: initialBlacksTime,
      whitesTimeRemaining: initialWhitesTime,
      blacksTimeRemaining: initialBlacksTime,
      player1Score: 0,
      player2Score: 0,
      isPrivate: true,
      spectatorLink: null,
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

  /// Validates that a user has all required fields for game matching.
  Future<bool> validateUserForGameMatching(String userId) async {
    try {
      final userDoc =
          await _firestore
              .collection(Constants.usersCollection)
              .doc(userId)
              .get();

      if (!userDoc.exists) {
        _logger.e('User document not found for userId: $userId');
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final isGuest = userData[Constants.isGuest] ?? false;

      // Required fields for all users
      final requiredFields = [
        Constants.uid,
        Constants.displayName,
        Constants.isOnline,
        Constants.classicalRating,
        Constants.blitzRating,
        Constants.tempoRating,
      ];

      for (final field in requiredFields) {
        if (!userData.containsKey(field) || userData[field] == null) {
          _logger.e(
            'Missing required field "$field" for user $userId (isGuest: $isGuest)',
          );
          return false;
        }
      }

      // Validate rating values are reasonable
      final classicalRating = userData[Constants.classicalRating] as int? ?? 0;
      final blitzRating = userData[Constants.blitzRating] as int? ?? 0;
      final tempoRating = userData[Constants.tempoRating] as int? ?? 0;

      if (classicalRating < 100 || blitzRating < 100 || tempoRating < 100) {
        _logger.e(
          'Invalid rating values for user $userId: classical=$classicalRating, blitz=$blitzRating, tempo=$tempoRating',
        );
        return false;
      }

      _logger.i('User $userId validation successful (isGuest: $isGuest)');
      return true;
    } catch (e) {
      _logger.e('Error validating user $userId for game matching: $e');
      return false;
    }
  }

  /// Verifies that a created game room is discoverable by other players.
  Future<void> _verifyGameRoomDiscoverability(
    String gameId,
    String gameMode,
  ) async {
    try {
      // Wait a moment for Firestore to propagate the write
      await Future.delayed(const Duration(milliseconds: 500));

      final query = _firestore
          .collection(Constants.gameRoomsCollection)
          .where(Constants.fieldGameId, isEqualTo: gameId)
          .where(Constants.fieldGameMode, isEqualTo: gameMode)
          .where(Constants.fieldStatus, isEqualTo: Constants.statusWaiting);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _logger.w(
          'Game room $gameId may not be discoverable - not found in query',
        );
      } else {
        _logger.i('Game room $gameId is discoverable and ready for matching');
      }
    } catch (e) {
      _logger.e('Error verifying game room discoverability for $gameId: $e');
      // Don't throw here as the game room was created successfully
    }
  }

  /// Creates a new game room in Firestore.
  /// Validates the user before creating the game room.
  Future<GameRoom> createGameRoom({
    required String gameMode,
    required String player1Id,
    required String player1DisplayName,
    String? player1PhotoUrl,
    required String player1Flag,
    required String player2Flag,
    required int player1Rating,
    required bool ratingBasedSearch,
    required int initialWhitesTime,
    required int initialBlacksTime,
    int player1Score = 0, // Default to 0
    int player2Score = 0, // Default to 0
  }) async {
    final String gameId = _uuid.v4();
    final Timestamp now = Timestamp.now();

    _logger.i(
      'Creating game room for player: $player1Id ($player1DisplayName), mode: $gameMode, rating: $player1Rating',
    );

    // Validate user before creating game room
    final isValidUser = await validateUserForGameMatching(player1Id);
    if (!isValidUser) {
      throw Exception('User $player1Id is not valid for game matching');
    }

    // Player 1 always starts as White when creating a new game
    final GameRoom newGameRoom = GameRoom(
      gameId: gameId,
      gameMode: gameMode,
      player1Id: player1Id,
      player1DisplayName: player1DisplayName,
      player1PhotoUrl: player1PhotoUrl,
      player1Flag: player1Flag,
      player2Flag: player2Flag,
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
      spectatorLink: null,
    );

    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .set(newGameRoom.toMap());
      _logger.i(
        'Game room created successfully: $gameId for player $player1Id',
      );

      // Verify the game room was created and is discoverable
      await _verifyGameRoomDiscoverability(gameId, gameMode);

      return newGameRoom;
    } catch (e) {
      _logger.e('Error creating game room for player $player1Id: $e');
      rethrow;
    }
  }

  // Send game notification to friends notification collection
  Future<void> sendGameNotification({required GameRoom gameRoom}) async {
    try {
      await _firestore
          .collection(Constants.notificationsCollection)
          .doc(gameRoom.player2Id)
          .collection(Constants.invitesCollection)
          .doc(gameRoom.gameId)
          .set(gameRoom.toMap());
      _logger.i('Game notification sent to ${gameRoom.player2Id}');
    } catch (e) {
      _logger.e('Error sending game notification: $e');
    }
  }

  /// Finds an available game room based on game mode and rating.
  /// This method includes guest users in the search and provides detailed logging.
  Future<GameRoom?> findAvailableGame({
    required String gameMode,
    required int userRating,
    bool ratingBasedSearch = false,
    bool isPrivate = false,
    required String currentUserId, // Add this parameter
  }) async {
    _logger.i(
      'Finding available game for mode: $gameMode, userRating: $userRating, currentUserId: $currentUserId',
    );

    try {
      Query query = _firestore
          .collection(Constants.gameRoomsCollection)
          .where(Constants.fieldGameMode, isEqualTo: gameMode)
          .where(Constants.fieldStatus, isEqualTo: Constants.statusWaiting)
          .where(
            Constants.fieldIsPrivate,
            isEqualTo: isPrivate,
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

        _logger.i('Using rating-based search: $minRating - $maxRating');
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
      _logger.i('Query returned ${snapshot.docs.length} potential games');

      if (snapshot.docs.isNotEmpty) {
        // Filter out games created by the current user and check if creator is online
        for (final doc in snapshot.docs) {
          final gameRoom = GameRoom.fromMap(doc.data() as Map<String, dynamic>);
          _logger.i(
            'Checking game ${gameRoom.gameId} created by ${gameRoom.player1Id}',
          );

          if (gameRoom.player1Id != currentUserId) {
            // Check if the game creator is online
            final creatorDoc =
                await _firestore
                    .collection(Constants.usersCollection)
                    .doc(gameRoom.player1Id)
                    .get();

            if (creatorDoc.exists) {
              final creatorData = creatorDoc.data() as Map<String, dynamic>;
              final isCreatorOnline = creatorData[Constants.isOnline] ?? false;
              final isCreatorGuest = creatorData[Constants.isGuest] ?? false;

              _logger.i(
                'Game creator ${gameRoom.player1Id}: online=$isCreatorOnline, isGuest=$isCreatorGuest',
              );

              if (isCreatorOnline) {
                _logger.i(
                  'Found suitable game ${gameRoom.gameId} created by ${gameRoom.player1Id}',
                );
                return gameRoom;
              } else {
                _logger.i(
                  'Game creator ${gameRoom.player1Id} is offline, skipping game ${gameRoom.gameId}',
                );
              }
            } else {
              _logger.w(
                'Game creator ${gameRoom.player1Id} document not found, skipping game ${gameRoom.gameId}',
              );
            }
          } else {
            _logger.i('Skipping own game ${gameRoom.gameId}');
          }
        }

        _logger.i(
          'No available games found that are not created by current user and have online creators',
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
    required String player2Flag,
    required int player2Rating,
  }) async {
    _logger.i(
      'Player $player2Id ($player2DisplayName) attempting to join game room: $gameId',
    );

    // Validate user before joining game room
    final isValidUser = await validateUserForGameMatching(player2Id);
    if (!isValidUser) {
      throw Exception('User $player2Id is not valid for game matching');
    }

    try {
      // Player 2 always plays as Black when joining an existing game
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldPlayer2Id: player2Id,
            Constants.fieldPlayer2DisplayName: player2DisplayName,
            Constants.fieldPlayer2PhotoUrl: player2PhotoUrl,
            Constants.fieldPlayer2Flag: player2Flag,
            Constants.fieldPlayer2Color: Squares.black,
            Constants.fieldPlayer2Rating: player2Rating,
            Constants.fieldStatus: Constants.statusActive,
            Constants.fieldLastMoveAt: Timestamp.now(),
          });
      _logger.i(
        'Player $player2Id ($player2DisplayName) successfully joined game room: $gameId',
      );
    } catch (e) {
      _logger.e('Error joining game room $gameId for player $player2Id: $e');
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
          if (!snapshot.exists || snapshot.data() == null) {
            _logger.w('Game room $gameId does not exist or has no data.');
            throw Exception('Game room does not exist or is empty');
          }
          final data = snapshot.data() as Map<String, dynamic>;
          _logger.i('Received snapshot for game room $gameId: $data');
          try {
            return GameRoom.fromMap(data);
          } catch (e, stacktrace) {
            _logger.e(
              'Error parsing game room $gameId: $e',
              error: e,
              stackTrace: stacktrace,
            );
            throw Exception('Failed to parse game room data');
          }
        });
  }

  Stream<List<GameRoom>> streamGameInvites(String userId) {
    return _firestore
        .collection(Constants.notificationsCollection)
        .doc(userId)
        .collection(Constants.invitesCollection)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GameRoom.fromMap(doc.data())).toList(),
        );
  }

  Future<void> declineGameInvite(String gameId, String userId) async {
    try {
      // Delete the game room
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({Constants.fieldStatus: Constants.statusDeclined});

      // Delete the notification
      await deleteGameNotification(userId, gameId);

      _logger.i('Game invite declined: $gameId');
    } catch (e) {
      _logger.e('Error declining game invite: $e');
      rethrow;
    }
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

  // Delete a game notification
  /// This is used when the game has started or canclled
  Future<void> deleteGameNotification(String userId, String gameId) async {
    try {
      final game =
          await _firestore
              .collection(Constants.notificationsCollection)
              .doc(userId)
              .collection(Constants.invitesCollection)
              .doc(gameId)
              .get();

      if (game.exists && game.data() != null) {
        await _firestore
            .collection(Constants.notificationsCollection)
            .doc(userId)
            .collection(Constants.invitesCollection)
            .doc(gameId)
            .delete();
        _logger.i('Game notification deleted: $gameId');
      }
    } catch (e) {
      _logger.e('Error deleting game room: $e');
    }
  }

  /// Resigns the game, setting the winner and updating the status to completed.
  Future<void> resignGame(String gameId, String winnerId) async {
    try {
      final game =
          await _firestore
              .collection(Constants.gameRoomsCollection)
              .doc(gameId)
              .get();

      if (game.exists && game.data() != null) {
        // update the game
        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldWinnerId: winnerId,
              Constants.fieldStatus: Constants.statusCompleted,
            });
        _logger.i('Game $gameId resigned. Winner: $winnerId');
      }
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

  /// Aborts the game.
  Future<void> abortGame(String gameId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({Constants.fieldStatus: Constants.statusAborted});
      _logger.i('Game $gameId aborted.');
    } catch (e) {
      _logger.e('Error aborting game $gameId: $e');
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

  // Audio Room Management Methods

  /// Invites opponent to join audio room
  Future<void> inviteToAudioRoom(String gameId, String invitingUserId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldAudioRoomStatus: Constants.audioStatusInvitePending,
            Constants.fieldAudioRoomInvitedBy: invitingUserId,
            Constants.fieldAudioRoomCreatedAt: Timestamp.now(),
            Constants.fieldAudioRoomUpdatedAt: Timestamp.now(),
          });
      _logger.i(
        'Audio room invitation sent for game $gameId by $invitingUserId',
      );
    } catch (e) {
      _logger.e('Error inviting to audio room for game $gameId: $e');
      rethrow;
    }
  }

  /// Handles audio room invitation response
  Future<void> handleAudioRoomInvitation(
    String gameId,
    String respondingUserId,
    bool accepted,
  ) async {
    try {
      if (accepted) {
        // Get the inviting user ID to add both users to participants
        final doc =
            await _firestore
                .collection(Constants.gameRoomsCollection)
                .doc(gameId)
                .get();

        if (!doc.exists) {
          throw Exception('Game room $gameId not found');
        }

        final gameRoom = GameRoom.fromMap(doc.data() as Map<String, dynamic>);
        final invitingUserId = gameRoom.audioRoomInvitedBy;

        if (invitingUserId == null) {
          throw Exception('No audio room invitation found for game $gameId');
        }

        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldAudioRoomStatus: Constants.audioStatusActive,
              Constants.fieldAudioRoomParticipants: [
                invitingUserId,
                respondingUserId,
              ],
              Constants.fieldAudioRoomUpdatedAt: Timestamp.now(),
            });
        _logger.i(
          'Audio room invitation accepted for game $gameId by $respondingUserId',
        );
      } else {
        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldAudioRoomStatus: Constants.audioStatusDeclined,
              Constants.fieldAudioRoomUpdatedAt: Timestamp.now(),
            });
        _logger.i(
          'Audio room invitation declined for game $gameId by $respondingUserId',
        );
      }
    } catch (e) {
      _logger.e('Error handling audio room invitation for game $gameId: $e');
      rethrow;
    }
  }

  /// Joins the audio room (for when user accepts invitation)
  Future<void> joinAudioRoom(String gameId, String userId) async {
    try {
      final doc =
          await _firestore
              .collection(Constants.gameRoomsCollection)
              .doc(gameId)
              .get();

      if (!doc.exists) {
        throw Exception('Game room $gameId not found');
      }

      final gameRoom = GameRoom.fromMap(doc.data() as Map<String, dynamic>);
      final participants = List<String>.from(gameRoom.audioRoomParticipants);

      if (!participants.contains(userId)) {
        participants.add(userId);

        await _firestore
            .collection(Constants.gameRoomsCollection)
            .doc(gameId)
            .update({
              Constants.fieldAudioRoomParticipants: participants,
              Constants.fieldAudioRoomUpdatedAt: Timestamp.now(),
            });
        _logger.i('User $userId joined audio room for game $gameId');
      }
    } catch (e) {
      _logger.e('Error joining audio room for game $gameId: $e');
      rethrow;
    }
  }

  /// Leaves the audio room
  Future<void> leaveAudioRoom(String gameId, String userId) async {
    try {
      final doc =
          await _firestore
              .collection(Constants.gameRoomsCollection)
              .doc(gameId)
              .get();

      if (!doc.exists) {
        throw Exception('Game room $gameId not found');
      }

      final gameRoom = GameRoom.fromMap(doc.data() as Map<String, dynamic>);
      final participants = List<String>.from(gameRoom.audioRoomParticipants);

      participants.remove(userId);

      // If no participants left, end the audio room
      final newStatus =
          participants.isEmpty
              ? Constants.audioStatusEnded
              : Constants.audioStatusActive;

      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldAudioRoomParticipants: participants,
            Constants.fieldAudioRoomStatus: newStatus,
            Constants.fieldAudioRoomUpdatedAt: Timestamp.now(),
          });
      _logger.i('User $userId left audio room for game $gameId');
    } catch (e) {
      _logger.e('Error leaving audio room for game $gameId: $e');
      rethrow;
    }
  }

  /// Ends the audio room for all participants
  Future<void> endAudioRoom(String gameId, String userId) async {
    try {
      await _firestore
          .collection(Constants.gameRoomsCollection)
          .doc(gameId)
          .update({
            Constants.fieldAudioRoomStatus: Constants.audioStatusEnded,
            Constants.fieldAudioRoomParticipants: [],
            Constants.fieldAudioRoomUpdatedAt: Timestamp.now(),
          });
      _logger.i('Audio room ended for game $gameId by $userId');
    } catch (e) {
      _logger.e('Error ending audio room for game $gameId: $e');
      rethrow;
    }
  }

  /// Tests cross-user-type game matching functionality.
  /// This method verifies that guest users can match with registered users and vice versa.
  Future<Map<String, dynamic>> testCrossUserTypeMatching({
    required String gameMode,
    required String guestUserId,
    required String registeredUserId,
    int testRating = 1200,
  }) async {
    final results = <String, dynamic>{
      'success': false,
      'tests': <String, bool>{},
      'errors': <String>[],
      'details': <String, dynamic>{},
    };

    try {
      _logger.i(
        'Starting cross-user-type matching test for gameMode: $gameMode',
      );

      // Test 1: Validate both users
      _logger.i('Test 1: Validating users for game matching');
      final guestValid = await validateUserForGameMatching(guestUserId);
      final registeredValid = await validateUserForGameMatching(
        registeredUserId,
      );

      results['tests']['guest_user_validation'] = guestValid;
      results['tests']['registered_user_validation'] = registeredValid;

      if (!guestValid) {
        results['errors'].add('Guest user $guestUserId failed validation');
      }
      if (!registeredValid) {
        results['errors'].add(
          'Registered user $registeredUserId failed validation',
        );
      }

      // Test 2: Guest user creates game, registered user finds it
      _logger.i('Test 2: Guest creates game, registered user finds it');
      try {
        final guestGameRoom = await createGameRoom(
          gameMode: gameMode,
          player1Id: guestUserId,
          player1DisplayName: 'Test Guest',
          player1Flag: 'US',
          player2Flag: '',
          player1Rating: testRating,
          ratingBasedSearch: false,
          initialWhitesTime: 300000,
          initialBlacksTime: 300000,
        );

        // Try to find the game as registered user
        final foundByRegistered = await findAvailableGame(
          gameMode: gameMode,
          userRating: testRating,
          currentUserId: registeredUserId,
        );

        results['tests']['guest_creates_registered_finds'] =
            foundByRegistered?.gameId == guestGameRoom.gameId;
        results['details']['guest_created_game_id'] = guestGameRoom.gameId;
        results['details']['found_by_registered'] = foundByRegistered?.gameId;

        // Clean up
        await deleteGameRoom(guestGameRoom.gameId);
      } catch (e) {
        results['tests']['guest_creates_registered_finds'] = false;
        results['errors'].add(
          'Guest creates, registered finds test failed: $e',
        );
      }

      // Test 3: Registered user creates game, guest user finds it
      _logger.i('Test 3: Registered user creates game, guest user finds it');
      try {
        final registeredGameRoom = await createGameRoom(
          gameMode: gameMode,
          player1Id: registeredUserId,
          player1DisplayName: 'Test Registered',
          player1Flag: 'US',
          player2Flag: '',
          player1Rating: testRating,
          ratingBasedSearch: false,
          initialWhitesTime: 300000,
          initialBlacksTime: 300000,
        );

        // Try to find the game as guest user
        final foundByGuest = await findAvailableGame(
          gameMode: gameMode,
          userRating: testRating,
          currentUserId: guestUserId,
        );

        results['tests']['registered_creates_guest_finds'] =
            foundByGuest?.gameId == registeredGameRoom.gameId;
        results['details']['registered_created_game_id'] =
            registeredGameRoom.gameId;
        results['details']['found_by_guest'] = foundByGuest?.gameId;

        // Clean up
        await deleteGameRoom(registeredGameRoom.gameId);
      } catch (e) {
        results['tests']['registered_creates_guest_finds'] = false;
        results['errors'].add(
          'Registered creates, guest finds test failed: $e',
        );
      }

      // Test 4: Test joining functionality
      _logger.i('Test 4: Testing join functionality between user types');
      try {
        // Create a game with guest user
        final testGameRoom = await createGameRoom(
          gameMode: gameMode,
          player1Id: guestUserId,
          player1DisplayName: 'Test Guest',
          player1Flag: 'US',
          player2Flag: '',
          player1Rating: testRating,
          ratingBasedSearch: false,
          initialWhitesTime: 300000,
          initialBlacksTime: 300000,
        );

        // Have registered user join
        await joinGameRoom(
          gameId: testGameRoom.gameId,
          player2Id: registeredUserId,
          player2DisplayName: 'Test Registered',
          player2Flag: 'US',
          player2Rating: testRating,
        );

        // Verify the game is now active
        final updatedGame =
            await _firestore
                .collection(Constants.gameRoomsCollection)
                .doc(testGameRoom.gameId)
                .get();

        if (updatedGame.exists) {
          final gameData = updatedGame.data() as Map<String, dynamic>;
          final status = gameData[Constants.fieldStatus];
          results['tests']['cross_user_join'] =
              status == Constants.statusActive;
        } else {
          results['tests']['cross_user_join'] = false;
        }

        // Clean up
        await deleteGameRoom(testGameRoom.gameId);
      } catch (e) {
        results['tests']['cross_user_join'] = false;
        results['errors'].add('Cross-user join test failed: $e');
      }

      // Determine overall success
      final allTestsPassed = results['tests'].values.every(
        (test) => test == true,
      );
      results['success'] =
          allTestsPassed && (results['errors'] as List).isEmpty;

      _logger.i(
        'Cross-user-type matching test completed. Success: ${results['success']}',
      );
      return results;
    } catch (e) {
      _logger.e('Error during cross-user-type matching test: $e');
      results['errors'].add('Test framework error: $e');
      return results;
    }
  }

  /// Tests guest-to-guest user matching functionality.
  Future<Map<String, dynamic>> testGuestToGuestMatching({
    required String gameMode,
    required String guestUser1Id,
    required String guestUser2Id,
    int testRating = 1200,
  }) async {
    final results = <String, dynamic>{
      'success': false,
      'tests': <String, bool>{},
      'errors': <String>[],
      'details': <String, dynamic>{},
    };

    try {
      _logger.i(
        'Starting guest-to-guest matching test for gameMode: $gameMode',
      );

      // Test 1: Validate both guest users
      final guest1Valid = await validateUserForGameMatching(guestUser1Id);
      final guest2Valid = await validateUserForGameMatching(guestUser2Id);

      results['tests']['guest1_validation'] = guest1Valid;
      results['tests']['guest2_validation'] = guest2Valid;

      // Test 2: Guest 1 creates game, Guest 2 finds it
      try {
        final guest1GameRoom = await createGameRoom(
          gameMode: gameMode,
          player1Id: guestUser1Id,
          player1DisplayName: 'Test Guest 1',
          player1Flag: 'US',
          player2Flag: '',
          player1Rating: testRating,
          ratingBasedSearch: false,
          initialWhitesTime: 300000,
          initialBlacksTime: 300000,
        );

        final foundByGuest2 = await findAvailableGame(
          gameMode: gameMode,
          userRating: testRating,
          currentUserId: guestUser2Id,
        );

        results['tests']['guest_to_guest_matching'] =
            foundByGuest2?.gameId == guest1GameRoom.gameId;

        // Test joining
        if (foundByGuest2 != null) {
          await joinGameRoom(
            gameId: foundByGuest2.gameId,
            player2Id: guestUser2Id,
            player2DisplayName: 'Test Guest 2',
            player2Flag: 'US',
            player2Rating: testRating,
          );
          results['tests']['guest_to_guest_join'] = true;
        } else {
          results['tests']['guest_to_guest_join'] = false;
        }

        // Clean up
        await deleteGameRoom(guest1GameRoom.gameId);
      } catch (e) {
        results['tests']['guest_to_guest_matching'] = false;
        results['tests']['guest_to_guest_join'] = false;
        results['errors'].add('Guest-to-guest test failed: $e');
      }

      final allTestsPassed = results['tests'].values.every(
        (test) => test == true,
      );
      results['success'] =
          allTestsPassed && (results['errors'] as List).isEmpty;

      _logger.i(
        'Guest-to-guest matching test completed. Success: ${results['success']}',
      );
      return results;
    } catch (e) {
      _logger.e('Error during guest-to-guest matching test: $e');
      results['errors'].add('Test framework error: $e');
      return results;
    }
  }
}
