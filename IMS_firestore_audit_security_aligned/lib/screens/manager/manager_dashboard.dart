import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../finance/fees_screen.dart';
import '../admin/manage_users.dart';
import '../admin/manage_classes_screen.dart';
import '../admin/owner_payroll_screen.dart';
import '../../core/smooth_route.dart';
import '../../widgets/role_diagnostic_widget.dart';
import '../../widgets/pending_staff_approval_widget.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- WELCOME HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manager Portal',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Administrative Overview',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (user?.email?.isNotEmpty == true)
                          ? user!.email![0].toUpperCase()
                          : 'M',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // --- STAFF APPROVAL REQUESTS ---
              const PendingStaffApprovalWidget(currentUserRole: 'manager'),

              // --- ROLE DIAGNOSTIC (TEMPORARY DEBUG WIDGET) ---
              const RoleDiagnosticWidget(),
              const SizedBox(height: 28),

              // --- REAL-TIME METRICS ---
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'student')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('Student count error: ${snapshot.error}');
                          return _buildMetricCard(
                            context,
                            title: 'Students',
                            value: 'Error',
                            icon: Icons.school_outlined,
                            color: Colors.red,
                          );
                        }
                        int count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return _buildMetricCard(
                          context,
                          title: 'Students',
                          value: '$count',
                          icon: Icons.school_outlined,
                          color: Colors.blue,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'teacher')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('Teacher count error: ${snapshot.error}');
                          return _buildMetricCard(
                            context,
                            title: 'Teachers',
                            value: 'Error',
                            icon: Icons.person_outline,
                            color: Colors.red,
                          );
                        }
                        int count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return _buildMetricCard(
                          context,
                          title: 'Teachers',
                          value: '$count',
                          icon: Icons.person_outline,
                          color: Colors.green,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('lectures')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('Lectures count error: ${snapshot.error}');
                          return _buildMetricCard(
                            context,
                            title: 'Class Lectures',
                            value: 'Error',
                            icon: Icons.class_outlined,
                            color: Colors.red,
                          );
                        }
                        int count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return _buildMetricCard(
                          context,
                          title: 'Class Lectures',
                          value: '$count',
                          icon: Icons.class_outlined,
                          color: Colors.orange,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'teacher')
                          .where('isVerified', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint(
                            'Pending teachers count error: ${snapshot.error}',
                          );
                          return _buildMetricCard(
                            context,
                            title: 'Pending',
                            value: 'Error',
                            icon: Icons.pending_outlined,
                            color: Colors.red,
                          );
                        }
                        int count = snapshot.hasData
                            ? snapshot.data!.docs.length
                            : 0;
                        return _buildMetricCard(
                          context,
                          title: 'Pending',
                          value: '$count',
                          icon: Icons.pending_outlined,
                          color: Colors.red,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // --- STAFF VERIFICATION SECTION ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'teacher')
                    .where('isVerified', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  var unverifiedTeachers = snapshot.data!.docs;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pending Staff Approvals',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...unverifiedTeachers.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String name = data['name'] ?? 'Unknown User';
                        String email = data['email'] ?? 'No email';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: Colors.orange,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(
                                Icons.person_outline,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(email),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                              ),
                              onPressed: () async {
                                // Approve the teacher
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(doc.id)
                                    .update({'isVerified': true});

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$name has been approved!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Approve'),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 28),
                    ],
                  );
                },
              ),

              // --- QUICK ACTIONS ---
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.manage_accounts,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Manage Users',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Approve or verify user accounts'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      SmoothPageRoute(child: const ManageUsersScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.class_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Manage Classes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Create, edit, and archive course classes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      SmoothPageRoute(child: const ManageClassesScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.account_balance_wallet,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Teacher Payroll',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Manage teacher salaries and payments'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OwnerPayrollScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.payment,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Fees Management',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('View and manage all student fees'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      SmoothPageRoute(child: FeesScreen(userRole: 'manager')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Schedule Lecture',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Add a new lecture to the schedule'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddLectureDialog(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class AddLectureDialog extends StatefulWidget {
  const AddLectureDialog({super.key});

  @override
  State<AddLectureDialog> createState() => _AddLectureDialogState();
}

class _AddLectureDialogState extends State<AddLectureDialog> {
  final _subjectController = TextEditingController();
  final _classIdController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _teacherId;
  bool _isLoading = false;

  Future<void> _createLecture() async {
    if (_subjectController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await FirebaseFirestore.instance.collection('lectures').add({
        'subject': _subjectController.text.trim(),
        'classId': _classIdController.text.trim(),
        'teacherId': _teacherId,
        'date': Timestamp.fromDate(DateUtils.dateOnly(combinedDateTime)),
        'startTime': Timestamp.fromDate(combinedDateTime),
        'endTime': Timestamp.fromDate(combinedDateTime.add(const Duration(hours: 1))),
        'scheduled_at': Timestamp.fromDate(combinedDateTime),
        'time': _selectedTime!.format(context),
        'status': 'scheduled',
        'created_by': FirebaseAuth.instance.currentUser?.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lecture scheduled successfully!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding lecture: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule New Lecture'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject / Lecture Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classIdController,
              decoration: const InputDecoration(
                labelText: 'Class Code (optional until classes are migrated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'teacher')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  initialValue: _teacherId,
                  decoration: const InputDecoration(
                    labelText: 'Assign teacher',
                    border: OutlineInputBorder(),
                  ),
                  items: snapshot.data!.docs.map((teacher) {
                    final data = teacher.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: teacher.id,
                      child: Text(data['name'] ?? data['email'] ?? 'Teacher'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _teacherId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() => _selectedTime = picked);
                }
              },
              icon: const Icon(Icons.access_time),
              label: Text(
                _selectedTime == null
                    ? 'Select Time'
                    : _selectedTime!.format(context),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createLecture,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Schedule'),
        ),
      ],
    );
  }
}
