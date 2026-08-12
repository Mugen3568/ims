import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const SizedBox.shrink();
    }

    final notificationService = NotificationService();

    return StreamBuilder<int>(
      stream: notificationService.getUnreadCount(user.uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
