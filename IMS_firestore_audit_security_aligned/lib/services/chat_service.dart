import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream messages for a specific group or chat room
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Send a text or image attachment message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String message,
    String? imageUrl,
  }) async {
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'image_url': imageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
