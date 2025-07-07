import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  /// Sends a friend request from the current user to another user.
  Future<void> sendFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      // Add friendUserId to the current user's sent requests
      await _firestore
          .collection(Constants.usersCollection)
          .doc(currentUserId)
          .update({
            Constants.friendRequestsSent: FieldValue.arrayUnion([friendUserId]),
          });

      // Add currentUserId to the friend's received requests
      await _firestore
          .collection(Constants.usersCollection)
          .doc(friendUserId)
          .update({
            Constants.friendRequestsReceived: FieldValue.arrayUnion([
              currentUserId,
            ]),
          });

      _logger.i('Friend request sent from $currentUserId to $friendUserId');
    } catch (e) {
      _logger.e('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accepts a friend request from another user.
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      // Add each user to the other's friends list
      await _firestore
          .collection(Constants.usersCollection)
          .doc(currentUserId)
          .update({
            Constants.friends: FieldValue.arrayUnion([friendUserId]),
          });
      await _firestore
          .collection(Constants.usersCollection)
          .doc(friendUserId)
          .update({
            Constants.friends: FieldValue.arrayUnion([currentUserId]),
          });

      // Remove the request from both users' request lists
      await declineFriendRequest(
        currentUserId: currentUserId,
        friendUserId: friendUserId,
      );

      _logger.i('$currentUserId and $friendUserId are now friends.');
    } catch (e) {
      _logger.e('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Declines or cancels a friend request.
  Future<void> declineFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      // Remove friendUserId from the current user's received requests
      await _firestore
          .collection(Constants.usersCollection)
          .doc(currentUserId)
          .update({
            Constants.friendRequestsReceived: FieldValue.arrayRemove([
              friendUserId,
            ]),
          });

      // Remove currentUserId from the friend's sent requests
      await _firestore
          .collection(Constants.usersCollection)
          .doc(friendUserId)
          .update({
            Constants.friendRequestsSent: FieldValue.arrayRemove([
              currentUserId,
            ]),
          });

      _logger.i(
        'Friend request between $currentUserId and $friendUserId declined/cancelled.',
      );
    } catch (e) {
      _logger.e('Error declining friend request: $e');
      rethrow;
    }
  }

  /// Removes a friend from the user's friend list.
  Future<void> removeFriend({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      // Remove friend from current user's list
      await _firestore
          .collection(Constants.usersCollection)
          .doc(currentUserId)
          .update({
            Constants.friends: FieldValue.arrayRemove([friendUserId]),
          });

      // Remove current user from friend's list
      await _firestore
          .collection(Constants.usersCollection)
          .doc(friendUserId)
          .update({
            Constants.friends: FieldValue.arrayRemove([currentUserId]),
          });

      _logger.i('$currentUserId and $friendUserId are no longer friends.');
    } catch (e) {
      _logger.e('Error removing friend: $e');
      rethrow;
    }
  }

  /// Blocks a user.
  Future<void> blockUser({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    try {
      // Add the blocked user's ID to the current user's blocked list
      await _firestore
          .collection(Constants.usersCollection)
          .doc(currentUserId)
          .update({
            Constants.blockedUsers: FieldValue.arrayUnion([blockedUserId]),
          });

      // Also remove them as a friend, if they are one
      await removeFriend(
        currentUserId: currentUserId,
        friendUserId: blockedUserId,
      );

      _logger.i('$currentUserId blocked $blockedUserId.');
    } catch (e) {
      _logger.e('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblocks a user.
  Future<void> unblockUser({
    required String currentUserId,
    required String unblockedUserId,
  }) async {
    try {
      // Remove the unblocked user's ID from the current user's blocked list
      await _firestore
          .collection(Constants.usersCollection)
          .doc(currentUserId)
          .update({
            Constants.blockedUsers: FieldValue.arrayRemove([unblockedUserId]),
          });
      _logger.i('$currentUserId unblocked $unblockedUserId.');
    } catch (e) {
      _logger.e('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Fetches a stream of the user's friends.
  Stream<List<ChessUser>> getFriends(String userId) {
    return _firestore
        .collection(Constants.usersCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists) return [];
          final userData = snapshot.data()!;
          List<String> friendIds = List<String>.from(
            userData[Constants.friends] ?? [],
          );
          List<String> blockedIds = List<String>.from(
            userData[Constants.blockedUsers] ?? [],
          );

          if (friendIds.isEmpty) return [];

          // Filter out blocked users from the friend list
          friendIds.removeWhere((id) => blockedIds.contains(id));

          if (friendIds.isEmpty) return [];

          final friendDocs =
              await _firestore
                  .collection(Constants.usersCollection)
                  .where(FieldPath.documentId, whereIn: friendIds)
                  .get();

          return friendDocs.docs
              .map((doc) => ChessUser.fromMap(doc.data()))
              .toList();
        });
  }

  /// Fetches a stream of the user's incoming friend requests.
  Stream<List<ChessUser>> getFriendRequests(String userId) {
    return _firestore
        .collection(Constants.usersCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists) return [];
          final userData = snapshot.data()!;
          List<String> requestIds = List<String>.from(
            userData[Constants.friendRequestsReceived] ?? [],
          );
          List<String> blockedIds = List<String>.from(
            userData[Constants.blockedUsers] ?? [],
          );

          if (requestIds.isEmpty) return [];

          // Filter out requests from blocked users
          requestIds.removeWhere((id) => blockedIds.contains(id));

          if (requestIds.isEmpty) return [];

          final requestDocs =
              await _firestore
                  .collection(Constants.usersCollection)
                  .where(FieldPath.documentId, whereIn: requestIds)
                  .get();

          return requestDocs.docs
              .map((doc) => ChessUser.fromMap(doc.data()))
              .toList();
        });
  }

  /// Searches for users by their display name, excluding blocked users.
  Future<List<ChessUser>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.isEmpty) return [];
    try {
      // First, get the list of blocked users
      final userDoc =
          await _firestore
              .collection(Constants.usersCollection)
              .doc(currentUserId)
              .get();
      final blockedUsers = List<String>.from(
        userDoc.data()?[Constants.blockedUsers] ?? [],
      );

      final snapshot =
          await _firestore
              .collection(Constants.usersCollection)
              .where(Constants.displayName, isGreaterThanOrEqualTo: query)
              .where(Constants.displayName, isLessThanOrEqualTo: '$query\uf8ff')
              .limit(10)
              .get();

      var users =
          snapshot.docs.map((doc) => ChessUser.fromMap(doc.data())).toList();

      // Filter out the current user and blocked users from the search results
      users.removeWhere(
        (user) => user.uid == currentUserId || blockedUsers.contains(user.uid),
      );

      return users;
    } catch (e) {
      _logger.e('Error searching users: $e');
      return [];
    }
  }
}
