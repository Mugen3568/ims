import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../models/lecture_model.dart';
import 'audit_service.dart';

/// Class for student marking entries
class StudentMarkEntry {
  final String studentId;
  final String studentName;
  final String status; // 'Present', 'Absent', 'Late', 'Excused'

  const StudentMarkEntry({
    required this.studentId,
    this.studentName = '',
    required this.status,
  });
}

typedef StudentAttendanceEntry = StudentMarkEntry;

/// Production-Ready Attendance Service
class AttendanceService {
  AttendanceService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // Atomic 7-Step Attendance Submission Transaction
  // ────────────────────────────────────────────────────────────────────────────

  /// Submits student and teacher attendance in a single atomic Firestore transaction.
  ///
  /// Guarantees:
  ///   1. One-time submission (`!attendanceSubmitted`)
  ///   2. Deterministic document IDs (`${lectureId}_${studentId}`)
  ///   3. Re-validates active attendance window inside transaction
  ///   4. Uses `FieldValue.increment(1)` for atomic payroll counter updates
  ///   5. Embeds `attendanceSummary` map on the lecture document
  Future<void> submitLectureAttendance({
    required String lectureId,
    required String teacherId,
    required List<StudentMarkEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError('At least one student is required to submit attendance.');
    }

    final cleanLectureId = _cleanDocId(lectureId);
    final lectureRef = _db.collection('lectures').doc(cleanLectureId);

    final teacherAttendanceId =
        TeacherAttendance.generateId(cleanLectureId, teacherId);
    final teacherAttendanceRef =
        _db.collection('teacher_attendance').doc(teacherAttendanceId);

    final teacherUserRef = _db.collection('users').doc(teacherId);
    final payrollRef = _db.collection('payroll').doc(teacherId);

    await _db.runTransaction((transaction) async {
      // ── STEP 1: READ LECTURE & IN-TRANSACTION VALIDATIONS ─────────────────
      final lectureSnap = await transaction.get(lectureRef);
      if (!lectureSnap.exists) {
        throw StateError('Lecture not found.');
      }

      final lecture = Lecture.fromSnapshot(lectureSnap);

      // Check one-time submission gate
      if (lecture.attendanceSubmitted) {
        throw StateError('Attendance has already been submitted for this lecture.');
      }

      // Check active status
      if (lecture.status == 'cancelled' || lecture.status == 'archived') {
        throw StateError(
          'Cannot submit attendance for a ${lecture.status} lecture.',
        );
      }

      // Check teacher assignment
      if (lecture.teacherId != teacherId) {
        throw StateError(
          'You are not assigned to teach this lecture.',
        );
      }

      // Re-verify attendance window inside transaction right before write
      final now = DateTime.now();
      final windowEnd = lecture.endDateTime
          .add(Duration(minutes: lecture.attendanceWindow));
      final windowStart = lecture.startDateTime
          .subtract(const Duration(minutes: 15));

      if (now.isBefore(windowStart) || now.isAfter(windowEnd)) {
        throw StateError(
          'Attendance window is closed. Submissions are only permitted from '
          '15 mins before lecture start until ${lecture.attendanceWindow} mins after end time.',
        );
      }

      // ── STEP 2: CALCULATE SUMMARY & WRITE STUDENT ATTENDANCE RECORDS ──────
      int presentCount = 0;
      int absentCount = 0;
      int lateCount = 0;
      int excusedCount = 0;

      for (final entry in entries) {
        final status = entry.status;
        if (status == 'Present') {
          presentCount++;
        } else if (status == 'Absent') {
          absentCount++;
        } else if (status == 'Late') {
          lateCount++;
        } else if (status == 'Excused') {
          excusedCount++;
        }

        final studentAttendanceId =
            StudentAttendance.generateId(cleanLectureId, entry.studentId);
        final studentRef =
            _db.collection('student_attendance').doc(studentAttendanceId);

        final record = StudentAttendance(
          attendanceId: studentAttendanceId,
          lectureId: cleanLectureId,
          lectureCode: lecture.lectureCode,
          classId: lecture.classId,
          className: lecture.className,
          studentId: entry.studentId,
          studentName: entry.studentName,
          teacherId: teacherId,
          teacherName: lecture.teacherName,
          subject: lecture.subject,
          status: status,
          attendanceVersion: 1,
          submittedAt: now,
        );

        transaction.set(studentRef, record.toMap());
      }

      final summary = AttendanceSummary(
        present: presentCount,
        absent: absentCount,
        lateCount: lateCount,
        excused: excusedCount,
        total: entries.length,
        attendanceVersion: 1,
      );

      // ── STEP 3: WRITE TEACHER ATTENDANCE RECORD ────────────────────────────
      final teacherRecord = TeacherAttendance(
        attendanceId: teacherAttendanceId,
        lectureId: cleanLectureId,
        lectureCode: lecture.lectureCode,
        teacherId: teacherId,
        teacherName: lecture.teacherName,
        classId: lecture.classId,
        className: lecture.className,
        subject: lecture.subject,
        status: 'Present',
        attendanceVersion: 1,
        submittedAt: now,
      );

      transaction.set(teacherAttendanceRef, teacherRecord.toMap());

      // ── STEP 4: UPDATE TEACHER USER COUNTERS (FieldValue.increment) ────────
      transaction.update(teacherUserRef, {
        'total_lectures_taken': FieldValue.increment(1),
        'unpaid_lectures': FieldValue.increment(1),
      });

      // ── STEP 5: UPDATE PAYROLL COUNTERS (FieldValue.increment) ────────────
      // Read teacher rate to update pendingSalary correctly
      final teacherUserSnap = await transaction.get(teacherUserRef);
      final teacherUserData = teacherUserSnap.data() ?? {};
      final rate = (teacherUserData['rate_per_lecture'] as num? ?? 0).toDouble();

      transaction.set(payrollRef, {
        'teacherId': teacherId,
        'perLecture': rate,
        'completedLectures': FieldValue.increment(1),
        'unpaidLectures': FieldValue.increment(1),
        'pendingSalary': FieldValue.increment(rate),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ── STEP 6: LOCK LECTURE & WRITE EMBEDDED ATTENDANCE SUMMARY ──────────
      transaction.update(lectureRef, {
        'attendanceSubmitted': true,
        'attendanceSubmittedAt': FieldValue.serverTimestamp(),
        'attendanceSummary': summary.toMap(),
        'attendanceVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // ── STEP 7: POST-TRANSACTION LOGS & NOTIFICATIONS ─────────────────────────
    await AuditService(firestore: _db).log(
      userId: teacherId,
      action: 'Submitted attendance for lecture $cleanLectureId',
      module: 'Attendance',
      entityId: cleanLectureId,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Scoped Streams
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream of student attendance records for a specific student
  Stream<List<StudentAttendance>> studentAttendance(String studentId) {
    return _db
        .collection('student_attendance')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => StudentAttendance.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream of teacher attendance records for a specific teacher
  Stream<List<TeacherAttendance>> teacherAttendance(String teacherId) {
    return _db
        .collection('teacher_attendance')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => TeacherAttendance.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream of all student attendance records for a class
  Stream<List<StudentAttendance>> classAttendance(String classId) {
    return _db
        .collection('student_attendance')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => StudentAttendance.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }

  static String _cleanDocId(String id) =>
      id.contains('/') ? id.split('/').last : id;
}
