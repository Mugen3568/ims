import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/permissions/permission_service.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';
import '../../services/lecture_service.dart';
import 'direct_messages_screen.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ClassesHome();
}

class _ClassesHome extends StatefulWidget {
  const _ClassesHome();
  @override
  State<_ClassesHome> createState() => _ClassesHomeState();
}

class _ClassesHomeState extends State<_ClassesHome> {
  final _service = ClassService();
  String _role = 'student';
  String _name = 'Member';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final data = profile.data() ?? {};
      if (mounted) {
        setState(() {
          _role = (data['role'] ?? 'student').toString().toLowerCase().trim();
          _name = (data['name'] ?? user.email?.split('@').first ?? 'Member').toString();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canCreate => PermissionService.canManageClasses(_role);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Classes (Role: $_role)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Direct messages',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DirectMessagesScreen()),
            ),
          ),
          if (_canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create class',
              onPressed: () => _showCreateClass(context),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.hasError) {
            return Center(child: Text('Error: ${userSnap.error}'));
          }
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data!.data() ?? {};
          final role =
              (userData['role'] ?? _role).toString().toLowerCase().trim();

          // ── 1. STUDENT BRANCH ──────────────────────────────────────────────
          if (role == 'student') {
            final classId = userData['classId'] as String?;
            if (classId == null || classId.trim().isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No class assigned.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .doc(classId)
                  .snapshots(),
              builder: (context, classSnap) {
                if (classSnap.hasError) {
                  return Center(
                    child: Text('Unable to load class: ${classSnap.error}'),
                  );
                }
                if (!classSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!classSnap.data!.exists) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Assigned class not found.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                final schoolClass = SchoolClass.fromSnapshot(classSnap.data!);
                if (!schoolClass.isActive) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Assigned class is inactive.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ClassCard(
                      schoolClass: schoolClass,
                      userId: userId,
                      role: role,
                    ),
                  ],
                );
              },
            );
          }

          // ── 2. PARENT BRANCH ───────────────────────────────────────────────
          if (role == 'parent') {
            final linkedStudentId = userData['linkedStudentId'] as String?;
            final ownClassId = userData['classId'] as String?;

            if (linkedStudentId != null && linkedStudentId.trim().isNotEmpty) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(linkedStudentId)
                    .snapshots(),
                builder: (context, studentSnap) {
                  if (studentSnap.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load student data: ${studentSnap.error}',
                      ),
                    );
                  }
                  if (!studentSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final studentData = studentSnap.data!.data() ?? {};
                  final studentClassId = studentData['classId'] as String?;

                  if (studentClassId == null || studentClassId.trim().isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No class assigned to child.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('classes')
                        .doc(studentClassId)
                        .snapshots(),
                    builder: (context, classSnap) {
                      if (classSnap.hasError) {
                        return Center(
                          child: Text(
                            'Unable to load class: ${classSnap.error}',
                          ),
                        );
                      }
                      if (!classSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!classSnap.data!.exists) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              "Child's assigned class not found.",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }

                      final schoolClass =
                          SchoolClass.fromSnapshot(classSnap.data!);
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _ClassCard(
                            schoolClass: schoolClass,
                            userId: userId,
                            role: role,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            } else if (ownClassId != null && ownClassId.trim().isNotEmpty) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('classes')
                    .doc(ownClassId)
                    .snapshots(),
                builder: (context, classSnap) {
                  if (classSnap.hasError) {
                    return Center(
                      child: Text('Unable to load class: ${classSnap.error}'),
                    );
                  }
                  if (!classSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!classSnap.data!.exists) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'Assigned class not found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  final schoolClass = SchoolClass.fromSnapshot(classSnap.data!);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ClassCard(
                        schoolClass: schoolClass,
                        userId: userId,
                        role: role,
                      ),
                    ],
                  );
                },
              );
            } else {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No linked student or class found.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
          }

          // ── 3. TEACHER BRANCH ──────────────────────────────────────────────
          if (role == 'teacher') {
            List<String> assignedClasses = [];
            if (userData['assignedClasses'] is List) {
              assignedClasses = List<String>.from(
                (userData['assignedClasses'] as List).map((e) => e.toString()),
              );
            }

            return _TeacherClassesView(
              assignedClassIds: assignedClasses,
              userId: userId,
              role: role,
            );
          }

          // ── 4. OWNER / MANAGER / SUPER ADMIN BRANCH ─────────────────────────
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.classes(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Unable to load classes: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final classes = snapshot.data!.docs
                  .map(SchoolClass.fromSnapshot)
                  .where((schoolClass) => schoolClass.isActive)
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (classes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No active classes yet.'),
                      ),
                    ),
                  ...classes.map(
                    (schoolClass) => _ClassCard(
                      schoolClass: schoolClass,
                      userId: userId,
                      role: role,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateClass(BuildContext context) async {
    final className = TextEditingController();
    final subject = TextEditingController();
    final description = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Class'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: className, decoration: const InputDecoration(labelText: 'Class name')),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Description (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (className.text.trim().isEmpty || subject.text.trim().isEmpty) return;
            try {
              final id = await _service.createClass(className: className.text.trim(), subject: subject.text.trim(), description: description.text.trim(), teacherId: FirebaseAuth.instance.currentUser!.uid, teacherName: _name);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              if (mounted) _showJoinCode(context, id);
            } catch (error) {
              if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
            }
          }, child: const Text('Create')),
        ],
      ),
    );
    if (created == true && mounted) setState(() {});
  }

  void _showJoinCode(BuildContext context, String classId) {
    FirebaseFirestore.instance.collection('classes').doc(classId).get().then((doc) {
      if (!mounted || !context.mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Class created'), content: Text('Share this class invite code:\n\n${doc.data()?['inviteCode'] ?? doc.data()?['joinCode'] ?? ''}', textAlign: TextAlign.center), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
    });
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.schoolClass,
    required this.userId,
    required this.role,
  });
  final SchoolClass schoolClass;
  final String? userId;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.class_outlined)),
        title: Text(schoolClass.className),
        subtitle: Text(
          '${schoolClass.subject}\n${schoolClass.memberCount} members • ${schoolClass.teacherName}',
        ),
        isThreeLine: true,
        trailing:
            role == 'teacher' && schoolClass.teacherId == userId
                ? const Icon(Icons.key)
                : null,
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ClassWorkspaceScreen(schoolClass: schoolClass),
              ),
            ),
      ),
    );
  }
}

class ClassWorkspaceScreen extends StatefulWidget {
  const ClassWorkspaceScreen({super.key, required this.schoolClass});
  final SchoolClass schoolClass;
  @override
  State<ClassWorkspaceScreen> createState() => _ClassWorkspaceScreenState();
}

class _ClassWorkspaceScreenState extends State<ClassWorkspaceScreen> {
  final _service = ClassService();
  final _lectureService = LectureService();
  final _message = TextEditingController();
  String _userRole = 'student';
  String _inviteCode = '';

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndClassData();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadUserRoleAndClassData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = (userDoc.data()?['role'] ?? 'student')
            .toString()
            .toLowerCase()
            .trim();

        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(widget.schoolClass.id)
            .get();
        final rawInvite = (classDoc.data()?['inviteCode'] ?? '').toString();
        String inviteCode = rawInvite;

        // If class lacks a 12-character registration inviteCode, staff auto-generates & backfills one now
        final isStaff = role == 'owner' || role == 'manager' || role == 'teacher' || role == 'super_admin';
        if (isStaff && (inviteCode.isEmpty || inviteCode == widget.schoolClass.joinCode || inviteCode.length < 10)) {
          inviteCode = await _service.regenerateInviteCode(
            widget.schoolClass.id,
            resetByUid: user.uid,
          );
        }

        if (mounted) {
          setState(() {
            _userRole = role;
            _inviteCode = inviteCode;
          });
        }
      } catch (e) {
        debugPrint('Error loading workspace data: $e');
      }
    }
  }

  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to delete "${widget.schoolClass.className}"?\n\nThis action cannot be undone.',
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
        await _service.deleteCourseClass(widget.schoolClass.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${widget.schoolClass.className}" deleted.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete class: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _scheduleLecture() async {
    final subject = TextEditingController(text: widget.schoolClass.subject);
    final room = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay start = TimeOfDay.now();
    TimeOfDay end = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Schedule Lecture'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
        TextField(controller: room, decoration: const InputDecoration(labelText: 'Room')),
        TextButton(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (picked != null) setDialogState(() => date = picked); }, child: Text('Date: ${date.day}/${date.month}/${date.year}')),
        TextButton(onPressed: () async { final picked = await showTimePicker(context: context, initialTime: start); if (picked != null) setDialogState(() => start = picked); }, child: Text('Start: ${start.format(context)}')),
        TextButton(onPressed: () async { final picked = await showTimePicker(context: context, initialTime: end); if (picked != null) setDialogState(() => end = picked); }, child: Text('End: ${end.format(context)}')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () async {
        final startAt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
        final endAt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
        try { await _lectureService.createLecture(classId: widget.schoolClass.id, className: widget.schoolClass.className, subject: subject.text.trim(), teacherId: widget.schoolClass.teacherId, teacherName: widget.schoolClass.teacherName, startDateTime: startAt, endDateTime: endAt, room: room.text.trim(), createdBy: FirebaseAuth.instance.currentUser!.uid); if (dialogContext.mounted) Navigator.pop(dialogContext); } catch (error) { if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error'))); }
      }, child: const Text('Save'))],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _userRole == 'owner' || _userRole == 'manager' || _userRole == 'super_admin';
    final canSeeInviteCode = _userRole == 'owner' || _userRole == 'manager' || _userRole == 'teacher' || _userRole == 'super_admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schoolClass.className),
        actions: [
          if (FirebaseAuth.instance.currentUser?.uid == widget.schoolClass.teacherId || canDelete)
            IconButton(
              icon: const Icon(Icons.add_alarm),
              tooltip: 'Schedule lecture',
              onPressed: _scheduleLecture,
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Class',
              onPressed: _deleteClass,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.schoolClass.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (canSeeInviteCode)
                      SelectableText('Class Invite Code: ${_inviteCode.isNotEmpty ? _inviteCode : widget.schoolClass.joinCode}'),
                  ],
                ),
                if (canSeeInviteCode && _inviteCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Invite Code: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      SelectableText(
                        _inviteCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _lectureService.classLectures(widget.schoolClass.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final lectures = snapshot.data!.docs.toList()..sort((a, b) => ((a.data()['startTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((b.data()['startTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
                if (lectures.isEmpty) return const Center(child: Text('No lectures scheduled.'));
                return ListView.builder(itemCount: lectures.length, itemBuilder: (context, index) { final data = lectures[index].data(); final start = (data['startTime'] as Timestamp?)?.toDate(); return ListTile(dense: true, leading: const Icon(Icons.schedule), title: Text(data['subject'] ?? 'Lecture'), subtitle: Text(start == null ? '' : '${start.day}/${start.month} ${TimeOfDay.fromDateTime(start).format(context)}'), trailing: Text(data['status'] ?? 'scheduled')); });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.messages(widget.schoolClass.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) return const Center(child: Text('No messages yet.'));
                return ListView.builder(reverse: true, itemCount: messages.length, itemBuilder: (context, index) { final data = messages[index].data(); return ListTile(title: Text(data['senderName'] ?? 'Member'), subtitle: Text(data['text'] ?? data['message'] ?? '')); });
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      decoration: const InputDecoration(hintText: 'Message class'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _message.text.trim();
                      if (text.isEmpty) return;
                      final user = FirebaseAuth.instance.currentUser!;
                      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                      await _service.sendMessage(classId: widget.schoolClass.id, senderId: user.uid, senderName: profile.data()?['name'] ?? 'Member', role: profile.data()?['role'] ?? 'member', message: text);
                      _message.clear();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherClassesView extends StatelessWidget {
  const _TeacherClassesView({
    required this.assignedClassIds,
    required this.userId,
    required this.role,
  });

  final List<String> assignedClassIds;
  final String? userId;
  final String role;

  @override
  Widget build(BuildContext context) {
    if (assignedClassIds.isNotEmpty) {
      return _TeacherAssignedClassesList(
        classIds: assignedClassIds,
        userId: userId,
        role: role,
      );
    }

    if (userId != null && userId!.isNotEmpty) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .where('teacherIds', arrayContains: userId)
            .snapshots(),
        builder: (context, fallbackSnap) {
          if (fallbackSnap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No classes assigned.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }
          if (!fallbackSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fallbackClasses = fallbackSnap.data!.docs
              .map(SchoolClass.fromSnapshot)
              .where((c) => c.isActive)
              .toList();

          if (fallbackClasses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No classes assigned.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: fallbackClasses
                .map(
                  (schoolClass) => _ClassCard(
                    schoolClass: schoolClass,
                    userId: userId,
                    role: role,
                  ),
                )
                .toList(),
          );
        },
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Text(
          'No classes assigned.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TeacherAssignedClassesList extends StatefulWidget {
  const _TeacherAssignedClassesList({
    required this.classIds,
    required this.userId,
    required this.role,
  });

  final List<String> classIds;
  final String? userId;
  final String role;

  @override
  State<_TeacherAssignedClassesList> createState() =>
      _TeacherAssignedClassesListState();
}

class _TeacherAssignedClassesListState
    extends State<_TeacherAssignedClassesList> {
  final Map<String, SchoolClass?> _loadedClasses = {};
  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subscriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribeToClasses();
  }

  @override
  void didUpdateWidget(covariant _TeacherAssignedClassesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listEquals(oldWidget.classIds, widget.classIds)) {
      _unsubscribe();
      _subscribeToClasses();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _unsubscribe() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _subscribeToClasses() {
    _unsubscribe();
    _loadedClasses.clear();
    if (widget.classIds.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _loading = true;
    int loadedCount = 0;
    for (final classId in widget.classIds) {
      final sub = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots()
          .listen(
        (docSnap) {
          if (docSnap.exists) {
            _loadedClasses[classId] = SchoolClass.fromSnapshot(docSnap);
          } else {
            _loadedClasses.remove(classId);
          }
          loadedCount++;
          if (mounted) {
            setState(() {
              if (loadedCount >= widget.classIds.length) {
                _loading = false;
              }
            });
          }
        },
        onError: (e) {
          debugPrint('Error loading class $classId: $e');
          loadedCount++;
          if (mounted) {
            setState(() {
              if (loadedCount >= widget.classIds.length) {
                _loading = false;
              }
            });
          }
        },
      );
      _subscriptions.add(sub);
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _loadedClasses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeClasses = widget.classIds
        .map((id) => _loadedClasses[id])
        .whereType<SchoolClass>()
        .where((c) => c.isActive)
        .toList();

    if (activeClasses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No classes assigned.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: activeClasses
          .map(
            (schoolClass) => _ClassCard(
              schoolClass: schoolClass,
              userId: widget.userId,
              role: widget.role,
            ),
          )
          .toList(),
    );
  }
}
