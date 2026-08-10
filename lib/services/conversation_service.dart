import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationService {
  ConversationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  String idFor(String firstUserId, String secondUserId) {
    final ids = [firstUserId, secondUserId]..sort();
    return '${ids.first}_${ids.last}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> conversations(String userId) => _db
      .collection('conversations')
      .where('participants', arrayContains: userId)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String conversationId) => _db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> send({
    required String senderId,
    required String recipientId,
    required String text,
  }) async {
    final message = text.trim();
    if (message.isEmpty) return;
    final conversationId = idFor(senderId, recipientId);
    final conversationRef = _db.collection('conversations').doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();
    final batch = _db.batch();
    batch.set(conversationRef, {
      'participants': [senderId, recipientId]..sort(),
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSender': senderId,
      'typing': {senderId: false},
    }, SetOptions(merge: true));
    batch.set(messageRef, {
      'senderId': senderId,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
    await batch.commit();
  }

  Future<void> markRead(String conversationId, String currentUserId) async {
    final unread = await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final message in unread.docs) {
      if (message.data()['senderId'] != currentUserId) {
        batch.update(message.reference, {'read': true, 'readAt': FieldValue.serverTimestamp()});
      }
    }
    await batch.commit();
  }

  Future<void> setTyping(String conversationId, String userId, bool typing) async {
    final conversationRef = _db.collection('conversations').doc(conversationId);
    if (!(await conversationRef.get()).exists) return;
    await conversationRef.update({'typing.$userId': typing});
  }
}
