import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String role;
  final String? childNameOrEmail;

  const WaitingApprovalScreen({
    super.key,
    required this.role,
    this.childNameOrEmail,
  });

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  bool _isReloading = false;

  Future<void> _refreshStatus() async {
    setState(() => _isReloading = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Force fetch from SERVER to bypass local offline cache
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  String get _title {
    switch (widget.role.toLowerCase()) {
      case 'parent':
        return 'Awaiting Student Approval';
      case 'teacher':
        return 'Teacher Approval Pending';
      case 'manager':
        return 'Manager Approval Pending';
      case 'owner':
        return 'Owner Approval Pending';
      default:
        return 'Account Approval Pending';
    }
  }

  String get _message {
    switch (widget.role.toLowerCase()) {
      case 'parent':
        if (widget.childNameOrEmail != null && widget.childNameOrEmail!.isNotEmpty) {
          return 'Your parent account request is linked to student (${widget.childNameOrEmail}).\n\nPlease ask your child to log into their Student portal and approve your connection request.';
        }
        return 'Your parent account has been created. Please ask your child to log into their Student portal and approve your connection request.';
      case 'teacher':
        return 'Your teacher account has been submitted. An administrator or owner must approve your account before you can access the portal.';
      case 'manager':
        return 'Your manager account has been submitted. An administrator or owner must approve your account before you can access the portal.';
      case 'owner':
        return 'Your owner account has been submitted. An existing administrator or owner must approve your account before access is granted.';
      default:
        return 'Your account request is pending administrative approval. Please check back shortly.';
    }
  }

  IconData get _icon {
    switch (widget.role.toLowerCase()) {
      case 'parent':
        return Icons.family_restroom_rounded;
      case 'teacher':
        return Icons.school_rounded;
      case 'manager':
        return Icons.manage_accounts_rounded;
      case 'owner':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _icon,
                      size: 72,
                      color: const Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    onPressed: _isReloading ? null : _refreshStatus,
                    icon: _isReloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_isReloading ? 'Checking...' : 'Refresh Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(220, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(220, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
