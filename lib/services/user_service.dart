import 'dart:math';
import 'package:flutter_chess_app/services/rating_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/sign_in_results.dart';
import '../providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/rating_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/sign_in_results.dart';
import '../providers/user_provider.dart';
import 'package:flutter/material.dart';

class UserService {
  final Logger logger = Logger();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChessUser createGuestUser() {
    final random = Random();
    final guestId = random.nextInt(100000); // Generate a random 5-digit number
    final displayName = 'Guest$guestId';
    return ChessUser(displayName: displayName, isGuest: true);
  }

  Stream<int> getOnlinePlayersCountStream() {
    return _firestore
        .collection(Constants.usersCollection)
        .where(Constants.isOnline, isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Update user status to online
  Future<void> updateUserStatusOnline(String uid, bool isOnline) async {
    try {
      await _firestore.collection(Constants.usersCollection).doc(uid).update({
        Constants.isOnline: isOnline,
        Constants.lastSeen: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('An unknown error occurred while updating user status.');
    }
  }

  Future<ChessUser?> signUp(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(name);
        await firebaseUser.sendEmailVerification();

        ChessUser newUser = ChessUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          displayName: name,
        );
        await _firestore
            .collection(Constants.usersCollection)
            .doc(firebaseUser.uid)
            .set(newUser.toMap());
        logger.i('User signed up: ${firebaseUser.email}');
        return newUser;
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unknown error occurred during sign up.');
    }
    return null;
  }

  Future<SignInResult> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        if (!firebaseUser.emailVerified) {
          return SignInEmailNotVerified(firebaseUser.email ?? 'your email');
        }

        try {
          DocumentSnapshot userDoc =
              await _firestore
                  .collection(Constants.usersCollection)
                  .doc(firebaseUser.uid)
                  .get();

          if (userDoc.exists) {
            final ChessUser chessUser = ChessUser.fromMap(
              userDoc.data() as Map<String, dynamic>,
            );

            // set online status
            await updateUserStatusOnline(chessUser.uid!, true);

            return SignInSuccess(chessUser);
          } else {
            // Create missing user document
            ChessUser currentUser = ChessUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email,
              displayName: firebaseUser.displayName ?? 'User',
            );
            await _firestore
                .collection(Constants.usersCollection)
                .doc(firebaseUser.uid)
                .set(currentUser.toMap());
            return SignInSuccess(currentUser);
          }
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            return SignInError('Permission denied. Please try again.');
          }
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e) {
      return SignInError(e.message ?? 'Authentication failed');
    } catch (e) {
      logger.e('Error during sign in: $e');
      return SignInError('An unknown error occurred during sign in.');
    }
    return SignInError('Sign in failed');
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('An unknown error occurred during sign out.');
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else {
        throw Exception('No user found or email already verified.');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(
        'An unknown error occurred while resending verification email.',
      );
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unknown error occurred during password reset.');
    }
  }

  Future<void> updateUser(ChessUser user) async {
    try {
      bool isValid = isValidName(user.displayName);
      if (!isValid) {
        throw ArgumentError('Invalid user name: ${user.displayName}');
      }
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      throw Exception('An unknown error occurred while updating user data.');
    }
  }

  Future<void> deleteUserAccount(String uid) async {
    try {
      await _firestore.collection(Constants.usersCollection).doc(uid).delete();
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unknown error occurred during account deletion.');
    }
  }

  bool isValidName(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    if (name.length < 3) {
      throw ArgumentError('Name must be at least 3 characters long');
    }
    if (name.length > 30) {
      throw ArgumentError('Name cannot exceed 30 characters');
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      throw ArgumentError('Name can only contain letters and spaces');
    }
    return true;
  }

  /// Updates user statistics after a game concludes.
  Future<void> updateUserStatsAfterGame({
    required String userId,
    required String gameResult,
    required String gameMode,
    required String gameId,
    String? opponentId,
  }) async {
    try {
      final userDocRef = _firestore
          .collection(Constants.usersCollection)
          .doc(userId);
      final opponentDocRef =
          opponentId != null && opponentId.isNotEmpty
              ? _firestore.collection(Constants.usersCollection).doc(opponentId)
              : null;

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userDocRef);
        if (!userDoc.exists) {
          throw Exception('User document not found for ID: $userId');
        }
        ChessUser currentUser = ChessUser.fromMap(userDoc.data()!);

        ChessUser? opponentUser;
        if (opponentDocRef != null) {
          final opponentDoc = await transaction.get(opponentDocRef);
          if (opponentDoc.exists) {
            opponentUser = ChessUser.fromMap(opponentDoc.data()!);
          } else {
            logger.w(
              'Opponent document not found for ID: $opponentId. Skipping opponent rating update.',
            );
          }
        }

        // Determine outcome for the current user
        double playerOutcome;
        if (gameResult == Constants.win) {
          playerOutcome = 1.0;
        } else if (gameResult == Constants.draw) {
          playerOutcome = 0.5;
        } else {
          playerOutcome = 0.0;
        }

        // Get the rating type based on game mode
        final String ratingTypeField =
            Constants.gameModeToRatingType[gameMode] ??
            Constants.classicalRating;

        // Get current ratings
        int playerCurrentRating = currentUser.toMap()[ratingTypeField] ?? 1200;
        int opponentCurrentRating =
            opponentUser?.toMap()[ratingTypeField] ?? 1200;

        // Calculate new ratings using RatingService
        final RatingService ratingService = RatingService();
        final Map<String, int> newRatings = ratingService.updateGameRatings(
          player1CurrentRating: playerCurrentRating,
          player2CurrentRating: opponentCurrentRating,
          player1Outcome: playerOutcome,
        );

        // Update game counts
        int updatedGamesPlayed = currentUser.gamesPlayed + 1;
        int updatedGamesWon = currentUser.gamesWon;
        int updatedGamesLost = currentUser.gamesLost;
        int updatedGamesDraw = currentUser.gamesDraw;

        if (gameResult == Constants.win) {
          updatedGamesWon++;
        } else if (gameResult == Constants.loss) {
          updatedGamesLost++;
        } else if (gameResult == Constants.draw) {
          updatedGamesDraw++;
        }

        // Update win streak
        Map<String, int> updatedWinStreak = Map<String, int>.from(
          currentUser.winStreak,
        );
        if (gameResult == Constants.win) {
          updatedWinStreak[gameMode] = (updatedWinStreak[gameMode] ?? 0) + 1;
        } else {
          updatedWinStreak[gameMode] = 0; // Reset streak on loss/draw
        }

        // Add gameId to savedGames list if not already present
        List<String> updatedSavedGames = List<String>.from(
          currentUser.savedGames,
        );
        if (!updatedSavedGames.contains(gameId)) {
          updatedSavedGames.add(gameId);
        }

        // Create updated user object for current user
        ChessUser updatedUser = currentUser.copyWith(
          gamesPlayed: updatedGamesPlayed,
          gamesWon: updatedGamesWon,
          gamesLost: updatedGamesLost,
          gamesDraw: updatedGamesDraw,
          winStreak: updatedWinStreak,
          savedGames: updatedSavedGames,
          classicalRating:
              ratingTypeField == Constants.classicalRating
                  ? newRatings['player1Rating']
                  : null,
          blitzRating:
              ratingTypeField == Constants.blitzRating
                  ? newRatings['player1Rating']
                  : null,
          tempoRating:
              ratingTypeField == Constants.tempoRating
                  ? newRatings['player1Rating']
                  : null,
        );

        // Update Firestore document for current user
        transaction.update(userDocRef, updatedUser.toMap());

        // Update userProvider with the new rating
        context.read<UserProvider>().updateUserRating(
          ratingTypeField,
          newRatings['player1Rating']!,
        );

        // Update opponent's rating if applicable
        if (opponentUser != null && opponentDocRef != null) {
          ChessUser updatedOpponentUser = opponentUser.copyWith(
            classicalRating:
                ratingTypeField == Constants.classicalRating
                    ? newRatings['player2Rating']
                    : null,
            blitzRating:
                ratingTypeField == Constants.blitzRating
                    ? newRatings['player2Rating']
                    : null,
            tempoRating:
                ratingTypeField == Constants.tempoRating
                    ? newRatings['player2Rating']
                    : null,
          );
          transaction.update(opponentDocRef, updatedOpponentUser.toMap());
          logger.i(
            'Opponent stats updated for $opponentId after game $gameId.',
          );
        }
      });
      logger.i('User stats updated for $userId after game $gameId.');
    } catch (e) {
      logger.e('Error updating user stats for $userId: $e');
      throw Exception('Failed to update user statistics.');
    }
  }

  bool isValidEmail(String email) {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    // Regex for email validation
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      throw ArgumentError('Enter a valid email address');
    }
    return true;
  }
}

class EmailNotVerifiedException implements Exception {
  final String email;
  const EmailNotVerifiedException(this.email);

  @override
  String toString() => 'Email not verified: $email';
}
