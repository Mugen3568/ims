import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'email_verification_screen.dart';
import 'waiting_approval_screen.dart';
import '../../widgets/global_bottom_nav.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final initialUser = FirebaseAuth.instance.currentUser;
    debugPrint('AUTH STARTUP UID: ${initialUser?.uid}');
    debugPrint('AUTH STARTUP EMAIL: ${initialUser?.email}');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        debugPrint('AUTH STATE CHANGED: ${currentUser?.uid}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && currentUser != null) {
          return AuthenticatedUserGate(user: currentUser);
        }

        return const LoginScreen();
      },
    );
  }
}

class AuthenticatedUserGate extends StatefulWidget {
  final User user;
  const AuthenticatedUserGate({super.key, required this.user});

  @override
  State<AuthenticatedUserGate> createState() => _AuthenticatedUserGateState();
}

class _AuthenticatedUserGateState extends State<AuthenticatedUserGate> {
  bool _isReloading = true;

  @override
  void initState() {
    super.initState();
    _reloadUser();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedUserGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _reloadUser();
    }
  }

  Future<void> _reloadUser() async {
    try {
      await widget.user.reload();
      debugPrint(
        'AUTH RELOAD SUCCESS FOR UID: ${widget.user.uid}, emailVerified: ${widget.user.emailVerified}',
      );
    } catch (e) {
      debugPrint('Auth user reload error (non-fatal): $e');
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReloading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser ?? widget.user;

    // ✅ SECURITY FEATURE #1: Email Verification Gating (fresh status after reload)
    if (!currentUser.emailVerified) {
      return const EmailVerificationScreen();
    }

    // User is authenticated and email verified. Now listen to live Firestore user doc.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError) {
          debugPrint('User doc stream error (sign-out or permission): ${userSnapshot.error}');
          return const LoginScreen();
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          // Give Firestore 5 seconds to finish saving before panicking.
          final creationTime = currentUser.metadata.creationTime;
          if (creationTime != null &&
              DateTime.now().difference(creationTime).inSeconds < 5) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    SizedBox(height: 20),
                    Text('Finalizing account setup...'),
                  ],
                ),
              ),
            );
          }

          // If it takes longer than 5 seconds, auto-route to profile setup.
          debugPrint(
            'Ghost account detected for ${currentUser.uid}. Auto-routing.',
          );
          return ProfileSetupScreen(
            userId: currentUser.uid,
            role: '',
            roleMissing: true,
          );
        }

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;

        bool roleMissing =
            userData['role'] == null ||
            userData['role'].toString().trim().isEmpty;

        String role = (userData['role'] ?? 'student')
            .toString()
            .toLowerCase()
            .trim();
        String approvalStatus = (userData['approvalStatus'] ??
                (userData['isVerified'] == true ? 'approved' : 'pending'))
            .toString()
            .toLowerCase()
            .trim();
        String accountStatus = (userData['accountStatus'] ??
                (userData['isVerified'] == true ? 'active' : 'pending'))
            .toString()
            .toLowerCase()
            .trim();
        bool isProfileComplete =
            userData['is_profile_complete'] ?? userData['isProfileComplete'] ?? false;
        String? childEmail = userData['childEmail'] as String?;

        // ✅ SECURITY LAYER 1: TRAP REJECTED ACCOUNTS
        if (approvalStatus == 'rejected' || accountStatus == 'rejected') {
          return const RejectedParentScreen();
        }

        // ✅ SECURITY LAYER 2: TRAP UNAPPROVED ACCOUNTS
        if (approvalStatus != 'approved' || accountStatus != 'active') {
          return WaitingApprovalScreen(
            role: role,
            childNameOrEmail: childEmail,
          );
        }

        // ✅ PROFILE COMPLETION CHECK
        if (!isProfileComplete) {
          return ProfileSetupScreen(
            userId: currentUser.uid,
            role: role,
            roleMissing: roleMissing,
          );
        }

        // ✅ FINAL ROUTING: Only approved and active users reach here
        return GlobalBottomNav(userRole: role, userId: currentUser.uid);
      },
    );
  }
}



class RejectedParentScreen extends StatelessWidget {
  const RejectedParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Rejected')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Your parent account request has been rejected.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please contact your child or support for more information.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
