import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';
import '../../models/study_material_model.dart';
import '../../services/study_material_service.dart';

class AddMaterialDialog extends StatefulWidget {
  final String userRole;
  final StudyMaterial? editMaterial;

  const AddMaterialDialog({
    super.key,
    required this.userRole,
    this.editMaterial,
  });

  @override
  State<AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<AddMaterialDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _linkController = TextEditingController();

  String? _selectedClassId;
  String? _selectedClassName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editMaterial != null) {
      final mat = widget.editMaterial!;
      _titleController.text = mat.title;
      _descriptionController.text = mat.description;
      _subjectController.text = mat.subject;
      _linkController.text = mat.link;
      _selectedClassId = mat.classId.isEmpty ? null : mat.classId;
      _selectedClassName = mat.className;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _linkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in title and material link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final link = _linkController.text.trim();
    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid link starting with http:// or https://'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      
      String teacherName = 'Teacher';
      if (uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          teacherName = userDoc.data()?['name'] ?? userDoc.data()?['email'] ?? teacherName;
        }
      }

      final service = StudyMaterialService();

      if (widget.editMaterial != null) {
        await service.updateMaterial(widget.editMaterial!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'subject': _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim(),
          'classId': _selectedClassId ?? '',
          'className': _selectedClassName ?? '',
          'link': link,
          'url': link,
        });
      } else {
        final material = StudyMaterial(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          subject: _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim(),
          classId: _selectedClassId ?? '',
          className: _selectedClassName ?? '',
          teacherId: uid,
          teacherName: teacherName,
          uploadedByRole: widget.userRole,
          link: link,
        );
        await service.addMaterial(material);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editMaterial != null ? 'Material updated!' : 'Material uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editMaterial != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.add_link, color: Colors.blue),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Material' : 'Add Study Material'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Unit 4 Revision Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Physics, Flutter, Mathematics',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                List<String> assignedClassIds = [];
                String effectiveRole = widget.userRole;
                String? studentClassId;
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  effectiveRole = (userData['role'] ?? widget.userRole).toString().toLowerCase();
                  studentClassId = userData['classId'] as String?;
                  if (userData['assignedClasses'] is List) {
                    assignedClassIds = List<String>.from(
                      (userData['assignedClasses'] as List).map((e) => e.toString()),
                    );
                  }
                }
                final teacherUid = FirebaseAuth.instance.currentUser?.uid;

                return StreamBuilder<List<CourseClass>>(
                  stream: ClassService().allCourseClasses(),
                  builder: (context, snapshot) {
                    var classes = snapshot.data ?? [];

                    if (effectiveRole == 'teacher' && teacherUid != null) {
                      classes = classes.where((c) {
                        return assignedClassIds.contains(c.id) ||
                            c.teacherIds.contains(teacherUid);
                      }).toList();
                    } else if (effectiveRole == 'student') {
                      classes = classes.where((c) => c.id == studentClassId).toList();
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Class (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: classes.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.displayName),
                          onTap: () {
                            _selectedClassName = c.displayName;
                          },
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                        });
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Material Link (URL) *',
                hintText: 'Google Drive, YouTube, OneDrive, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Summary or instructions for students',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Update' : 'Upload'),
        ),
      ],
    );
  }
}
