import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LinkedStudentProfileView extends StatelessWidget {
  const LinkedStudentProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<DocumentSnapshot>(
      // 1. Fetch the Parent's Document
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, parentSnapshot) {
        if (parentSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!parentSnapshot.hasData || !parentSnapshot.data!.exists) {
          return const Center(child: Text('Parent profile not found.'));
        }

        var parentData = parentSnapshot.data!.data() as Map<String, dynamic>;
        String childEmail = parentData['childEmail'] ?? '';

        if (childEmail.isEmpty) {
          return const Center(
            child: Text('No student linked to this account.'),
          );
        }

        // 2. Query the exact Student Document using the childEmail
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('email', isEqualTo: childEmail)
              .limit(1) // Ensure we only grab one record
              .snapshots(),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!studentSnapshot.hasData ||
                studentSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'Student account for $childEmail not found.\nThey may not have registered yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            }

            var studentData =
                studentSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            String studentName = studentData['name'] ?? 'Unknown Student';
            String studentContact =
                studentData['contact_number'] ?? 'No contact provided';

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked Student Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.surface,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              studentName.isNotEmpty
                                  ? studentName[0].toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                fontSize: 32,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            childEmail,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          ListTile(
                            leading: Icon(
                              Icons.phone,
                              color: theme.colorScheme.primary,
                            ),
                            title: const Text('Contact Number'),
                            subtitle: Text(studentContact),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            ),
                            title: const Text('Account Status'),
                            subtitle: Text(
                              (studentData['is_profile_complete'] ?? false)
                                  ? 'Active & Profile Complete'
                                  : 'Pending Profile Completion',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions for Parents
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Route to Attendance Module with studentId
                            Navigator.pushNamed(
                              context,
                              '/attendance',
                              arguments: {'childEmail': childEmail},
                            );
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Attendance'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Route to Fees Module with studentId
                            Navigator.pushNamed(
                              context,
                              '/fees',
                              arguments: {'childEmail': childEmail},
                            );
                          },
                          icon: const Icon(Icons.monetization_on, size: 18),
                          label: const Text('View Fees'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                            foregroundColor: theme.colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
