import 'dart:math';
import 'package:logger/logger.dart';
import '../models/user_model.dart';

class UserService {
  final Logger logger = Logger();
  ChessUser createGuestUser() {
    final random = Random();
    final guestId = random.nextInt(100000); // Generate a random 5-digit number
    final displayName = 'Guest$guestId';
    logger.i('Creating guest user: $displayName');
    return ChessUser(displayName: displayName, isGuest: true);
  }

  // Placeholder for updating user data
  Future<void> updateUser(ChessUser user) async {
    // After we connect to Firebase, this method will update the user data
    // in the Firebase Firestore or Realtime Database.
    // For now, we just simulate the update with a print statement.
    bool isValid = isValidName(user.displayName);
    if (!isValid) {
      throw ArgumentError('Invalid user name: ${user.displayName}');
    }
    logger.i('Simulating user update for: ${user.displayName}');
    // For now, we just print and do nothing else.
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate network delay
  }

  // Placeholder for deleting user account
  Future<void> deleteUserAccount(String uid) async {
    // After we connect to Firebase, this method will delete the user account
    // from the Firebase Authentication and Firestore or Realtime Database.
    // For now, we just simulate the deletion with a print statement.

    logger.i('Simulating account deletion for UID: $uid');
    // For now, we just print and do nothing else.
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate network delay
  }

  // Resuable function to validate user name input
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
}
