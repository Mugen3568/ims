import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/approval_service.dart';

/// Reusable widget for Owner & Manager dashboards to manage pending staff approval requests
class PendingStaffApprovalWidget extends StatefulWidget {
  final String currentUserRole;

  const PendingStaffApprovalWidget({
    super.key,
    required this.currentUserRole,
  });

  @override
  State<PendingStaffApprovalWidget> createState() =>
      _PendingStaffApprovalWidgetState();
}

class _PendingStaffApprovalWidgetState
    extends State<PendingStaffApprovalWidget> {
  final ApprovalService _approvalService = ApprovalService();

  Future<void> _handleApprove(Map<String, dynamic> staff) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      await _approvalService.approveUser(
        targetUid: staff['uid'],
        targetRole: staff['role'] ?? 'teacher',
        approvedByUid: currentUid,
        approvedByRole: widget.currentUserRole,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Approved ${staff['name'] ?? 'user'} as ${staff['role']}.',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> staff) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject ${staff['name'] ?? 'User'}?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection (optional)',
            hintText: 'e.g. Unverified identity',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _approvalService.rejectUser(
          targetUid: staff['uid'],
          targetRole: staff['role'] ?? 'teacher',
          approvedByUid: currentUid,
          approvedByRole: widget.currentUserRole,
          reason: reasonCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rejected ${staff['name'] ?? 'user'}.'),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'manager':
        return const Color(0xFF0D47A1);
      case 'teacher':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _approvalService.pendingStaffRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Approval Requests',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${requests.length} pending account${requests.length == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final staff = requests[index];
                  final name = staff['name'] ?? 'Unknown';
                  final email = staff['email'] ?? '';
                  final role = (staff['role'] ?? 'teacher').toString();
                  final assignedClasses = staff['assignedClasses'] as List?;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _roleColor(role),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _roleColor(role),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        if (assignedClasses != null &&
                            assignedClasses.isNotEmpty)
                          Text(
                            'Classes: ${assignedClasses.join(', ')}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 28,
                          ),
                          onPressed: () => _handleApprove(staff),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                            size: 28,
                          ),
                          onPressed: () => _handleReject(staff),
                          tooltip: 'Reject',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
