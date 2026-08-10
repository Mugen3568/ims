import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db;

  NotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection("notifications");

  /// Strict notification payload builder adhering to Notification Contract
  Map<String, dynamic> buildNotificationData({
    required String receiverId,
    required String title,
    required String body,
    required String type,
    String? senderId,
    String? referenceId,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'receiverId': receiverId,
      'to_user': receiverId, // legacy mapping support for rules query
      'senderId': senderId ?? 'system',
      'title': title,
      'body': body,
      'message': body, // legacy mapping support
      'type': type,
      'referenceId': referenceId ?? '',
      'isRead': false,
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  Future<void> send({
    required String title,
    required String body,
    required String receiverId,
    required String receiverRole,
    required String type,
    required String referenceId,
    String? senderId,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = buildNotificationData(
      receiverId: receiverId,
      title: title,
      body: body,
      type: type,
      senderId: senderId,
      referenceId: referenceId,
      metadata: metadata,
    );
    payload['receiverRole'] = receiverRole;
    await _notifications.add(payload);
  }

  Future<void> sendApprovalNotification({
    required String receiverId,
    required String title,
    required String body,
    required String targetRole,
    WriteBatch? batch,
  }) async {
    final docRef = _notifications.doc();
    final payload = buildNotificationData(
      receiverId: receiverId,
      title: title,
      body: body,
      type: 'approval',
      metadata: {'targetRole': targetRole},
    );
    if (batch != null) {
      batch.set(docRef, payload);
    } else {
      await docRef.set(payload);
    }
  }

  Future<void> sendLectureCancelled({
    required String receiverId,
    required String lectureTitle,
    required String reason,
    WriteBatch? batch,
  }) async {
    final docRef = _notifications.doc();
    final payload = buildNotificationData(
      receiverId: receiverId,
      title: 'Lecture Cancellation Request',
      body: 'Cancellation requested for lecture "$lectureTitle": $reason',
      type: 'lecture_cancelled',
      metadata: {'reason': reason},
    );
    if (batch != null) {
      batch.set(docRef, payload);
    } else {
      await docRef.set(payload);
    }
  }

  Future<void> sendFeeReceipt({
    required String receiverId,
    required String amount,
    required String feeType,
  }) async {
    await send(
      title: 'Fee Payment Received',
      body: 'Payment of $amount for $feeType has been recorded.',
      receiverId: receiverId,
      receiverRole: 'student',
      type: 'fee_receipt',
      referenceId: feeType,
    );
  }

  Future<void> sendPayroll({
    required String receiverId,
    required String amount,
    required String month,
  }) async {
    await send(
      title: 'Payroll Disbursed',
      body: 'Salary payout of $amount for $month has been credited.',
      receiverId: receiverId,
      receiverRole: 'teacher',
      type: 'payroll',
      referenceId: month,
    );
  }

  Future<void> sendAttendance({
    required String receiverId,
    required String date,
    required String status,
  }) async {
    await send(
      title: 'Attendance Marked',
      body: 'Attendance status for $date recorded as: $status.',
      receiverId: receiverId,
      receiverRole: 'student',
      type: 'attendance',
      referenceId: date,
    );
  }

  Future<void> notifyClass({
    required String classId,
    required String title,
    required String body,
    required String type,
    required String referenceId,
  }) async {
    final members = await _db
        .collection('classes')
        .doc(classId)
        .collection('members')
        .get();

    final batch = _db.batch();
    for (final member in members.docs) {
      final docRef = _notifications.doc();
      final payload = buildNotificationData(
        receiverId: member.id,
        title: title,
        body: body,
        type: type,
        referenceId: referenceId,
      );
      payload['receiverRole'] = member.data()['role'] ?? 'student';
      batch.set(docRef, payload);
    }
    await batch.commit();
  }

  /// Sends standardized lecture notifications (lecture_scheduled, lecture_cancelled, lecture_updated)
  /// to all students enrolled in the specified class.
  Future<void> sendLectureNotificationToClass({
    required String classId,
    required String lectureId,
    required String title,
    required String body,
    required String type,
  }) async {
    final studentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: classId)
        .get();

    final batch = _db.batch();
    for (final doc in studentsSnap.docs) {
      final studentUid = doc.id;
      final notifRef = _notifications.doc();
      notifRef.set({
        'receiverId': studentUid,
        'to_user': studentUid,
        'title': title,
        'body': body,
        'message': body,
        'type': type,
        'lectureId': lectureId,
        'classId': classId,
        'referenceId': lectureId,
        'createdAt': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userNotifications(String userId) {
    return _notifications
        .where("receiverId", isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserNotifications(String userId) {
    return userNotifications(userId);
  }

  Stream<int> getUnreadCount(String userId) {
    return _notifications
        .where("receiverId", isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.where((doc) => doc.data()['isRead'] != true).length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({
      "isRead": true,
      "readAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _notifications
        .where("receiverId", isEqualTo: userId)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      if (doc.data()['isRead'] != true) {
        batch.update(doc.reference, {"isRead": true});
      }
    }
    await batch.commit();
  }
}
