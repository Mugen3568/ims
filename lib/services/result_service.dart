import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/result_model.dart';
import 'audit_log_service.dart';

class ResultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _results => _db.collection("results");

  Future<void> saveResult(ResultModel result) async {
    final String customDocId = "${result.testId}_${result.studentId}";

    final mapData = result.toMap();
    mapData['updatedAt'] = FieldValue.serverTimestamp();

    await _results.doc(customDocId).set(mapData, SetOptions(merge: true));

    await AuditLogService().logAction(
      action: 'SAVE_RESULT',
      module: 'results',
      description: 'Saved test result for student ${result.studentName} (${result.grade})',
      documentId: customDocId,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> testResults(String testId) {
    return _results.where("testId", isEqualTo: testId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> studentResults(String studentId) {
    return _results.where("studentId", isEqualTo: studentId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allResults() {
    return _results.snapshots();
  }

  Future<void> deleteResult(String resultId) async {
    await _results.doc(resultId).delete();
    await AuditLogService().logAction(
      action: 'DELETE_RESULT',
      module: 'results',
      description: 'Deleted test result record $resultId',
      documentId: resultId,
    );
  }
}
