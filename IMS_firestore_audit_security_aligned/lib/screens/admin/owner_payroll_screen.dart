import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/finance_service.dart';

class OwnerPayrollScreen extends StatelessWidget {
  const OwnerPayrollScreen({super.key});

  // Dialog for Owner to set/update rate per lecture
  void _showSetRateDialog(BuildContext context, String teacherId, String teacherName, int currentRate) {
    final rateController = TextEditingController(text: currentRate.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Rate for $teacherName'),
        content: TextField(
          controller: rateController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Rate Per Lecture (₹)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              int? newRate = int.tryParse(rateController.text.trim());
              if (newRate != null) {
                await FirebaseFirestore.instance.collection('users').doc(teacherId).update({
                  'rate_per_lecture': newRate,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }

  // Process payout and reset unpaid lecture counter
  Future<void> _processPayout(BuildContext context, String teacherId, String teacherName, int unpaidCount, int rate, double totalPay) async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Text('Process payment of ₹${totalPay.toStringAsFixed(0)} for $teacherName?\n\nThis will clear $unpaidCount unpaid lectures.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FinanceService().payTeacher(
      teacherId: teacherId,
      teacherName: teacherName,
      unpaidLectures: unpaidCount,
      ratePerLecture: rate,
      paymentMode: 'Bank transfer',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payout processed for $teacherName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Payroll Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No teachers found.'));
          }

          var teachers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              var doc = teachers[index];
              var data = doc.data() as Map<String, dynamic>;

              String name = data['name'] ?? 'Teacher';
              int unpaidLectures = data['unpaid_lectures'] ?? 0;
              int ratePerLecture = data['rate_per_lecture'] ?? 0;
              double calculatedPay = (unpaidLectures * ratePerLecture).toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                            onPressed: () => _showSetRateDialog(context, doc.id, name, ratePerLecture),
                            tooltip: 'Set Rate',
                          )
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lectures Pending Pay: $unpaidLectures', style: const TextStyle(fontSize: 14)),
                          Text('Rate: ₹$ratePerLecture / lec', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Calculated Pay', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('₹${calculatedPay.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary)),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: unpaidLectures > 0 ? theme.colorScheme.primary : Colors.grey,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: unpaidLectures > 0
                                ? () => _processPayout(context, doc.id, name, unpaidLectures, ratePerLecture, calculatedPay)
                                : null,
                            child: const Text('Process Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
