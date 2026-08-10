import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingParentRequestsWidget extends StatelessWidget {
  const PendingParentRequestsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      return const SizedBox.shrink();
    }

    final studentEmail = currentUser.email!.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      // Query: Find parents who want to link to this student's email but aren't verified yet
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('childEmail', isEqualTo: studentEmail)
          .where('isVerified', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error loading parent requests: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }

        final requests = snapshot.data?.docs ?? [];

        // If no pending requests, return an empty box (invisible)
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Pending Family Connections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final parentName = data['name'] ?? 'Unknown Parent';
              final parentEmail = data['email'] ?? 'No email';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF050505), // Dark background
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orangeAccent, width: 1.5),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    parentName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  subtitle: Text(
                    parentEmail,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reject Button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => _rejectRequest(context, doc.id),
                        tooltip: 'Reject',
                      ),
                      // Approve Button
                      IconButton(
                        icon: const Icon(Icons.check, color: Color(0xFF00E5FF)),
                        onPressed: () => _approveRequest(context, doc.id),
                        tooltip: 'Approve',
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ✅ Approve: Sets the parent's isVerified status to true
  Future<void> _approveRequest(BuildContext context, String parentId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(parentId).update({
        'isVerified': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parent connection approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ❌ Reject: Clears the childEmail field so the parent is unlinked
  Future<void> _rejectRequest(BuildContext context, String parentId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(parentId).update({
        'childEmail': '', 
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parent connection rejected.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
