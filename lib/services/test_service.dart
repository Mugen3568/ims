import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/test_model.dart';
import 'audit_service.dart';

/// DTO for entering student marks
class StudentMarkEntryInput {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final double marksObtained;
  final String? remarks;

  const StudentMarkEntryInput({
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    required this.marksObtained,
    this.remarks,
  });
}

/// Production-Ready Test & Results Service
class TestService {
  TestService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // 1. Create Scheduled Test
  // ────────────────────────────────────────────────────────────────────────────

  Future<String> createTest({
    required String testName,
    required String classId,
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    required double maxMarks,
    required DateTime testDate,
    String? externalLink,
    required String createdBy,
  }) async {
    if (maxMarks <= 0) {
      throw ArgumentError('Max marks must be greater than 0.');
    }

    final testRef = _db.collection('tests').doc();

    final test = TestModel(
      testId: testRef.id,
      testName: testName.trim(),
      classId: classId,
      className: className,
      subject: subject,
      teacherId: teacherId,
      teacherName: teacherName,
      maxMarks: maxMarks,
      testDate: testDate,
      externalLink: externalLink?.trim().isEmpty == true ? null : externalLink?.trim(),
      isPublished: true,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await testRef.set(test.toMap());

    await AuditService(firestore: _db).log(
      userId: createdBy,
      action: 'Created test "${test.testName}" for class $className',
      module: 'Tests',
      entityId: testRef.id,
    );

    return testRef.id;
  }

  /// Legacy updateTest helper
  Future<void> updateTest(TestModel test) async {
    final docId = test.testId.isNotEmpty ? test.testId : test.id;
    await _db.collection('tests').doc(docId).set(test.toMap(), SetOptions(merge: true));
  }

  /// Delete Test helper
  Future<void> deleteTest(String testId) async {
    await _db.collection('tests').doc(testId).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 2. Submit Student Marks Batch (Deterministic Doc IDs)
  // ────────────────────────────────────────────────────────────────────────────

  /// Submits student test scores atomically using deterministic doc IDs (`${testId}_${studentId}`).
  /// Automatically computes `percentage` and letter `grade` (`A+`, `A`, `B`, `C`, `D`, `F`).
  Future<void> submitTestMarks({
    required String testId,
    required List<StudentMarkEntryInput> entries,
    required String submittedBy,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError('At least one student entry is required to submit marks.');
    }

    final testSnap = await _db.collection('tests').doc(testId).get();
    if (!testSnap.exists) {
      throw StateError('Test document not found.');
    }

    final test = TestModel.fromSnapshot(testSnap);
    final batch = _db.batch();
    final now = DateTime.now();

    for (final entry in entries) {
      final resultId = TestResultModel.generateId(testId, entry.studentId);
      final resultRef = _db.collection('results').doc(resultId);

      double obtained = entry.marksObtained;
      if (obtained > test.maxMarks) obtained = test.maxMarks;
      if (obtained < 0) obtained = 0.0;

      final pct = test.maxMarks > 0 ? (obtained / test.maxMarks) * 100 : 0.0;
      final grade = TestResultModel.computeGrade(pct);

      final record = TestResultModel(
        resultId: resultId,
        testId: testId,
        testName: test.testName,
        classId: test.classId,
        className: test.className,
        subject: test.subject,
        studentId: entry.studentId,
        studentName: entry.studentName,
        teacherId: test.teacherId,
        teacherName: test.teacherName,
        marksObtained: obtained,
        maxMarks: test.maxMarks,
        percentage: pct,
        grade: grade,
        remarks: entry.remarks?.trim(),
        submittedAt: now,
      );

      batch.set(resultRef, record.toMap(), SetOptions(merge: true));
    }

    await batch.commit();

    await AuditService(firestore: _db).log(
      userId: submittedBy,
      action: 'Submitted marks for test "${test.testName}" (${entries.length} students)',
      module: 'Tests',
      entityId: testId,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 3. Scoped Streams
  // ────────────────────────────────────────────────────────────────────────────

  /// All tests stream for staff view
  Stream<QuerySnapshot<Map<String, dynamic>>> allTests() {
    return _db.collection('tests').snapshots();
  }

  /// Stream of tests for a specific class
  Stream<List<TestModel>> classTestsStream(String classId) {
    return _db
        .collection('tests')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => TestModel.fromSnapshot(d)).toList();
      list.sort((a, b) => b.testDate.compareTo(a.testDate));
      return list;
    });
  }

  /// Stream of tests created by or assigned to a teacher
  Stream<List<TestModel>> teacherTestsStream(String teacherId) {
    return _db
        .collection('tests')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => TestModel.fromSnapshot(d)).toList();
      list.sort((a, b) => b.testDate.compareTo(a.testDate));
      return list;
    });
  }

  /// Stream of all results for a student
  Stream<List<TestResultModel>> studentResultsStream(String studentId) {
    return _db
        .collection('results')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => TestResultModel.fromSnapshot(d)).toList();
      list.sort((a, b) => (b.submittedAt ?? DateTime(0))
          .compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream of results for a specific test (admin use — full collection query)
  Stream<List<TestResultModel>> testResultsStream(String testId) {
    return _db
        .collection('results')
        .where('testId', isEqualTo: testId)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => TestResultModel.fromSnapshot(d)).toList();
    });
  }

  /// Stream of results for a specific test scoped to a teacher.
  /// Queries by both testId AND teacherId so the Firestore rule
  /// `resource.data.teacherId == request.auth.uid` is satisfied for list queries.
  Stream<List<TestResultModel>> teacherTestResultsStream(
      String testId, String teacherId) {
    return _db
        .collection('results')
        .where('testId', isEqualTo: testId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => TestResultModel.fromSnapshot(d)).toList();
    });
  }
}
