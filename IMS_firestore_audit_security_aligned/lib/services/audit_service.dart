import 'package:cloud_firestore/cloud_firestore.dart';

class AuditService {
  AuditService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> log({
    required String userId,
    required String action,
    required String module,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) => _db.collection('audit_logs').add({
    'userId': userId,
    'action': action,
    'module': module,
    'entityId': ?entityId,
    'metadata': ?metadata,
    'time': FieldValue.serverTimestamp(),
  });
}
