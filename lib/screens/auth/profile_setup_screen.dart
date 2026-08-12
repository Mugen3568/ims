import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';

/// ProfileSetupScreen — ghost-account recovery screen.
/// Shown when a user has a Firebase Auth account but their Firestore document
/// is missing or incomplete. Collects name + role-specific class data.
class ProfileSetupScreen extends StatefulWidget {
  final String userId;
  final String role;
  final bool roleMissing; // true if 'role' was missing/empty in Firestore

  const ProfileSetupScreen({
    super.key,
    required this.userId,
    required this.role,
    this.roleMissing = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _childEmailController = TextEditingController();
  bool _isLoading = false;
  late String _selectedRole;

  // Class selection
  String? _selectedClassId; // Student & Parent
  final Set<String> _selectedTeacherClasses = {}; // Teacher

  final ClassService _classService = ClassService();
  final List<String> _roles = ['student', 'teacher', 'parent', 'manager'];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.roleMissing
        ? 'student'
        : widget.role.toLowerCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _childEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final String cleanName = _nameController.text.trim();
    if (cleanName.isEmpty) {
      _showSnack('Please enter your name');
      return;
    }

    final effectiveRole = widget.roleMissing
        ? _selectedRole.toLowerCase()
        : widget.role.toLowerCase();

    // Validate role-specific class fields
    if (effectiveRole == 'teacher') {
      if (_selectedTeacherClasses.isEmpty) {
        _showSnack('Please select at least one assigned class');
        return;
      }
    }
    if (effectiveRole == 'student' || effectiveRole == 'parent') {
      if (_selectedClassId == null || _selectedClassId!.isEmpty) {
        _showSnack('Please select your class');
        return;
      }
    }
    if (effectiveRole == 'parent') {
      if (_childEmailController.text.trim().isEmpty) {
        _showSnack("Please enter your child's email");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final currentUserEmail =
          (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();
      final childEmail = _childEmailController.text.trim().toLowerCase();

      // Cross-check student email if linking parent
      if (effectiveRole == 'parent' && widget.roleMissing) {
        var childQuery = await db
            .collection('directory')
            .where('email', isEqualTo: childEmail)
            .where('role', isEqualTo: 'student')
            .get();

        if (childQuery.docs.isEmpty) {
          if (mounted) {
            _showSnack('Associated student email not found in the system.');
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // Build profile data — personal onboarding fields only
      final Map<String, dynamic> data = {
        'name': cleanName,
        'isProfileComplete': true,
        'is_profile_complete': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Update primary user profile
      await db
          .collection('users')
          .doc(widget.userId)
          .set(data, SetOptions(merge: true));

      if (effectiveRole == 'teacher' && _selectedTeacherClasses.isNotEmpty) {
        await _classService.addTeacherToClasses(
          teacherUid: widget.userId,
          classIds: _selectedTeacherClasses.toList(),
        );
      }

      // Update public directory
      await db.collection('directory').doc(widget.userId).set({
        'name': cleanName,
        'email': currentUserEmail,
        'role': effectiveRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (mounted) {
        _showSnack('Failed to save profile: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Please complete your profile to proceed.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // ── Name ─────────────────────────────────────────────────────────
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // ── Role picker (only for ghost accounts) ─────────────────────────
            if (widget.roleMissing) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role[0].toUpperCase() + role.substring(1)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                      _selectedClassId = null;
                      _selectedTeacherClasses.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Role-specific class fields ────────────────────────────────────
            _buildClassFields(isDark),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassFields(bool isDark) {
    final effectiveRole = widget.roleMissing
        ? _selectedRole
        : widget.role.toLowerCase();

    if (effectiveRole == 'teacher') {
      return _buildTeacherCheckboxes(isDark);
    }

    if (effectiveRole == 'student') {
      return _buildSingleClassDropdown('Select Your Class');
    }

    if (effectiveRole == 'parent') {
      return Column(
        children: [
          TextField(
            controller: _childEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Child's Email Address",
              prefixIcon: Icon(Icons.child_care_rounded),
            ),
          ),
          const SizedBox(height: 16),
          _buildSingleClassDropdown("Child's Class"),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSingleClassDropdown(String label) {
    return StreamBuilder<List<CourseClass>>(
      stream: _classService.activeClasses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: const LinearProgressIndicator(),
          );
        }

        final classes = snapshot.data ?? [];
        if (classes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              color: Colors.orange.withValues(alpha: 0.06),
            ),
            child: Text(
              'No active classes found. Contact the administrator.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange),
            ),
          );
        }

        if (_selectedClassId != null &&
            !classes.any((c) => c.id == _selectedClassId)) {
          _selectedClassId = null;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedClassId,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.class_rounded),
          ),
          isExpanded: true,
          hint: const Text('Select class'),
          items: classes
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(c.displayName),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedClassId = val),
        );
      },
    );
  }

  Widget _buildTeacherCheckboxes(bool isDark) {
    return StreamBuilder<List<CourseClass>>(
      stream: _classService.activeClasses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        final classes = snapshot.data ?? [];
        if (classes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              color: Colors.orange.withValues(alpha: 0.06),
            ),
            child: Text(
              'No active classes found. Contact the administrator.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Assigned Classes',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ),
              const Divider(height: 1),
              ...classes.map((c) {
                final isChecked = _selectedTeacherClasses.contains(c.id);
                return CheckboxListTile(
                  value: isChecked,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedTeacherClasses.add(c.id);
                      } else {
                        _selectedTeacherClasses.remove(c.id);
                      }
                    });
                  },
                  title: Text(
                    c.displayName,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  activeColor: const Color(0xFF0D47A1),
                  dense: true,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
