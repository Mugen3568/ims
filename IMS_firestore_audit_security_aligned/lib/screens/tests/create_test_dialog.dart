import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

class CreateTestDialog extends StatefulWidget {
  final String userRole;
  final TestModel? editTest;

  const CreateTestDialog({
    super.key,
    required this.userRole,
    this.editTest,
  });

  @override
  State<CreateTestDialog> createState() => _CreateTestDialogState();
}

class _CreateTestDialogState extends State<CreateTestDialog> {
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _maxMarksController = TextEditingController(text: '100');
  final _testLinkController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _examDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedClassId;
  String? _selectedClassName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editTest != null) {
      final t = widget.editTest!;
      _titleController.text = t.title;
      _subjectController.text = t.subject;
      _maxMarksController.text = t.maxMarks.toString();
      _testLinkController.text = t.testLink ?? '';
      _descriptionController.text = t.description;
      _examDate = t.examDate;
      _selectedClassId = t.classId.isEmpty ? null : t.classId;
      _selectedClassName = t.className;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _maxMarksController.dispose();
    _testLinkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _examDate = picked);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in test title.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final link = _testLinkController.text.trim();
    if (link.isNotEmpty && !link.startsWith('http://') && !link.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid link starting with http:// or https://'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final maxMarks = double.tryParse(_maxMarksController.text.trim()) ?? 100.0;
    if (maxMarks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid maximum marks amount.'),
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

      final service = TestService();

      if (widget.editTest != null) {
        final updated = TestModel(
          testId: widget.editTest!.id,
          testName: _titleController.text.trim(),
          classId: _selectedClassId ?? '',
          className: _selectedClassName ?? '',
          subject: _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim(),
          teacherId: widget.editTest!.teacherId.isEmpty ? uid : widget.editTest!.teacherId,
          teacherName: widget.editTest!.teacherName.isEmpty ? teacherName : widget.editTest!.teacherName,
          maxMarks: maxMarks,
          testDate: _examDate,
          externalLink: link.isEmpty ? null : link,
          createdBy: widget.editTest!.createdBy.isEmpty ? uid : widget.editTest!.createdBy,
        );
        await service.updateTest(updated);
      } else {
        await service.createTest(
          testName: _titleController.text.trim(),
          classId: _selectedClassId ?? '',
          className: _selectedClassName ?? '',
          subject: _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim(),
          teacherId: uid,
          teacherName: teacherName,
          maxMarks: maxMarks,
          testDate: _examDate,
          externalLink: link.isEmpty ? null : link,
          createdBy: uid,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editTest != null ? 'Test updated successfully!' : 'Test created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save test: $e'),
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
    final isEdit = widget.editTest != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.assignment_add, color: Colors.blue),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Test' : 'Create New Test'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Test Title *',
                hintText: 'e.g. Java Midterm Exam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Java, Physics',
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
                String effectiveRole = widget.userRole;
                if (userSnap.hasData && userSnap.data!.exists) {
                  final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  effectiveRole = (userData['role'] ?? widget.userRole).toString().toLowerCase();
                }
                final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                return StreamBuilder<List<CourseClass>>(
                  stream: ClassService().streamClassesForUser(
                    uid: currentUid,
                    role: effectiveRole,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Class (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        child: Text('Loading classes...', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    final classes = snapshot.data ?? [];

                    if (classes.isEmpty) {
                      return const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Class (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        child: Text('No classes assigned', style: TextStyle(color: Colors.grey)),
                      );
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
                          onTap: () {
                            _selectedClassName = c.displayName;
                          },
                          child: Text(c.displayName),
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
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Exam Date: ${DateFormat('MMM d, yyyy').format(_examDate)}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxMarksController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum Marks *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _testLinkController,
              decoration: const InputDecoration(
                labelText: 'Test Link (URL)',
                hintText: 'Google Forms or test portal link',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Instructions for students',
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
              : Text(isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
