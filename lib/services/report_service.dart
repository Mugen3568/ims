import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../models/finance_model.dart';
import '../models/lecture_model.dart';
import '../models/report_model.dart';

/// High-Performance Zero-Redundancy Reports & Analytics Service
class ReportService {
  ReportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // 1. Institute KPI Summary Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<InstituteKpiSummary> getInstituteKpiSummary() async {
    final studentsSnap =
        await _db.collection('users').where('role', isEqualTo: 'student').get();
    final teachersSnap =
        await _db.collection('users').where('role', isEqualTo: 'teacher').get();
    final classesSnap = await _db.collection('classes').get();
    final lecturesSnap = await _db.collection('lectures').get();
    final studentFeesSnap = await _db.collection('student_fees').get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayLectures = lecturesSnap.docs.map((d) => Lecture.fromSnapshot(d)).where((l) {
      return l.startDateTime.isAfter(todayStart) && l.startDateTime.isBefore(todayEnd);
    }).toList();

    int todaySubmitted = todayLectures.where((l) => l.attendanceSubmitted).length;
    double todayAttendanceRate =
        todayLectures.isNotEmpty ? (todaySubmitted / todayLectures.length) * 100 : 0.0;

    double pendingFees = 0.0;
    for (final doc in studentFeesSnap.docs) {
      final fee = StudentFee.fromSnapshot(doc);
      pendingFees += fee.pendingAmount;
    }

    double pendingPayroll = 0.0;
    for (final doc in teachersSnap.docs) {
      final data = doc.data();
      final unpaid = (data['unpaid_lectures'] as num? ?? 0).toInt();
      final rate = (data['rate_per_lecture'] as num? ?? 500.0).toDouble();
      pendingPayroll += (unpaid * rate);
    }

    // Monthly revenue calculation
    final monthStart = DateTime(now.year, now.month, 1);
    final txnsSnap = await _db
        .collection('financial_transactions')
        .where('type', isEqualTo: 'student_fee')
        .get();

    double monthlyRev = 0.0;
    for (final doc in txnsSnap.docs) {
      final txn = FinanceTransaction.fromSnapshot(doc);
      if (txn.createdAt != null && txn.createdAt!.isAfter(monthStart)) {
        monthlyRev += txn.amount;
      }
    }

    return InstituteKpiSummary(
      totalStudents: studentsSnap.docs.length,
      totalTeachers: teachersSnap.docs.length,
      totalClasses: classesSnap.docs.length,
      todayLecturesCount: todayLectures.length,
      todayAttendanceRate: todayAttendanceRate,
      totalPendingFees: pendingFees,
      totalPendingPayroll: pendingPayroll,
      monthlyRevenue: monthlyRev,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 2. Filtered Attendance Report Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<AttendanceReportSummary> getAttendanceReport({
    String? classId,
    DateTimeRange? dateRange,
  }) async {
    Query query = _db.collection('student_attendance');

    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }

    final snap = await query.get();
    var docs = snap.docs.map((d) => StudentAttendance.fromSnapshot(d)).toList();

    if (dateRange != null) {
      docs = docs.where((r) {
        if (r.submittedAt == null) return false;
        return r.submittedAt!.isAfter(dateRange.start) &&
            r.submittedAt!.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    int present = 0;
    int absent = 0;
    int lateCount = 0;
    int excused = 0;

    final Map<String, List<StudentAttendance>> studentMap = {};

    for (final r in docs) {
      if (r.status == 'Present') {
        present++;
      } else if (r.status == 'Absent') {
        absent++;
      } else if (r.status == 'Late') {
        lateCount++;
      } else if (r.status == 'Excused') {
        excused++;
      }

      studentMap.putIfAbsent(r.studentId, () => []).add(r);
    }

    final int total = docs.length;
    final double overallRate = total > 0 ? ((present + lateCount) / total) * 100 : 0.0;

    // Detect Low Attendance Students (< 75%)
    final List<LowAttendanceEntry> lowAttendance = [];
    studentMap.forEach((sId, records) {
      int sPresent = records.where((r) => r.isPresentOrLate).length;
      double pct = records.isNotEmpty ? (sPresent / records.length) * 100 : 0.0;
      if (pct < 75.0 && records.isNotEmpty) {
        final first = records.first;
        lowAttendance.add(
          LowAttendanceEntry(
            studentId: sId,
            studentName: first.studentName,
            className: first.className,
            presentCount: sPresent,
            totalCount: records.length,
            percentage: pct,
          ),
        );
      }
    });

    return AttendanceReportSummary(
      totalLectures: docs.map((d) => d.lectureId).toSet().length,
      totalRecords: total,
      presentCount: present,
      absentCount: absent,
      lateCount: lateCount,
      excusedCount: excused,
      overallPercentage: overallRate,
      lowAttendanceStudents: lowAttendance,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 3. Class Analytics Dashboard Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<ClassAnalyticsSummary> getClassAnalytics(String classId, String className) async {
    final studentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: classId)
        .get();

    final lecturesSnap = await _db
        .collection('lectures')
        .where('classId', isEqualTo: classId)
        .get();

    final attendanceSnap = await _db
        .collection('student_attendance')
        .where('classId', isEqualTo: classId)
        .get();

    final feesSnap = await _db
        .collection('student_fees')
        .where('classId', isEqualTo: classId)
        .get();

    int totalStudents = studentsSnap.docs.length;
    int completedLectures =
        lecturesSnap.docs.map((d) => Lecture.fromSnapshot(d)).where((l) => l.attendanceSubmitted).length;

    int presentCount = 0;
    int totalAttendance = attendanceSnap.docs.length;

    for (final doc in attendanceSnap.docs) {
      final att = StudentAttendance.fromSnapshot(doc);
      if (att.isPresentOrLate) presentCount++;
    }

    double attendanceRate =
        totalAttendance > 0 ? (presentCount / totalAttendance) * 100 : 0.0;

    double feesCollected = 0.0;
    double pendingFees = 0.0;

    for (final doc in feesSnap.docs) {
      final fee = StudentFee.fromSnapshot(doc);
      feesCollected += fee.paidAmount;
      pendingFees += fee.pendingAmount;
    }

    return ClassAnalyticsSummary(
      classId: classId,
      className: className,
      totalStudents: totalStudents,
      attendanceRate: attendanceRate,
      feesCollected: feesCollected,
      pendingFees: pendingFees,
      lecturesCompleted: completedLectures,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 4. Subject Analytics Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<SubjectAnalyticsSummary>> getSubjectAnalytics() async {
    final lecturesSnap = await _db.collection('lectures').get();
    final attendanceSnap = await _db.collection('student_attendance').get();

    final Map<String, List<Lecture>> subjectLectures = {};
    final Map<String, List<StudentAttendance>> subjectAttendance = {};

    for (final doc in lecturesSnap.docs) {
      final lecture = Lecture.fromSnapshot(doc);
      subjectLectures.putIfAbsent(lecture.subject, () => []).add(lecture);
    }

    for (final doc in attendanceSnap.docs) {
      final att = StudentAttendance.fromSnapshot(doc);
      subjectAttendance.putIfAbsent(att.subject, () => []).add(att);
    }

    final List<SubjectAnalyticsSummary> list = [];

    subjectLectures.forEach((subject, lectures) {
      final attRecords = subjectAttendance[subject] ?? [];
      int present = attRecords.where((a) => a.isPresentOrLate).length;
      double rate = attRecords.isNotEmpty ? (present / attRecords.length) * 100 : 0.0;
      final first = lectures.first;

      list.add(
        SubjectAnalyticsSummary(
          subjectName: subject,
          className: first.className,
          teacherName: first.teacherName,
          lecturesCount: lectures.length,
          attendanceRate: rate,
        ),
      );
    });

    return list;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 5. Teacher Performance Report Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<TeacherPerformanceSummary>> getTeacherPerformanceReport() async {
    final teachersSnap =
        await _db.collection('users').where('role', isEqualTo: 'teacher').get();
    final lecturesSnap = await _db.collection('lectures').get();
    final attendanceSnap = await _db.collection('student_attendance').get();

    final allLectures =
        lecturesSnap.docs.map((d) => Lecture.fromSnapshot(d)).toList();
    final allAttendance =
        attendanceSnap.docs.map((d) => StudentAttendance.fromSnapshot(d)).toList();

    final List<TeacherPerformanceSummary> list = [];

    for (final doc in teachersSnap.docs) {
      final tId = doc.id;
      final tData = doc.data();
      final tName = (tData['name'] ?? tData['email'] ?? 'Teacher').toString();
      final unpaid = (tData['unpaid_lectures'] as num? ?? 0).toInt();
      final rate = (tData['rate_per_lecture'] as num? ?? 500.0).toDouble();

      final tLectures = allLectures.where((l) => l.teacherId == tId).toList();
      final completed = tLectures.where((l) => l.attendanceSubmitted).length;
      final cancelled = tLectures.where((l) => l.status == 'cancelled').length;

      double submissionRate =
          tLectures.isNotEmpty ? (completed / tLectures.length) * 100 : 0.0;

      final tAttendance = allAttendance.where((a) => a.teacherId == tId).toList();
      int present = tAttendance.where((a) => a.isPresentOrLate).length;
      double avgAttendance =
          tAttendance.isNotEmpty ? (present / tAttendance.length) * 100 : 0.0;

      list.add(
        TeacherPerformanceSummary(
          teacherId: tId,
          teacherName: tName,
          completedLectures: completed,
          submissionRate: submissionRate,
          cancellationsCount: cancelled,
          avgClassAttendance: avgAttendance,
          pendingPayroll: unpaid * rate,
        ),
      );
    }

    return list;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 6. Fee Defaulters Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<List<FeeDefaulterEntry>> getFeeDefaulters() async {
    final snap = await _db
        .collection('student_fees')
        .where('pendingAmount', isGreaterThan: 0)
        .get();

    final list = snap.docs.map((d) {
      final fee = StudentFee.fromSnapshot(d);
      return FeeDefaulterEntry(
        studentId: fee.studentId,
        studentName: fee.studentName,
        className: fee.className,
        studentEmail: fee.studentEmail,
        pendingAmount: fee.pendingAmount,
        status: fee.status,
        dueDate: fee.dueDate,
      );
    }).toList();

    list.sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));
    return list;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 7. Modular CSV Exporters
  // ────────────────────────────────────────────────────────────────────────────

  String exportAttendanceCsv(AttendanceReportSummary summary) {
    final buffer = StringBuffer();
    buffer.writeln('Attendance Summary Report');
    buffer.writeln('Total Lectures,Total Records,Present,Absent,Late,Excused,Overall Rate %');
    buffer.writeln(
        '${summary.totalLectures},${summary.totalRecords},${summary.presentCount},${summary.absentCount},${summary.lateCount},${summary.excusedCount},${summary.overallPercentage.toStringAsFixed(1)}%');
    buffer.writeln();
    buffer.writeln('Low Attendance Students (<75%)');
    buffer.writeln('Student ID,Student Name,Class,Present,Total,Percentage %');
    for (final s in summary.lowAttendanceStudents) {
      buffer.writeln('${s.studentId},"${s.studentName}","${s.className}",${s.presentCount},${s.totalCount},${s.percentage.toStringAsFixed(1)}%');
    }
    return buffer.toString();
  }

  String exportTeacherPerformanceCsv(List<TeacherPerformanceSummary> teachers) {
    final buffer = StringBuffer();
    buffer.writeln('Teacher Performance Report');
    buffer.writeln('Teacher ID,Teacher Name,Completed Lectures,Submission Rate %,Cancellations,Avg Class Attendance %,Pending Payroll (\$)');
    for (final t in teachers) {
      buffer.writeln(
          '${t.teacherId},"${t.teacherName}",${t.completedLectures},${t.submissionRate.toStringAsFixed(1)}%,${t.cancellationsCount},${t.avgClassAttendance.toStringAsFixed(1)}%,${t.pendingPayroll.toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  String exportFeeDefaultersCsv(List<FeeDefaulterEntry> defaulters) {
    final buffer = StringBuffer();
    buffer.writeln('Student Fee Defaulters Report');
    buffer.writeln('Student ID,Student Name,Email,Class,Pending Amount (\$),Status');
    for (final d in defaulters) {
      buffer.writeln(
          '${d.studentId},"${d.studentName}","${d.studentEmail}","${d.className}",${d.pendingAmount.toStringAsFixed(2)},${d.status.toUpperCase()}');
    }
    return buffer.toString();
  }
}
