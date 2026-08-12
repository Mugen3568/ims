import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

class ResultEntryScreen extends StatefulWidget {
  final TestModel test;
  final String teacherId;
  final String teacherName;

  const ResultEntryScreen({
    super.key,
    required this.test,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends State<ResultEntryScreen> {
  final TestService _testService = TestService();
  final Map<String, TextEditingController> _marksControllers = {};
  final Map<String, TextEditingController> _remarksControllers = {};
  final Map<String, bool> _savingStatus = {};

  @override
  void dispose() {
    for (final c in _marksControllers.values) {
      c.dispose();
    }
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveStudentResult(String studentId, String studentName) async {
    final marksText = _marksControllers[studentId]?.text.trim() ?? '';
    final remarksText = _remarksControllers[studentId]?.text.trim() ?? '';

    if (marksText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter marks before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double marks = double.tryParse(marksText) ?? -1.0;
    if (marks < 0 || marks > widget.test.maxMarks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marks must be between 0 and ${widget.test.maxMarks}.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _savingStatus[studentId] = true);

    try {
      final entry = StudentMarkEntryInput(
        studentId: studentId,
        studentName: studentName,
        marksObtained: marks,
        remarks: remarksText.isEmpty ? null : remarksText,
      );

      final testId = widget.test.testId.isNotEmpty ? widget.test.testId : widget.test.id;

      await _testService.submitTestMarks(
        testId: testId,
        entries: [entry],
        submittedBy: widget.teacherId,
      );

      if (mounted) {
        final pct = widget.test.maxMarks > 0 ? (marks / widget.test.maxMarks) * 100 : 0.0;
        final grade = TestResultModel.computeGrade(pct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Result saved for $studentName ($grade)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save result: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus[studentId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final testId = widget.test.testId.isNotEmpty ? widget.test.testId : widget.test.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Marks - ${widget.test.title}'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.test.classId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('classes')
                .doc(widget.test.classId)
                .collection('members')
                .snapshots()
            : Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading students: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final studentDocs = snapshot.data!.docs.toList();
          studentDocs.sort((a, b) {
            final nameA = (a.data()['name'] ?? '').toString().toLowerCase();
            final nameB = (b.data()['name'] ?? '').toString().toLowerCase();
            return nameA.compareTo(nameB);
          });

          if (studentDocs.isEmpty) {
            return const Center(
              child: Text('No students found to grade.'),
            );
          }

          return StreamBuilder<List<TestResultModel>>(
            stream: _testService.testResultsStream(testId),
            builder: (context, existingResultsSnapshot) {
              final existingMap = <String, TestResultModel>{};
              if (existingResultsSnapshot.hasData) {
                for (final r in existingResultsSnapshot.data!) {
                  existingMap[r.studentId] = r;
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: studentDocs.length,
                itemBuilder: (context, index) {
                  final studentDoc = studentDocs[index];
                  final sData = studentDoc.data();
                  final studentId = studentDoc.id;
                  final studentName = sData['name'] ?? sData['email'] ?? 'Student';

                  final existing = existingMap[studentId];

                  if (!_marksControllers.containsKey(studentId)) {
                    _marksControllers[studentId] = TextEditingController(
                      text: existing != null ? existing.marksObtained.toString() : '',
                    );
                  }
                  if (!_remarksControllers.containsKey(studentId)) {
                    _remarksControllers[studentId] = TextEditingController(
                      text: existing != null ? (existing.remarks ?? '') : '',
                    );
                  }

                  final isSaving = _savingStatus[studentId] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  studentName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  studentName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (existing != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Grade: ${existing.grade}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _marksControllers[studentId],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Marks (out of ${widget.test.maxMarks.toStringAsFixed(0)})',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _remarksControllers[studentId],
                                  decoration: const InputDecoration(
                                    labelText: 'Remarks (e.g. Excellent)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: isSaving ? null : () => _saveStudentResult(studentId, studentName),
                              icon: const Icon(Icons.save_outlined, size: 16),
                              label: Text(isSaving ? 'Saving...' : 'Save Result'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
