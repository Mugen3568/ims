import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/lecture_model.dart';
import '../../services/lecture_service.dart';
import '../academic/attendance_screen.dart';

/// TeacherLecturesScreen — Scoped view for teachers to manage assigned lectures.
/// Allows starting attendance and requesting schedule cancellations.
class TeacherLecturesScreen extends StatefulWidget {
  const TeacherLecturesScreen({super.key});

  @override
  State<TeacherLecturesScreen> createState() => _TeacherLecturesScreenState();
}

class _TeacherLecturesScreenState extends State<TeacherLecturesScreen> {
  final LectureService _lectureService = LectureService();

  void _showRequestCancellationDialog(Lecture lecture) {
    final reasonCtrl = TextEditingController();
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Request Cancellation',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requesting cancellation for ${lecture.subject} (${lecture.className}).\n'
                'An owner or manager must approve this request.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for Cancellation *',
                  hintText: 'e.g. Personal emergency, Illness',
                  alignLabelWithHint: true,
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 11),
                ),
              ],
            ],
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
                      final reason = reasonCtrl.text.trim();
                      if (reason.isEmpty) {
                        setDialogState(() => errorText = 'Please enter a reason.');
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await _lectureService.requestCancellation(
                          lectureId: lecture.id,
                          teacherUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                          reason: reason,
                        );

                        if (dialogCtx.mounted) {
                          final messenger = ScaffoldMessenger.of(dialogCtx);
                          Navigator.pop(dialogCtx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Cancellation request submitted to management.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorText = e.toString().replaceAll('StateError: ', '');
                        });
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scheduled Lectures'),
      ),
      body: StreamBuilder<List<Lecture>>(
        stream: _lectureService.teacherLecturesStream(user?.uid ?? ''),
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
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
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
              return _buildTeacherLectureCard(lecture, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildTeacherLectureCard(Lecture lecture, bool isDark) {
    Color badgeColor = Colors.blue;
    if (lecture.status == 'cancel_pending') badgeColor = Colors.orange;
    if (lecture.status == 'cancelled') badgeColor = Colors.red;
    if (lecture.status == 'completed') badgeColor = Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject & Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    lecture.subject,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor, width: 1),
                  ),
                  child: Text(
                    lecture.status.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Class: ${lecture.className}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF0D47A1),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Date & Time
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE, MMM d, yyyy').format(lecture.startDateTime),
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

            if (lecture.status == 'cancel_pending') ...[
              const SizedBox(height: 10),
              Text(
                'Cancellation pending: "${lecture.cancellationReason ?? ''}"',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.orange[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                // Start Attendance
                Expanded(
                  child: FilledButton.icon(
                    onPressed: lecture.status == 'cancelled'
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AttendanceScreen(userRole: 'teacher'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      lecture.attendanceSubmitted ? 'Attendance Taken' : 'Start Attendance',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: lecture.attendanceSubmitted
                          ? Colors.green[700]
                          : const Color(0xFF0D47A1),
                    ),
                  ),
                ),
                if (lecture.status == 'scheduled') ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showRequestCancellationDialog(lecture),
                    icon: const Icon(Icons.cancel_schedule_send_rounded, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange[800]!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
