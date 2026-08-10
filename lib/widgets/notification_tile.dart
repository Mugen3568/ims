import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const NotificationTile({
    super.key,
    required this.notification,
  });

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'study_material':
        return Icons.menu_book;
      case 'test':
        return Icons.assignment;
      case 'result':
        return Icons.grade;
      case 'lecture':
      case 'lecture_scheduled':
        return Icons.event_available;
      case 'lecture_cancelled':
        return Icons.event_busy;
      case 'lecture_updated':
        return Icons.edit_calendar;
      case 'fee':
        return Icons.payments;
      case 'payroll':
        return Icons.account_balance_wallet;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'study_material':
        return Colors.blue;
      case 'test':
        return Colors.purple;
      case 'result':
        return Colors.green;
      case 'lecture':
      case 'lecture_scheduled':
        return Colors.orange;
      case 'lecture_cancelled':
        return Colors.red;
      case 'lecture_updated':
        return Colors.teal;
      case 'fee':
        return Colors.deepOrange;
      case 'payroll':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconData = _getTypeIcon(notification.type);
    final color = _getTypeColor(notification.type);
    final dateStr = notification.createdAt != null
        ? DateFormat('MMM d, h:mm a').format(notification.createdAt!.toDate())
        : 'Just now';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: notification.isRead
          ? theme.colorScheme.surface
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(iconData, color: color, size: 20),
        ),
        title: Row(
          children: [
            if (!notification.isRead) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        onTap: () {
          if (!notification.isRead) {
            NotificationService().markAsRead(notification.id);
          }
        },
      ),
    );
  }
}
