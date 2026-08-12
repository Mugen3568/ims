import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/approval_service.dart';

/// Reusable widget for Student dashboard to view and approve/reject parent connection requests
class PendingParentApprovalWidget extends StatefulWidget {
  final String studentUid;

  const PendingParentApprovalWidget({
    super.key,
    required this.studentUid,
  });

  @override
  State<PendingParentApprovalWidget> createState() =>
      _PendingParentApprovalWidgetState();
}

class _PendingParentApprovalWidgetState
    extends State<PendingParentApprovalWidget> {
  final ApprovalService _approvalService = ApprovalService();

  Future<void> _handleApprove(Map<String, dynamic> parent) async {
    try {
      await _approvalService.approveUser(
        targetUid: parent['uid'],
        targetRole: 'parent',
        approvedByUid: widget.studentUid,
        approvedByRole: 'student',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Approved parent request from ${parent['name'] ?? 'Parent'}.'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve parent request: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> parent) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Parent Connection?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject ${parent['name'] ?? 'this parent'}?',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Unrecognized email',
              ),
            ),
          ],
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
          targetUid: parent['uid'],
          targetRole: 'parent',
          approvedByUid: widget.studentUid,
          approvedByRole: 'student',
          reason: reasonCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rejected request from ${parent['name'] ?? 'Parent'}.'),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _approvalService.pendingParentsForStudent(widget.studentUid),
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
            color: Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.purple.withValues(alpha: 0.2),
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
                        color: Colors.purple[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
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
                            'Parent Connection Requests',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${requests.length} parent requesting connection to your profile',
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
                  final parent = requests[index];
                  final name = parent['name'] ?? 'Unknown Parent';
                  final email = parent['email'] ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: GoogleFonts.poppins(fontSize: 12),
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
                          onPressed: () => _handleApprove(parent),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                            size: 28,
                          ),
                          onPressed: () => _handleReject(parent),
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
