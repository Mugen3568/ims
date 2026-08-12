/// Report Data Transfer Objects (DTOs) for Module 6 Reports & Analytics

/// High-level Institute Key Performance Indicators
class InstituteKpiSummary {
  final int totalStudents;
  final int totalTeachers;
  final int totalClasses;
  final int todayLecturesCount;
  final double todayAttendanceRate;
  final double totalPendingFees;
  final double totalPendingPayroll;
  final double monthlyRevenue;

  const InstituteKpiSummary({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalClasses,
    required this.todayLecturesCount,
    required this.todayAttendanceRate,
    required this.totalPendingFees,
    required this.totalPendingPayroll,
    required this.monthlyRevenue,
  });
}

/// Class-scoped analytics DTO
class ClassAnalyticsSummary {
  final String classId;
  final String className;
  final int totalStudents;
  final double attendanceRate;
  final double feesCollected;
  final double pendingFees;
  final int lecturesCompleted;

  const ClassAnalyticsSummary({
    required this.classId,
    required this.className,
    required this.totalStudents,
    required this.attendanceRate,
    required this.feesCollected,
    required this.pendingFees,
    required this.lecturesCompleted,
  });
}

/// Subject-scoped analytics DTO
class SubjectAnalyticsSummary {
  final String subjectName;
  final String className;
  final String teacherName;
  final int lecturesCount;
  final double attendanceRate;

  const SubjectAnalyticsSummary({
    required this.subjectName,
    required this.className,
    required this.teacherName,
    required this.lecturesCount,
    required this.attendanceRate,
  });
}

/// Teacher Performance DTO
class TeacherPerformanceSummary {
  final String teacherId;
  final String teacherName;
  final int completedLectures;
  final double submissionRate; // e.g. 96.5%
  final int cancellationsCount;
  final double avgClassAttendance; // e.g. 88.2%
  final double pendingPayroll;

  const TeacherPerformanceSummary({
    required this.teacherId,
    required this.teacherName,
    required this.completedLectures,
    required this.submissionRate,
    required this.cancellationsCount,
    required this.avgClassAttendance,
    required this.pendingPayroll,
  });
}

/// Student Fee Defaulter Entry DTO
class FeeDefaulterEntry {
  final String studentId;
  final String studentName;
  final String className;
  final String studentEmail;
  final double pendingAmount;
  final String status; // 'overdue', 'pending', 'partial'
  final DateTime? dueDate;

  const FeeDefaulterEntry({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.studentEmail,
    required this.pendingAmount,
    required this.status,
    this.dueDate,
  });
}

/// Low Attendance Student Entry (< 75%) DTO
class LowAttendanceEntry {
  final String studentId;
  final String studentName;
  final String className;
  final int presentCount;
  final int totalCount;
  final double percentage;

  const LowAttendanceEntry({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.presentCount,
    required this.totalCount,
    required this.percentage,
  });
}

/// Filtered Attendance Summary DTO
class AttendanceReportSummary {
  final int totalLectures;
  final int totalRecords;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final double overallPercentage;
  final List<LowAttendanceEntry> lowAttendanceStudents;

  const AttendanceReportSummary({
    required this.totalLectures,
    required this.totalRecords,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.overallPercentage,
    required this.lowAttendanceStudents,
  });
}
