import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/class_model.dart';
import '../../models/lecture_model.dart';
import '../../services/class_service.dart';
import '../../services/lecture_service.dart';

/// Dialog for creating or editing a lecture.
/// Features dynamic teacher filtering (class.teacherIds) and real-time conflict checking.
class CreateLectureDialog extends StatefulWidget {
  final Lecture? existingLecture;

  const CreateLectureDialog({super.key, this.existingLecture});

  @override
  State<CreateLectureDialog> createState() => _CreateLectureDialogState();
}

class _CreateLectureDialogState extends State<CreateLectureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _windowCtrl = TextEditingController(text: '15');

  final ClassService _classService = ClassService();
  final LectureService _lectureService = LectureService();

  CourseClass? _selectedClass;
  String? _selectedTeacherId;
  String? _selectedTeacherName;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.existingLecture != null) {
      final l = widget.existingLecture!;
      _subjectCtrl.text = l.subject;
      _roomCtrl.text = l.room;
      _windowCtrl.text = l.attendanceWindow.toString();

      _selectedTeacherId = l.teacherId;
      _selectedTeacherName = l.teacherName;
      _selectedDate = l.startDateTime;
      _startTime = TimeOfDay.fromDateTime(l.startDateTime);
      _endTime = TimeOfDay.fromDateTime(l.endDateTime);
    } else {
      _loadInstituteSettings();
    }
  }

  Future<void> _loadInstituteSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('institute')
          .get();
      if (doc.exists && mounted) {
        final windowMins = (doc.data()?['attendanceWindowMinutes'] as num?)?.toInt();
        if (windowMins != null && windowMins > 0) {
          setState(() {
            _windowCtrl.text = windowMins.toString();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    _windowCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto-adjust end time if start >= end
        final startMins = _startTime.hour * 60 + _startTime.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          _endTime = TimeOfDay(
            hour: (_startTime.hour + 1) % 24,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClass == null && widget.existingLecture == null) {
      setState(() => _errorMessage = 'Please select a class.');
      return;
    }
    if (_selectedTeacherId == null || _selectedTeacherId!.isEmpty) {
      setState(() => _errorMessage = 'Please select an assigned teacher.');
      return;
    }

    final startDT = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDT = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (!startDT.isBefore(endDT)) {
      setState(() => _errorMessage = 'Start time must be strictly before end time.');
      return;
    }

    final windowMins = int.tryParse(_windowCtrl.text.trim()) ?? 15;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final classId = _selectedClass?.id ?? widget.existingLecture!.classId;
    final className = _selectedClass?.displayName ?? widget.existingLecture!.className;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.existingLecture == null) {
        // Create new lecture
        await _lectureService.createLecture(
          classId: classId,
          className: className,
          subject: _subjectCtrl.text.trim(),
          teacherId: _selectedTeacherId!,
          teacherName: _selectedTeacherName ?? 'Teacher',
          room: _roomCtrl.text.trim(),
          startDateTime: startDT,
          endDateTime: endDT,
          createdBy: currentUid,
          attendanceWindow: windowMins,
        );
      } else {
        // Edit existing lecture
        await _lectureService.updateLecture(
          lectureId: widget.existingLecture!.id,
          classId: classId,
          className: className,
          subject: _subjectCtrl.text.trim(),
          teacherId: _selectedTeacherId!,
          teacherName: _selectedTeacherName ?? 'Teacher',
          room: _roomCtrl.text.trim(),
          startDateTime: startDT,
          endDateTime: endDT,
          updatedBy: currentUid,
          attendanceWindow: windowMins,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingLecture == null
                  ? 'Lecture created successfully!'
                  : 'Lecture updated successfully!',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMins = (_endTime.hour * 60 + _endTime.minute) -
        (_startTime.hour * 60 + _startTime.minute);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            widget.existingLecture == null
                ? Icons.add_alarm_rounded
                : Icons.edit_calendar_rounded,
            color: const Color(0xFF0D47A1),
          ),
          const SizedBox(width: 10),
          Text(
            widget.existingLecture == null
                ? 'Create Lecture'
                : 'Edit Lecture',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. CLASS SELECTION ───────────────────────────────────────
                if (widget.existingLecture == null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, userSnap) {
                      String role = 'staff';
                      if (userSnap.hasData && userSnap.data!.exists) {
                        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                        role = (userData['role'] ?? 'staff').toString().toLowerCase();
                      }
                      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                      return StreamBuilder<List<CourseClass>>(
                        stream: _classService.streamClassesForUser(
                          uid: currentUid,
                          role: role,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Select Class *',
                                prefixIcon: Icon(Icons.class_rounded),
                              ),
                              child: Text('Loading classes...', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          final classes = snapshot.data ?? [];

                          if (classes.isEmpty) {
                            return const InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Select Class *',
                                prefixIcon: Icon(Icons.class_rounded),
                              ),
                              child: Text('No classes assigned', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          return DropdownButtonFormField<CourseClass>(
                            decoration: const InputDecoration(
                              labelText: 'Select Class *',
                              prefixIcon: Icon(Icons.class_rounded),
                            ),
                            isExpanded: true,
                            hint: const Text('Choose active class'),
                            items: classes
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.displayName),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClass = val;
                                _selectedTeacherId = null;
                                _selectedTeacherName = null;
                              });
                            },
                            validator: (val) => val == null && widget.existingLecture == null
                                ? 'Please select a class'
                                : null,
                          );
                        },
                      );
                    },
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      prefixIcon: Icon(Icons.class_rounded),
                    ),
                    child: Text(
                      widget.existingLecture!.className,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── 2. DYNAMIC TEACHER SELECTION ──────────────────────────────
                // Filtered by class.teacherIds & teacher.assignedClasses
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'teacher')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final allTeachers = snapshot.data?.docs ?? [];

                    // Filter teachers that belong to the selected class
                    final targetClassId =
                        _selectedClass?.id ?? widget.existingLecture?.classId;

                    List<QueryDocumentSnapshot> eligibleTeachers = [];
                    if (targetClassId != null && targetClassId.isNotEmpty) {
                      eligibleTeachers = allTeachers.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        // Check teacher's assignedClasses array
                        final assigned = data['assignedClasses'] as List? ?? [];
                        final inAssigned = assigned.contains(targetClassId);

                        // Check class.teacherIds array if class object is available
                        final inClassIndex =
                            _selectedClass?.teacherIds.contains(doc.id) ?? false;

                        return inAssigned || inClassIndex;
                      }).toList();
                    } else {
                      eligibleTeachers = allTeachers;
                    }

                    if (targetClassId != null && eligibleTeachers.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          'No teachers assigned to this class yet. Assign a teacher in Manage Users.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.orange[800],
                          ),
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Teacher *',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      isExpanded: true,
                      hint: const Text('Select teacher'),
                      items: eligibleTeachers.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? data['email'] ?? 'Teacher';
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(name),
                          onTap: () {
                            _selectedTeacherName = name;
                          },
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTeacherId = val);
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please select a teacher'
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── 3. SUBJECT & ROOM ──────────────────────────────────────────
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'e.g. Flutter, Mathematics, Physics',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter subject name'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room / Lab',
                    hintText: 'e.g. Room A-102, Lab 2',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 4. DATE PICKER ─────────────────────────────────────────────
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 5. START & END TIMES ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStartTime,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            prefixIcon: Icon(Icons.access_time_rounded),
                          ),
                          child: Text(
                            _startTime.format(context),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEndTime,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            prefixIcon: Icon(Icons.access_time_filled_rounded),
                          ),
                          child: Text(
                            _endTime.format(context),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Duration badge
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: ${durationMins > 0 ? '$durationMins mins' : 'Invalid range'}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: durationMins > 0 ? Colors.grey[600] : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 6. ATTENDANCE WINDOW ───────────────────────────────────────
                TextFormField(
                  controller: _windowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Attendance Buffer (Minutes)',
                    hintText: 'e.g. 15',
                    prefixIcon: Icon(Icons.more_time_rounded),
                  ),
                ),

                // Error alert message box
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
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
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(widget.existingLecture == null ? 'Create Lecture' : 'Save Changes'),
        ),
      ],
    );
  }
}
