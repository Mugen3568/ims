import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String receiverId;
  final String receiverRole;
  final String type;
  final String referenceId;
  final bool isRead;
  final Timestamp? createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receiverId,
    required this.receiverRole,
    required this.type,
    required this.referenceId,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? data['message'] ?? '',
      receiverId: data['receiverId'] ?? data['receiver_id'] ?? data['user_id'] ?? '',
      receiverRole: data['receiverRole'] ?? '',
      type: data['type'] ?? 'general',
      referenceId: data['referenceId'] ?? data['actionId'] ?? '',
      isRead: data['isRead'] ?? (data['status'] == 'read') ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? data['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "title": title,
      "body": body,
      "receiverId": receiverId,
      "receiverRole": receiverRole,
      "type": type,
      "referenceId": referenceId,
      "isRead": isRead,
      "createdAt": FieldValue.serverTimestamp(),
    };
  }
}
