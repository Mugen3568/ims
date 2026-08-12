import 'package:cloud_firestore/cloud_firestore.dart';

import '../result.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<Result<String>> createDocument(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    try {
      final reference = _db.collection(collection).doc(id);
      await reference.set(data);
      return Success(reference.id);
    } catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }

  Future<Result<void>> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db.collection(collection).doc(id).update(data);
      return const Success<void>(null);
    } catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }

  Future<Result<DocumentSnapshot<Map<String, dynamic>>>> getDocument(
    String collection,
    String id,
  ) async {
    try {
      return Success(await _db.collection(collection).doc(id).get());
    } catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collection,
  ) => _db.collection(collection).snapshots();
}
