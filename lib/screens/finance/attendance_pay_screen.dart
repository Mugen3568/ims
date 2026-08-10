import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/attendance_pay_service.dart';

class AttendancePayScreen extends StatelessWidget {
  final String userRole; // 'manager', 'owner', 'teacher', 'parent', 'student'
  final String currentUserId;
  final String? currentInstituteId;

  const AttendancePayScreen({
    super.key,
    required this.userRole,
    required this.currentUserId,
    this.currentInstituteId,
  });

  @override
  Widget build(BuildContext context) {
    final AttendancePayService payService = AttendancePayService();
    final theme = Theme.of(context);

    // 1. Teacher View: Personal payroll dashboard
    if (userRole == 'teacher') {
      return Scaffold(
        appBar: AppBar(title: const Text('My Payroll')),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('User data not found.'));
            }

            var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            int totalLecturesTaken = data['total_lectures_taken'] ?? 0;
            int unpaidLectures = data['unpaid_lectures'] ?? 0;
            double baseRate = (data['rate_per_lecture'] ?? 0).toDouble();
            double pendingSalary = unpaidLectures * baseRate;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'My Payroll Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildPayrollRow(
                        'Completed Lectures',
                        '$totalLecturesTaken',
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildPayrollRow(
                        'Rate / Lecture',
                        '₹${baseRate.toStringAsFixed(0)}',
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildPayrollRow(
                        'Unpaid Lectures',
                        '$unpaidLectures',
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildPayrollRow(
                        'Pending Salary',
                        '₹${pendingSalary.toStringAsFixed(0)}',
                        theme,
                        isHighlight: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Calculated automatically upon lecture attendance submission.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // 2. Admin View: Manager and Owner payroll management
    if (userRole == 'manager' || userRole == 'owner') {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher');

      if (currentInstituteId != null && currentInstituteId!.isNotEmpty) {
        query = query.where('instituteId', isEqualTo: currentInstituteId);
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Teacher Payroll & Admin')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No teachers found.'));
            }

            var teachers = snapshot.data!.docs;

            return ListView.builder(
              itemCount: teachers.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                var teacher = teachers[index];
                var data = teacher.data();
                String name = data['name'] ?? 'Teacher';
                int totalLecturesTaken = data['total_lectures_taken'] ?? 0;
                int unpaidLectures = data['unpaid_lectures'] ?? 0;
                double baseRate = (data['rate_per_lecture'] ?? 0).toDouble();
                double pendingSalary = unpaidLectures * baseRate;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 20),
                        _buildAdminRow('Completed Lectures', '$totalLecturesTaken'),
                        const SizedBox(height: 6),
                        _buildAdminRow('Unpaid Lectures', '$unpaidLectures'),
                        const SizedBox(height: 6),
                        _buildAdminRow(
                          'Rate / Lecture',
                          '₹${baseRate.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pending Salary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${pendingSalary.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: unpaidLectures > 0
                                ? () async {
                                    await payService.resetTeacherPay(
                                      teacher.id,
                                      teacherName: name,
                                      unpaidLectures: unpaidLectures,
                                      ratePerLecture: baseRate,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Payout of ₹${pendingSalary.toStringAsFixed(0)} recorded for $name!',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Mark Paid'),
                          ),
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

    // 3. Fallback for unauthorized roles
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: const Center(
        child: Text('Payroll not available'),
      ),
    );
  }

  Widget _buildPayrollRow(
    String label,
    String value,
    ThemeData theme, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 22 : 16,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}
