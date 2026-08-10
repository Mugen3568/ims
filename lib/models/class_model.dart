import 'package:cloud_firestore/cloud_firestore.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SchoolClass — original model kept intact for backwards compatibility
// (used by lectures, attendance, class chat, etc.)
// ──────────────────────────────────────────────────────────────────────────────
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.className,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.joinCode,
    required this.isActive,
    required this.memberCount,
    this.teacherIds = const [],
  });

  final String id;
  final String className;
  final String subject;
  final String teacherId;
  final String teacherName;
  final String joinCode;
  final bool isActive;
  final int memberCount;
  final List<String> teacherIds;

  factory SchoolClass.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SchoolClass(
      id: doc.id,
      className: (data['className'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? '').toString(),
      joinCode: (data['joinCode'] ?? '').toString(),
      isActive: data['isActive'] == true,
      memberCount: (data['memberCount'] as num? ?? 0).toInt(),
      teacherIds: List<String>.from((data['teacherIds'] as List? ?? []).map((e) => e.toString())),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CourseClass — new model for the IMS class management system.
// Document ID is auto-generated as e.g. "BCA_Sem3_A".
// Used for: class registration (student/teacher/parent), Owner class management.
// ──────────────────────────────────────────────────────────────────────────────
class CourseClass {
  const CourseClass({
    required this.id,
    required this.className,
    required this.course,
    required this.semester,
    required this.section,
    required this.createdBy,
    required this.createdAt,
    required this.isActive,
    this.inviteCode = '',
    this.inviteCodeCreatedAt,
    this.inviteCodeCreatedBy,
    this.inviteCodeLastResetAt,
    this.inviteCodeVersion = 1,
    this.teacherIds = const [],
  });

  /// Auto-generated readable ID, e.g. "BCA_Sem3_A"
  final String id;

  /// Human-readable label, e.g. "BCA – Sem 3 – A"
  final String className;

  final String course;
  final int semester;
  final String section;
  final String createdBy; // UID of owner/manager who created it
  final DateTime? createdAt;
  final bool isActive;
  final String inviteCode;
  final DateTime? inviteCodeCreatedAt;
  final String? inviteCodeCreatedBy;
  final DateTime? inviteCodeLastResetAt;
  final int inviteCodeVersion;

  /// Reverse index: UIDs of all teachers assigned to this class.
  /// Used by lecture creation to filter the teacher dropdown.
  final List<String> teacherIds;

  /// Returns the canonical display label used in dropdowns and list tiles.
  String get displayName => '$course – Sem $semester – $section';

  /// Backwards compatibility property for name
  String get name => className.isNotEmpty ? className : displayName;

  factory CourseClass.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CourseClass(
      id: doc.id,
      className: (data['className'] ?? data['name'] ?? '').toString(),
      course: (data['course'] ?? data['className'] ?? '').toString(),
      semester: (data['semester'] as num? ?? 1).toInt(),
      section: (data['section'] ?? 'A').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] == true,
      inviteCode: (data['inviteCode'] ?? data['joinCode'] ?? '').toString(),
      inviteCodeCreatedAt: (data['inviteCodeCreatedAt'] as Timestamp?)?.toDate(),
      inviteCodeCreatedBy: data['inviteCodeCreatedBy']?.toString(),
      inviteCodeLastResetAt: (data['inviteCodeLastResetAt'] as Timestamp?)?.toDate(),
      inviteCodeVersion: (data['inviteCodeVersion'] as num? ?? 1).toInt(),
      teacherIds: List<String>.from(data['teacherIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap(String createdByUid) {
    return {
      'className': className,
      'name': className,
      'course': course,
      'semester': semester,
      'section': section,
      'createdBy': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
      'inviteCode': inviteCode,
      'inviteCodeCreatedAt': FieldValue.serverTimestamp(),
      'inviteCodeCreatedBy': createdByUid,
      'inviteCodeVersion': inviteCodeVersion,
      'teacherIds': teacherIds,
    };
  }

  /// Generates a deterministic, readable Firestore document ID.
  /// e.g. course="BCA", semester=3, section="A" → "BCA_Sem3_A"
  static String generateId(String course, int semester, String section) {
    final c = course.trim().replaceAll(' ', '');
    final s = section.trim().replaceAll(' ', '');
    return '${c}_Sem${semester}_$s';
  }

  CourseClass copyWith({
    String? course,
    int? semester,
    String? section,
    bool? isActive,
    String? inviteCode,
    List<String>? teacherIds,
  }) {
    final newCourse = course ?? this.course;
    final newSem = semester ?? this.semester;
    final newSection = section ?? this.section;
    return CourseClass(
      id: CourseClass.generateId(newCourse, newSem, newSection),
      className: '$newCourse – Sem $newSem – $newSection',
      course: newCourse,
      semester: newSem,
      section: newSection,
      createdBy: createdBy,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      inviteCode: inviteCode ?? this.inviteCode,
      teacherIds: teacherIds ?? this.teacherIds,
    );
  }
}
