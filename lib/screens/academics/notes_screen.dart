import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/study_material_model.dart';
import '../../services/study_material_service.dart';

/// NotesScreen — Production Study Materials & External Resource Hub
class NotesScreen extends StatefulWidget {
  final String userRole; // 'owner', 'manager', 'teacher', 'parent', 'student'

  const NotesScreen({super.key, required this.userRole});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final StudyMaterialService _materialService = StudyMaterialService();

  String _searchQuery = '';
  String? _selectedSubject;

  bool get isStaff =>
      widget.userRole == 'owner' ||
      widget.userRole == 'manager' ||
      widget.userRole == 'teacher';

  void _showAddMaterialDialog() {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    String? selectedClassId;
    String? selectedClassName;
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.library_books_rounded, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Text(
                'Share Study Resource Link',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resource Title *',
                    hintText: 'e.g. Unit 3 State Management Notes',
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                  builder: (context, snapshot) {
                    final classDocs = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Target Class *',
                        prefixIcon: Icon(Icons.class_rounded),
                      ),
                      items: classDocs.map((c) {
                        final data = c.data() as Map<String, dynamic>;
                        final name = data['name'] ?? c.id;
                        return DropdownMenuItem<String>(
                          value: c.id,
                          onTap: () => selectedClassName = name,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedClassId = val),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'e.g. Flutter Development',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'External URL Link *',
                    hintText: 'https://drive.google.com/file/d/12345',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Instructions for students...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  '💡 Accepts Google Drive, OneDrive, Dropbox, YouTube, or Website links.',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
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
                      final url = urlCtrl.text.trim();
                      try {
                        StudyMaterialService.validateUrl(url);

                        if (titleCtrl.text.trim().isEmpty || selectedClassId == null) {
                          setDialogState(() => errorText = 'Please enter title and select a class.');
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          errorText = null;
                        });

                        final user = FirebaseAuth.instance.currentUser;
                        final uid = user?.uid ?? '';
                        String teacherName = user?.displayName ?? user?.email ?? 'Teacher';

                        if (uid.isNotEmpty) {
                          final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                          if (uDoc.exists) {
                            teacherName = uDoc.data()?['name'] ?? uDoc.data()?['email'] ?? teacherName;
                          }
                        }

                        await _materialService.addMaterialLink(
                          title: titleCtrl.text,
                          description: descriptionCtrl.text,
                          classId: selectedClassId!,
                          className: selectedClassName ?? selectedClassId!,
                          subject: subjectCtrl.text.trim().isEmpty ? 'General' : subjectCtrl.text.trim(),
                          teacherId: uid,
                          teacherName: teacherName,
                          url: url,
                          createdBy: uid,
                        );

                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Study resource "${titleCtrl.text.trim()}" shared!'),
                              backgroundColor: Colors.green[700],
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorText = e.toString().replaceAll('ArgumentError: ', '');
                        });
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Share Resource'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openResourceUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch resource URL.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching link: $e')),
        );
      }
    }
  }

  IconData _getProviderIcon(String provider) {
    switch (provider) {
      case 'drive':
        return Icons.add_to_drive_rounded;
      case 'youtube':
        return Icons.video_library_rounded;
      case 'dropbox':
        return Icons.folder_shared_rounded;
      case 'onedrive':
        return Icons.cloud_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.language_rounded;
    }
  }

  Color _getProviderColor(String provider) {
    switch (provider) {
      case 'drive':
        return Colors.amber[800]!;
      case 'youtube':
        return Colors.red[700]!;
      case 'dropbox':
        return Colors.blue[700]!;
      case 'onedrive':
        return Colors.blue[900]!;
      case 'pdf':
        return Colors.red[900]!;
      default:
        return const Color(0xFF0D47A1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials & Resources'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final userClassId = (userData['classId'] ?? '').toString();

          Stream<List<StudyMaterialModel>> stream;
          if (isStaff) {
            stream = _materialService.allMaterialsStream();
          } else {
            final targetClassId = (widget.userRole == 'parent')
                ? (userData['linkedClassId'] ?? userClassId).toString()
                : userClassId;
            stream = _materialService.classMaterialsStream(targetClassId);
          }

          return StreamBuilder<List<StudyMaterialModel>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var materials = snapshot.data ?? [];

              // Filter by search query & subject
              if (_searchQuery.isNotEmpty) {
                materials = materials.where((m) {
                  return m.title.toLowerCase().contains(_searchQuery) ||
                      m.subject.toLowerCase().contains(_searchQuery) ||
                      m.className.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              if (_selectedSubject != null && _selectedSubject!.isNotEmpty) {
                materials = materials.where((m) => m.subject == _selectedSubject).toList();
              }

              final subjects = materials.map((m) => m.subject).toSet().toList();

              return Column(
                children: [
                  // Search & Filter Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search materials...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          ),
                        ),
                        if (subjects.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedSubject,
                            hint: const Text('Subject'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Subjects')),
                              ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                            ],
                            onChanged: (val) => setState(() => _selectedSubject = val),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Material Cards List
                  Expanded(
                    child: materials.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No study materials shared yet.',
                                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: materials.length,
                            itemBuilder: (context, index) {
                              final mat = materials[index];
                              final color = _getProviderColor(mat.provider);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: color.withValues(alpha: 0.12),
                                            child: Icon(_getProviderIcon(mat.provider), color: color),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  mat.title,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  'Subject: ${mat.subject} • Class: ${mat.className}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              mat.provider.toUpperCase(),
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: color.withValues(alpha: 0.1),
                                          ),
                                        ],
                                      ),
                                      if (mat.description.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          mat.description,
                                          style: GoogleFonts.poppins(fontSize: 13),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Text(
                                            'By ${mat.teacherName}'
                                            '${mat.createdAt != null ? ' • ${DateFormat('MMM d, yyyy').format(mat.createdAt!)}' : ''}',
                                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                          const Spacer(),
                                          if (isStaff)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text('Delete Resource?'),
                                                    content: Text('Delete "${mat.title}"?'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                      FilledButton(
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                        child: const Text('Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await _materialService.deleteMaterialLink(mat.materialId, uid);
                                                }
                                              },
                                            ),
                                          FilledButton.icon(
                                            onPressed: () => _openResourceUrl(mat.url),
                                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                            label: const Text('Open Resource'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF0D47A1),
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
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: _showAddMaterialDialog,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Share Resource Link'),
              backgroundColor: const Color(0xFF0D47A1),
            )
          : null,
    );
  }
}