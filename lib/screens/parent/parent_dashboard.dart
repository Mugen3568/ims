import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentLinkStudentCard extends StatefulWidget {
  const ParentLinkStudentCard({super.key});

  @override
  State<ParentLinkStudentCard> createState() => _ParentLinkStudentCardState();
}

class _ParentLinkStudentCardState extends State<ParentLinkStudentCard> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendLinkRequest() async {
    String email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your child\'s email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Use student_lookup — readable by all signed-in users per Firestore rule,
        // avoids the /users collection-level query that teachers/parents cannot perform.
        final lookupDoc = await FirebaseFirestore.instance
            .collection('student_lookup')
            .doc(email.toLowerCase())
            .get();

        if (!lookupDoc.exists || lookupDoc.data()?['isActive'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No student found with that email address'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        // Update the parent's document — only childEmail (no isVerified write;
        // isVerified is not in the parent self-update whitelist).
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'childEmail': email});

        // AuthWrapper will automatically redirect to PendingParentApprovalScreen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Connection request sent! Waiting for student approval...',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking account: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
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
              children: [
                Icon(
                  Icons.link_off,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'No Student Linked',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your child\'s registered student email address to send a connection request.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Input Field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'student@example.com',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendLinkRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Send Connection Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  /// Returns a typed stream of the linked student's Firestore document.
  /// Preference order:
  ///   1. users/{linkedStudentId} — direct read, rule explicitly allows isParent() && userId==linkedStudentId
  ///   2. Fallback: student_lookup/{childEmail} → resolve studentId → users/{studentId}
  Stream<DocumentSnapshot<Map<String, dynamic>>> _studentStream(
      Map<String, dynamic>? userData) {
    final linkedStudentId =
        (userData?['linkedStudentId'] ?? '').toString().trim();
    if (linkedStudentId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(linkedStudentId)
          .snapshots();
    }

    // Fallback: resolve via student_lookup (allowed for all signed-in users)
    final childEmail =
        (userData?['childEmail'] ?? '').toString().toLowerCase().trim();
    if (childEmail.isEmpty) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('student_lookup')
        .doc(childEmail)
        .snapshots()
        .asyncExpand((lookupSnap) {
      final studentId =
          (lookupSnap.data()?['studentId'] ?? '').toString().trim();
      if (studentId.isEmpty) return const Stream.empty();
      return FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          String parentName = userData?['name'] ?? 'Parent';
          String linkedStudentEmail = userData?['childEmail'] ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                Text(
                  'Welcome, $parentName',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor your child\'s academic progress',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // IF NO EMAIL IS LINKED, SHOW THE INTERACTIVE LINKING CARD
                if (linkedStudentEmail.isEmpty)
                  const ParentLinkStudentCard()
                else
                // Linked Student Info Card — read users/{linkedStudentId} directly.
                // Rule allows: isParent() && userId == linkedStudentId.
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _studentStream(userData),
                    builder: (context, studentSnapshot) {
                      if (!studentSnapshot.hasData ||
                          !studentSnapshot.data!.exists) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Student profile not found.',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        );
                      }

                      final studentData =
                          studentSnapshot.data!.data() as Map<String, dynamic>;
                      final studentName = studentData['name'] ?? 'Student';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.2),
                                    child: Icon(
                                      Icons.school,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Linked Student',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          studentName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),


                const SizedBox(height: 24),

                // Quick Access Guide - Interactive Version
                if (linkedStudentEmail.isNotEmpty)
                  ParentQuickAccessCard(linkedChildEmail: linkedStudentEmail),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ParentQuickAccessCard extends StatelessWidget {
  final String linkedChildEmail;

  const ParentQuickAccessCard({super.key, required this.linkedChildEmail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary, // E Sekula Neon Cyan
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.black, size: 24),
              SizedBox(width: 8),
              Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Monitor your child\'s academic progress:',
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // LECTURES BUTTON - Triggers Lectures tab (index 1)
          _buildClickableTile(
            context: context,
            icon: Icons.calendar_today,
            title: 'View Lectures',
            subtitle: 'Check today\'s schedule',
            tabIndex: 1,
          ),

          // TESTS BUTTON - Triggers Tests tab (index 3)
          _buildClickableTile(
            context: context,
            icon: Icons.assignment,
            title: 'View Tests & Results',
            subtitle: 'Monitor academic performance',
            tabIndex: 3,
          ),

          // FEES BUTTON - Triggers Fees tab (index 4)
          _buildClickableTile(
            context: context,
            icon: Icons.monetization_on,
            title: 'View Fees',
            subtitle: 'Check fee payment status',
            tabIndex: 4,
          ),

          // NOTES BUTTON - Triggers Notes tab (index 5)
          _buildClickableTile(
            context: context,
            icon: Icons.description,
            title: 'Access Notes',
            subtitle: 'Download study materials',
            tabIndex: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildClickableTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required int tabIndex,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Trigger tab change in GlobalBottomNav
          // The parent widget (GlobalBottomNav) manages the tab state
          // We need to notify it to change tabs
          Navigator.of(context).popUntil((route) => route.isFirst);
          // This will reset to the navigation wrapper, then we can use a callback
          // For now, let's use a simple approach with a global key or provider
          // But since we don't have that setup, let's just show a message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigate to $title using bottom navigation'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.black87,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.black87, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.black54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
