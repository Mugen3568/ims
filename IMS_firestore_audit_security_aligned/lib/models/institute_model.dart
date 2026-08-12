import 'package:cloud_firestore/cloud_firestore.dart';

class Institute {
  const Institute({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerId,
    required this.subscription,
    required this.status,
  });

  final String id;
  final String name;
  final String code;
  final String ownerId;
  final String subscription;
  final String status;

  factory Institute.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Institute(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      ownerId: (data['ownerId'] ?? '').toString(),
      subscription: (data['subscription'] ?? 'Free').toString(),
      status: (data['status'] ?? 'active').toString(),
    );
  }
}
