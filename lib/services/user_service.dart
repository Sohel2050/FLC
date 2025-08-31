import 'dart:developer';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_chess_app/services/rating_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/sign_in_results.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class UserService {
  final Logger logger = Logger();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<ChessUser> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user != null) {
        // Use consistent guest user creation
        final chessUser = createConsistentGuestUser(user);
        await _firestore
            .collection(Constants.usersCollection)
            .doc(user.uid)
            .set(chessUser.toMap());
        return chessUser;
      }
      throw Exception('Anonymous sign-in failed.');
    } catch (e) {
      throw Exception('An unknown error occurred during anonymous sign-in.');
    }
  }

  /// Update UserProvider immediately after successful sign-up
  /// This ensures the UI refreshes without requiring app restart
  Future<void> updateUserProviderAfterSignUp(
    BuildContext context,
    ChessUser updatedUser,
  ) async {
    try {
      // Update the UserProvider with the new user data
      context.read<UserProvider>().setUser(updatedUser);
      logger.i(
        'UserProvider updated after sign-up for user: ${updatedUser.uid}',
      );
    } catch (e) {
      logger.e('Error updating UserProvider after sign-up: $e');
      // Don't throw error to prevent sign-up failure
    }
  }

  /// Handle existing anonymous user session on app startup
  /// This method checks if an anonymous user has a valid Firestore document
  /// and creates one if missing, ensuring guest user persistence
  Future<ChessUser> handleAnonymousUserSession(User firebaseUser) async {
    try {
      // Try to get existing guest user document
      final userDoc =
          await _firestore
              .collection(Constants.usersCollection)
              .doc(firebaseUser.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Validate and ensure document completeness
        if (validateGuestUserDocument(userData)) {
          final chessUser = await ensureGuestUserDocumentComplete(
            firebaseUser.uid,
            userData,
          );

          // Update online status for the restored session
          await updateUserStatusOnline(chessUser.uid!, true);

          logger.i('Anonymous user session restored: ${chessUser.uid}');
          return chessUser;
        } else {
          // Document exists but is invalid, recreate it
          logger.w(
            'Invalid guest user document found, recreating: ${firebaseUser.uid}',
          );
          final chessUser = createConsistentGuestUser(firebaseUser);
          await _firestore
              .collection(Constants.usersCollection)
              .doc(firebaseUser.uid)
              .set(chessUser.toMap());

          await updateUserStatusOnline(chessUser.uid!, true);
          return chessUser;
        }
      } else {
        // User document doesn't exist, create a new guest user document
        final chessUser = createConsistentGuestUser(firebaseUser);

        await _firestore
            .collection(Constants.usersCollection)
            .doc(firebaseUser.uid)
            .set(chessUser.toMap());

        logger.i(
          'Created guest user document for existing anonymous session: ${chessUser.uid}',
        );
        return chessUser;
      }
    } catch (e) {
      logger.e('Error handling anonymous user session: $e');
      // Fallback: create new anonymous session
      return await signInAnonymously();
    }
  }

  /// Validate guest user document structure
  /// Ensures guest users have all required fields for game matching
  bool validateGuestUserDocument(Map<String, dynamic> userData) {
    try {
      // Check required fields for game matching
      final requiredFields = [
        Constants.uid,
        Constants.displayName,
        Constants.isGuest,
        Constants.isOnline,
        Constants.classicalRating,
        Constants.blitzRating,
        Constants.tempoRating,
        Constants.gamesPlayed,
        Constants.gamesWon,
        Constants.gamesLost,
        Constants.gamesDraw,
      ];

      for (String field in requiredFields) {
        if (!userData.containsKey(field)) {
          logger.w('Guest user document missing required field: $field');
          return false;
        }
      }

      // Validate data types and values
      if (userData[Constants.isGuest] != true) {
        logger.w('Guest user document has isGuest set to false');
        return false;
      }

      // Validate rating fields are integers and within reasonable range
      final ratingFields = [
        Constants.classicalRating,
        Constants.blitzRating,
        Constants.tempoRating,
      ];

      for (String field in ratingFields) {
        final rating = userData[field];
        if (rating is! int || rating < 100 || rating > 3000) {
          logger.w(
            'Guest user document has invalid rating for $field: $rating',
          );
          return false;
        }
      }

      logger.i('Guest user document validation passed');
      return true;
    } catch (e) {
      logger.e('Error validating guest user document: $e');
      return false;
    }
  }

  /// Create a consistent guest user document with all required fields
  /// This ensures guest users can participate in game matching
  ChessUser createConsistentGuestUser(User firebaseUser) {
    return ChessUser(
      uid: firebaseUser.uid,
      displayName: 'Guest-${firebaseUser.uid.substring(0, 5)}',
      isGuest: true,
      isOnline: true,
      removeAds: false,
      // Ensure all required fields for game matching are present
      classicalRating: 1200,
      blitzRating: 1200,
      tempoRating: 1200,
      gamesPlayed: 0,
      gamesWon: 0,
      gamesLost: 0,
      gamesDraw: 0,
      achievements: [],
      friends: [],
      friendRequestsSent: [],
      friendRequestsReceived: [],
      blockedUsers: [],
      winStreak: {},
      savedGames: [],
      preferences: {},
      fcmToken: '',
      lastSeen: DateTime.now(),
    );
  }

  /// Ensure guest user document has all required fields for game matching
  /// Updates existing document if fields are missing
  Future<ChessUser> ensureGuestUserDocumentComplete(
    String userId,
    Map<String, dynamic> existingData,
  ) async {
    try {
      // Create a complete guest user from existing data
      ChessUser existingUser = ChessUser.fromMap(existingData);

      // Check if document needs updates
      bool needsUpdate = false;
      Map<String, dynamic> updates = {};

      // Ensure required rating fields exist
      if (existingUser.classicalRating == 0) {
        updates[Constants.classicalRating] = 1200;
        needsUpdate = true;
      }
      if (existingUser.blitzRating == 0) {
        updates[Constants.blitzRating] = 1200;
        needsUpdate = true;
      }
      if (existingUser.tempoRating == 0) {
        updates[Constants.tempoRating] = 1200;
        needsUpdate = true;
      }

      // Ensure isGuest is properly set
      if (!existingUser.isGuest) {
        updates[Constants.isGuest] = true;
        needsUpdate = true;
      }

      // Update document if needed
      if (needsUpdate) {
        await _firestore
            .collection(Constants.usersCollection)
            .doc(userId)
            .update(updates);

        logger.i('Updated guest user document with missing fields: $userId');

        // Return updated user
        return ChessUser.fromMap({...existingData, ...updates});
      }

      return existingUser;
    } catch (e) {
      logger.e('Error ensuring guest user document completeness: $e');
      rethrow;
    }
  }

  // save fcmToken to firetore
  Future<void> saveFcmToken(String fcmToken) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection(Constants.usersCollection)
            .doc(user.uid)
            .update({Constants.fcmToken: fcmToken});
      }
    } catch (e) {
      logger.e('Error saving FCM token: $e');
    }
  }

  Stream<int> getOnlinePlayersCountStream() {
    return _firestore
        .collection(Constants.usersCollection)
        .where(Constants.isOnline, isEqualTo: true)
        // .where(
        //   Constants.isGuest,
        //   isEqualTo: false,
        // ) // Exclude guest users from count
        .snapshots(
          includeMetadataChanges: false,
        ) // Only get actual data changes
        .map((snapshot) {
          try {
            // Use snapshot.size for better performance instead of docs.length
            return snapshot.size;
          } catch (e) {
            logger.e('Error processing online players count: $e');
            return 0;
          }
        })
        .handleError((error) {
          logger.e('Error in online players count stream: $error');
          return 0;
        });
  }

  // Update user status to online
  Future<void> updateUserStatusOnline(String uid, bool isOnline) async {
    try {
      log(
        'App Service: Attempting to set $uid to ${isOnline ? "online" : "offline"}',
      );

      await _firestore.collection(Constants.usersCollection).doc(uid).update({
        Constants.isOnline: isOnline,
        Constants.lastSeen: FieldValue.serverTimestamp(),
      });

      log(
        'SUCCESS: User $uid status updated to ${isOnline ? "online" : "offline"}',
      );
      logger.i(
        'User $uid status updated to ${isOnline ? "online" : "offline"}',
      );
    } catch (e) {
      log(
        'ERROR: Failed to update user $uid status to ${isOnline ? "online" : "offline"}: $e',
      );
      logger.e('Error updating user status for $uid: $e');

      // If setting to offline fails (common when app goes to background and loses network),
      // we can try a delayed retry when network becomes available again
      if (!isOnline) {
        log('Scheduling retry for offline status update');
        _scheduleOfflineStatusRetry(uid);
      }

      // Don't throw error to prevent app crashes - this is a background operation
    }
  }

  // Schedule a retry for offline status update
  void _scheduleOfflineStatusRetry(String uid) {
    // Retry after a delay - this will help when network comes back
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        log('RETRY: Attempting to set $uid offline (delayed retry)');
        await _firestore.collection(Constants.usersCollection).doc(uid).update({
          Constants.isOnline: false,
          Constants.lastSeen: FieldValue.serverTimestamp(),
        });
        log('RETRY SUCCESS: User $uid set to offline');
        logger.i('Retry successful: User $uid set to offline');
      } catch (e) {
        log('RETRY FAILED: Could not set $uid offline: $e');
        logger.w('Retry failed for setting user $uid offline: $e');
        // If retry fails, we'll rely on server-side cleanup or next app launch
      }
    });
  }

  /// Clean up stale online status on app startup
  /// This helps ensure accurate online counts by setting the current user online
  /// and potentially cleaning up any stale online status from previous sessions
  Future<void> cleanupOnlineStatus(String uid) async {
    try {
      log('CLEANUP: Setting user $uid online and cleaning up stale status');

      // Set current user online
      await updateUserStatusOnline(uid, true);

      logger.i('Online status cleanup completed for user $uid');
    } catch (e) {
      logger.e('Error during online status cleanup for $uid: $e');
    }
  }

  /// Force set user offline with multiple retry attempts
  /// This is useful when the app is being terminated or when we really need
  /// to ensure the user is marked offline
  Future<void> forceSetUserOffline(String uid) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        log('FORCE OFFLINE: Attempt $attempt/$maxRetries for user $uid');

        await _firestore.collection(Constants.usersCollection).doc(uid).update({
          Constants.isOnline: false,
          Constants.lastSeen: FieldValue.serverTimestamp(),
        });

        log('FORCE OFFLINE SUCCESS: User $uid set offline on attempt $attempt');
        logger.i('Force offline successful for user $uid on attempt $attempt');
        return; // Success, exit the retry loop
      } catch (e) {
        log('FORCE OFFLINE FAILED: Attempt $attempt failed for user $uid: $e');

        if (attempt == maxRetries) {
          logger.e(
            'Force offline failed for user $uid after $maxRetries attempts: $e',
          );
          // Last attempt failed, but don't throw to avoid crashes
          return;
        }

        // Wait before retrying
        await Future.delayed(retryDelay);
      }
    }
  }

  /// Get users who have been online for too long (potential stale status)
  /// This can be used for server-side cleanup or debugging
  /// Returns users who have been marked online but haven't updated lastSeen recently
  Future<List<String>> getStaleOnlineUsers({
    Duration staleThreshold = const Duration(minutes: 10),
  }) async {
    try {
      final staleTimestamp = Timestamp.fromDate(
        DateTime.now().subtract(staleThreshold),
      );

      final querySnapshot =
          await _firestore
              .collection(Constants.usersCollection)
              .where(Constants.isOnline, isEqualTo: true)
              .where(Constants.lastSeen, isLessThan: staleTimestamp)
              .get();

      final staleUserIds = querySnapshot.docs.map((doc) => doc.id).toList();

      if (staleUserIds.isNotEmpty) {
        logger.w('Found ${staleUserIds.length} potentially stale online users');
      }

      return staleUserIds;
    } catch (e) {
      logger.e('Error getting stale online users: $e');
      return [];
    }
  }

  Future<ChessUser?> signUp(
    String email,
    String password,
    String name,
    String countryCode, {
    BuildContext? context,
  }) async {
    try {
      final User? anonymousUser = _auth.currentUser;
      AuthCredential? credential;

      if (anonymousUser != null && anonymousUser.isAnonymous) {
        credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await anonymousUser.linkWithCredential(credential);

        await anonymousUser.updateDisplayName(name);
        await anonymousUser.sendEmailVerification();

        final updatedUser = ChessUser(
          uid: anonymousUser.uid,
          email: email,
          displayName: name,
          isGuest: false,
          countryCode: countryCode,
        );

        await _firestore
            .collection(Constants.usersCollection)
            .doc(anonymousUser.uid)
            .update(updatedUser.toMap());

        // Immediately update UserProvider if context is provided
        if (context != null && context.mounted) {
          await updateUserProviderAfterSignUp(context, updatedUser);
        }

        logger.i('User account upgraded: ${anonymousUser.email}');
        return updatedUser;
      } else {
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
            countryCode: countryCode,
          );
          await _firestore
              .collection(Constants.usersCollection)
              .doc(firebaseUser.uid)
              .set(newUser.toMap());
          logger.i('User signed up: ${firebaseUser.email}');
          return newUser;
        }
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

  Future<bool> emailExists(String email) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(Constants.usersCollection)
              .where(Constants.email, isEqualTo: email)
              .limit(1)
              .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      logger.e('Error checking if email exists: $e');
      return false;
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

  Future<File> _compressImage(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 70,
    );

    return File(result!.path);
  }

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final compressedImage = await _compressImage(imageFile);
      final ref = _storage
          .ref()
          .child(Constants.profileImagesCollection)
          .child('$userId.jpg');
      final uploadTask = ref.putFile(compressedImage);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      logger.e('Error uploading profile image: $e');
      throw Exception('Failed to upload profile image.');
    }
  }

  Future<void> deleteProfileImage(String userId) async {
    try {
      final ref = _storage
          .ref()
          .child(Constants.profileImagesCollection)
          .child('$userId.jpg');
      await ref.delete();
    } on FirebaseException catch (e) {
      // It's okay if the file doesn't exist, so we can ignore that error.
      if (e.code != 'object-not-found') {
        logger.e('Error deleting profile image: $e');
        throw Exception('Failed to delete profile image.');
      }
    }
  }

  Future<void> updateUser(ChessUser user) async {
    try {
      bool isValid = isValidName(user.displayName);
      if (!isValid) {
        throw ArgumentError('Invalid user name: ${user.displayName}');
      }
      await _firestore
          .collection(Constants.usersCollection)
          .doc(user.uid)
          .update(user.toMap());
    } catch (e) {
      throw Exception('An unknown error occurred while updating user data.');
    }
  }

  /// Update user's removeAds status (for in-app purchases)
  Future<void> updateRemoveAds(String userId, bool removeAds) async {
    try {
      await _firestore.collection(Constants.usersCollection).doc(userId).update(
        {Constants.removeAds: removeAds},
      );
      logger.i('Updated removeAds status for user $userId to $removeAds');
    } catch (e) {
      logger.e('Error updating removeAds status: $e');
      throw Exception('Failed to update ad removal status.');
    }
  }

  Future<void> deleteUserAccount(String uid) async {
    try {
      // First, delete the profile image from storage
      await deleteProfileImage(uid);
      // Then, delete the user document from Firestore
      await _firestore.collection(Constants.usersCollection).doc(uid).delete();
      // Finally, delete the user from Firebase Auth
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
    // Name can only contain letters, numbers and spaces
    if (!RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(name)) {
      throw ArgumentError('Name can only contain letters, numbers and spaces');
    }

    return true;
  }

  Future<ChessUser?> getUserById(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore
              .collection(Constants.usersCollection)
              .doc(userId)
              .get();
      if (userDoc.exists) {
        return ChessUser.fromMap(userDoc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      logger.e('Error getting user by ID: $e');
    }
    return null;
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

        final userProvider = GetIt.instance<UserProvider>();
        // Update userProvider with the new rating
        userProvider.updateUserRating(
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
