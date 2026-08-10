import 'attendance_service.dart';
import 'finance_service.dart';

/// Backwards-compatible entry point for code that submits a complete lecture or processes pay.
class AttendancePayService {
  AttendancePayService({
    AttendanceService? attendanceService,
    FinanceService? financeService,
  })  : _attendanceService = attendanceService ?? AttendanceService(),
        _financeService = financeService ?? FinanceService();

  final AttendanceService _attendanceService;
  final FinanceService _financeService;

  Future<void> submitAttendanceAndIncrementPay({
    required String lectureId,
    required String teacherId,
    required List<Map<String, dynamic>> studentAttendanceRecords,
  }) {
    return _attendanceService.submitLectureAttendance(
      lectureId: lectureId,
      teacherId: teacherId,
      entries: studentAttendanceRecords
          .map(
            (record) => StudentAttendanceEntry(
              studentId:
                  (record['studentId'] ?? record['student_id'] ?? '').toString(),
              status: record['status'] as String,
            ),
          )
          .toList(),
    );
  }

  Future<void> resetTeacherPay(
    String teacherId, {
    String teacherName = 'Teacher',
    int unpaidLectures = 0,
    num ratePerLecture = 0,
    String paymentMode = 'Cash',
  }) {
    return _financeService.payTeacher(
      teacherId: teacherId,
      teacherName: teacherName,
      unpaidLectures: unpaidLectures,
      ratePerLecture: ratePerLecture,
      paymentMode: paymentMode,
    );
  }
}
