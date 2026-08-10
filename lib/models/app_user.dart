import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String approvalStatus;
  final String accountStatus;
  final String? classId; // Student & Parent
  final List<String> assignedClasses; // Teacher
  final String? childEmail; // Parent
  final String? linkedStudentId;
  final bool isVerified;
  final bool isProfileComplete;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.approvalStatus = 'approved',
    this.accountStatus = 'active',
    this.classId,
    this.assignedClasses = const [],
    this.childEmail,
    this.linkedStudentId,
    required this.isVerified,
    this.isProfileComplete = false,
    this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Safely parse assignedClasses from Firestore (could be null or a list)
    List<String> assignedClasses = [];
    if (data['assignedClasses'] is List) {
      assignedClasses = List<String>.from(
        (data['assignedClasses'] as List).map((e) => e.toString()),
      );
    }

    final bool isVerified = data['isVerified'] ?? false;
    final String approvalStatus = (data['approvalStatus'] ?? (isVerified ? 'approved' : 'pending')).toString().toLowerCase().trim();
    final String accountStatus = (data['accountStatus'] ?? (isVerified ? 'active' : 'pending')).toString().toLowerCase().trim();

    return AppUser(
      uid: doc.id,
      name: data['name'] ?? data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: (data['role'] ?? 'student').toString().toLowerCase().trim(),
      approvalStatus: approvalStatus,
      accountStatus: accountStatus,
      classId: data['classId'],
      assignedClasses: assignedClasses,
      linkedStudentId: data['linkedStudentId'],
      childEmail: data['childEmail'] ?? data['linked_student_email'],
      isVerified: isVerified,
      isProfileComplete:
          data['isProfileComplete'] ?? data['is_profile_complete'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      if (phone.isNotEmpty) 'phone': phone,
      'role': role,
      'approvalStatus': approvalStatus,
      'accountStatus': accountStatus,
      if (classId != null) 'classId': classId,
      if (assignedClasses.isNotEmpty) 'assignedClasses': assignedClasses,
      if (linkedStudentId != null) 'linkedStudentId': linkedStudentId,
      if (childEmail != null) 'childEmail': childEmail,
      'isVerified': isVerified,
      'isProfileComplete': isProfileComplete,
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? approvalStatus,
    String? accountStatus,
    String? classId,
    List<String>? assignedClasses,
    bool? isVerified,
    bool? isProfileComplete,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      accountStatus: accountStatus ?? this.accountStatus,
      classId: classId ?? this.classId,
      assignedClasses: assignedClasses ?? this.assignedClasses,
      childEmail: childEmail,
      linkedStudentId: linkedStudentId,
      isVerified: isVerified ?? this.isVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt,
    );
  }
}
