import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ParentFeeDashboard extends StatelessWidget {
  const ParentFeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final parentId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Child Fees')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(parentId)
            .snapshots(),
        builder: (context, parent) {
          if (!parent.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final parentData = parent.data?.data() ?? {};

          // Primary branch: use linkedStudentId (set during registration)
          final childId =
              (parentData['linkedStudentId'] ?? '').toString().trim();
          if (childId.isNotEmpty) return _feeView(childId);

          // Fallback: resolve via student_lookup (allowed for all signed-in users).
          // Avoids the /users where email query that violates the security rule.
          final email =
              (parentData['childEmail'] ?? '').toString().toLowerCase().trim();
          if (email.isEmpty) {
            return const Center(
                child: Text('Link a child account to view fees.'));
          }

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('student_lookup')
                .doc(email)
                .get(),
            builder: (context, lookup) {
              if (!lookup.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final studentId =
                  (lookup.data?.data()?['studentId'] ?? '').toString().trim();
              if (studentId.isEmpty) {
                return const Center(child: Text('Linked student not found.'));
              }
              return _feeView(studentId);
            },
          );
        },
      ),
    );
  }

  Widget _feeView(String studentId) => StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('fees')
            .doc(studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('No fee plan has been set up.'));
          }
          final fee = snapshot.data!.data()!;
          final total = (fee['totalFee'] as num? ?? 0).toDouble();
          final paid = (fee['paid'] as num? ?? 0).toDouble();
          final remaining = (fee['remaining'] as num? ?? 0).toDouble();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Total ₹${total.toStringAsFixed(0)}'),
                      Text('Paid ₹${paid.toStringAsFixed(0)}'),
                      Text(
                        'Pending ₹${remaining.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Payment History',
                  style: Theme.of(context).textTheme.titleLarge),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('payments')
                    .where('studentId', isEqualTo: studentId)
                    .snapshots(),
                builder: (context, payments) {
                  if (!payments.hasData) {
                    return const CircularProgressIndicator();
                  }
                  if (payments.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No payments recorded.'),
                    );
                  }
                  return Column(
                    children: payments.data!.docs.map((payment) {
                      final data = payment.data();
                      return ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text('₹${data['amount']}'),
                        subtitle: Text(data['paymentMode'] ?? ''),
                        trailing: Text(data['receiptNumber'] ?? ''),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      );
}
