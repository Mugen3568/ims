import 'package:cloud_firestore/cloud_firestore.dart';

/// Legacy typedef for StudyMaterial
typedef StudyMaterial = StudyMaterialModel;

/// StudyMaterialModel — Represents an external study material link
class StudyMaterialModel {
  final String materialId;
  final String title;
  final String description;
  final String classId;
  final String className;
  final String subject;
  final String teacherId;
  final String teacherName;
  final String url;
  final String provider; // 'drive', 'youtube', 'dropbox', 'onedrive', 'website', 'pdf', 'other'
  final String createdBy;
  final DateTime? createdAt;

  StudyMaterialModel({
    String? materialId,
    String? id,
    required this.title,
    required this.description,
    required this.classId,
    required this.className,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    String? url,
    String? link,
    String? provider,
    String? createdBy,
    String? uploadedByRole,
    this.createdAt,
  })  : materialId = materialId ?? id ?? '',
        url = url ?? link ?? '',
        createdBy = createdBy ?? (teacherId.isNotEmpty ? teacherId : ''),
        provider = provider ?? detectProvider(url ?? link ?? '');

  String get id => materialId;
  String get link => url;

  /// Auto-detect provider from URL string
  static String detectProvider(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('drive.google.com') || lower.contains('docs.google.com')) {
      return 'drive';
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'youtube';
    }
    if (lower.contains('dropbox.com')) {
      return 'dropbox';
    }
    if (lower.contains('onedrive') || lower.contains('1drv.ms') || lower.contains('sharepoint.com')) {
      return 'onedrive';
    }
    if (lower.endsWith('.pdf') || lower.contains('/pdf/')) {
      return 'pdf';
    }
    return 'website';
  }

  factory StudyMaterialModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final urlStr = (data['url'] ?? data['link'] ?? '').toString();
    final p = (data['provider'] ?? detectProvider(urlStr)).toString();

    return StudyMaterialModel(
      materialId: doc.id,
      title: (data['title'] ?? data['name'] ?? 'Resource').toString(),
      description: (data['description'] ?? data['notes'] ?? '').toString(),
      classId: (data['classId'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      subject: (data['subject'] ?? 'General').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? data['uploadedBy'] ?? '').toString(),
      url: urlStr,
      provider: p,
      createdBy: (data['createdBy'] ?? data['teacherId'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  factory StudyMaterialModel.fromFirestore(DocumentSnapshot doc) =>
      StudyMaterialModel.fromSnapshot(doc);

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'classId': classId,
      'className': className,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'url': url,
      'link': url,
      'provider': provider,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  bool get isGoogleDrive => provider == 'drive';
  bool get isYouTube => provider == 'youtube';
  bool get isPdf => provider == 'pdf';
}
