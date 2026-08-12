import 'package:cloud_firestore/cloud_firestore.dart';

/// ClassSnapshot — preserves historical course/semester/section data
class ClassSnapshot {
  final String course;
  final int semester;
  final String section;

  const ClassSnapshot({
    required this.course,
    required this.semester,
    required this.section,
  });

  factory ClassSnapshot.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ClassSnapshot(course: '', semester: 0, section: '');
    }
    return ClassSnapshot(
      course: (map['course'] ?? '').toString(),
      semester: (map['semester'] as num? ?? 0).toInt(),
      section: (map['section'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course': course,
      'semester': semester,
      'section': section,
    };
  }

  String get displayName => '$course – Sem $semester – $section';
}

/// Lecture Model — Production-ready data model for Module 2
class Lecture {
  final String id;
  final String lectureCode; // e.g. LEC-20260801-001
  final String classId;
  final String className;
  final ClassSnapshot classSnapshot;
  final String subject;
  final String teacherId;
  final String teacherName;
  final String room;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int durationMinutes;
  final String status; // 'scheduled', 'cancel_pending', 'cancelled', 'completed', 'archived'
  final bool attendanceSubmitted;
  final int attendanceWindow; // default 15 mins
  final String? cancellationReason;
  final String? cancelledBy; // teacherUid
  final String? approvedBy; // owner/manager Uid
  final DateTime? cancellationRequestedAt;
  final DateTime? cancellationApprovedAt;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lecture({
    required this.id,
    required this.lectureCode,
    required this.classId,
    required this.className,
    required this.classSnapshot,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.room,
    required this.startDateTime,
    required this.endDateTime,
    required this.durationMinutes,
    required this.status,
    required this.attendanceSubmitted,
    required this.attendanceWindow,
    this.cancellationReason,
    this.cancelledBy,
    this.approvedBy,
    this.cancellationRequestedAt,
    this.cancellationApprovedAt,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to parse Firestore DocumentSnapshot
  factory Lecture.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse start and end timestamps (with fallbacks for legacy docs)
    DateTime start = (data['startDateTime'] as Timestamp?)?.toDate() ??
        (data['startTime'] as Timestamp?)?.toDate() ??
        (data['date'] as Timestamp?)?.toDate() ??
        DateTime.now();

    DateTime end = (data['endDateTime'] as Timestamp?)?.toDate() ??
        (data['endTime'] as Timestamp?)?.toDate() ??
        start.add(const Duration(hours: 1));

    int duration = (data['durationMinutes'] as num?)?.toInt() ??
        end.difference(start).inMinutes;
    if (duration <= 0) duration = 60;

    // Standardize status string
    String rawStatus = (data['status'] ?? 'scheduled').toString().toLowerCase();
    if (rawStatus == 'active' || rawStatus == 'running') rawStatus = 'scheduled';
    if (rawStatus == 'done' || rawStatus == 'finished') rawStatus = 'completed';
    if (!['scheduled', 'cancel_pending', 'cancelled', 'completed', 'archived']
        .contains(rawStatus)) {
      rawStatus = 'scheduled';
    }

    return Lecture(
      id: doc.id,
      lectureCode: (data['lectureCode'] ?? 'LEC-${doc.id.substring(0, 6)}').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? data['name'] ?? '').toString(),
      classSnapshot: ClassSnapshot.fromMap(
        data['classSnapshot'] as Map<String, dynamic>?,
      ),
      subject: (data['subject'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? data['teacher_uid'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? data['teacher_name'] ?? data['teacher'] ?? '').toString(),
      room: (data['room'] ?? '').toString(),
      startDateTime: start,
      endDateTime: end,
      durationMinutes: duration,
      status: rawStatus,
      attendanceSubmitted: data['attendanceSubmitted'] == true,
      attendanceWindow: (data['attendanceWindow'] as num? ?? 15).toInt(),
      cancellationReason: data['cancellationReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      approvedBy: data['approvedBy'] as String?,
      cancellationRequestedAt:
          (data['cancellationRequestedAt'] as Timestamp?)?.toDate(),
      cancellationApprovedAt:
          (data['cancellationApprovedAt'] as Timestamp?)?.toDate(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts model to Map for Firestore document creation/updates
  Map<String, dynamic> toMap() {
    return {
      'lectureCode': lectureCode,
      'classId': classId,
      'className': className,
      'classSnapshot': classSnapshot.toMap(),
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'room': room,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'durationMinutes': durationMinutes,
      'status': status,
      'attendanceSubmitted': attendanceSubmitted,
      'attendanceWindow': attendanceWindow,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'approvedBy': approvedBy,
      'cancellationRequestedAt': cancellationRequestedAt != null
          ? Timestamp.fromDate(cancellationRequestedAt!)
          : null,
      'cancellationApprovedAt': cancellationApprovedAt != null
          ? Timestamp.fromDate(cancellationApprovedAt!)
          : null,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Helper: Check if attendance can currently be marked
  bool get isAttendanceWindowActive {
    if (status == 'cancelled' || status == 'archived') return false;
    final now = DateTime.now();
    final windowEnd = endDateTime.add(Duration(minutes: attendanceWindow));
    return now.isAfter(startDateTime.subtract(const Duration(minutes: 15))) &&
        now.isBefore(windowEnd);
  }

  /// Helper: Check if lecture schedule is locked from editing
  bool get isLockedForEditing {
    return attendanceSubmitted || status == 'completed' || status == 'archived';
  }
}
