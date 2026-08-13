import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/lecture_model.dart';
import 'audit_service.dart';
import 'notification_service.dart';

/// Production-Ready Lecture Management Service
class LectureService {
  LectureService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // Conflict Validation Algorithm
  // ────────────────────────────────────────────────────────────────────────────

  /// Validates whether a proposed time slot conflicts with existing active lectures.
  /// Checks for both:
  ///   1. Class double-booking (same classId overlapping time)
  ///   2. Teacher double-booking (same teacherId overlapping time)
  Future<void> validateLectureConflict({
    required String classId,
    required String teacherId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? excludedLectureId,
  }) async {
    if (!startDateTime.isBefore(endDateTime)) {
      throw ArgumentError('Start time must be strictly before end time.');
    }

    // Query active lectures from /lectures collection
    final snapshot = await _db.collection('lectures').get();

    for (final doc in snapshot.docs) {
      if (doc.id == excludedLectureId) continue;
      final data = doc.data();

      // Skip cancelled or archived lectures
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled' || status == 'archived') continue;

      // Extract timestamps
      final existingStart = (data['startDateTime'] as Timestamp?)?.toDate() ??
          (data['startTime'] as Timestamp?)?.toDate();
      final existingEnd = (data['endDateTime'] as Timestamp?)?.toDate() ??
          (data['endTime'] as Timestamp?)?.toDate();

      if (existingStart == null || existingEnd == null) continue;

      // Check time overlap: (StartA < EndB) && (EndA > StartB)
      final overlaps = startDateTime.isBefore(existingEnd) &&
          endDateTime.isAfter(existingStart);

      if (!overlaps) continue;

      // 1. Check Class Conflict
      if (data['classId'] == classId) {
        final className = data['className'] ?? classId;
        throw StateError(
          'Conflict: Class "$className" is already scheduled for a lecture from '
          '${_formatTime(existingStart)} to ${_formatTime(existingEnd)}.',
        );
      }

      // 2. Check Teacher Conflict
      if (data['teacherId'] == teacherId || data['teacher_uid'] == teacherId) {
        final teacherName = data['teacherName'] ?? data['teacher'] ?? 'Teacher';
        throw StateError(
          'Conflict: Teacher "$teacherName" is already assigned to another lecture from '
          '${_formatTime(existingStart)} to ${_formatTime(existingEnd)}.',
        );
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Lecture Creation & Management (Owner / Manager)
  // ────────────────────────────────────────────────────────────────────────────

  /// Generates a human-readable lecture code e.g. "LEC-20260801-001"
  Future<String> generateLectureCode(DateTime date) async {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final prefix = 'LEC-$dateStr';

    final countSnap = await _db
        .collection('lectures')
        .where('lectureCode', isGreaterThanOrEqualTo: prefix)
        .where('lectureCode', isLessThan: '$prefix-z')
        .get();

    final nextNum = countSnap.docs.length + 1;
    return '$prefix-${nextNum.toString().padLeft(3, '0')}';
  }

  /// Creates a new lecture in the top-level `/lectures` collection.
  Future<String> createLecture({
    required String classId,
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    required String room,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String createdBy,
    int attendanceWindow = 15,
  }) async {
    // 1. Validate start < end
    if (!startDateTime.isBefore(endDateTime)) {
      throw ArgumentError('Start time must be before end time.');
    }

    // 2. Perform Conflict Check
    await validateLectureConflict(
      classId: classId,
      teacherId: teacherId,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
    );

    // 3. Fetch Class snapshot details if available
    ClassSnapshot classSnapshot = const ClassSnapshot(course: '', semester: 0, section: '');
    try {
      final classDoc = await _db.collection('classes').doc(classId).get();
      if (classDoc.exists) {
        final cData = classDoc.data() ?? {};
        classSnapshot = ClassSnapshot(
          course: (cData['course'] ?? '').toString(),
          semester: (cData['semester'] as num? ?? 0).toInt(),
          section: (cData['section'] ?? '').toString(),
        );
      }
    } catch (_) {}

    // 4. Generate lecture code
    final lectureCode = await generateLectureCode(startDateTime);
    final duration = endDateTime.difference(startDateTime).inMinutes;

    final lectureRef = _db.collection('lectures').doc();
    final newLecture = Lecture(
      id: lectureRef.id,
      lectureCode: lectureCode,
      classId: classId,
      className: className,
      classSnapshot: classSnapshot,
      subject: subject,
      teacherId: teacherId,
      teacherName: teacherName,
      room: room,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      durationMinutes: duration > 0 ? duration : 60,
      status: 'scheduled',
      attendanceSubmitted: false,
      attendanceWindow: attendanceWindow,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await lectureRef.set(newLecture.toMap());

    // Audit log
    await AuditService(firestore: _db).log(
      userId: createdBy,
      action: 'Created lecture $lectureCode',
      module: 'Lecture',
      entityId: lectureRef.id,
      metadata: {'classId': classId, 'teacherId': teacherId},
    );

    // Notify assigned teacher
    await _notifyUsers(
      [teacherId],
      'New Lecture Assigned',
      'You have been assigned to teach $subject ($className) at ${_formatTime(startDateTime)}.',
      lectureRef.id,
    );

    // Notify class students
    final dateStr = DateFormat('dd MMM').format(startDateTime);
    final timeStr = _formatTime(startDateTime);
    await NotificationService(firestore: _db).sendLectureNotificationToClass(
      classId: classId,
      lectureId: lectureRef.id,
      title: 'New Lecture Scheduled',
      body: '$subject with $teacherName on $dateStr at $timeStr',
      type: 'lecture_scheduled',
    );

    return lectureRef.id;
  }

  /// Updates lecture parameters if not attendance-locked.
  Future<void> updateLecture({
    required String lectureId,
    required String classId,
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    required String room,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String updatedBy,
    int attendanceWindow = 15,
  }) async {
    final docRef = _db.collection('lectures').doc(lectureId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) throw StateError('Lecture not found.');

    final existing = Lecture.fromSnapshot(docSnap);

    // Enforce attendance lock
    if (existing.isLockedForEditing) {
      throw StateError(
        'This lecture schedule is locked because attendance has already been submitted '
        'or it is marked as completed/archived.',
      );
    }

    // Perform Conflict Check if timing, teacher, or class changed
    if (existing.startDateTime != startDateTime ||
        existing.endDateTime != endDateTime ||
        existing.teacherId != teacherId ||
        existing.classId != classId) {
      await validateLectureConflict(
        classId: classId,
        teacherId: teacherId,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        excludedLectureId: lectureId,
      );
    }

    final duration = endDateTime.difference(startDateTime).inMinutes;

    await docRef.update({
      'classId': classId,
      'className': className,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'room': room,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'durationMinutes': duration > 0 ? duration : 60,
      'attendanceWindow': attendanceWindow,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditService(firestore: _db).log(
      userId: updatedBy,
      action: 'Updated lecture ${existing.lectureCode}',
      module: 'Lecture',
      entityId: lectureId,
    );

    // Notify class students & teacher of reschedule
    final dateStr = DateFormat('dd MMM').format(startDateTime);
    final timeStr = _formatTime(startDateTime);
    await NotificationService(firestore: _db).sendLectureNotificationToClass(
      classId: classId,
      lectureId: lectureId,
      title: 'Lecture Rescheduled',
      body: '$subject with $teacherName rescheduled to $dateStr at $timeStr',
      type: 'lecture_updated',
    );
    await _notifyUsers(
      [teacherId],
      'Lecture Rescheduled',
      'Your lecture for $subject ($className) has been rescheduled to $dateStr at $timeStr.',
      lectureId,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Cancellation Workflow
  // ────────────────────────────────────────────────────────────────────────────

  /// Teacher requests cancellation with a reason
  Future<void> requestCancellation({
    required String lectureId,
    required String teacherUid,
    required String reason,
  }) async {
    final docRef = _db.collection('lectures').doc(lectureId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) throw StateError('Lecture not found.');

    final lecture = Lecture.fromSnapshot(docSnap);
    if (lecture.teacherId != teacherUid) {
      throw StateError('You can only request cancellation for your own lectures.');
    }

    await docRef.update({
      'status': 'cancel_pending',
      'cancellationReason': reason.trim(),
      'cancelledBy': teacherUid,
      'cancellationRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditService(firestore: _db).log(
      userId: teacherUid,
      action: 'Requested cancellation for lecture ${lecture.lectureCode}',
      module: 'Lecture',
      entityId: lectureId,
    );
  }

  /// Owner / Manager approves cancellation request
  Future<void> approveCancellation({
    required String lectureId,
    required String ownerUid,
  }) async {
    final docRef = _db.collection('lectures').doc(lectureId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) throw StateError('Lecture not found.');

    final lecture = Lecture.fromSnapshot(docSnap);

    await docRef.update({
      'status': 'cancelled',
      'approvedBy': ownerUid,
      'cancellationApprovedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await AuditService(firestore: _db).log(
        userId: ownerUid,
        action: 'Approved cancellation for lecture ${lecture.lectureCode}',
        module: 'Lecture',
        entityId: lectureId,
      );

      // Notify assigned teacher
      await _notifyUsers(
        [lecture.teacherId],
        'Cancellation Approved',
        'Your cancellation request for ${lecture.subject} (${lecture.className}) was approved.',
        lectureId,
      );

      // Notify class students
      final dateStr = DateFormat('dd MMM').format(lecture.startDateTime);
      final timeStr = _formatTime(lecture.startDateTime);
      await NotificationService(firestore: _db).sendLectureNotificationToClass(
        classId: lecture.classId,
        lectureId: lectureId,
        title: 'Lecture Cancelled',
        body: '${lecture.subject} on $dateStr at $timeStr has been cancelled',
        type: 'lecture_cancelled',
      );
    } catch (e) {
      debugPrint('Secondary notifications failed during cancellation approval: $e');
    }
  }

  /// Owner / Manager rejects cancellation request
  Future<void> rejectCancellation({
    required String lectureId,
    required String ownerUid,
  }) async {
    final docRef = _db.collection('lectures').doc(lectureId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) throw StateError('Lecture not found.');

    final lecture = Lecture.fromSnapshot(docSnap);

    await docRef.update({
      'status': 'scheduled',
      'cancellationReason': null,
      'cancelledBy': null,
      'cancellationRequestedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditService(firestore: _db).log(
      userId: ownerUid,
      action: 'Rejected cancellation for lecture ${lecture.lectureCode}',
      module: 'Lecture',
      entityId: lectureId,
    );

    // Notify assigned teacher
    await _notifyUsers(
      [lecture.teacherId],
      'Cancellation Rejected',
      'Your cancellation request for ${lecture.subject} (${lecture.className}) was rejected.',
      lectureId,
    );
  }

  /// Archives a lecture (soft-delete)
  Future<void> archiveLecture(String lectureId, String uid) async {
    final docRef = _db.collection('lectures').doc(lectureId);
    await docRef.update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditService(firestore: _db).log(
      userId: uid,
      action: 'Archived lecture $lectureId',
      module: 'Lecture',
      entityId: lectureId,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Reactive Streams
  // ────────────────────────────────────────────────────────────────────────────

  /// All active/scheduled/cancelled/completed lectures for Owner/Manager
  Stream<List<Lecture>> allLecturesStream({bool includeArchived = false}) {
    return _db.collection('lectures').snapshots().map((snap) {
      final list = snap.docs.map((d) => Lecture.fromSnapshot(d)).toList();
      if (!includeArchived) {
        list.removeWhere((l) => l.status == 'archived');
      }
      list.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      return list;
    });
  }

  /// Stream of lectures for an assigned Teacher (excluding archived).
  /// Uses a Firestore-side where() so the security rule
  /// `resource.data.teacherId == request.auth.uid` is satisfied for list queries.
  Stream<List<Lecture>> teacherLecturesStream(String teacherUid) {
    return _db
        .collection('lectures')
        .where('teacherId', isEqualTo: teacherUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Lecture.fromSnapshot(d))
          .where((l) => l.status != 'archived')
          .toList();
      list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return list;
    });
  }

  /// Stream of lectures for a Student's class (excluding archived & cancelled).
  /// Uses a Firestore-side where() so the security rule
  /// `resource.data.classId == getUserData().get('classId', '')` is satisfied
  /// for list queries. Archived/cancelled filtering remains client-side.
  Stream<List<Lecture>> studentLecturesStream(String classId) {
    final cleanClassId = classId.trim();
    return _db
        .collection('lectures')
        .where('classId', isEqualTo: cleanClassId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Lecture.fromSnapshot(d))
          .where((l) => l.status != 'archived' && l.status != 'cancelled')
          .toList();
      list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return list;
    });
  }

  /// Stream of pending cancellation requests for Owner/Manager
  Stream<List<Lecture>> cancellationRequestsStream() {
    return _db.collection('lectures').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Lecture.fromSnapshot(d))
          .where((l) => l.status == 'cancel_pending')
          .toList();
      list.sort((a, b) =>
          (b.cancellationRequestedAt ?? b.startDateTime)
              .compareTo(a.cancellationRequestedAt ?? a.startDateTime));
      return list;
    });
  }

  /// Stream of lectures for a specific class (for legacy class chat compatibility)
  Stream<QuerySnapshot<Map<String, dynamic>>> classLectures(String classId) {
    return _db
        .collection('lectures')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  // Helper function for sending notifications
  Future<void> _notifyUsers(
    List<String> uids,
    String title,
    String message,
    String lectureId,
  ) async {
    final notificationService = NotificationService(firestore: _db);
    for (final uid in uids) {
      await notificationService.send(
        title: title,
        body: message,
        receiverId: uid,
        receiverRole: 'user',
        type: 'lecture',
        referenceId: lectureId,
      );
    }
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
