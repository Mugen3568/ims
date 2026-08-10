import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';

/// ManageClassesScreen — Full CRUD for course-classes.
/// Accessible by Owner and Manager only.
class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  final ClassService _classService = ClassService();

  // ── Add / Edit dialog ────────────────────────────────────────────────────────
  Future<void> _showClassDialog({CourseClass? existing}) async {
    final courseController =
        TextEditingController(text: existing?.course ?? '');
    final sectionController =
        TextEditingController(text: existing?.section ?? '');
    int selectedSemester = existing?.semester ?? 1;
    bool isActive = existing?.isActive ?? true;
    String? errorText;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            existing == null ? 'Add Class' : 'Edit Class',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Course name
                TextField(
                  controller: courseController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    hintText: 'e.g. BCA, BCom, BSc',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Semester selector
                DropdownButtonFormField<int>(
                  initialValue: selectedSemester,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                  items: List.generate(
                    8,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Semester ${i + 1}'),
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSemester = val);
                  },
                ),
                const SizedBox(height: 16),

                // Section
                TextField(
                  controller: sectionController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    hintText: 'e.g. A, B, C',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Active toggle
                SwitchListTile.adaptive(
                  title: Text(
                    'Active',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  subtitle: Text(
                    isActive
                        ? 'Visible in signup dropdowns'
                        : 'Hidden from signup',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  value: isActive,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF0D47A1)
                        : null,
                  ),
                  onChanged: (val) => setDialogState(() => isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),

                // Error display
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final course = courseController.text.trim().toUpperCase();
                      final section =
                          sectionController.text.trim().toUpperCase();

                      if (course.isEmpty || section.isEmpty) {
                        setDialogState(
                          () => errorText =
                              'Course and Section cannot be empty.',
                        );
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorText = null;
                      });

                      try {
                        if (existing == null) {
                          // Create new
                          await _classService.createCourseClass(
                            course: course,
                            semester: selectedSemester,
                            section: section,
                            createdByUid:
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                          );
                        } else {
                          // If active status changed, update it
                          if (isActive != existing.isActive) {
                            await _classService.toggleClassActive(
                              existing.id,
                              isActive,
                            );
                          }
                          // Note: course/semester/section change requires
                          // a delete+recreate since ID is derived from them
                          if (course != existing.course ||
                              selectedSemester != existing.semester ||
                              section != existing.section) {
                            await _classService.deleteCourseClass(existing.id);
                            await _classService.createCourseClass(
                              course: course,
                              semester: selectedSemester,
                              section: section,
                              createdByUid:
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                            );
                          }
                        }
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setDialogState(() {
                          errorText = e.toString().replaceAll(
                            'StateError: ',
                            '',
                          );
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
                  : Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────────
  Future<void> _deleteClass(CourseClass courseClass) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Class?'),
        content: Text(
          'Are you sure you want to delete "${courseClass.displayName}"?\n\n'
          'This action cannot be undone. Students registered to this class '
          'will still have their classId saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _classService.deleteCourseClass(courseClass.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${courseClass.displayName}" deleted.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Classes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClassDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CourseClass>>(
        stream: _classService.allCourseClasses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final classes = snapshot.data ?? [];

          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "+ Add Class" to create the first class.',
                    style: GoogleFonts.poppins(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Group by course
          final Map<String, List<CourseClass>> grouped = {};
          for (final c in classes) {
            grouped.putIfAbsent(c.course, () => []).add(c);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D47A1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            entry.key,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value.length} class${entry.value.length == 1 ? '' : 'es'}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.map(
                    (courseClass) =>
                        _buildClassCard(courseClass, isDark),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildClassCard(CourseClass courseClass, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: courseClass.isActive
                ? const Color(0xFF0D47A1).withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.class_rounded,
            color: courseClass.isActive
                ? const Color(0xFF0D47A1)
                : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          courseClass.displayName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${courseClass.id}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                SelectableText(
                  'Code: ${courseClass.inviteCode.isNotEmpty ? courseClass.inviteCode : "N/A"}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () async {
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    final newCode = await _classService.regenerateInviteCode(
                      courseClass.id,
                      resetByUid: currentUid,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('New invite code generated: $newCode'),
                          backgroundColor: const Color(0xFF0D47A1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active/Inactive badge
            GestureDetector(
              onTap: () => _classService.toggleClassActive(
                courseClass.id,
                !courseClass.isActive,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: courseClass.isActive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: courseClass.isActive ? Colors.green : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Text(
                  courseClass.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: courseClass.isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Edit
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showClassDialog(existing: courseClass),
              tooltip: 'Edit',
            ),

            // Delete
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Colors.red,
              ),
              onPressed: () => _deleteClass(courseClass),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
