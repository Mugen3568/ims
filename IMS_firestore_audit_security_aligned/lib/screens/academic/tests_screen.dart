import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

/// TestsScreen — Production Test Creation, Marks Entry, & Grade Cards Hub
class TestsScreen extends StatelessWidget {
  final String userRole; // 'owner', 'manager', 'teacher', 'student', 'parent'

  const TestsScreen({super.key, required this.userRole});

  bool get isStaff =>
      userRole == 'owner' || userRole == 'manager' || userRole == 'teacher';

  @override
  Widget build(BuildContext context) {
    if (!isStaff) {
      return _StudentParentTestsView(userRole: userRole);
    }
    return _StaffTestsView(userRole: userRole);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 1. STAFF VIEW: TEACHERS, MANAGERS, & OWNERS
// ────────────────────────────────────────────────────────────────────────────
class _StaffTestsView extends StatefulWidget {
  final String userRole;
  const _StaffTestsView({required this.userRole});

  @override
  State<_StaffTestsView> createState() => _StaffTestsViewState();
}

class _StaffTestsViewState extends State<_StaffTestsView> {
  final TestService _testService = TestService();

  void _showCreateTestDialog() {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final maxMarksCtrl = TextEditingController(text: '100');
    final linkCtrl = TextEditingController();

    String? selectedClassId;
    String? selectedClassName;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create New Test',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Test Name / Title *',
                    hintText: 'e.g. Mid-Term Examination',
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                  builder: (context, snapshot) {
                    final classes = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Target Class *',
                        prefixIcon: Icon(Icons.class_rounded),
                      ),
                      items: classes.map((c) {
                        final data = c.data() as Map<String, dynamic>;
                        final name = data['name'] ?? c.id;
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final doc = classes.firstWhere((c) => c.id == val);
                          final data = doc.data() as Map<String, dynamic>;
                          setDialogState(() {
                            selectedClassId = val;
                            selectedClassName = data['name'] ?? val;
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'e.g. Mathematics',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxMarksCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Marks *',
                    hintText: 'e.g. 100',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'External Test Paper Link (Optional)',
                    hintText: 'https://drive.google.com/test-paper',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = titleCtrl.text.trim();
                final subject = subjectCtrl.text.trim();
                final maxM = double.tryParse(maxMarksCtrl.text.trim()) ?? 0.0;

                if (name.isEmpty || subject.isEmpty || selectedClassId == null || maxM <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields correctly.')),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                final userName = user?.displayName ?? user?.email ?? 'Teacher';

                await _testService.createTest(
                  testName: name,
                  classId: selectedClassId!,
                  className: selectedClassName ?? selectedClassId!,
                  subject: subject,
                  teacherId: user?.uid ?? '',
                  teacherName: userName,
                  maxMarks: maxM,
                  testDate: selectedDate,
                  externalLink: linkCtrl.text,
                  createdBy: user?.uid ?? '',
                );

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test "$name" created successfully!'),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              child: const Text('Create Test'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Test & Exam Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final tests = docs.map((d) => TestModel.fromSnapshot(d)).toList();
          tests.sort((a, b) => b.testDate.compareTo(a.testDate));

          if (tests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tests scheduled yet.',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateTestDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Test'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              final test = tests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              test.testName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Max: ${test.maxMarks.toStringAsFixed(0)} Marks',
                              style: const TextStyle(
                                color: Color(0xFF0D47A1),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subject: ${test.subject} • Class: ${test.className}',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _EnterStudentMarksScreen(test: test),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('Enter Marks'),
                            ),
                          ),
                          if (test.externalLink != null && test.externalLink!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded),
                              tooltip: 'Open Test Paper Link',
                              onPressed: () async {
                                final uri = Uri.parse(test.externalLink!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTestDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Test'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// ENTER STUDENT MARKS SHEET (WITH LIVE GRADE PREVIEW)
// ────────────────────────────────────────────────────────────────────────────
class _EnterStudentMarksScreen extends StatefulWidget {
  final TestModel test;
  const _EnterStudentMarksScreen({required this.test});

  @override
  State<_EnterStudentMarksScreen> createState() => _EnterStudentMarksScreenState();
}

class _EnterStudentMarksScreenState extends State<_EnterStudentMarksScreen> {
  final TestService _testService = TestService();

  final Map<String, TextEditingController> _marksCtrls = {};
  final Map<String, TextEditingController> _remarksCtrls = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in _marksCtrls.values) {
      c.dispose();
    }
    for (final c in _remarksCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitResults(List<QueryDocumentSnapshot> students) async {
    final existingSnap = await FirebaseFirestore.instance
        .collection('results')
        .where('testId', isEqualTo: widget.test.testId)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Update Existing Test Results?'),
          content: Text(
            'Marks have already been submitted for test "${widget.test.testName}".\n\n'
            'Do you want to overwrite existing student marks with your new inputs?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              child: const Text('Confirm Overwrite'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isSaving = true);
    try {
      final entries = students.map((doc) {
        final sData = doc.data() as Map<String, dynamic>;
        final sName = sData['name'] ?? sData['email'] ?? 'Student';
        final score = double.tryParse(_marksCtrls[doc.id]?.text.trim() ?? '0') ?? 0.0;
        final rem = _remarksCtrls[doc.id]?.text.trim();

        return StudentMarkEntryInput(
          studentId: doc.id,
          studentName: sName,
          studentEmail: (sData['email'] ?? '').toString(),
          marksObtained: score,
          remarks: rem,
        );
      }).toList();

      await _testService.submitTestMarks(
        testId: widget.test.testId,
        entries: entries,
        submittedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marks submitted successfully for ${widget.test.testName}!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;

    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Marks: ${test.testName}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('classId', isEqualTo: test.classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data?.docs ?? [];

          if (students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No students found registered in Class "${test.className}".',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Max Marks: ${test.maxMarks.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    Text('${students.length} Students', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final sData = student.data() as Map<String, dynamic>;
                    final sName = sData['name'] ?? sData['email'] ?? 'Student';

                    final marksCtrl = _marksCtrls.putIfAbsent(student.id, () => TextEditingController(text: '0'));
                    final remarksCtrl = _remarksCtrls.putIfAbsent(student.id, () => TextEditingController());

                    final obtained = double.tryParse(marksCtrl.text) ?? 0.0;
                    final pct = test.maxMarks > 0 ? (obtained / test.maxMarks) * 100 : 0.0;
                    final grade = TestResultModel.computeGrade(pct);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sName,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    'Grade: $grade (${pct.toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: grade == 'F' ? Colors.red : Colors.green[800],
                                    ),
                                  ),
                                  backgroundColor: (grade == 'F' ? Colors.red : Colors.green).withValues(alpha: 0.1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: marksCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Marks Obtained',
                                      prefixIcon: Icon(Icons.grade_rounded),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: remarksCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Remarks (Optional)',
                                      prefixIcon: Icon(Icons.comment_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isSaving ? null : () => _submitResults(students),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Test Results'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 2. STUDENT & PARENT VIEW: RESULT CARDS & GRADE CARDS
// ────────────────────────────────────────────────────────────────────────────
class _StudentParentTestsView extends StatelessWidget {
  final String userRole;
  const _StudentParentTestsView({required this.userRole});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please sign in.'));

    return Scaffold(
      appBar: AppBar(title: const Text('My Test Scores & Grades')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final targetStudentId = (userRole == 'parent')
              ? (userData['linkedStudentId'] ?? user.uid).toString()
              : user.uid;

          return StreamBuilder<List<TestResultModel>>(
            stream: TestService().studentResultsStream(targetStudentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final results = snapshot.data ?? [];

              if (results.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No test results published for this account yet.',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              double totalPct = 0;
              for (final r in results) {
                totalPct += r.percentage;
              }
              double avgPct = totalPct / results.length;
              String overallGrade = TestResultModel.computeGrade(avgPct);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                overallGrade,
                                style: GoogleFonts.poppins(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D47A1),
                                ),
                              ),
                              Text('Overall Grade', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${avgPct.toStringAsFixed(1)}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              Text('Average Percentage', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Published Test Scores',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...results.map((r) {
                    Color gColor = Colors.green;
                    if (r.grade == 'F') gColor = Colors.red;
                    if (r.grade == 'C' || r.grade == 'D') gColor = Colors.orange;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: gColor.withValues(alpha: 0.15),
                          child: Text(
                            r.grade,
                            style: TextStyle(fontWeight: FontWeight.bold, color: gColor),
                          ),
                        ),
                        title: Text(r.testName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Subject: ${r.subject}\n'
                          'Score: ${r.marksObtained.toStringAsFixed(1)} / ${r.maxMarks.toStringAsFixed(0)} (${r.percentage.toStringAsFixed(1)}%)'
                          '${r.remarks != null && r.remarks!.isNotEmpty ? '\nRemarks: ${r.remarks}' : ''}',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                        trailing: Chip(
                          label: Text(
                            '${r.percentage.toStringAsFixed(0)}%',
                            style: TextStyle(color: gColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          backgroundColor: gColor.withValues(alpha: 0.1),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}