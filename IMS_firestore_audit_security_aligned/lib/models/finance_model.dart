import 'package:cloud_firestore/cloud_firestore.dart';

/// Single fee payment entry stored inside StudentFee.paymentHistory
class FeePaymentEntry {
  final String receiptNo;
  final double amount;
  final String paymentMode; // 'Cash', 'UPI', 'Bank Transfer', 'Cheque'
  final String paymentStatus; // 'completed', 'pending', 'failed', 'refunded'
  final String recordedBy;
  final DateTime? timestamp;

  const FeePaymentEntry({
    required this.receiptNo,
    required this.amount,
    required this.paymentMode,
    this.paymentStatus = 'completed',
    required this.recordedBy,
    this.timestamp,
  });

  factory FeePaymentEntry.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FeePaymentEntry(
        receiptNo: '',
        amount: 0.0,
        paymentMode: 'Cash',
        recordedBy: '',
      );
    }
    return FeePaymentEntry(
      receiptNo: (map['receiptNo'] ?? '').toString(),
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      paymentMode: (map['paymentMode'] ?? 'Cash').toString(),
      paymentStatus: (map['paymentStatus'] ?? 'completed').toString(),
      recordedBy: (map['recordedBy'] ?? '').toString(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiptNo': receiptNo,
      'amount': amount,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'recordedBy': recordedBy,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// StudentFee Model — Document ID: `${studentId}`
class StudentFee {
  final String feeId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String classId;
  final String className;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final String status; // 'paid', 'partial', 'pending', 'overdue'
  final DateTime? dueDate;
  final List<FeePaymentEntry> paymentHistory;
  final DateTime? updatedAt;

  const StudentFee({
    required this.feeId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.classId,
    required this.className,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.status,
    this.dueDate,
    this.paymentHistory = const [],
    this.updatedAt,
  });

  factory StudentFee.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final total = (data['totalAmount'] as num? ?? 0.0).toDouble();
    final paid = (data['paidAmount'] as num? ?? 0.0).toDouble();
    double pending = (data['pendingAmount'] as num? ?? (total - paid)).toDouble();
    if (pending < 0) pending = 0;

    String computedStatus = (data['status'] ?? 'pending').toString().toLowerCase();
    if (pending <= 0 && total > 0) {
      computedStatus = 'paid';
    } else if (paid > 0 && pending > 0) {
      computedStatus = 'partial';
    }

    final historyList = (data['paymentHistory'] as List? ?? [])
        .map((item) => FeePaymentEntry.fromMap(item as Map<String, dynamic>?))
        .toList();

    return StudentFee(
      feeId: doc.id,
      studentId: (data['studentId'] ?? doc.id).toString(),
      studentName: (data['studentName'] ?? data['name'] ?? '').toString(),
      studentEmail: (data['studentEmail'] ?? data['email'] ?? '').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      totalAmount: total,
      paidAmount: paid,
      pendingAmount: pending,
      status: computedStatus,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      paymentHistory: historyList,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'classId': classId,
      'className': className,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'status': status,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'paymentHistory': paymentHistory.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isFullyPaid => status == 'paid' || pendingAmount <= 0;
}

/// FinanceTransaction Model — Saved to `/financial_transactions` collection
class FinanceTransaction {
  final String transactionId;
  final String receiptNo;
  final String type; // 'teacher_payout', 'student_fee'
  final String partyId; // teacherId or studentId
  final String partyName;
  final String partyRole; // 'teacher', 'student'
  final String? classId;
  final double amount;
  final String paymentMode; // 'Cash', 'UPI', 'Bank Transfer', 'Cheque'
  final String paymentStatus; // 'completed', 'pending', 'failed', 'refunded'
  final Map<String, dynamic>? metadata;
  final String createdBy;
  final DateTime? createdAt;

  const FinanceTransaction({
    required this.transactionId,
    required this.receiptNo,
    required this.type,
    required this.partyId,
    required this.partyName,
    required this.partyRole,
    this.classId,
    required this.amount,
    required this.paymentMode,
    this.paymentStatus = 'completed',
    this.metadata,
    required this.createdBy,
    this.createdAt,
  });

  factory FinanceTransaction.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FinanceTransaction(
      transactionId: doc.id,
      receiptNo: (data['receiptNo'] ?? 'RCP-${doc.id.substring(0, 6)}').toString(),
      type: (data['type'] ?? 'student_fee').toString(),
      partyId: (data['partyId'] ?? data['teacherId'] ?? data['studentId'] ?? '').toString(),
      partyName: (data['partyName'] ?? data['teacherName'] ?? data['studentName'] ?? '').toString(),
      partyRole: (data['partyRole'] ?? '').toString(),
      classId: data['classId'] as String?,
      amount: (data['amount'] as num? ?? 0.0).toDouble(),
      paymentMode: (data['paymentMode'] ?? 'Cash').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'completed').toString(),
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiptNo': receiptNo,
      'type': type,
      'partyId': partyId,
      'partyName': partyName,
      'partyRole': partyRole,
      'classId': classId,
      'amount': amount,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'metadata': metadata,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
