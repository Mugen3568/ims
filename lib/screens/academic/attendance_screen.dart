import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/lecture_model.dart';
import '../../services/attendance_service.dart';
import '../../services/lecture_service.dart';

/// AttendanceScreen — Production Hub for marking, viewing, and tracking attendance.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({
    super.key,
    required this.userRole,
    this.linkedChildEmail,
  });

  final String userRole;
  final String? linkedChildEmail;

  @override
  Widget build(BuildContext context) {
    switch (userRole) {
      case 'teacher':
        return const _TeacherAttendanceView();
      case 'owner':
      case 'manager':
        return const _OwnerAttendanceView();
      case 'parent':
        return _ParentAttendanceView(linkedChildEmail: linkedChildEmail);
      default:
        return const _StudentAttendanceView();
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 1. TEACHER ATTENDANCE VIEW
// ────────────────────────────────────────────────────────────────────────────
class _TeacherAttendanceView extends StatelessWidget {
  const _TeacherAttendanceView();

  @override
  Widget build(BuildContext context) {
    final teacherId = FirebaseAuth.instance.currentUser?.uid;
    if (teacherId == null) {
      return const Center(child: Text('Please sign in again.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark & Review Attendance'),
      ),
      body: StreamBuilder<List<Lecture>>(
        stream: LectureService().teacherLecturesStream(teacherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading lectures: ${snapshot.error}'));
          }

          final lectures = snapshot.data ?? [];

          if (lectures.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No lectures assigned to you.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lectures.length,
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              return _TeacherLectureAttendanceCard(
                lecture: lecture,
                teacherId: teacherId,
              );
            },
          );
        },
      ),
    );
  }
}

class _TeacherLectureAttendanceCard extends StatelessWidget {
  final Lecture lecture;
  final String teacherId;

  const _TeacherLectureAttendanceCard({
    required this.lecture,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWindowActive = lecture.isAttendanceWindowActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: lecture.attendanceSubmitted
              ? Colors.green.withValues(alpha: 0.5)
              : isWindowActive
                  ? const Color(0xFF0D47A1).withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lecture.subject,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Class: ${lecture.className}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF0D47A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  lecture.lectureCode,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE, MMM d').format(lecture.startDateTime),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('hh:mm a').format(lecture.startDateTime)} – ${DateFormat('hh:mm a').format(lecture.endDateTime)}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (isWindowActive && !lecture.attendanceSubmitted)
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _MarkLectureAttendanceScreen(
                              lecture: lecture,
                              teacherId: teacherId,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: Icon(
                  lecture.attendanceSubmitted
                      ? Icons.check_circle_rounded
                      : isWindowActive
                          ? Icons.fact_check_rounded
                          : Icons.lock_clock_rounded,
                  size: 18,
                ),
                label: Text(
                  lecture.attendanceSubmitted
                      ? 'Attendance Submitted ✓'
                      : isWindowActive
                          ? 'Start Attendance'
                          : 'Attendance Window Closed',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: lecture.attendanceSubmitted
                      ? Colors.green[700]
                      : const Color(0xFF0D47A1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK ATTENDANCE SCREEN (ROSTER + LIVE CLASS QUERY + TRANSACTION SUBMIT)
// ────────────────────────────────────────────────────────────────────────────
class _MarkLectureAttendanceScreen extends StatefulWidget {
  final Lecture lecture;
  final String teacherId;

  const _MarkLectureAttendanceScreen({
    required this.lecture,
    required this.teacherId,
  });

  @override
  State<_MarkLectureAttendanceScreen> createState() =>
      _MarkLectureAttendanceScreenState();
}

class _MarkLectureAttendanceScreenState
    extends State<_MarkLectureAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  // Map of studentId -> status ('Present', 'Absent', 'Late', 'Excused')
  final Map<String, String> _statuses = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  void _markAllPresent(List<QueryDocumentSnapshot> students) {
    setState(() {
      for (final s in students) {
        _statuses[s.id] = 'Present';
      }
    });
  }

  Future<void> _submit(List<QueryDocumentSnapshot> students) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Attendance Submission'),
        content: Text(
          'Submit attendance for ${students.length} students?\n\n'
          'Once submitted, attendance is locked and cannot be edited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            child: const Text('Submit & Lock'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final entries = students.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? data['email'] ?? 'Student';
        final status = _statuses[doc.id] ?? 'Present';
        return StudentMarkEntry(
          studentId: doc.id,
          studentName: name,
          status: status,
        );
      }).toList();

      await _attendanceService.submitLectureAttendance(
        lectureId: widget.lecture.id,
        teacherId: widget.teacherId,
        entries: entries,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance submitted successfully for ${widget.lecture.lectureCode}!',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lecture = widget.lecture;

    return Scaffold(
      appBar: AppBar(
        title: Text('${lecture.subject} (${lecture.className})'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Scoped student roster query by classId
        stream: FirebaseFirestore.instance
            .collection('classes')
            .doc(lecture.classId)
            .collection('members')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading students: ${snapshot.error}'));
          }

          final students = snapshot.data?.docs ?? [];

          if (students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No students found registered for class "${lecture.className}".\n'
                  'Assign students to this class in Manage Users first.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            );
          }

          // Pre-populate missing entries with 'Present'
          for (final s in students) {
            _statuses.putIfAbsent(s.id, () => 'Present');
          }

          return Column(
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code: ${lecture.lectureCode}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${students.length} Total Students',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _markAllPresent(students),
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text('Mark All Present'),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Student List Tiles
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final sData = student.data();
                    final name = sData['name'] ?? sData['email'] ?? 'Student';
                    final currentStatus = _statuses[student.id] ?? 'Present';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'Present', label: Text('Present')),
                                ButtonSegment(
                                    value: 'Absent', label: Text('Absent')),
                                ButtonSegment(
                                    value: 'Late', label: Text('Late')),
                                ButtonSegment(
                                    value: 'Excused', label: Text('Excused')),
                              ],
                              selected: {currentStatus},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _statuses[student.id] = val.first;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Submit Container
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : () => _submit(students),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Submit Attendance'),
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
// 2. STUDENT ATTENDANCE VIEW
// ────────────────────────────────────────────────────────────────────────────
class _StudentAttendanceView extends StatelessWidget {
  const _StudentAttendanceView();

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser?.uid;
    if (studentId == null) {
      return const Center(child: Text('Please sign in again.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance History')),
      body: _StudentRecordsWidget(studentId: studentId),
    );
  }
}

class _StudentRecordsWidget extends StatelessWidget {
  final String studentId;
  const _StudentRecordsWidget({required this.studentId});

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<List<StudentAttendance>>(
      stream: AttendanceService().studentAttendance(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];

        int present = records.where((r) => r.status == 'Present').length;
        int lateCount = records.where((r) => r.status == 'Late').length;
        int absent = records.where((r) => r.status == 'Absent').length;
        int excused = records.where((r) => r.status == 'Excused').length;
        int totalConducted = records.length;

        int attended = present + lateCount + excused;
        double rate = totalConducted == 0
            ? 0.0
            : (attended / totalConducted) * 100;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Percentage Card
            Card(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D47A1),
                      ),
                    ),
                    Text(
                      'Overall Attendance Rate',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Breakdown Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCountBadge('Present', present, Colors.green),
                _buildCountBadge('Late', lateCount, Colors.orange),
                _buildCountBadge('Absent', absent, Colors.red),
                _buildCountBadge('Excused', excused, Colors.blue),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Historical Records',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (records.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No attendance records found.',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...records.map((r) {
                Color c = Colors.green;
                if (r.status == 'Absent') c = Colors.red;
                if (r.status == 'Late') c = Colors.orange;
                if (r.status == 'Excused') c = Colors.blue;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.withValues(alpha: 0.15),
                      child: Icon(
                        r.isPresentOrLate
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: c,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      r.subject,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      r.submittedAt != null
                          ? DateFormat('EEE, MMM d, yyyy • hh:mm a').format(r.submittedAt!)
                          : r.lectureCode,
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    trailing: Chip(
                      label: Text(
                        r.status.toUpperCase(),
                        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: c.withValues(alpha: 0.1),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 3. PARENT ATTENDANCE VIEW
// ────────────────────────────────────────────────────────────────────────────
class _ParentAttendanceView extends StatelessWidget {
  final String? linkedChildEmail;
  const _ParentAttendanceView({this.linkedChildEmail});

  @override
  Widget build(BuildContext context) {
    final parentId = FirebaseAuth.instance.currentUser?.uid;
    if (parentId == null) {
      return const Center(child: Text('Please sign in again.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Child\'s Attendance')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(parentId)
            .snapshots(),
        builder: (context, parentSnapshot) {
          if (!parentSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final parentData = parentSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final email = linkedChildEmail ??
              parentData['childEmail'] ??
              parentData['linked_student_email'];

          if (email == null || email.toString().isEmpty) {
            return Center(
              child: Text(
                'No child account linked to your profile.',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .snapshots(),
            builder: (context, childSnap) {
              if (!childSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (childSnap.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'Student account for $email not found.',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                );
              }

              final childUid = childSnap.data!.docs.first.id;
              return _StudentRecordsWidget(studentId: childUid);
            },
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 4. OWNER / MANAGER ATTENDANCE VIEW (INSTITUTE SUMMARY)
// ────────────────────────────────────────────────────────────────────────────
class _OwnerAttendanceView extends StatelessWidget {
  const _OwnerAttendanceView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Institute Attendance Overview')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('lectures').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allLectures = (snapshot.data?.docs ?? [])
              .map((d) => Lecture.fromSnapshot(d))
              .toList();

          final submitted = allLectures.where((l) => l.attendanceSubmitted).toList();
          final pending = allLectures.where((l) => !l.attendanceSubmitted && l.status == 'scheduled').toList();

          int totalPresent = 0;
          int totalStudents = 0;

          for (final l in submitted) {
            try {
              final snapDoc = snapshot.data!.docs.firstWhere((d) => d.id == l.id);
              final map = snapDoc.data() as Map<String, dynamic>?;
              final summary = AttendanceSummary.fromMap(
                map?['attendanceSummary'] as Map<String, dynamic>?,
              );
              totalPresent += summary.present + summary.lateCount;
              totalStudents += summary.total;
            } catch (_) {}
          }

          double overallRate =
              totalStudents > 0 ? (totalPresent / totalStudents) * 100 : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        '${overallRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                      Text(
                        'Institute Student Attendance Rate',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text('${submitted.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Submitted'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.pending_actions, color: Colors.orange),
                        title: Text('${pending.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Pending'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Recent Submissions',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (submitted.isEmpty)
                Center(
                  child: Text(
                    'No submitted lectures found.',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                )
              else
                ...submitted.take(10).map((l) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(l.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text('Teacher: ${l.teacherName} • Class: ${l.className}'),
                      trailing: const Icon(Icons.verified, color: Colors.green),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
