import '../core/result.dart';
import '../services/attendance_service.dart';

class AttendanceRepository {
  AttendanceRepository({AttendanceService? service})
      : _service = service ?? AttendanceService();

  final AttendanceService _service;

  Future<Result<void>> submit({
    required String lectureId,
    required String teacherId,
    required List<StudentAttendanceEntry> entries,
  }) async {
    try {
      await _service.submitLectureAttendance(
        lectureId: lectureId,
        teacherId: teacherId,
        entries: entries,
      );
      return const Success(null);
    } catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }
}
