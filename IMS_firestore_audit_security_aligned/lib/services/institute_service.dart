import 'package:cloud_firestore/cloud_firestore.dart';

class InstituteService {
  InstituteService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<QuerySnapshot<Map<String, dynamic>>> institutes() =>
      _db.collection('institutes').snapshots();

  Future<String> createInstitute({
    required String name,
    required String code,
    required String ownerId,
    required String subscription,
    String email = '',
    String phone = '',
    String address = '',
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final duplicate = await _db
        .collection('institutes')
        .where('code', isEqualTo: normalizedCode)
        .limit(1)
        .get();
    if (duplicate.docs.isNotEmpty) throw StateError('Institute code already exists.');
    final reference = _db.collection('institutes').doc();
    await reference.set({
      'name': name.trim(),
      'code': normalizedCode,
      'ownerId': ownerId,
      'email': email.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'status': 'active',
      'subscription': subscription,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }
}
