import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/result_model.dart';
import '../../services/result_service.dart';
import '../../widgets/result_card.dart';

class StudentResultsScreen extends StatelessWidget {
  final String? studentId;
  final String? studentName;

  const StudentResultsScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetUid = studentId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = ResultService();

    if (targetUid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Results')),
        body: const Center(child: Text('Please sign in to view test results.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(studentName != null ? '$studentName - Test Results' : 'My Test Results'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.studentResults(targetUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading results: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text('No test results published yet.'),
                ],
              ),
            );
          }

          final results = docs.map((doc) => ResultModel.fromFirestore(doc)).toList();
          results.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return -1;
            if (a.createdAt == null) return 1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return ResultCard(result: results[index]);
            },
          );
        },
      ),
    );
  }
}
