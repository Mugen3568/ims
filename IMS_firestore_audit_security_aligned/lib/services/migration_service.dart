import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/status_constants.dart';

class MigrationService {
  final FirebaseFirestore _db;

  MigrationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Runs all schema migrations if system schema version is less than target (v2)
  Future<void> runSchemaMigration({int targetVersion = 2}) async {
    try {
      final systemRef = _db.collection('settings').doc('system');
      final systemSnap = await systemRef.get();

      int currentVersion = 1;
      if (systemSnap.exists) {
        currentVersion = (systemSnap.data()?['schemaVersion'] as int?) ?? 1;
      }

      if (currentVersion >= targetVersion) {
        debugPrint('MigrationService: Schema version is up to date (v$currentVersion). Skipping migration.');
        return;
      }

      debugPrint('MigrationService: Migrating schema from v$currentVersion to v$targetVersion...');

      await migrateApprovalSchema();
      await migrateTeacherIds();
      await migrateNotifications();

      await systemRef.set({
        'schemaVersion': targetVersion,
        'migrationCompleted': true,
        'migratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('MigrationService: Migration to v$targetVersion completed successfully.');
    } catch (e) {
      debugPrint('MigrationService error: $e');
    }
  }

  /// Populates approvalStatus and accountStatus for legacy users missing these fields
  Future<void> migrateApprovalSchema() async {
    final usersSnap = await _db.collection('users').get();
    final batch = _db.batch();
    int count = 0;

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final hasApprovalStatus = data.containsKey('approvalStatus') && data['approvalStatus'] != null;
      final hasAccountStatus = data.containsKey('accountStatus') && data['accountStatus'] != null;

      if (!hasApprovalStatus || !hasAccountStatus) {
        final bool isVerified = data['isVerified'] == true;
        final String role = (data['role'] ?? 'student').toString().toLowerCase();

        String approvalStatus = ApprovalStatus.pending;
        String accountStatus = AccountStatus.pending;

        if (isVerified || role == 'student' || role == 'owner') {
          approvalStatus = ApprovalStatus.approved;
          accountStatus = AccountStatus.active;
        }

        batch.update(doc.reference, {
          'approvalStatus': approvalStatus,
          'accountStatus': accountStatus,
          'isVerified': approvalStatus == ApprovalStatus.approved,
          'updatedAt': FieldValue.serverTimestamp(),
          'created_at': data['createdAt'] ?? FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('MigrationService: Migrated $count user documents to new approval schema.');
    }
  }

  /// Standardizes teacher_id to teacherId in payouts collection
  Future<void> migrateTeacherIds() async {
    final payoutsSnap = await _db.collection('payouts').get();
    final batch = _db.batch();
    int count = 0;

    for (final doc in payoutsSnap.docs) {
      final data = doc.data();
      if (data.containsKey('teacher_id') && !data.containsKey('teacherId')) {
        batch.update(doc.reference, {
          'teacherId': data['teacher_id'],
        });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('MigrationService: Migrated $count payouts to standardized teacherId.');
    }
  }

  /// Copies legacy alerts documents into notifications collection
  Future<void> migrateNotifications() async {
    final alertsSnap = await _db.collection('alerts').get();
    if (alertsSnap.docs.isEmpty) return;

    final batch = _db.batch();
    int count = 0;

    for (final doc in alertsSnap.docs) {
      final data = doc.data();
      final targetUser = data['to_user'] ?? data['receiverId'];
      if (targetUser != null) {
        final notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'receiverId': targetUser,
          'to_user': targetUser,
          'senderId': 'system',
          'title': data['title'] ?? 'Notification',
          'body': data['message'] ?? data['body'] ?? '',
          'type': data['type'] ?? 'system',
          'isRead': data['isRead'] ?? false,
          'createdAt': data['created_at'] ?? FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('MigrationService: Migrated $count legacy alerts into notifications collection.');
    }
  }
}
