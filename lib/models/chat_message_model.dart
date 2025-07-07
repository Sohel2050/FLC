import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/utils/constants.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final Timestamp timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data[Constants.senderId] ?? '',
      text: data[Constants.text] ?? '',
      timestamp: data[Constants.timestamp] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      Constants.senderId: senderId,
      Constants.text: text,
      Constants.timestamp: timestamp,
    };
  }
}
