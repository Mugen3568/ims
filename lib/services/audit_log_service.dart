import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> logAction({
    required String action,
    required String module,
    required String description,
    String? documentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      String userRole = 'staff';

      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userName = userDoc.data()?['name'] ?? userName;
        userRole = userDoc.data()?['role'] ?? userRole;
      }

      await _db.collection('audit_logs').add({
        'action': action,
        'module': module,
        'description': description,
        'documentId': documentId ?? '',
        'userId': user.uid,
        'userName': userName,
        'role': userRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAuditLogs() {
    return _db
        .collection('audit_logs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
