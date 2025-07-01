import 'dart:math';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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

  Future<ChessUser?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        if (!firebaseUser.emailVerified) {
          await _auth.signOut();
          throw Exception('Please verify your email before logging in.');
        }
        DocumentSnapshot userDoc =
            await _firestore
                .collection(Constants.usersCollection)
                .doc(firebaseUser.uid)
                .get();
        if (userDoc.exists) {
          logger.i('User signed in: ${firebaseUser.email}');
          return ChessUser.fromMap(userDoc.data() as Map<String, dynamic>);
        } else {
          // This case should ideally not happen if sign-up creates the user document
          // but as a fallback, create a basic user model
          ChessUser currentUser = ChessUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName ?? 'User',
          );
          await _firestore
              .collection(Constants.usersCollection)
              .doc(firebaseUser.uid)
              .set(currentUser.toMap());
          logger.i('Created missing user document for: ${firebaseUser.email}');
          return currentUser;
        }
      }
    } on FirebaseAuthException catch (e) {
      logger.e('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      logger.e('Error during sign in: $e');
      throw Exception('An unknown error occurred during sign in.');
    }
    return null;
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
