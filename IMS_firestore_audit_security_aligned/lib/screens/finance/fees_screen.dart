import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/finance_model.dart';
import '../../services/finance_service.dart';

/// FeesScreen — Financial & Payroll Administration Portal for All Roles.
class FeesScreen extends StatefulWidget {
  final String userRole; // 'owner', 'manager', 'teacher', 'student', 'parent'

  const FeesScreen({super.key, required this.userRole});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FinanceService _financeService = FinanceService();

  bool get isOwnerOrManager =>
      widget.userRole == 'owner' || widget.userRole == 'manager';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: isOwnerOrManager ? 3 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isOwnerOrManager) {
      if (widget.userRole == 'teacher') {
        return const _TeacherPayrollPortal();
      }
      return const _StudentParentFeePortal();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll & Financial Hub'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0D47A1),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Teacher Payroll'),
            Tab(text: 'Student Fees'),
            Tab(text: 'Transaction Audit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeacherPayrollTab(),
          _buildStudentFeesTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  // ── 1. OWNER: TEACHER PAYROLL TAB ──────────────────────────────────────────
  Widget _buildTeacherPayrollTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final teachers = snapshot.data?.docs ?? [];

        if (teachers.isEmpty) {
          return Center(
            child: Text(
              'No teachers found in the directory.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            final doc = teachers[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? data['email'] ?? 'Teacher';
            final unpaidLectures = (data['unpaid_lectures'] as num? ?? 0).toInt();
            final rate = (data['rate_per_lecture'] as num? ?? 500.0).toDouble();
            final pendingSalary = unpaidLectures * rate;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: unpaidLectures > 0
                      ? Colors.orange.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: Color(0xFF0D47A1)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Unpaid Lectures: $unpaidLectures • Rate: \$${rate.toStringAsFixed(0)}/lec',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Pending: \$${pendingSalary.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: unpaidLectures > 0 ? Colors.orange[800] : Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: unpaidLectures > 0
                          ? () => _showProcessPayoutDialog(
                                teacherId: doc.id,
                                teacherName: name,
                                unpaidLectures: unpaidLectures,
                                ratePerLecture: rate,
                              )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                      ),
                      child: const Text('Pay Teacher'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProcessPayoutDialog({
    required String teacherId,
    required String teacherName,
    required int unpaidLectures,
    required double ratePerLecture,
  }) {
    final lecturesCtrl = TextEditingController(text: unpaidLectures.toString());
    String paymentMode = 'Bank Transfer';
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final countToPay = int.tryParse(lecturesCtrl.text.trim()) ?? 0;
          final totalAmount = countToPay * ratePerLecture;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.payments_rounded, color: Color(0xFF0D47A1)),
                const SizedBox(width: 10),
                Text(
                  'Process Payout',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher: $teacherName\nUnpaid Balance: $unpaidLectures lectures (\$${(unpaidLectures * ratePerLecture).toStringAsFixed(2)})',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: lecturesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lectures to Pay *',
                    hintText: 'e.g. 5',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: ['Bank Transfer', 'Cash', 'UPI', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payout Amount:',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 11),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (countToPay <= 0 || countToPay > unpaidLectures) {
                          setDialogState(() => errorText =
                              'Enter a valid lecture count between 1 and $unpaidLectures.');
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          await _financeService.payTeacher(
                            teacherId: teacherId,
                            teacherName: teacherName,
                            unpaidLectures: countToPay,
                            ratePerLecture: ratePerLecture,
                            paymentMode: paymentMode,
                            recordedBy: FirebaseAuth.instance.currentUser?.uid,
                          );

                          final messenger = ScaffoldMessenger.of(context);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Payout of \$${totalAmount.toStringAsFixed(2)} processed for $teacherName!',
                                ),
                                backgroundColor: Colors.green[700],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorText = e.toString();
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirm Payout'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 2. OWNER: STUDENT FEES TAB ─────────────────────────────────────────────
  Widget _buildStudentFeesTab() {
    return StreamBuilder<List<StudentFee>>(
      stream: _financeService.allStudentFeesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final fees = snapshot.data ?? [];

        if (fees.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No student fee structures created yet.',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: fees.length,
          itemBuilder: (context, index) {
            final fee = fees[index];
            Color statusColor = Colors.green;
            if (fee.status == 'partial') statusColor = Colors.orange;
            if (fee.status == 'pending') statusColor = Colors.red;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fee.studentName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Class: ${fee.className}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            fee.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: \$${fee.totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        Text(
                          'Paid: \$${fee.paidAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Pending: \$${fee.pendingAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: fee.isFullyPaid
                            ? null
                            : () => _showCollectFeeDialog(fee),
                        icon: const Icon(Icons.add_card_rounded, size: 16),
                        label: Text(fee.isFullyPaid ? 'Fee Fully Paid' : 'Collect Fee'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCollectFeeDialog(StudentFee fee) {
    final amountCtrl = TextEditingController(text: fee.pendingAmount.toString());
    String paymentMode = 'UPI';
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Collect Student Fee',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${fee.studentName}\nPending Balance: \$${fee.pendingAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount to Collect (\$)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: Icon(Icons.payment_rounded),
                ),
                items: ['UPI', 'Cash', 'Bank Transfer', 'Cheque']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => paymentMode = val);
                },
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 11),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amount <= 0 || amount > fee.pendingAmount) {
                        setDialogState(() => errorText =
                            'Enter a valid amount up to \$${fee.pendingAmount.toStringAsFixed(2)}.');
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await _financeService.recordPayment(
                          studentId: fee.studentId,
                          parentId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          amount: amount,
                          mode: paymentMode,
                        );

                        final messenger = ScaffoldMessenger.of(context);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Payment of \$${amount.toStringAsFixed(2)} recorded for ${fee.studentName}!',
                              ),
                              backgroundColor: Colors.green[700],
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorText = e.toString();
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. OWNER: TRANSACTIONS TAB ─────────────────────────────────────────────
  Widget _buildTransactionsTab() {
    return StreamBuilder<List<FinanceTransaction>>(
      stream: _financeService.allTransactionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txns = snapshot.data ?? [];

        if (txns.isEmpty) {
          return Center(
            child: Text(
              'No financial transactions recorded yet.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: txns.length,
          itemBuilder: (context, index) {
            final t = txns[index];
            final isPayout = t.type == 'teacher_payout';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isPayout ? Colors.orange : Colors.green)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    isPayout ? Icons.output_rounded : Icons.move_to_inbox_rounded,
                    color: isPayout ? Colors.orange[800] : Colors.green[800],
                    size: 20,
                  ),
                ),
                title: Text(
                  '${t.partyName} (${isPayout ? 'Teacher Payout' : 'Student Fee'})',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Receipt: ${t.receiptNo} • ${t.paymentMode}\n'
                  '${t.createdAt != null ? DateFormat('MMM d, yyyy • hh:mm a').format(t.createdAt!) : ''}',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                trailing: Text(
                  '${isPayout ? '-' : '+'}\$${t.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPayout ? Colors.orange[800] : Colors.green[800],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TEACHER PAYROLL PORTAL VIEW
// ────────────────────────────────────────────────────────────────────────────
class _TeacherPayrollPortal extends StatelessWidget {
  const _TeacherPayrollPortal();

  @override
  Widget build(BuildContext context) {
    final teacherId = FirebaseAuth.instance.currentUser?.uid;
    if (teacherId == null) {
      return const Center(child: Text('Please sign in again.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Payroll & Earnings')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final totalTaken = (userData['total_lectures_taken'] as num? ?? 0).toInt();
          final unpaid = (userData['unpaid_lectures'] as num? ?? 0).toInt();
          final rate = (userData['rate_per_lecture'] as num? ?? 500.0).toDouble();
          final pendingSalary = unpaid * rate;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        '\$${pendingSalary.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                      Text(
                        'Estimated Pending Earnings',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        title: Text('$totalTaken', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Lectures Taken'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        title: Text('$unpaid', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Unpaid Lectures'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// STUDENT & PARENT FEE PORTAL VIEW
// ────────────────────────────────────────────────────────────────────────────
class _StudentParentFeePortal extends StatelessWidget {
  const _StudentParentFeePortal();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please sign in.'));

    return Scaffold(
      appBar: AppBar(title: const Text('Fee Schedule & Receipts')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final targetStudentId = (userData['role'] == 'parent')
              ? (userData['linkedStudentId'] ?? user.uid).toString()
              : user.uid;

          return StreamBuilder<StudentFee?>(
            stream: FinanceService().studentFeeStream(targetStudentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final fee = snapshot.data;

              if (fee == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No fee schedule initialized for this student yet.',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              Color statusColor = Colors.green;
              if (fee.status == 'partial') statusColor = Colors.orange;
              if (fee.status == 'pending') statusColor = Colors.red;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: statusColor.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: statusColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            '\$${fee.pendingAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            'Pending Fee Balance (${fee.status.toUpperCase()})',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: ListTile(
                            title: Text('\$${fee.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Total Fee'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: ListTile(
                            title: Text('\$${fee.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Paid Fee'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Payment Receipt History',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (fee.paymentHistory.isEmpty)
                    Center(
                      child: Text(
                        'No payments recorded yet.',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ...fee.paymentHistory.map((p) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_rounded, color: Colors.green),
                          title: Text('Receipt: ${p.receiptNo}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle: Text('Mode: ${p.paymentMode}'),
                          trailing: Text(
                            '+\$${p.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
