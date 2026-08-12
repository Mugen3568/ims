import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/lecture_model.dart';
import '../../services/lecture_service.dart';
import 'create_lecture_dialog.dart';

/// LecturesScreen — Comprehensive Lecture Management Portal for Owner & Manager.
/// Features:
///   • Real-time schedule stream
///   • Cancellation Requests banner / review section (Approve / Reject)
///   • Create & Edit lecture forms (Attendance Lock enforced)
///   • Archive (soft-delete) instead of hard deletion
class LecturesScreen extends StatefulWidget {
  final String userRole; // 'owner', 'manager', 'teacher', 'student', 'parent'
  final String currentUserId;

  const LecturesScreen({
    super.key,
    required this.userRole,
    required this.currentUserId,
  });

  @override
  State<LecturesScreen> createState() => _LecturesScreenState();
}

class _LecturesScreenState extends State<LecturesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LectureService _lectureService = LectureService();

  bool get isOwnerOrManager =>
      widget.userRole == 'owner' || widget.userRole == 'manager';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: isOwnerOrManager ? 3 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateDialog([Lecture? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateLectureDialog(existingLecture: existing),
    );
  }

  Future<void> _archiveLecture(Lecture lecture) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Archive Lecture?'),
        content: Text(
          'Are you sure you want to archive "${lecture.subject}" (${lecture.lectureCode})?\n\n'
          'It will be hidden from normal timetables but preserved for attendance and payroll reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _lectureService.archiveLecture(lecture.id, widget.currentUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lecture ${lecture.lectureCode} archived.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectures & Schedule'),
        bottom: isOwnerOrManager
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF0D47A1),
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Schedule'),
                  Tab(text: 'Cancellation Requests'),
                  Tab(text: 'Archived'),
                ],
              )
            : null,
      ),
      floatingActionButton: isOwnerOrManager
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Lecture'),
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            )
          : null,
      body: isOwnerOrManager
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(isDark, false),
                _buildCancellationRequestsTab(isDark),
                _buildScheduleTab(isDark, true),
              ],
            )
          : _buildScheduleTab(isDark, false),
    );
  }

  Stream<List<Lecture>> _getLecturesStream(bool showArchivedOnly) {
    if (isOwnerOrManager) {
      return _lectureService.allLecturesStream(includeArchived: showArchivedOnly);
    } else if (widget.userRole == 'teacher') {
      return _lectureService.teacherLecturesStream(widget.currentUserId);
    } else {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .snapshots()
          .asyncExpand((userSnap) async* {
            final data = userSnap.data() ?? {};
            String classId = (data['classId'] ?? '').toString();
            if (widget.userRole == 'parent' && classId.isEmpty) {
              final linkedId = data['linkedStudentId'] as String?;
              if (linkedId != null && linkedId.isNotEmpty) {
                final studentDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(linkedId)
                    .get();
                classId = (studentDoc.data()?['classId'] ?? '').toString();
              }
            }
            yield* _lectureService.studentLecturesStream(classId);
          });
    }
  }

  // ── 1. SCHEDULE TAB (Active / Archived) ────────────────────────────────────
  Widget _buildScheduleTab(bool isDark, bool showArchivedOnly) {
    return StreamBuilder<List<Lecture>>(
      stream: _getLecturesStream(showArchivedOnly),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading schedule: ${snapshot.error}'));
        }

        var lectures = snapshot.data ?? [];

        if (showArchivedOnly) {
          lectures = lectures.where((l) => l.status == 'archived').toList();
        } else {
          lectures = lectures.where((l) => l.status != 'archived').toList();
        }

        if (lectures.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showArchivedOnly ? Icons.archive_outlined : Icons.calendar_today_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  showArchivedOnly
                      ? 'No archived lectures'
                      : 'No lectures scheduled yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                if (!showArchivedOnly && isOwnerOrManager) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Lecture'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: lectures.length,
          itemBuilder: (context, index) {
            final lecture = lectures[index];
            return _buildLectureCard(lecture, isDark);
          },
        );
      },
    );
  }

  // ── 2. CANCELLATION REQUESTS TAB ───────────────────────────────────────────
  Widget _buildCancellationRequestsTab(bool isDark) {
    return StreamBuilder<List<Lecture>>(
      stream: _lectureService.cancellationRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: Colors.green[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending cancellation requests',
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
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final lecture = requests[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'CANCELLATION REQUEST',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          lecture.lectureCode,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lecture.subject,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teacher: ${lecture.teacherName} • Class: ${lecture.className}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Scheduled: ${DateFormat('EEE, MMM d • hh:mm a').format(lecture.startDateTime)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reason: "${lecture.cancellationReason ?? 'No reason provided'}"',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _lectureService.rejectCancellation(
                            lectureId: lecture.id,
                            ownerUid: widget.currentUserId,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => _lectureService.approveCancellation(
                            lectureId: lecture.id,
                            ownerUid: widget.currentUserId,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green[700],
                          ),
                          child: const Text('Approve Cancellation'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── LECTURE CARD BUILDER ───────────────────────────────────────────────────
  Widget _buildLectureCard(Lecture lecture, bool isDark) {
    Color badgeColor = Colors.blue;
    IconData badgeIcon = Icons.schedule_rounded;

    switch (lecture.status) {
      case 'cancel_pending':
        badgeColor = Colors.orange;
        badgeIcon = Icons.pending_actions_rounded;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        badgeIcon = Icons.cancel_rounded;
        break;
      case 'completed':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle_rounded;
        break;
      case 'archived':
        badgeColor = Colors.grey;
        badgeIcon = Icons.archive_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            lecture.subject,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: badgeColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeColor),
                                const SizedBox(width: 4),
                                Text(
                                  lecture.status.replaceAll('_', ' ').toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ],
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
                      Text(
                        'Teacher: ${lecture.teacherName}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lock indicator / Popup menu
                if (lecture.attendanceSubmitted)
                  Tooltip(
                    message: 'Schedule locked (attendance submitted)',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                  )
                else if (isOwnerOrManager && lecture.status != 'archived')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (val) {
                      if (val == 'edit') _openCreateDialog(lecture);
                      if (val == 'archive') _archiveLecture(lecture);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Schedule'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined,
                                color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text('Archive Lecture',
                                style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Time metadata row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE, MMM d, yyyy').format(lecture.startDateTime),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time_rounded,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('hh:mm a').format(lecture.startDateTime)} – ${DateFormat('hh:mm a').format(lecture.endDateTime)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (lecture.room.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.meeting_room_outlined,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      lecture.room,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
