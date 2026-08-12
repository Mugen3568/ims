import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/class_model.dart';

class ClassService {
  ClassService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final Random _random = Random.secure();

  // ────────────────────────────────────────────────────────────────────────────
  // Legacy SchoolClass methods — kept intact for backwards compatibility
  // (lectures, attendance, class chat all depend on these)
  // ────────────────────────────────────────────────────────────────────────────

  Future<String> createClass({
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    String description = '',
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final joinCode = _newJoinCode();
      final existing = await _db
          .collection('classes')
          .where('joinCode', isEqualTo: joinCode)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final classRef = _db.collection('classes').doc();
      final teacherMemberRef = classRef.collection('members').doc(teacherId);
      final batch = _db.batch();
      final inviteCode = generateInviteCode();
      batch.set(classRef, {
        'className': className,
        'name': className,
        'subject': subject,
        'course': className,
        'description': description,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'joinCode': joinCode,
        'inviteCode': inviteCode,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'memberCount': 1,
      });
      batch.set(teacherMemberRef, {
        'uid': teacherId,
        'name': teacherName,
        'role': 'teacher',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return classRef.id;
    }
    throw StateError('Unable to generate a unique class join code. Try again.');
  }

  Future<void> joinClass({
    required String joinCode,
    required String studentId,
    required String studentName,
  }) async {
    final matches = await _db
        .collection('classes')
        .where('joinCode', isEqualTo: joinCode.trim().toUpperCase())
        .limit(1)
        .get();
    if (matches.docs.isEmpty) throw StateError('That join code was not found.');
    final classRef = matches.docs.first.reference;
    final memberRef = classRef.collection('members').doc(studentId);

    await _db.runTransaction((transaction) async {
      final classSnapshot = await transaction.get(classRef);
      if (classSnapshot.data()?['isActive'] != true) {
        throw StateError('This class is not accepting new members.');
      }
      final memberSnapshot = await transaction.get(memberRef);
      if (memberSnapshot.exists) {
        throw StateError('You have already joined this class.');
      }
      transaction.set(memberRef, {
        'uid': studentId,
        'name': studentName,
        'role': 'student',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(classRef, {'memberCount': FieldValue.increment(1)});
    });
  }

  /// Adds a student directly to a class by class document ID (used for auto-joining upon invite code signup).
  Future<void> joinClassById({
    required String classId,
    required String studentId,
    required String studentName,
  }) async {
    final classRef = _db.collection('classes').doc(classId);
    final memberRef = classRef.collection('members').doc(studentId);
    final userRef = _db.collection('users').doc(studentId);

    await _db.runTransaction((transaction) async {
      final classSnapshot = await transaction.get(classRef);
      if (!classSnapshot.exists) return;
      if (classSnapshot.data()?['isActive'] != true) return;

      final memberSnapshot = await transaction.get(memberRef);
      if (!memberSnapshot.exists) {
        transaction.set(memberRef, {
          'uid': studentId,
          'name': studentName,
          'role': 'student',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(classRef, {'memberCount': FieldValue.increment(1)});
      }

      // Always guarantee user profile classId field is set for attendance calculation & class access
      transaction.set(userRef, {'classId': classId}, SetOptions(merge: true));
    });
  }

  /// Atomically transfers a student from [oldClassId] to [newClassId].
  /// Removes student doc from old class members, decrements old memberCount,
  /// adds student doc to new class members, increments new memberCount,
  /// and updates users/{studentId}.classId.
  Future<void> transferStudentClass({
    required String studentId,
    required String studentName,
    required String? oldClassId,
    required String newClassId,
  }) async {
    final userRef = _db.collection('users').doc(studentId);
    final newClassRef = _db.collection('classes').doc(newClassId);
    final newMemberRef = newClassRef.collection('members').doc(studentId);

    DocumentReference? oldClassRef;
    DocumentReference? oldMemberRef;
    if (oldClassId != null &&
        oldClassId.isNotEmpty &&
        oldClassId != newClassId) {
      oldClassRef = _db.collection('classes').doc(oldClassId);
      oldMemberRef = oldClassRef.collection('members').doc(studentId);
    }

    await _db.runTransaction((transaction) async {
      // 1. Remove from old class if assigned
      if (oldClassRef != null && oldMemberRef != null) {
        final oldMemberSnap = await transaction.get(oldMemberRef);
        if (oldMemberSnap.exists) {
          transaction.delete(oldMemberRef);
          final oldClassSnap = await transaction.get(oldClassRef);
          if (oldClassSnap.exists) {
            final currentCount =
                (oldClassSnap.data() as Map<String, dynamic>?)?['memberCount']
                        as int? ??
                    1;
            final newCount = currentCount > 0 ? currentCount - 1 : 0;
            transaction.update(oldClassRef, {'memberCount': newCount});
          }
        }
      }

      // 2. Add to new class if not already member
      final newClassSnap = await transaction.get(newClassRef);
      if (newClassSnap.exists) {
        final newMemberSnap = await transaction.get(newMemberRef);
        if (!newMemberSnap.exists) {
          transaction.set(newMemberRef, {
            'uid': studentId,
            'name': studentName,
            'role': 'student',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(
            newClassRef,
            {'memberCount': FieldValue.increment(1)},
          );
        }
      }

      // 3. Update student user profile classId
      transaction.set(userRef, {'classId': newClassId}, SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> classes() =>
      _db.collection('classes').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> members(String classId) =>
      _db.collection('classes').doc(classId).collection('members').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String classId) =>
      _db
          .collection('classes')
          .doc(classId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();

  Future<void> sendMessage({
    required String classId,
    required String senderId,
    required String senderName,
    required String message,
    String role = 'member',
  }) =>
      _db
          .collection('classes')
          .doc(classId)
          .collection('messages')
          .add({
            'senderId': senderId,
            'senderName': senderName,
            'role': role,
            'text': message.trim(),
            'message': message.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'text',
            'edited': false,
          });

  String _newJoinCode() => List.generate(
    6,
    (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
  ).join();

  // ────────────────────────────────────────────────────────────────────────────
  // CourseClass methods — IMS class management (Owner/Manager CRUD)
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream of all classes — for Owner/Manager admin panel.
  Stream<List<CourseClass>> allCourseClasses() {
    return _db
        .collection('classes')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => CourseClass.fromSnapshot(d))
                  .toList(),
        );
  }

  /// Stream of **active** classes only — used in signup dropdowns.
  Stream<List<CourseClass>> activeClasses() {
    return _db
        .collection('classes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => CourseClass.fromSnapshot(d))
                  .toList(),
        );
  }

  /// Generates a 12-character cryptographically secure invite code.
  String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      12,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Finds an active course class by its invite code (or legacy joinCode).
  Future<CourseClass?> findByInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    var result = await _db
        .collection('classes')
        .where('inviteCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    // Fallback: Check legacy joinCode for backwards compatibility with legacy classes
    if (result.docs.isEmpty) {
      result = await _db
          .collection('classes')
          .where('joinCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
    }

    if (result.docs.isEmpty) return null;

    final doc = result.docs.first;
    if (doc.data()['isActive'] != true) return null;

    return CourseClass.fromSnapshot(doc);
  }

  /// Regenerates and saves a new invite code for a class, invalidating the old one.
  Future<String> regenerateInviteCode(String classId, {String? resetByUid}) async {
    final newInvite = generateInviteCode();
    final updateData = <String, dynamic>{
      'inviteCode': newInvite,
      'inviteCodeLastResetAt': FieldValue.serverTimestamp(),
      'inviteCodeVersion': FieldValue.increment(1),
    };
    if (resetByUid != null) {
      updateData['inviteCodeResetBy'] = resetByUid;
    }
    await _db.collection('classes').doc(classId).update(updateData);
    return newInvite;
  }

  /// Creates a course-class with a deterministic ID (e.g. "BCA_Sem3_A").
  /// Throws [StateError] if a class with the same ID already exists.
  Future<String> createCourseClass({
    required String course,
    required int semester,
    required String section,
    required String createdByUid,
  }) async {
    final docId = CourseClass.generateId(course, semester, section);
    final ref = _db.collection('classes').doc(docId);

    final existing = await ref.get();
    if (existing.exists) {
      throw StateError(
        'A class "$docId" already exists. '
        'Please use a different course, semester, or section.',
      );
    }

    final inviteCode = generateInviteCode();
    final className = '$course – Sem $semester – $section';
    await ref.set({
      'className': className,
      'name': className,
      'course': course.trim(),
      'subject': course.trim(),
      'semester': semester,
      'section': section.trim(),
      'createdBy': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'inviteCode': inviteCode,
      'inviteCodeCreatedAt': FieldValue.serverTimestamp(),
      'inviteCodeCreatedBy': createdByUid,
      'inviteCodeVersion': 1,
      'teacherIds': [],          // reverse index: populated when teachers are assigned
    });

    return docId;
  }

  /// Updates the `isActive` flag for a class.
  Future<void> toggleClassActive(String classId, bool isActive) async {
    await _db.collection('classes').doc(classId).update({
      'isActive': isActive,
    });
  }

  /// Deletes a course-class document permanently.
  Future<void> deleteCourseClass(String classId) async {
    await _db.collection('classes').doc(classId).delete();
  }

  /// Fetches a single CourseClass by ID.
  Future<CourseClass?> getCourseClass(String classId) async {
    final doc = await _db.collection('classes').doc(classId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || !data.containsKey('course')) return null;
    return CourseClass.fromSnapshot(doc);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Reverse-index: keep class.teacherIds in sync with teacher.assignedClasses
  // ────────────────────────────────────────────────────────────────────────────

  /// Atomically updates the `teacherIds` array on every affected class document
  /// when a teacher's assigned classes change.
  ///
  /// - Removes [teacherUid] from classes in [removedClassIds]
  /// - Adds    [teacherUid] to classes in [addedClassIds]
  ///
  /// Safe to call with empty lists on either side.
  Future<void> syncTeacherToClasses({
    required String teacherUid,
    required List<String> removedClassIds,
    required List<String> addedClassIds,
  }) async {
    if (removedClassIds.isEmpty && addedClassIds.isEmpty) return;

    final batch = _db.batch();

    for (final classId in removedClassIds) {
      batch.set(
        _db.collection('classes').doc(classId),
        {'teacherIds': FieldValue.arrayRemove([teacherUid])},
        SetOptions(merge: true),
      );
    }

    for (final classId in addedClassIds) {
      batch.set(
        _db.collection('classes').doc(classId),
        {'teacherIds': FieldValue.arrayUnion([teacherUid])},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Convenience: add a teacher to multiple class teacherIds at once.
  /// Used during initial registration where the teacher has no prior classes.
  /// Convenience: add a teacher to multiple class teacherIds at once.
  /// Used during initial registration where the teacher has no prior classes.
  Future<void> addTeacherToClasses({
    required String teacherUid,
    required List<String> classIds,
  }) =>
      syncTeacherToClasses(
        teacherUid: teacherUid,
        removedClassIds: const [],
        addedClassIds: classIds,
      );

  /// Unified stream of authorized active [CourseClass] documents for any role.
  /// - Admin / Owner / Manager: Streams all active classes.
  /// - Teacher: Resolves assignedClasses array from user profile via document query/snapshots.
  /// - Student: Resolves single classId from user profile.
  /// - Parent: Resolves linked student's classId.
  Stream<List<CourseClass>> streamClassesForUser({
    required String uid,
    required String role,
  }) {
    final cleanRole = role.toLowerCase().trim();

    if (cleanRole == 'owner' ||
        cleanRole == 'manager' ||
        cleanRole == 'super_admin' ||
        cleanRole == 'admin') {
      return activeClasses();
    }

    if (uid.isEmpty) return Stream.value([]);

    return _db.collection('users').doc(uid).snapshots().asyncExpand((userSnap) async* {
      if (!userSnap.exists) {
        yield <CourseClass>[];
        return;
      }

      final userData = userSnap.data() ?? {};

      if (cleanRole == 'teacher') {
        List<String> assignedClasses = [];
        if (userData['assignedClasses'] is List) {
          assignedClasses = List<String>.from(
            (userData['assignedClasses'] as List).map((e) => e.toString()),
          );
        }

        if (assignedClasses.isNotEmpty) {
          yield* _streamClassesByIds(assignedClasses);
        } else {
          // Fallback: Check teacherIds array
          yield* _db
              .collection('classes')
              .where('teacherIds', arrayContains: uid)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map((d) => CourseClass.fromSnapshot(d))
                    .where((c) => c.isActive)
                    .toList(),
              );
        }
      } else if (cleanRole == 'student') {
        final classId = userData['classId'] as String?;
        if (classId != null && classId.trim().isNotEmpty) {
          yield* _streamClassesByIds([classId.trim()]);
        } else {
          yield <CourseClass>[];
        }
      } else if (cleanRole == 'parent') {
        final linkedStudentId = userData['linkedStudentId'] as String?;
        final ownClassId = userData['classId'] as String?;

        if (linkedStudentId != null && linkedStudentId.trim().isNotEmpty) {
          final studentDoc = await _db.collection('users').doc(linkedStudentId).get();
          final studentClassId = studentDoc.data()?['classId'] as String?;
          if (studentClassId != null && studentClassId.trim().isNotEmpty) {
            yield* _streamClassesByIds([studentClassId.trim()]);
          } else {
            yield <CourseClass>[];
          }
        } else if (ownClassId != null && ownClassId.trim().isNotEmpty) {
          yield* _streamClassesByIds([ownClassId.trim()]);
        } else {
          yield <CourseClass>[];
        }
      } else {
        yield <CourseClass>[];
      }
    });
  }

  Stream<List<CourseClass>> _streamClassesByIds(List<String> classIds) {
    if (classIds.isEmpty) return Stream.value([]);

    if (classIds.length == 1) {
      return _db
          .collection('classes')
          .doc(classIds.first)
          .snapshots()
          .map((docSnap) {
            if (!docSnap.exists) return <CourseClass>[];
            final courseClass = CourseClass.fromSnapshot(docSnap);
            return courseClass.isActive ? [courseClass] : <CourseClass>[];
          });
    }

    if (classIds.length <= 30) {
      return _db
          .collection('classes')
          .where(FieldPath.documentId, whereIn: classIds)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => CourseClass.fromSnapshot(d))
                .where((c) => c.isActive)
                .toList(),
          );
    }

    return Stream.value([]);
  }
}
