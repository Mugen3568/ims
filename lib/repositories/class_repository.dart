import '../core/result.dart';
import '../services/class_service.dart';

class ClassRepository {
  ClassRepository({ClassService? service}) : _service = service ?? ClassService();

  final ClassService _service;

  Future<Result<String>> create({
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    String description = '',
  }) async {
    try {
      return Success(await _service.createClass(
        className: className,
        subject: subject,
        teacherId: teacherId,
        teacherName: teacherName,
        description: description,
      ));
    } catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }
}
