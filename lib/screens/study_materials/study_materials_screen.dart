import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/study_material_model.dart';
import '../../services/study_material_service.dart';
import '../../widgets/material_card.dart';
import 'add_material_dialog.dart';

class StudyMaterialsScreen extends StatefulWidget {
  final String userRole; // 'owner', 'manager', 'teacher', 'parent', 'student'

  const StudyMaterialsScreen({super.key, required this.userRole});

  bool get canUpload =>
      userRole == 'owner' || userRole == 'manager' || userRole == 'teacher';

  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  void _showAddDialog(BuildContext context, {StudyMaterial? editMaterial}) {
    showDialog(
      context: context,
      builder: (context) => AddMaterialDialog(
        userRole: widget.userRole,
        editMaterial: editMaterial,
      ),
    );
  }

  void _confirmDelete(BuildContext context, String materialId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await StudyMaterialService().deleteMaterial(materialId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Material deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Builds the materials list from a role-scoped stream.
  /// [stream] must already be constrained to the fields the rule checks,
  /// so no global collection read is attempted.
  Widget _buildMaterialList(
    BuildContext context,
    Stream<List<StudyMaterialModel>> stream,
    String currentUserId,
  ) {
    final theme = Theme.of(context);
    return StreamBuilder<List<StudyMaterialModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading study materials: ${snapshot.error}'));
        }

        final materials = snapshot.data ?? [];

        if (materials.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                const Text('No study materials shared yet.'),
                if (widget.canUpload) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Upload Material'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final mat = materials[index];
            return MaterialCard(
              material: mat,
              currentUserId: currentUserId,
              userRole: widget.userRole,
              onEdit: () => _showAddDialog(context, editMaterial: mat),
              onDelete: () => _confirmDelete(context, mat.id, mat.title),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = StudyMaterialService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
      ),
      // Outer StreamBuilder resolves the user's profile so we know classId /
      // linkedStudentId before choosing a scoped materials stream.
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData =
              userSnap.data?.data() as Map<String, dynamic>? ?? {};

          switch (widget.userRole) {
            // ── Admin roles: full collection read allowed by rules ──────────
            case 'owner':
            case 'manager':
              return _buildMaterialList(
                  context, service.allMaterialsStream(), currentUserId);

            // ── Teacher: own materials only (teacherId == uid) ──────────────
            case 'teacher':
              return _buildMaterialList(context,
                  service.teacherMaterialsStream(currentUserId), currentUserId);

            // ── Student: class materials (classId == student's classId) ─────
            case 'student':
              final classId =
                  (userData['classId'] as String? ?? '').trim();
              return _buildMaterialList(
                context,
                classId.isNotEmpty
                    ? service.classMaterialsStream(classId)
                    : Stream.value([]),
                currentUserId,
              );

            // ── Parent: child's class materials via linkedStudentId ──────────
            case 'parent':
              final linkedStudentId =
                  (userData['linkedStudentId'] as String? ?? '').trim();
              if (linkedStudentId.isEmpty) {
                return const Center(
                    child: Text('No child account linked.'));
              }
              // Read child's profile to obtain their classId
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(linkedStudentId)
                    .snapshots(),
                builder: (context, childSnap) {
                  if (!childSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final childData =
                      childSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final childClassId =
                      (childData['classId'] as String? ?? '').trim();
                  return _buildMaterialList(
                    context,
                    childClassId.isNotEmpty
                        ? service.classMaterialsStream(childClassId)
                        : Stream.value([]),
                    currentUserId,
                  );
                },
              );

            default:
              return const Center(
                  child: Text('Materials not available for your role.'));
          }
        },
      ),
      floatingActionButton: widget.canUpload
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add_link),
              label: const Text('Add Material'),
            )
          : null,
    );
  }
}
