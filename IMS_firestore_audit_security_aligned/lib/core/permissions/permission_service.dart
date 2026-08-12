import 'roles.dart';

class PermissionService {
  static bool canManageUsers(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.superAdmin;
  }

  static bool canApproveStaff(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.superAdmin;
  }

  static bool canApproveParent(String role) {
    final r = role.toLowerCase();
    return r == Roles.student;
  }

  static bool canManageClasses(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canCreateLecture(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canCancelLecture(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canDeleteLecture(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canMarkAttendance(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canViewAttendanceReports(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canUploadMaterial(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canDeleteMaterial(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canCreateTest(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canEnterMarks(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canEnterResults(String role) {
    return canEnterMarks(role);
  }

  static bool canManageFees(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canManagePayroll(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canViewTeacherPayroll(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager || r == Roles.teacher;
  }

  static bool canViewReports(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.manager;
  }

  static bool canManageSettings(String role) {
    final r = role.toLowerCase();
    return r == Roles.owner || r == Roles.superAdmin;
  }
}
