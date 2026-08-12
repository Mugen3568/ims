import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_tile.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = NotificationService();

    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.userNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text('No notifications yet.'),
                ],
              ),
            );
          }

          final notifications = docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
          notifications.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return -1;
            if (b.createdAt == null) return 1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return NotificationTile(notification: notifications[index]);
            },
          );
        },
      ),
    );
  }
}
