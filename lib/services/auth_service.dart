import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/constants/status_constants.dart';
import '../firebase_options.dart';
import 'class_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // Register and Auto-Create Firestore Record
  // Supports all 5 roles: student, parent, teacher, manager, owner
  // ────────────────────────────────────────────────────────────────────────────
  Future<String?> registerWithEmailAndPassword(
    String email,
    String password,
    String role,
    String name, {
    String? phone,
    String? childEmail, // Parent only
    String? inviteCode, // Student only
    String? classId, // Direct class ID
    List<String>? assignedClasses, // Teacher — only used when isCreatedByAdmin
    bool isCreatedByAdmin = false,
  }) async {
    FirebaseApp? tempApp;
    try {
      // ✅ Normalize string inputs
      email = email.trim().toLowerCase();
      password = password.trim();
      name = name.trim();
      role = role.trim().toLowerCase();
      phone = phone?.trim() ?? '';
      childEmail = childEmail?.trim().toLowerCase();
      inviteCode = inviteCode?.trim().toUpperCase();
      classId = classId?.trim();

      String? resolvedClassId = classId;
      String? linkedStudentId;

      // ── Initial Parameter Checks ───────────────────────────────────────────
      if (role == 'student' && (resolvedClassId == null || resolvedClassId.isEmpty)) {
        if (inviteCode == null || inviteCode.isEmpty) {
          return 'Please enter a valid class invite code.';
        }
      }

      if (role == 'parent' && (childEmail == null || childEmail.isEmpty)) {
        return "Please enter your child's registered email address or Student ID.";
      }

      if (role == 'teacher' &&
          isCreatedByAdmin &&
          (assignedClasses == null || assignedClasses.isEmpty)) {
        return 'Please select at least one class for this teacher.';
      }

      // ── Create Firebase Auth account ───────────────────────────────────────
      FirebaseAuth targetAuth = _auth;
      if (isCreatedByAdmin) {
        tempApp = await Firebase.initializeApp(
          name: 'adminUserCreation_${DateTime.now().millisecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        targetAuth = FirebaseAuth.instanceFor(app: tempApp);
      }

      UserCredential result = await targetAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // ── Post-Authentication Student & Parent Validation ───────────────────
        try {
          if (role == 'student' && (resolvedClassId == null || resolvedClassId.isEmpty)) {
            if (inviteCode != null && inviteCode.isNotEmpty) {
              resolvedClassId = await ClassService(
                firestore: _db,
              ).resolveClassIdByInviteCode(inviteCode);
              if (resolvedClassId == null || resolvedClassId.isEmpty) {
                await user.delete();
                return 'Invalid or inactive class invite code. Please check with your administrator.';
              }
            }
          }

          if (role == 'parent') {
            final cleanChildEmail = (childEmail ?? '').trim().toLowerCase();
            if (cleanChildEmail.isNotEmpty) {
              try {
                final lookupDoc =
                    await _db.collection('student_lookup').doc(cleanChildEmail).get();
                if (lookupDoc.exists && lookupDoc.data()?['isActive'] == true) {
                  linkedStudentId = lookupDoc.data()?['studentId'] as String?;
                  resolvedClassId = lookupDoc.data()?['classId'] as String?;
                }
              } catch (e) {
                debugPrint('Parent student_lookup query error: $e');
              }
            }

            if (linkedStudentId == null || linkedStudentId.isEmpty) {
              await user.delete();
              return 'Child student email not found. Please verify with your administrator.';
            }
          }
        } catch (validationError) {
          debugPrint('Validation failed post-auth, rolling back: $validationError');
          try {
            await user.delete();
          } catch (_) {}
          return 'Registration failed during account setup: $validationError';
        }

        // ── Transaction-Protected First Owner Bootstrap ──────────────────────
        bool isBootstrapOwner = false;
        if (role == 'owner') {
          try {
            final systemRef = _db.collection('settings').doc('system');
            await _db.runTransaction((transaction) async {
              final systemDoc = await transaction.get(systemRef);
              final bool bootstrapCompleted =
                  systemDoc.exists &&
                  (systemDoc.data()?['bootstrapCompleted'] == true);

              if (!bootstrapCompleted) {
                transaction.set(systemRef, {
                  'bootstrapCompleted': true,
                  'bootstrappedAt': FieldValue.serverTimestamp(),
                  'bootstrappedBy': user.uid,
                }, SetOptions(merge: true));
                isBootstrapOwner = true;
              }
            });
          } catch (e) {
            debugPrint('Bootstrap check error: $e');
          }
        }

        String finalRole = role.trim().toLowerCase();
        String approvalStatus = ApprovalStatus.pending;
        String accountStatus = AccountStatus.pending;

        // Approval matrix: Students and Bootstrap Owners are auto-approved
        if (role == 'student' || isBootstrapOwner || isCreatedByAdmin) {
          approvalStatus = ApprovalStatus.approved;
          accountStatus = AccountStatus.active;
          if (isBootstrapOwner) finalRole = 'owner';
        }

        // ── Build Firestore User Document (User Contract) ─────────────────────
        try {
          final Map<String, dynamic> userDoc = {
            'uid': user.uid,
            'name': name,
            'email': email,
            'phone': phone,
            'role': finalRole.trim().toLowerCase(),
            'approvalStatus': approvalStatus,
            'accountStatus': accountStatus,
            'isVerified': (approvalStatus == ApprovalStatus.approved),
            'isProfileComplete': false,
            'is_profile_complete': false,
            'createdAt': FieldValue.serverTimestamp(),
            'created_at': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Role-specific fields
          if (finalRole == 'teacher') {
            userDoc['assignedClasses'] = assignedClasses ?? [];
            userDoc['total_lectures_taken'] = 0;
            userDoc['unpaid_lectures'] = 0;
            userDoc['rate_per_lecture'] = 0;
          } else if (finalRole == 'student') {
            userDoc['classId'] = resolvedClassId ?? '';
            if (inviteCode != null) userDoc['inviteCode'] = inviteCode;
            userDoc['linked_parent_email'] = '';
          } else if (finalRole == 'parent') {
            userDoc['classId'] = resolvedClassId ?? '';
            userDoc['childEmail'] = childEmail ?? '';
            if (linkedStudentId != null) {
              userDoc['linkedStudentId'] = linkedStudentId;
            }
          }

          // Save primary profile
          await _db.collection('users').doc(user.uid).set(userDoc);

          // ── Create student_lookup Entry for Student ──────────────────────────
          if (finalRole == 'student' && email.isNotEmpty) {
            await _db.collection('student_lookup').doc(email).set({
              'studentId': user.uid,
              'email': email,
              'classId': resolvedClassId ?? '',
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          // ── Auto-join class for Student upon signup via Invite Code ───────
          if (finalRole == 'student' &&
              resolvedClassId != null &&
              resolvedClassId.isNotEmpty) {
            try {
              await ClassService(firestore: _db).joinClassById(
                classId: resolvedClassId,
                studentId: user.uid,
                studentName: name,
              );
            } catch (autoJoinError) {
              debugPrint('Auto-join class error on student signup, performing rollback: $autoJoinError');
              try {
                await _db.collection('users').doc(user.uid).delete();
                await _db.collection('student_lookup').doc(email).delete();
                await user.delete();
              } catch (_) {}
              return 'Failed to join assigned class. Please try again.';
            }
          }

          // ── Reverse index: populate class.teacherIds ───────────────────────
          if (finalRole == 'teacher' &&
              assignedClasses != null &&
              assignedClasses.isNotEmpty) {
            await ClassService(firestore: _db).addTeacherToClasses(
              teacherUid: user.uid,
              classIds: assignedClasses,
            );
          }

          // Save public directory entry
          await _db.collection('directory').doc(user.uid).set({
            'name': name,
            'email': email,
            'role': finalRole,
          });
        } catch (setupError) {
          debugPrint('Critical setup failure: $setupError');
          try {
            await _db.collection('users').doc(user.uid).delete();
            await _db.collection('student_lookup').doc(email).delete();
            await user.delete();
          } catch (_) {}
          return 'Failed to complete registration setup. Please try again.';
        }

        // ── Send Email Verification ──────────────────────────────────────────
        try {
          await user.sendEmailVerification();
        } catch (emailError) {
          debugPrint('Email verification failed to send: $emailError');
        }

        return null; // Success
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return 'Too many attempts detected. Firebase has temporarily blocked this device. Please wait 15–30 minutes or switch your internet connection.';
      } else if (e.code == 'email-already-in-use') {
        return 'This email is already registered. Please login instead.';
      } else if (e.code == 'weak-password') {
        return 'Password is too weak. Please use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address format.';
      } else if (e.code == 'network-request-failed') {
        return 'Network error. Please check your internet connection.';
      } else {
        return e.message ?? 'Registration failed. Please try again.';
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      return 'An unexpected error occurred. Please try again.';
    } finally {
      if (tempApp != null) {
        try {
          await FirebaseAuth.instanceFor(app: tempApp).signOut();
          await tempApp.delete();
        } catch (cleanErr) {
          debugPrint('Secondary app cleanup warning: $cleanErr');
        }
      }
    }
    return 'Registration failed. Please try again.';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Email Verification Helpers
  // ────────────────────────────────────────────────────────────────────────────
  Future<bool> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Standard Login
  // ────────────────────────────────────────────────────────────────────────────
  Future<String?> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final cleanEmail = email.trim();
    debugPrint('LOGIN ATTEMPT EMAIL: "$cleanEmail"');

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      debugPrint('LOGIN SUCCESS UID: ${credential.user?.uid}');
      debugPrint('LOGIN SUCCESS EMAIL: ${credential.user?.email}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('LOGIN FAILED CODE: ${e.code}');
      debugPrint('LOGIN FAILED MESSAGE: ${e.message}');

      if (e.code == 'too-many-requests') {
        return 'Too many login attempts. Firebase has temporarily blocked this device. Please wait 15–30 minutes or switch your internet connection.';
      } else if (e.code == 'user-not-found') {
        return 'No user found with this email. Please register first.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect email or password. Please try again.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address format.';
      } else if (e.code == 'user-disabled') {
        return 'This account has been disabled. Please contact support.';
      } else if (e.code == 'network-request-failed') {
        return 'Network error. Please check your internet connection.';
      } else {
        return e.message ?? 'Login failed. Please try again.';
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
