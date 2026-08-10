import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/status_constants.dart';
import 'notification_service.dart';

class ApprovalService {
  final FirebaseFirestore _db;
  final NotificationService _notificationService;

  ApprovalService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService(firestore: firestore);

  /// Approves a pending user (Parent, Teacher, Manager, or Owner)
  Future<void> approveUser({
    required String targetUid,
    required String targetRole,
    required String approvedByUid,
    required String approvedByRole,
    String targetName = 'User',
    String approverName = 'Admin',
  }) async {
    final batch = _db.batch();

    // 1. Fetch user & approver names if default placeholders provided
    if (targetName == 'User' || approverName == 'Admin') {
      try {
        final targetSnap = await _db.collection('users').doc(targetUid).get();
        final approverSnap = await _db.collection('users').doc(approvedByUid).get();
        if (targetSnap.exists) {
          targetName = targetSnap.data()?['name'] ?? targetName;
        }
        if (approverSnap.exists) {
          approverName = approverSnap.data()?['name'] ?? approverName;
        }
      } catch (_) {}
    }

    // 2. Update user profile (Strict User Contract)
    final userRef = _db.collection('users').doc(targetUid);
    batch.update(userRef, {
      'approvalStatus': ApprovalStatus.approved,
      'accountStatus': AccountStatus.active,
      'isVerified': true,
      'approvedBy': approvedByUid,
      'approvedByRole': approvedByRole,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });

    // 3. Approval Log Entry (Strict Approval Log Contract)
    final logRef = _db.collection('approval_logs').doc();
    batch.set(logRef, {
      'action': 'approved',
      'targetUid': targetUid,
      'targetRole': targetRole,
      'targetName': targetName,
      'approvedBy': approvedByUid,
      'approvedByRole': approvedByRole,
      'approverName': approverName,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': null,
    });

    // 4. Send notification via NotificationService
    String message = 'Your account has been approved and activated.';
    if (targetRole == 'parent') {
      message = 'Your child has approved your parent connection request.';
    } else if (targetRole == 'teacher') {
      message = 'Administration has approved your teacher account.';
    } else if (targetRole == 'manager' || targetRole == 'owner') {
      message = 'Administration has approved your $targetRole account.';
    }

    await _notificationService.sendApprovalNotification(
      receiverId: targetUid,
      title: 'Account Approved',
      body: message,
      targetRole: targetRole,
      batch: batch,
    );

    await batch.commit();
  }

  /// Rejects a pending user request
  Future<void> rejectUser({
    required String targetUid,
    required String targetRole,
    required String approvedByUid,
    required String approvedByRole,
    String targetName = 'User',
    String approverName = 'Admin',
    String? reason,
  }) async {
    final batch = _db.batch();

    if (targetName == 'User' || approverName == 'Admin') {
      try {
        final targetSnap = await _db.collection('users').doc(targetUid).get();
        final approverSnap = await _db.collection('users').doc(approvedByUid).get();
        if (targetSnap.exists) {
          targetName = targetSnap.data()?['name'] ?? targetName;
        }
        if (approverSnap.exists) {
          approverName = approverSnap.data()?['name'] ?? approverName;
        }
      } catch (_) {}
    }

    // 1. Update user profile
    final userRef = _db.collection('users').doc(targetUid);
    batch.update(userRef, {
      'approvalStatus': ApprovalStatus.rejected,
      'accountStatus': AccountStatus.rejected,
      'isVerified': false,
      'approvedBy': approvedByUid,
      'approvedByRole': approvedByRole,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });

    // 2. Audit log entry
    final logRef = _db.collection('approval_logs').doc();
    batch.set(logRef, {
      'action': 'rejected',
      'targetUid': targetUid,
      'targetRole': targetRole,
      'targetName': targetName,
      'approvedBy': approvedByUid,
      'approvedByRole': approvedByRole,
      'approverName': approverName,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': reason,
    });

    // 3. Send notification alert via NotificationService
    String bodyMessage = (reason != null && reason.isNotEmpty)
        ? 'Your request was rejected: $reason'
        : 'Your account request has been rejected.';

    await _notificationService.sendApprovalNotification(
      receiverId: targetUid,
      title: 'Account Request Rejected',
      body: bodyMessage,
      targetRole: targetRole,
      batch: batch,
    );

    await batch.commit();
  }

  /// Stream of pending parent requests linked to a specific student UID
  Stream<List<Map<String, dynamic>>> pendingParentsForStudent(String studentUid) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .where('approvalStatus', isEqualTo: ApprovalStatus.pending)
        .where('linkedStudentId', isEqualTo: studentUid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList());
  }

  /// Stream of pending staff requests (Teacher, Manager, Owner)
  Stream<List<Map<String, dynamic>>> pendingStaffRequests() {
    return _db
        .collection('users')
        .where('approvalStatus', isEqualTo: ApprovalStatus.pending)
        .where('role', whereIn: ['teacher', 'manager', 'owner'])
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList());
  }
}
