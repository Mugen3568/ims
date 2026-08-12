import 'package:cloud_firestore/cloud_firestore.dart';

/// AttendanceSummary — embedded summary stored on the lecture document
class AttendanceSummary {
  final int present;
  final int absent;
  final int lateCount;
  final int excused;
  final int total;
  final int attendanceVersion;

  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.lateCount,
    required this.excused,
    required this.total,
    this.attendanceVersion = 1,
  });

  factory AttendanceSummary.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AttendanceSummary(
        present: 0,
        absent: 0,
        lateCount: 0,
        excused: 0,
        total: 0,
      );
    }
    return AttendanceSummary(
      present: (map['present'] as num? ?? 0).toInt(),
      absent: (map['absent'] as num? ?? 0).toInt(),
      lateCount: (map['late'] as num? ?? 0).toInt(),
      excused: (map['excused'] as num? ?? 0).toInt(),
      total: (map['total'] as num? ?? 0).toInt(),
      attendanceVersion: (map['attendanceVersion'] as num? ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'present': present,
      'absent': absent,
      'late': lateCount,
      'excused': excused,
      'total': total,
      'attendanceVersion': attendanceVersion,
    };
  }

  /// Calculates present percentage (Present + Late + Excused) / Total * 100
  double get presencePercentage {
    if (total <= 0) return 0.0;
    return ((present + lateCount + excused) / total) * 100.0;
  }
}

/// StudentAttendance Model — Doc ID: `${lectureId}_${studentId}`
class StudentAttendance {
  final String attendanceId;
  final String lectureId;
  final String lectureCode;
  final String classId;
  final String className;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final String subject;
  final String status; // 'Present', 'Absent', 'Late', 'Excused'
  final int attendanceVersion;
  final DateTime? submittedAt;

  const StudentAttendance({
    required this.attendanceId,
    required this.lectureId,
    required this.lectureCode,
    required this.classId,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.subject,
    required this.status,
    this.attendanceVersion = 1,
    this.submittedAt,
  });

  /// Deterministic ID generator for student attendance docs
  static String generateId(String lectureId, String studentId) {
    final cleanL = lectureId.replaceAll('/', '_');
    final cleanS = studentId.trim();
    return '${cleanL}_$cleanS';
  }

  factory StudentAttendance.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StudentAttendance(
      attendanceId: doc.id,
      lectureId: (data['lectureId'] ?? '').toString(),
      lectureCode: (data['lectureCode'] ?? '').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      studentName: (data['studentName'] ?? data['name'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      status: (data['status'] ?? 'Present').toString(),
      attendanceVersion: (data['attendanceVersion'] as num? ?? 1).toInt(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ??
          (data['date'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendanceId': attendanceId,
      'lectureId': lectureId,
      'lectureCode': lectureCode,
      'classId': classId,
      'className': className,
      'studentId': studentId,
      'studentName': studentName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subject': subject,
      'status': status,
      'attendanceVersion': attendanceVersion,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  bool get isPresentOrLate =>
      status == 'Present' || status == 'Late' || status == 'Excused';
}

/// TeacherAttendance Model — Doc ID: `${lectureId}_${teacherId}`
class TeacherAttendance {
  final String attendanceId;
  final String lectureId;
  final String lectureCode;
  final String teacherId;
  final String teacherName;
  final String classId;
  final String className;
  final String subject;
  final String status; // Always 'Present'
  final int attendanceVersion;
  final DateTime? submittedAt;

  const TeacherAttendance({
    required this.attendanceId,
    required this.lectureId,
    required this.lectureCode,
    required this.teacherId,
    required this.teacherName,
    required this.classId,
    required this.className,
    required this.subject,
    this.status = 'Present',
    this.attendanceVersion = 1,
    this.submittedAt,
  });

  /// Deterministic ID generator for teacher attendance docs
  static String generateId(String lectureId, String teacherId) {
    final cleanL = lectureId.replaceAll('/', '_');
    final cleanT = teacherId.trim();
    return '${cleanL}_$cleanT';
  }

  factory TeacherAttendance.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TeacherAttendance(
      attendanceId: doc.id,
      lectureId: (data['lectureId'] ?? '').toString(),
      lectureCode: (data['lectureCode'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? '').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      status: (data['status'] ?? 'Present').toString(),
      attendanceVersion: (data['attendanceVersion'] as num? ?? 1).toInt(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ??
          (data['date'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendanceId': attendanceId,
      'lectureId': lectureId,
      'lectureCode': lectureCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'classId': classId,
      'className': className,
      'subject': subject,
      'status': status,
      'attendanceVersion': attendanceVersion,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
