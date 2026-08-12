import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeesScreen extends StatelessWidget {
  final String userRole; // 'manager', 'teacher', 'parent', 'student'
  final String userId;

  const FeesScreen({super.key, required this.userRole, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userRole == 'manager') {
      return _ManagerFeesView(userId: userId);
    } else if (userRole == 'parent' || userRole == 'student') {
      return _StudentFeesView(userId: userId, userRole: userRole);
    } else {
      return const Scaffold(
        body: Center(child: Text('Fees module not available for teachers')),
      );
    }
  }
}

// Manager View - See all student fees
class _ManagerFeesView extends StatelessWidget {
  final String userId;

  const _ManagerFeesView({required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Fees Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fees')
            .orderBy('student_name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No fee records found'));
          }

          final feeRecords = snapshot.data!.docs;

          return ListView.builder(
            itemCount: feeRecords.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final record = feeRecords[index];
              final data = record.data() as Map<String, dynamic>;

              String studentName = data['student_name'] ?? 'Unknown';
              double totalFees = (data['total_fees'] ?? 0).toDouble();
              double paidAmount = (data['paid_amount'] ?? 0).toDouble();
              double dueAmount = totalFees - paidAmount;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: dueAmount > 0
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    child: Icon(
                      dueAmount > 0 ? Icons.warning : Icons.check_circle,
                      color: dueAmount > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Total: ₹${totalFees.toStringAsFixed(0)}'),
                      Text('Paid: ₹${paidAmount.toStringAsFixed(0)}'),
                      Text(
                        'Due: ₹${dueAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: dueAmount > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle),
                    color: theme.colorScheme.primary,
                    tooltip: 'Add Payment',
                    onPressed: () => _showAddPaymentDialog(
                      context,
                      record.id,
                      studentName,
                      dueAmount,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudentFeeDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
    );
  }

  void _showAddStudentFeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final totalFeesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student Fee Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Student Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalFeesController,
              decoration: const InputDecoration(
                labelText: 'Total Fees (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  totalFeesController.text.trim().isEmpty) {
                return;
              }

              await FirebaseFirestore.instance.collection('fees').add({
                'student_name': nameController.text.trim(),
                'total_fees': double.tryParse(totalFeesController.text) ?? 0,
                'paid_amount': 0,
                'created_at': FieldValue.serverTimestamp(),
                'last_updated': DateTime.now().toIso8601String().split('T')[0],
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Student fee record created')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(
    BuildContext context,
    String recordId,
    String studentName,
    double dueAmount,
  ) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Payment - $studentName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Due Amount: ₹${dueAmount.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final payment = double.tryParse(amountController.text) ?? 0;

              if (payment <= 0 || payment > dueAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid payment amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await FirebaseFirestore.instance
                  .collection('fees')
                  .doc(recordId)
                  .update({
                    'paid_amount': FieldValue.increment(payment),
                    'last_payment_date': FieldValue.serverTimestamp(),
                    'last_updated': DateTime.now().toIso8601String().split(
                      'T',
                    )[0],
                  });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment recorded successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Add Payment'),
          ),
        ],
      ),
    );
  }
}

// Student/Parent View - See own fees
class _StudentFeesView extends StatelessWidget {
  final String userId;
  final String userRole;

  const _StudentFeesView({required this.userId, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Fee Status')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          final studentName = userData?['name'] ?? 'Student';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fees')
                .where('student_name', isEqualTo: studentName)
                .limit(1)
                .snapshots(),
            builder: (context, feeSnapshot) {
              if (feeSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!feeSnapshot.hasData || feeSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No fee record found'));
              }

              final feeData =
                  feeSnapshot.data!.docs.first.data() as Map<String, dynamic>;

              double totalFees = (feeData['total_fees'] ?? 0).toDouble();
              double paidAmount = (feeData['paid_amount'] ?? 0).toDouble();
              double dueAmount = totalFees - paidAmount;
              double paidPercentage = totalFees > 0
                  ? (paidAmount / totalFees) * 100
                  : 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Fee Summary Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Fee Summary',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _FeeRow(
                              'Total Fees:',
                              '₹${totalFees.toStringAsFixed(0)}',
                            ),
                            _FeeRow(
                              'Paid Amount:',
                              '₹${paidAmount.toStringAsFixed(0)}',
                              Colors.green,
                            ),
                            const Divider(height: 24),
                            _FeeRow(
                              'Due Amount:',
                              '₹${dueAmount.toStringAsFixed(0)}',
                              dueAmount > 0 ? Colors.red : Colors.green,
                              true,
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: paidPercentage / 100,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                paidPercentage == 100
                                    ? Colors.green
                                    : theme.colorScheme.primary,
                              ),
                              minHeight: 10,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${paidPercentage.toStringAsFixed(1)}% Paid',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Status Card
                    Card(
                      color: dueAmount > 0
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              dueAmount > 0
                                  ? Icons.warning
                                  : Icons.check_circle,
                              color: dueAmount > 0 ? Colors.red : Colors.green,
                              size: 40,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                dueAmount > 0
                                    ? 'Payment pending. Please contact administration.'
                                    : 'All fees paid! Thank you.',
                                style: TextStyle(
                                  color: dueAmount > 0
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLarge;

  const _FeeRow(
    this.label,
    this.value, [
    this.valueColor,
    this.isLarge = false,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isLarge
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyLarge,
          ),
          Text(
            value,
            style:
                (isLarge
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}
