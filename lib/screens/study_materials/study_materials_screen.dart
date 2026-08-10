import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/study_material_model.dart';
import '../../services/study_material_service.dart';
import '../../widgets/material_card.dart';
import 'add_material_dialog.dart';

class StudyMaterialsScreen extends StatelessWidget {
  final String userRole; // 'owner', 'manager', 'teacher', 'parent', 'student'

  const StudyMaterialsScreen({super.key, required this.userRole});

  bool get canUpload => userRole == 'owner' || userRole == 'manager' || userRole == 'teacher';

  void _showAddDialog(BuildContext context, {StudyMaterial? editMaterial}) {
    showDialog(
      context: context,
      builder: (context) => AddMaterialDialog(
        userRole: userRole,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = StudyMaterialService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.allMaterials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading study materials: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
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
                  if (canUpload) ...[
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

          final materials = docs.map((doc) => StudyMaterial.fromFirestore(doc)).toList();
          materials.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return -1;
            if (b.createdAt == null) return 1;
            return b.createdAt!.compareTo(a.createdAt!);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final mat = materials[index];
              return MaterialCard(
                material: mat,
                currentUserId: currentUserId,
                userRole: userRole,
                onEdit: () => _showAddDialog(context, editMaterial: mat),
                onDelete: () => _confirmDelete(context, mat.id, mat.title),
              );
            },
          );
        },
      ),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add_link),
              label: const Text('Add Material'),
            )
          : null,
    );
  }
}
