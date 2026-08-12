import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/study_material_model.dart';
import '../services/storage_helper.dart';

class MaterialCard extends StatelessWidget {
  final StudyMaterial material;
  final String currentUserId;
  final String userRole;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const MaterialCard({
    super.key,
    required this.material,
    required this.currentUserId,
    required this.userRole,
    this.onDelete,
    this.onEdit,
  });

  bool get isOwnerOrManager => userRole == 'owner' || userRole == 'manager';
  bool get isOwnMaterial => material.teacherId == currentUserId;
  bool get canModify => isOwnerOrManager || isOwnMaterial;

  Future<void> _openLink(BuildContext context, String url) async {
    final cleanUrl = StorageHelper.formatCloudUrl(url);
    if (cleanUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid material link URL.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      final Uri uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open external link.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconText = StorageHelper.getProviderIcon(material.link);

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
                  child: Text(iconText, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Teacher: ${material.teacherName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canModify) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (material.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                material.description,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    material.subject.isEmpty ? 'General' : material.subject,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (material.className.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      material.className,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openLink(context, material.link),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
