import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/models/chat_message_model.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Generates a unique chat room ID for two users
  String getChatRoomId(String userId1, String userId2) {
    if (userId1.hashCode <= userId2.hashCode) {
      return '$userId1-$userId2';
    } else {
      return '$userId2-$userId1';
    }
  }

  // Sends a message in a chat room
  Future<void> sendMessage(String chatRoomId, ChatMessage message) async {
    try {
      await _firestore
          .collection(Constants.chatRoomsCollections)
          .doc(chatRoomId)
          .collection(Constants.messagesCollection)
          .add(message.toFirestore());
    } catch (e) {
      _logger.e('Error sending message: $e');
      rethrow;
    }
  }

  // Gets a stream of messages from a chat room
  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection(Constants.chatRoomsCollections)
        .doc(chatRoomId)
        .collection(Constants.messagesCollection)
        .orderBy(Constants.timestamp, descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  /// Deletes all messages in a chat room between two users.
  Future<void> deleteChatMessages(String userId1, String userId2) async {
    try {
      final chatRoomId = getChatRoomId(userId1, userId2);
      final messagesRef = _firestore
          .collection(Constants.chatRoomsCollections)
          .doc(chatRoomId)
          .collection(Constants.messagesCollection);

      // Get all messages in the chat room
      final snapshot = await messagesRef.get();

      // Delete each message
      for (var doc in snapshot.docs) {
        await messagesRef.doc(doc.id).delete();
      }
      _logger.i('All messages in chat room $chatRoomId deleted.');
    } catch (e) {
      _logger.e('Error deleting chat messages: $e');
      rethrow;
    }
  }

  // mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String receiverId) async {
    try {
      final messagesRef = _firestore
          .collection(Constants.chatRoomsCollections)
          .doc(chatRoomId)
          .collection(Constants.messagesCollection);

      final querySnapshot =
          await messagesRef
              .where(Constants.senderId, isNotEqualTo: receiverId)
              .where(Constants.isRead, isEqualTo: false)
              .get();

      for (var doc in querySnapshot.docs) {
        await messagesRef.doc(doc.id).update({Constants.isRead: true});
      }
    } catch (e) {
      _logger.e('Error marking messages as read: $e');
      rethrow;
    }
  }

  // get unread message count
  Stream<int> getUnreadMessageCount(String chatRoomId, String currentUserId) {
    return _firestore
        .collection(Constants.chatRoomsCollections)
        .doc(chatRoomId)
        .collection(Constants.messagesCollection)
        .where(Constants.senderId, isNotEqualTo: currentUserId)
        .where(Constants.isRead, isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
