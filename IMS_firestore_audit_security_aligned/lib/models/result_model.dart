import 'package:cloud_firestore/cloud_firestore.dart';

class ResultModel {
  final String id;
  final String testId;
  final String testTitle;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;
  final String subject;
  final int maxMarks;
  final int marks;
  final double percentage;
  final String grade;
  final String remarks;
  final Timestamp? createdAt;

  ResultModel({
    required this.id,
    required this.testId,
    required this.testTitle,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.subject,
    required this.maxMarks,
    required this.marks,
    required this.percentage,
    required this.grade,
    required this.remarks,
    this.createdAt,
  });

  static String calculateGrade(double pct) {
    if (pct >= 90) return "A+";
    if (pct >= 80) return "A";
    if (pct >= 70) return "B";
    if (pct >= 60) return "C";
    if (pct >= 40) return "D";
    return "F";
  }

  factory ResultModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    int m = (data['marks'] ?? data['marks_obtained'] ?? 0) as int;
    int maxM = (data['maxMarks'] ?? data['total_marks'] ?? 100) as int;
    double pct = maxM > 0 ? (m / maxM) * 100 : 0.0;
    if (data['percentage'] != null) {
      pct = (data['percentage'] as num).toDouble();
    }
    String g = data['grade'] ?? calculateGrade(pct);

    return ResultModel(
      id: doc.id,
      testId: data['testId'] ?? '',
      testTitle: data['testTitle'] ?? data['title'] ?? data['test_name'] ?? 'Test',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? data['student_email'] ?? 'Student',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? 'Teacher',
      subject: data['subject'] ?? '',
      maxMarks: maxM,
      marks: m,
      percentage: pct,
      grade: g,
      remarks: data['remarks'] ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? data['uploaded_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "testId": testId,
      "testTitle": testTitle,
      "studentId": studentId,
      "studentName": studentName,
      "classId": classId,
      "className": className,
      "teacherId": teacherId,
      "teacherName": teacherName,
      "subject": subject,
      "maxMarks": maxMarks,
      "marks": marks,
      "percentage": percentage,
      "grade": grade,
      "remarks": remarks,
      "createdAt": FieldValue.serverTimestamp(),
    };
  }
}
