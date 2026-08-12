import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finance_model.dart';
import 'audit_service.dart';

/// Production-Ready Financial & Payroll Service
class FinanceService {
  FinanceService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // Receipt Code Generator
  // ────────────────────────────────────────────────────────────────────────────

  Future<String> generateReceiptNo() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = 'RCP-$dateStr';

    final countSnap = await _db
        .collection('financial_transactions')
        .where('receiptNo', isGreaterThanOrEqualTo: prefix)
        .where('receiptNo', isLessThan: '$prefix-z')
        .get();

    final nextNum = countSnap.docs.length + 1;
    return '$prefix-${nextNum.toString().padLeft(3, '0')}';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Teacher Payroll Payout Transaction
  // ────────────────────────────────────────────────────────────────────────────

  /// Atomically processes payout for a teacher:
  ///   1. Decrements `unpaid_lectures` in `/users` and `unpaidLectures` in `/payroll`
  ///   2. Recalculates `pendingSalary`
  ///   3. Generates receipt number and creates `/financial_transactions` entry
  Future<void> payTeacher({
    required String teacherId,
    required String teacherName,
    required int unpaidLectures,
    required num ratePerLecture,
    required String paymentMode,
    String? recordedBy,
  }) async {
    if (unpaidLectures <= 0) {
      throw ArgumentError('Lectures count to pay must be greater than 0.');
    }

    final amount = unpaidLectures * ratePerLecture;
    final receiptNo = await generateReceiptNo();
    final currentAdminUid = recordedBy ?? 'system_admin';

    final userRef = _db.collection('users').doc(teacherId);
    final payrollRef = _db.collection('payroll').doc(teacherId);
    final txnRef = _db.collection('financial_transactions').doc();
    final payoutRef = _db.collection('payouts').doc();

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final payrollSnap = await transaction.get(payrollRef);

      final currentUnpaidUser =
          (userSnap.data()?['unpaid_lectures'] as num? ?? unpaidLectures).toInt();
      final currentUnpaidPayroll =
          (payrollSnap.data()?['unpaidLectures'] as num? ?? unpaidLectures).toInt();

      final newUnpaidUser =
          (currentUnpaidUser - unpaidLectures) < 0 ? 0 : (currentUnpaidUser - unpaidLectures);
      final newUnpaidPayroll =
          (currentUnpaidPayroll - unpaidLectures) < 0 ? 0 : (currentUnpaidPayroll - unpaidLectures);

      final newPendingSalary = newUnpaidPayroll * ratePerLecture;

      // Update User unpaid lectures
      transaction.update(userRef, {
        'unpaid_lectures': newUnpaidUser,
      });

      // Update Payroll doc
      transaction.set(payrollRef, {
        'teacherId': teacherId,
        'perLecture': ratePerLecture,
        'unpaidLectures': newUnpaidPayroll,
        'pendingSalary': newPendingSalary,
        'lastPaidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Record Financial Transaction
      transaction.set(txnRef, {
        'receiptNo': receiptNo,
        'type': 'teacher_payout',
        'partyId': teacherId,
        'partyName': teacherName,
        'partyRole': 'teacher',
        'amount': amount,
        'paymentMode': paymentMode,
        'paymentStatus': 'completed',
        'metadata': {
          'lecturesPaid': unpaidLectures,
          'ratePerLecture': ratePerLecture,
        },
        'createdBy': currentAdminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write legacy payouts doc for backwards compatibility
      transaction.set(payoutRef, {
        'teacherId': teacherId,
        'teacherName': teacherName,
        'amount': amount,
        'receiptNo': receiptNo,
        'lecturesPaid': unpaidLectures,
        'paymentMode': paymentMode,
        'status': 'paid',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    await AuditService(firestore: _db).log(
      userId: currentAdminUid,
      action: 'Processed teacher payout $receiptNo for $teacherName',
      module: 'Payroll',
      entityId: teacherId,
      metadata: {'amount': amount, 'receiptNo': receiptNo},
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Student Fee Collection Transaction
  // ────────────────────────────────────────────────────────────────────────────

  /// Atomically collects student fee payment:
  ///   1. Increments `paidAmount`, decrements `pendingAmount` in `/student_fees`
  ///   2. Flips status (`paid` if pending <= 0, else `partial`)
  ///   3. Appends payment entry to `paymentHistory`
  ///   4. Writes audit receipt to `/financial_transactions`
  Future<void> recordPayment({
    required String studentId,
    required String parentId,
    required double amount,
    required String mode,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than 0.');
    }

    final receiptNo = await generateReceiptNo();
    final studentFeeRef = _db.collection('student_fees').doc(studentId);
    final legacyFeeRef = _db.collection('fees').doc(studentId);
    final txnRef = _db.collection('financial_transactions').doc();
    final paymentRef = _db.collection('payments').doc();

    await _db.runTransaction((transaction) async {
      final studentFeeSnap = await transaction.get(studentFeeRef);
      final userSnap = await transaction.get(_db.collection('users').doc(studentId));
      final userData = userSnap.data() ?? {};
      final studentName = (userData['name'] ?? userData['email'] ?? 'Student').toString();

      double currentTotal = 12000.0;
      double currentPaid = 0.0;
      List history = [];
      String classId = (userData['classId'] ?? '').toString();

      if (studentFeeSnap.exists) {
        final data = studentFeeSnap.data() ?? {};
        currentTotal = (data['totalAmount'] as num? ?? 12000.0).toDouble();
        currentPaid = (data['paidAmount'] as num? ?? 0.0).toDouble();
        history = List.from(data['paymentHistory'] as List? ?? []);
        if (data.containsKey('classId')) classId = data['classId'].toString();
      }

      final newPaid = currentPaid + amount;
      final newPending = (currentTotal - newPaid) < 0 ? 0.0 : (currentTotal - newPaid);
      final newStatus = newPending <= 0 ? 'paid' : (newPaid > 0 ? 'partial' : 'pending');

      final paymentEntry = {
        'receiptNo': receiptNo,
        'amount': amount,
        'paymentMode': mode,
        'paymentStatus': 'completed',
        'recordedBy': parentId,
        'timestamp': Timestamp.now(),
      };
      history.add(paymentEntry);

      // Write student_fees
      transaction.set(studentFeeRef, {
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': (userData['email'] ?? '').toString(),
        'classId': classId,
        'totalAmount': currentTotal,
        'paidAmount': newPaid,
        'pendingAmount': newPending,
        'status': newStatus,
        'paymentHistory': history,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Write legacy fees doc
      transaction.set(legacyFeeRef, {
        'studentId': studentId,
        'totalFee': currentTotal,
        'paid': newPaid,
        'remaining': newPending,
        'status': newStatus,
        'lastPaymentDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Record Financial Transaction
      transaction.set(txnRef, {
        'receiptNo': receiptNo,
        'type': 'student_fee',
        'partyId': studentId,
        'partyName': studentName,
        'partyRole': 'student',
        'classId': classId,
        'amount': amount,
        'paymentMode': mode,
        'paymentStatus': 'completed',
        'createdBy': parentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Legacy payment doc
      transaction.set(paymentRef, {
        'studentId': studentId,
        'parentId': parentId,
        'amount': amount,
        'paymentDate': FieldValue.serverTimestamp(),
        'paymentMode': mode,
        'receiptNumber': receiptNo,
        'status': 'success',
      });
    });

    await AuditService(firestore: _db).log(
      userId: parentId,
      action: 'Recorded fee payment $receiptNo of \$${amount.toStringAsFixed(2)}',
      module: 'Fees',
      entityId: studentId,
      metadata: {'amount': amount, 'receiptNo': receiptNo},
    );
  }

  /// Sets or updates total fee structure for a student
  Future<void> createFeePlan({
    required String studentId,
    required String course,
    required String academicYear,
    required double totalFee,
    DateTime? nextDueDate,
  }) async {
    final userSnap = await _db.collection('users').doc(studentId).get();
    final userData = userSnap.data() ?? {};
    final studentName = (userData['name'] ?? userData['email'] ?? 'Student').toString();

    final batch = _db.batch();

    batch.set(_db.collection('student_fees').doc(studentId), {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': (userData['email'] ?? '').toString(),
      'classId': (userData['classId'] ?? '').toString(),
      'totalAmount': totalFee,
      'paidAmount': 0.0,
      'pendingAmount': totalFee,
      'status': 'pending',
      'dueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate) : null,
      'paymentHistory': [],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_db.collection('fees').doc(studentId), {
      'studentId': studentId,
      'course': course,
      'academicYear': academicYear,
      'totalFee': totalFee,
      'paid': 0.0,
      'remaining': totalFee,
      'status': 'pending',
      if (nextDueDate != null) 'nextDueDate': Timestamp.fromDate(nextDueDate),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Reactive Streams
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream of student fee document for a single student
  Stream<StudentFee?> studentFeeStream(String studentId) {
    return _db.collection('student_fees').doc(studentId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return StudentFee.fromSnapshot(doc);
    });
  }

  /// Stream of all student fee documents for Owner/Manager
  Stream<List<StudentFee>> allStudentFeesStream() {
    return _db.collection('student_fees').snapshots().map((snap) {
      return snap.docs.map((d) => StudentFee.fromSnapshot(d)).toList();
    });
  }

  /// Stream of financial transactions
  Stream<List<FinanceTransaction>> allTransactionsStream() {
    return _db.collection('financial_transactions').snapshots().map((snap) {
      final list =
          snap.docs.map((d) => FinanceTransaction.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}
