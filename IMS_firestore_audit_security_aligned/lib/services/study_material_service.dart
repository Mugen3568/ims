import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/study_material_model.dart';
import 'audit_service.dart';

/// Production-Ready Study Materials & External Resource Service
class StudyMaterialService {
  StudyMaterialService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // Strict Uri Validation Helper
  // ────────────────────────────────────────────────────────────────────────────

  static void validateUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Resource URL cannot be empty.');
    }

    final uri = Uri.tryParse(clean);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError(
        'Invalid URL: Please enter a complete web link starting with http:// or https://',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Add External Resource Link
  // ────────────────────────────────────────────────────────────────────────────

  Future<String> addMaterialLink({
    required String title,
    required String description,
    required String classId,
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    required String url,
    required String createdBy,
  }) async {
    validateUrl(url);

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Resource title cannot be empty.');
    }

    final provider = StudyMaterialModel.detectProvider(url);
    final materialRef = _db.collection('study_materials').doc();

    final model = StudyMaterialModel(
      materialId: materialRef.id,
      title: cleanTitle,
      description: description.trim(),
      classId: classId,
      className: className,
      subject: subject.trim().isEmpty ? 'General' : subject.trim(),
      teacherId: teacherId,
      teacherName: teacherName,
      url: url.trim(),
      provider: provider,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await materialRef.set(model.toMap());

    await AuditService(firestore: _db).log(
      userId: createdBy,
      action: 'Added study material link "${model.title}" ($provider) for class $className',
      module: 'StudyMaterials',
      entityId: materialRef.id,
    );

    return materialRef.id;
  }

  /// Legacy addMaterial helper
  Future<void> addMaterial(StudyMaterialModel model) async {
    await addMaterialLink(
      title: model.title,
      description: model.description,
      classId: model.classId,
      className: model.className,
      subject: model.subject,
      teacherId: model.teacherId,
      teacherName: model.teacherName,
      url: model.url,
      createdBy: model.createdBy,
    );
  }

  /// Legacy updateMaterial helper
  Future<void> updateMaterial(String docId, Map<String, dynamic> data) async {
    await _db.collection('study_materials').doc(docId).set(data, SetOptions(merge: true));
  }

  /// Delete Resource Link
  Future<void> deleteMaterialLink(String materialId, String deletedBy) async {
    await _db.collection('study_materials').doc(materialId).delete();
    await AuditService(firestore: _db).log(
      userId: deletedBy,
      action: 'Deleted study material $materialId',
      module: 'StudyMaterials',
      entityId: materialId,
    );
  }

  /// Legacy deleteMaterial helper
  Future<void> deleteMaterial(String materialId) async {
    await _db.collection('study_materials').doc(materialId).delete();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Scoped Streams
  // ────────────────────────────────────────────────────────────────────────────

  /// Legacy QuerySnapshot stream for older UI widgets
  Stream<QuerySnapshot<Map<String, dynamic>>> allMaterials() {
    return _db.collection('study_materials').snapshots();
  }

  /// Stream of all materials for staff
  Stream<List<StudyMaterialModel>> allMaterialsStream() {
    return _db.collection('study_materials').snapshots().map((snap) {
      final list =
          snap.docs.map((d) => StudyMaterialModel.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream of study materials scoped to a specific class
  Stream<List<StudyMaterialModel>> classMaterialsStream(String classId) {
    return _db
        .collection('study_materials')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => StudyMaterialModel.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream of materials uploaded by a teacher
  Stream<List<StudyMaterialModel>> teacherMaterialsStream(String teacherId) {
    return _db
        .collection('study_materials')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => StudyMaterialModel.fromSnapshot(d)).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}
