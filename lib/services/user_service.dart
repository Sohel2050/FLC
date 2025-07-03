import 'dart:math';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/sign_in_results.dart';

class UserService {
  final Logger logger = Logger();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChessUser createGuestUser() {
    final random = Random();
    final guestId = random.nextInt(100000); // Generate a random 5-digit number
    final displayName = 'Guest$guestId';
    logger.i('Creating guest user: $displayName');
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
      logger.i('User status updated to online: $isOnline for UID: $uid');
    } catch (e) {
      logger.e('Error updating user status to online: $e');
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
      logger.e('Firebase Auth Error during sign up: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      logger.e('Error during sign up: $e');
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
            logger.i('User signed in: ${firebaseUser.email}');
            final ChessUser chessUser = ChessUser.fromMap(
              userDoc.data() as Map<String, dynamic>,
            );

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
            logger.i(
              'Created missing user document for: ${firebaseUser.email}',
            );
            return SignInSuccess(currentUser);
          }
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            logger.e('Permission denied accessing user document');
            return SignInError('Permission denied. Please try again.');
          }
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e) {
      logger.e('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
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
      logger.i('User signed out.');
    } catch (e) {
      logger.e('Error during sign out: $e');
      throw Exception('An unknown error occurred during sign out.');
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        logger.i('Email verification resent to: ${user.email}');
      } else {
        throw Exception('No user found or email already verified.');
      }
    } on FirebaseAuthException catch (e) {
      logger.e(
        'Firebase Auth Error during email verification resend: ${e.code} - ${e.message}',
      );
      throw Exception(e.message);
    } catch (e) {
      logger.e('Error during email verification resend: $e');
      throw Exception(
        'An unknown error occurred while resending verification email.',
      );
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      logger.i('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      logger.e(
        'Firebase Auth Error during password reset: ${e.code} - ${e.message}',
      );
      throw Exception(e.message);
    } catch (e) {
      logger.e('Error during password reset: $e');
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
      logger.i('User data updated for: ${user.displayName}');
    } catch (e) {
      logger.e('Error updating user data: $e');
      throw Exception('An unknown error occurred while updating user data.');
    }
  }

  Future<void> deleteUserAccount(String uid) async {
    try {
      await _firestore.collection(Constants.usersCollection).doc(uid).delete();
      await _auth.currentUser?.delete();
      logger.i('User account deleted for UID: $uid');
    } on FirebaseAuthException catch (e) {
      logger.e(
        'Firebase Auth Error during account deletion: ${e.code} - ${e.message}',
      );
      throw Exception(e.message);
    } catch (e) {
      logger.e('Error during account deletion: $e');
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
