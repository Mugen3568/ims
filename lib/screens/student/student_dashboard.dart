import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/lecture_model.dart';
import '../../services/lecture_service.dart';
import '../finance/fees_screen.dart'; // ✅ Correct path
import '../../widgets/pending_parent_approval_widget.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

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
                        'Student Portal',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back, ${user?.email?.split('@').first ?? 'Student'}',
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
                          : 'S',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // --- PARENT APPROVAL REQUESTS ---
              if (user != null)
                PendingParentApprovalWidget(studentUid: user.uid),
              const SizedBox(height: 28),

              // --- DYNAMIC ATTENDANCE METRIC ---
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('student_attendance')
                    .where('studentId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String attendanceRate = 'No Data';
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    var docs = snapshot.data!.docs;
                    int totalConducted = docs.length;
                    int attended = docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      var st = (data['status'] ?? '').toString();
                      return st == 'Present' || st == 'Late' || st == 'Excused';
                    }).length;
                    double percentage = totalConducted == 0
                        ? 0.0
                        : (attended / totalConducted) * 100;
                    attendanceRate = '${percentage.toStringAsFixed(0)}%';
                  } else {
                    attendanceRate = 'No Data';
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'My Attendance',
                          value: attendanceRate,
                          icon: Icons.check_circle_outline,
                          color: attendanceRate == 'No Data'
                              ? Colors.grey
                              : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notes')
                              .snapshots(),
                          builder: (context, notesSnapshot) {
                            int notesCount = notesSnapshot.hasData
                                ? notesSnapshot.data!.docs.length
                                : 0;
                            return _buildMetricCard(
                              context,
                              title: 'Study Materials',
                              value: '$notesCount Files',
                              icon: Icons.folder_open_outlined,
                              color: Colors.orange,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // --- FEES TILE ---
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: ListTile(
                  leading: Icon(
                    Icons.payment,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Fee Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'View your fee details and payment history',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeesScreen(
                          userRole: 'student',
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- TODAY'S CLASSES SECTION ---
              Text(
                "Scheduled Classes",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final classId = userData['classId'] as String? ?? '';

                  if (classId.isEmpty) {
                    return _buildEmptyStateCard(
                      context,
                      'No class assigned to your account.',
                    );
                  }

                  return StreamBuilder<List<Lecture>>(
                    stream: LectureService().studentLecturesStream(classId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildEmptyStateCard(
                          context,
                          'Error loading lectures: ${snapshot.error}',
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyStateCard(
                          context,
                          'No scheduled classes for your class ($classId).',
                        );
                      }

                      final limitedClasses = snapshot.data!.take(5).toList();

                      return ListView.builder(
                        itemCount: limitedClasses.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final lecture = limitedClasses[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.book,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lecture.subject,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Teacher: ${lecture.teacherName} • ${DateFormat('hh:mm a').format(lecture.startDateTime)}',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    lecture.status.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
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

  Widget _buildEmptyStateCard(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
