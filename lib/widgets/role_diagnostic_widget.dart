import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// Diagnostic widget to check current user's role and permissions
/// Only shows in debug mode. Collapsible to save screen space.
class RoleDiagnosticWidget extends StatefulWidget {
  const RoleDiagnosticWidget({super.key});

  @override
  State<RoleDiagnosticWidget> createState() => _RoleDiagnosticWidgetState();
}

class _RoleDiagnosticWidgetState extends State<RoleDiagnosticWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (currentUser == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Not logged in',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return Card(
            color: Colors.red.shade900,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ERROR: User document does not exist!',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = data['role'];
        final isVerified = data['isVerified'];
        final email = data['email'];

        // Check if role is exactly correct (lowercase)
        final roleIsCorrect = role == 'manager' || role == 'owner';
        final statusColor = roleIsCorrect ? Colors.green : Colors.red;

        // Theme-aware background colors
        final cardColor = isDark
            ? (roleIsCorrect
                  ? Colors.green.shade900.withOpacity(0.3)
                  : Colors.red.shade900.withOpacity(0.3))
            : (roleIsCorrect ? Colors.green.shade50 : Colors.red.shade50);

        return Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          elevation: _isExpanded ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            children: [
              // Collapsible header
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        roleIsCorrect ? Icons.check_circle : Icons.error,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Role Diagnostic',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          role?.toString() ?? 'NULL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (_isExpanded) ...[
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDiagnosticRow(context, 'UID', currentUser.uid),
                      _buildDiagnosticRow(context, 'Email', email ?? 'N/A'),
                      _buildDiagnosticRow(
                        context,
                        'Role',
                        role?.toString() ?? 'NULL',
                        color: statusColor,
                        copyable: true,
                      ),
                      _buildDiagnosticRow(
                        context,
                        'Verified',
                        isVerified?.toString() ?? 'NULL',
                        color: isVerified == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(height: 12),

                      if (!roleIsCorrect) ...[
                        Divider(color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '⚠️ ROLE ISSUE DETECTED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Current role: "${role?.toString() ?? 'null'}"\n'
                                'Expected: "manager" or "owner" (lowercase)\n\n'
                                'This will cause permission errors for:\n'
                                '• Creating alerts\n'
                                '• Creating groups\n'
                                '• Viewing all users\n'
                                '• Managing payroll',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.red.shade200
                                      : Colors.red.shade900,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Fix Role?'),
                                      content: const Text(
                                        'This will update your role to "manager".\n\n'
                                        'Continue?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Fix Role'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true) return;

                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(currentUser.uid)
                                        .update({'role': 'manager'});

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Role updated to manager!',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to fix role: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.build, size: 16),
                                label: const Text('Auto-Fix Role'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (roleIsCorrect) ...[
                        Divider(color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '✓ Role is correct! If you still see permission errors, '
                            'check that Firestore rules are deployed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.green.shade200
                                  : Colors.green.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
    bool copyable = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: color ?? theme.colorScheme.onSurface,
                fontWeight: color != null ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              icon: Icon(
                Icons.copy,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: $value'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              tooltip: 'Copy',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
