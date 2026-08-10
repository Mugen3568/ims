import 'package:cloud_firestore/cloud_firestore.dart';

/// TestModel — Represents a scheduled/conducted test or examination
class TestModel {
  final String testId;
  final String testName;
  final String classId;
  final String className;
  final String subject;
  final String teacherId;
  final String teacherName;
  final double maxMarks;
  final DateTime testDate;
  final String? externalLink;
  final bool isPublished;
  final String createdBy;
  final DateTime? createdAt;

  TestModel({
    String? testId,
    String? id,
    String? testName,
    String? title,
    String? classId,
    String? className,
    String? subject,
    String? description,
    String? teacherId,
    String? teacherName,
    double? maxMarks,
    num? totalMarks,
    DateTime? testDate,
    DateTime? examDate,
    String? externalLink,
    String? testLink,
    bool isPublished = true,
    String? createdBy,
    DateTime? createdAt,
  })  : testId = testId ?? id ?? '',
        testName = testName ?? title ?? 'Test',
        classId = classId ?? '',
        className = className ?? '',
        subject = subject ?? description ?? '',
        teacherId = teacherId ?? '',
        teacherName = teacherName ?? '',
        maxMarks = (maxMarks ?? totalMarks?.toDouble() ?? 100.0),
        testDate = testDate ?? examDate ?? DateTime.now(),
        externalLink = externalLink ?? testLink,
        isPublished = isPublished,
        createdBy = createdBy ?? '',
        createdAt = createdAt;

  // Backwards-compatible getters
  String get id => testId;
  String get title => testName;
  String get description => subject;
  String? get testLink => externalLink;
  DateTime get examDate => testDate;

  factory TestModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TestModel(
      testId: doc.id,
      testName: (data['testName'] ?? data['title'] ?? 'Test').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      subject: (data['subject'] ?? data['description'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? '').toString(),
      maxMarks: (data['maxMarks'] as num? ?? data['totalMarks'] as num? ?? 100.0).toDouble(),
      testDate: (data['testDate'] as Timestamp?)?.toDate() ??
          (data['examDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      externalLink: (data['externalLink'] ?? data['testLink']) as String?,
      isPublished: data['isPublished'] as bool? ?? true,
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory TestModel.fromFirestore(DocumentSnapshot doc) => TestModel.fromSnapshot(doc);

  Map<String, dynamic> toMap() {
    return {
      'testName': testName,
      'title': testName,
      'classId': classId,
      'className': className,
      'subject': subject,
      'description': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'maxMarks': maxMarks,
      'totalMarks': maxMarks,
      'testDate': Timestamp.fromDate(testDate),
      'examDate': Timestamp.fromDate(testDate),
      'externalLink': externalLink,
      'testLink': externalLink,
      'isPublished': isPublished,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// TestResultModel — Represents a student's score for a specific test
/// Deterministic Doc ID: `${testId}_${studentId}`
class TestResultModel {
  final String resultId;
  final String testId;
  final String testName;
  final String classId;
  final String className;
  final String subject;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final double marksObtained;
  final double maxMarks;
  final double percentage;
  final String grade; // 'A+', 'A', 'B', 'C', 'D', 'F'
  final String? remarks;
  final DateTime? submittedAt;

  const TestResultModel({
    required this.resultId,
    required this.testId,
    required this.testName,
    required this.classId,
    required this.className,
    required this.subject,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.marksObtained,
    required this.maxMarks,
    required this.percentage,
    required this.grade,
    this.remarks,
    this.submittedAt,
  });

  /// Deterministic ID generator for student test results
  static String generateId(String testId, String studentId) {
    final cleanT = testId.replaceAll('/', '_');
    final cleanS = studentId.trim();
    return '${cleanT}_$cleanS';
  }

  /// Automatic Letter Grade Calculator
  static String computeGrade(double percentage) {
    if (percentage >= 90.0) return 'A+';
    if (percentage >= 80.0) return 'A';
    if (percentage >= 70.0) return 'B';
    if (percentage >= 60.0) return 'C';
    if (percentage >= 50.0) return 'D';
    return 'F';
  }

  factory TestResultModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final obtained = (data['marksObtained'] as num? ?? data['marks'] as num? ?? 0.0).toDouble();
    final maxM = (data['maxMarks'] as num? ?? data['totalMarks'] as num? ?? 100.0).toDouble();
    final pct = (data['percentage'] as num? ?? (maxM > 0 ? (obtained / maxM) * 100 : 0.0)).toDouble();
    final computedGrade = (data['grade'] ?? computeGrade(pct)).toString();

    return TestResultModel(
      resultId: doc.id,
      testId: (data['testId'] ?? '').toString(),
      testName: (data['testName'] ?? data['title'] ?? 'Test').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      studentName: (data['studentName'] ?? data['name'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? '').toString(),
      marksObtained: obtained,
      maxMarks: maxM,
      percentage: pct,
      grade: computedGrade,
      remarks: data['remarks'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'resultId': resultId,
      'testId': testId,
      'testName': testName,
      'classId': classId,
      'className': className,
      'subject': subject,
      'studentId': studentId,
      'studentName': studentName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'marksObtained': marksObtained,
      'maxMarks': maxMarks,
      'percentage': percentage,
      'grade': grade,
      'remarks': remarks,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  bool get isPassed => grade != 'F';
}
