import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/class_model.dart';
import '../../services/auth_service.dart';
import '../../services/class_service.dart';

/// ManageUsersScreen — Owner/Manager user management hub.
/// Features:
///   • Live list of all users with role/status badges
///   • Create user via role-specific dialog (with class selection)
///   • Edit class assignment / assigned classes
///   • Toggle verification status
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _roleFilter = 'all';
  final List<String> _filterOptions = [
    'all',
    'teacher',
    'student',
    'parent',
    'manager',
    'owner',
  ];

  // ── Verification toggle ───────────────────────────────────────────────────────
  Future<void> _toggleVerification(String userId, bool current) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isVerified': !current,
    });
  }

  // ── Edit class/assignedClasses dialog ─────────────────────────────────────────
  Future<void> _showEditClassDialog({
    required String userId,
    required String role,
    required Map<String, dynamic> userData,
  }) async {
    final classService = ClassService();
    String? selectedClassId = userData['classId'];
    Set<String> selectedTeacherClasses = {};
    if (userData['assignedClasses'] is List) {
      selectedTeacherClasses = Set<String>.from(
        (userData['assignedClasses'] as List).map((e) => e.toString()),
      );
    }
    bool isSaving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Class Assignment',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 360,
            child: StreamBuilder<List<CourseClass>>(
              stream: classService.allCourseClasses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final classes = snapshot.data ?? [];

                if (classes.isEmpty) {
                  return Text(
                    'No classes found.',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  );
                }

                // Teacher: multi-class checkboxes
                if (role == 'teacher') {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Classes',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          child: Column(
                            children: classes.map((c) {
                              final isChecked =
                                  selectedTeacherClasses.contains(c.id);
                              return CheckboxListTile(
                                value: isChecked,
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedTeacherClasses.add(c.id);
                                    } else {
                                      selectedTeacherClasses.remove(c.id);
                                    }
                                  });
                                },
                                title: Text(
                                  c.displayName,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                activeColor: const Color(0xFF0D47A1),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // Student / Parent: single dropdown
                if (selectedClassId != null &&
                    !classes.any((c) => c.id == selectedClassId)) {
                  selectedClassId = null;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedClassId,
                      decoration: InputDecoration(
                        labelText: role == 'parent'
                            ? "Child's Class"
                            : 'Select Class',
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
                      onChanged: (val) =>
                          setDialogState(() => selectedClassId = val),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (role == 'teacher' &&
                          selectedTeacherClasses.isEmpty) {
                        setDialogState(
                          () => errorText =
                              'Select at least one class.',
                        );
                        return;
                      }
                      if ((role == 'student' || role == 'parent') &&
                          selectedClassId == null) {
                        setDialogState(
                          () => errorText = 'Please select a class.',
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final Map<String, dynamic> update = {};
                        if (role == 'teacher') {
                          final newClasses = selectedTeacherClasses.toList();
                          update['assignedClasses'] = newClasses;

                          // Compute diff for reverse-index sync
                          final oldClasses = List<String>.from(
                            userData['assignedClasses'] as List? ?? [],
                          );
                          final removed = oldClasses
                              .where((c) => !selectedTeacherClasses.contains(c))
                              .toList();
                          final added = newClasses
                              .where((c) => !oldClasses.contains(c))
                              .toList();

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .update(update);

                          // Keep class.teacherIds in sync
                          await classService.syncTeacherToClasses(
                            teacherUid: userId,
                            removedClassIds: removed,
                            addedClassIds: added,
                          );
                        } else if (role == 'student') {
                          final oldClassId = userData['classId'] as String?;
                          final studentName =
                              (userData['name'] ?? 'Student').toString();
                          await classService.transferStudentClass(
                            studentId: userId,
                            studentName: studentName,
                            oldClassId: oldClassId,
                            newClassId: selectedClassId!,
                          );
                        } else {
                          update['classId'] = selectedClassId;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .update(update);
                        }

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setDialogState(() {
                          errorText = 'Failed: $e';
                          isSaving = false;
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create user dialog ────────────────────────────────────────────────────────
  Future<void> _showCreateUserDialog() async {
    final authService = AuthService();
    final classService = ClassService();

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final childEmailCtrl = TextEditingController();

    String selectedRole = 'student';
    String? selectedClassId;
    final Set<String> selectedTeacherClasses = {};
    bool isSaving = false;
    String? errorText;
    bool obscurePass = true;

    final roles = ['student', 'teacher', 'parent', 'manager'];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Create User',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscurePass = !obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r[0].toUpperCase() + r.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedRole = val;
                            selectedClassId = null;
                            selectedTeacherClasses.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Role-specific class fields
                    if (selectedRole == 'parent') ...[
                      TextField(
                        controller: childEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Child's Email",
                          prefixIcon: Icon(Icons.child_care_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (selectedRole == 'student' ||
                        selectedRole == 'parent') ...[
                      StreamBuilder<List<CourseClass>>(
                        stream: classService.allCourseClasses(),
                        builder: (_, snapshot) {
                          final classes = snapshot.data ?? [];
                          if (selectedClassId != null &&
                              !classes.any((c) => c.id == selectedClassId)) {
                            selectedClassId = null;
                          }
                          return DropdownButtonFormField<String>(
                            initialValue: selectedClassId,
                            decoration: InputDecoration(
                              labelText: selectedRole == 'parent'
                                  ? "Child's Class"
                                  : 'Select Class',
                              prefixIcon:
                                  const Icon(Icons.class_rounded),
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
                            onChanged: (val) =>
                                setDialogState(
                                  () => selectedClassId = val,
                                ),
                          );
                        },
                      ),
                    ],

                    if (selectedRole == 'teacher') ...[
                      StreamBuilder<List<CourseClass>>(
                        stream: classService.allCourseClasses(),
                        builder: (_, snapshot) {
                          final classes = snapshot.data ?? [];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[400]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    4,
                                  ),
                                  child: Text(
                                    'Assigned Classes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0D47A1),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                if (classes.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      'No active classes available.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                else
                                  ...classes.map((c) {
                                    final isChecked =
                                        selectedTeacherClasses
                                            .contains(c.id);
                                    return CheckboxListTile(
                                      value: isChecked,
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          if (checked == true) {
                                            selectedTeacherClasses
                                                .add(c.id);
                                          } else {
                                            selectedTeacherClasses
                                                .remove(c.id);
                                          }
                                        });
                                      },
                                      title: Text(
                                        c.displayName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                      activeColor: const Color(0xFF0D47A1),
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // Error
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorText!,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        final error =
                            await authService.registerWithEmailAndPassword(
                          emailCtrl.text.trim(),
                          passwordCtrl.text.trim(),
                          selectedRole,
                          nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          childEmail: selectedRole == 'parent'
                              ? childEmailCtrl.text.trim()
                              : null,
                          classId: (selectedRole == 'student' ||
                                  selectedRole == 'parent')
                              ? selectedClassId
                              : null,
                          assignedClasses: selectedRole == 'teacher'
                              ? selectedTeacherClasses.toList()
                              : null,
                          isCreatedByAdmin: true,
                        );

                        if (error != null) {
                          setDialogState(() {
                            errorText = error;
                            isSaving = false;
                          });
                        } else {
                          // Auto-verify users created by admin
                          if (dialogCtx.mounted) {
                            final messenger =
                                ScaffoldMessenger.of(dialogCtx);
                            Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'User "${nameCtrl.text.trim()}" created successfully.',
                                ),
                                backgroundColor: Colors.green[700],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create User'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Role color helpers ────────────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'manager':
        return const Color(0xFF0D47A1);
      case 'teacher':
        return Colors.teal;
      case 'student':
        return Colors.orange;
      case 'parent':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.admin_panel_settings_rounded;
      case 'manager':
        return Icons.manage_accounts_rounded;
      case 'teacher':
        return Icons.school_rounded;
      case 'parent':
        return Icons.family_restroom_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((role) {
                  final isSelected = _roleFilter == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        role == 'all'
                            ? 'All'
                            : role[0].toUpperCase() + role.substring(1),
                      ),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _roleFilter = role),
                      selectedColor: const Color(0xFF0D47A1),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add User'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No users found.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          var users = snapshot.data!.docs;

          // Apply role filter
          if (_roleFilter != 'all') {
            users = users.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['role'] ?? '').toString().toLowerCase() ==
                  _roleFilter;
            }).toList();
          }

          if (users.isEmpty) {
            return Center(
              child: Text(
                'No ${_roleFilter}s found.',
                style: GoogleFonts.poppins(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final name = userData['name'] ?? 'Unknown';
              final email = userData['email'] ?? '';
              final role =
                  (userData['role'] ?? 'student').toString().toLowerCase();
              final isVerified = userData['isVerified'] ?? false;
              final classId = userData['classId'] as String?;
              final assignedClasses = userData['assignedClasses'] as List?;
              final phone = userData['phone'] as String?;

              // Skip current user from being shown
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              if (userId == currentUid) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: _roleColor(role).withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(
                              _roleIcon(role),
                              color: _roleColor(role),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (phone != null && phone.isNotEmpty)
                                  Text(
                                    phone,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Verify toggle
                          IconButton(
                            icon: Icon(
                              isVerified
                                  ? Icons.verified_rounded
                                  : Icons.pending_actions_rounded,
                              color: isVerified ? Colors.green : Colors.orange,
                            ),
                            onPressed: () =>
                                _toggleVerification(userId, isVerified),
                            tooltip: isVerified ? 'Mark unverified' : 'Verify',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Badges row
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Role badge
                          _badge(
                            role.toUpperCase(),
                            _roleColor(role).withValues(alpha: 0.12),
                            _roleColor(role),
                          ),
                          // Verification badge
                          _badge(
                            isVerified ? 'VERIFIED' : 'PENDING',
                            isVerified
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            isVerified ? Colors.green : Colors.orange,
                          ),
                          // Class info
                          if (classId != null && classId.isNotEmpty)
                            _badge(
                              classId,
                              const Color(0xFF0D47A1).withValues(alpha: 0.08),
                              const Color(0xFF0D47A1),
                            ),
                          if (assignedClasses != null &&
                              assignedClasses.isNotEmpty)
                            _badge(
                              '${assignedClasses.length} class${assignedClasses.length == 1 ? '' : 'es'}',
                              const Color(0xFF0D47A1).withValues(alpha: 0.08),
                              const Color(0xFF0D47A1),
                            ),
                        ],
                      ),

                      // Class edit button (for editable roles)
                      if (role == 'teacher' ||
                          role == 'student' ||
                          role == 'parent') ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showEditClassDialog(
                              userId: userId,
                              role: role,
                              userData: userData,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(
                              role == 'teacher'
                                  ? 'Edit Assigned Classes'
                                  : 'Change Class',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
