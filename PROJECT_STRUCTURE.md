# IMS (Institute Management System) — Project Architecture & AI Context Guide

This document provides a comprehensive overview of the **Institute Management System (IMS)** application. It is designed to serve as an authoritative reference for developers and AI coding assistants working on this codebase.

---

## 1. Executive Summary & Tech Stack

- **Application Name**: IMS (Institute Management System)
- **Framework**: Flutter (Dart 3.x) — Cross-platform (Android, Web, iOS, Windows, macOS, Linux)
- **Backend Services**:
  - **Firebase Authentication**: Email/Password authentication & session token management.
  - **Cloud Firestore**: Realtime NoSQL document database with custom security rules.
  - **Cloudinary**: Media and file storage service (documents, study materials, profile pictures).
  - **Sentry**: Error reporting and telemetry logging (`sentry.properties`).

---

## 2. Directory Structure (`lib/`)

```
lib/
├── core/                         # Core utilities, theme, and global constants
│   ├── constants/
│   │   └── status_constants.dart # Standardized status strings
│   ├── permissions/
│   │   ├── permission_service.dart # Frontend UI permission checker
│   │   └── roles.dart           # Role definitions & helpers
│   ├── services/
│   │   └── firestore_service.dart # Base Firestore query helper
│   ├── result.dart               # Sealed Result<T> pattern for safe error handling
│   ├── smooth_route.dart         # Custom page transition routes
│   └── theme.dart                # App styling, color palettes, dark/light themes
│
├── models/                       # Data models with fromSnapshot / toMap serializers
│   ├── app_user.dart             # User profile model & approval status
│   ├── attendance_model.dart     # Student & teacher attendance models
│   ├── class_model.dart          # CourseClass & SchoolClass models
│   ├── finance_model.dart        # Fee, StudentFee, & Transaction models
│   ├── institute_model.dart      # Institute branding & metadata
│   ├── lecture_model.dart        # Lecture schedule & cancellation models
│   ├── notification_model.dart   # In-app notification model
│   ├── report_model.dart         # Generated analytical report data models
│   ├── result_model.dart         # Test score & student result models
│   ├── study_material_model.dart # Uploaded document/study material model
│   └── test_model.dart           # Test/Exam definition model
│
├── repositories/                 # Abstract repository layer for data sources
│   ├── attendance_repository.dart
│   └── class_repository.dart
│
├── services/                     # Business logic & Firestore API integrations (19 services)
│   ├── approval_service.dart     # Manages user and parent approval queues
│   ├── attendance_pay_service.dart# Calculates teacher per-lecture compensation
│   ├── attendance_service.dart   # Student/Teacher attendance recording & stream listeners
│   ├── audit_log_service.dart    # Audit trail logger (detailed)
│   ├── audit_service.dart        # Simplified audit action logger
│   ├── auth_service.dart         # Login, registration, role checks, profile updates
│   ├── chat_service.dart         # Realtime chat messaging (legacy & hub)
│   ├── class_service.dart        # Class creation, invite code generation, member management
│   ├── cloudinary_service.dart   # Uploading images & files directly to Cloudinary
│   ├── conversation_service.dart # 1-on-1 direct messaging system
│   ├── finance_service.dart      # Fee assignment, payments, teacher payroll, payouts
│   ├── institute_service.dart    # Institute profile configuration
│   ├── lecture_service.dart      # Lecture scheduling, status transitions, cancellations
│   ├── migration_service.dart    # DB schema upgrade & data backfill script runner
│   ├── notification_service.dart # Creates & delivers user notifications
│   ├── report_service.dart       # Exports PDF/CSV analytics reports
│   ├── result_service.dart       # Test results calculation and storage
│   ├── storage_helper.dart       # Utility for file opening and web downloads
│   ├── study_material_service.dart# CRUD for study resources & notes
│   └── test_service.dart         # Test creation and management
│
├── screens/                      # UI Screens grouped by feature area
│   ├── academic/                 # AttendanceScreen, TestsScreen
│   ├── academics/                # NotesScreen
│   ├── admin/                    # Admin panel, user approval, class mgmt, reports, owner payroll
│   ├── alerts/                   # System alerts screen
│   ├── auth/                     # LoginScreen, SignUpScreen, PendingApprovalScreen
│   ├── community/                # Chat screens, conversations list
│   ├── fees/                     # Fee overview & payment history screens
│   ├── finance/                  # Financial dashboard & transactions
│   ├── lectures/                 # LecturesScreen, CreateLectureDialog
│   ├── manager/                  # Manager Dashboard
│   ├── notifications/            # Notification list screen
│   ├── parent/                   # Parent Dashboard
│   ├── profile/                  # User Profile & edit profile screen
│   ├── settings/                 # Settings screen
│   ├── student/                  # Student Dashboard, Join Class modal
│   ├── study_materials/          # Study Materials screen & upload dialog
│   ├── teacher/                  # Teacher Dashboard, lecture logs
│   └── tests/                    # Test creation dialogs & result entry forms
│
├── widgets/                      # Reusable Flutter components
│   ├── global_bottom_nav.dart    # Role-adaptive bottom navigation bar
│   ├── image_picker_widget.dart  # File selector with Cloudinary upload preview
│   ├── linked_student_profile_view.dart # Parent view for linked student profile
│   ├── material_card.dart        # Card display for study material files
│   ├── notification_badge.dart   # Unread notifications indicator badge
│   ├── notification_tile.dart    # Item list tile for notifications
│   ├── pending_parent_approval_widget.dart # Banner/card for parent approval
│   ├── pending_parent_requests.dart # Student list of pending parent link requests
│   ├── pending_staff_approval_widget.dart  # Admin banner for unapproved staff
│   ├── result_card.dart          # Test result display card
│   ├── role_diagnostic_widget.dart# Troubleshooting overlay for account roles
│   ├── teacher_payroll_widget.dart # Teacher salary & payout summary card
│   └── test_card.dart            # Test information card
│
├── firebase_options.dart         # Auto-generated Firebase cross-platform config
└── main.dart                     # App entrypoint, theme initialization, route handler
```

---

## 3. Role & Account Security Architecture

### System Roles (`role`)
The application defines six distinct roles:
1. `owner`: Full system owner. Can manage payroll, delete records, grant roles, edit settings.
2. `super_admin`: System administrator with identical privileges to `owner`.
3. `manager`: Institute manager. Can create classes, manage users, create fee structures, view reports.
4. `teacher`: Faculty member. Can mark attendance, schedule/cancel lectures, post tests, upload study materials.
5. `student`: Student account. Can join classes via invite codes, view schedule/attendance/results/fees, approve parent account links.
6. `parent`: Parent account. Linked to a student (`linkedStudentId`). Can view student's attendance, performance, and fee status.

### Account Approval States
Access is controlled via two status flags on the user document (`/users/{uid}`):
- `approvalStatus`: `'approved'` | `'pending'` | `'rejected'`
- `accountStatus`: `'active'` | `'pending'` | `'rejected'`

#### Approval Workflow Rules
- Users registering as **Teacher** or **Manager** start in `approvalStatus = 'pending'`. They cannot access dashboards until an `owner` or `manager` approves them.
- Users registering as **Parent** must select their student. The linked student (or an admin) must approve the parent link request before parent access is granted.
- **Students** and **Owners** default to `approvalStatus = 'approved'`.

---

## 4. Firestore Security Rules Engine (`firestore.rules`)

The system uses [firestore.rules](file:///d:/IMS/firestore.rules) to enforce document security server-side.

### Safe Helper Functions
To prevent rule execution errors when fields are missing or casing differs:
- `userExists()`: Checks `exists(/users/$(request.auth.uid))` before accessing `.data`.
- `getUserData()`: Returns user document data or `{}` if non-existent.
- `role()`: `getUserData().get('role', '').lower()` — case-insensitive role extraction.
- `isApproved()`: Checks `approvalStatus == 'approved'`, `isVerified == true`, or owner/super_admin roles, ensuring `accountStatus != 'rejected'`.

### Collection Summary & Permissions Matrix
| Collection | Read Rule | Write/Create Rule | Delete Rule |
| :--- | :--- | :--- | :--- |
| `/users/{userId}` | Signed-in users | Self profile (limited keys) OR Admin | Owner only |
| `/classes/{classId}` | Signed-in users | Admin (Student can increment memberCount on join) | Owner only |
| `/lectures/{lectureId}` | Signed-in users | Admin (Teacher can set `cancel_pending`) | Disabled |
| `/student_attendance` | Admin, Teacher (own), Student (own), Parent (linked) | Admin OR Teacher (own class) | Disabled |
| `/teacher_attendance` | Admin OR Teacher (own) | Admin OR Teacher (own) | Disabled |
| `/tests/{testId}` | Signed-in users | Admin OR Teacher | Admin only |
| `/results/{resultId}` | Admin, Teacher (own), Student (own), Parent (linked) | Admin OR Teacher | Admin only |
| `/study_materials` | Signed-in users | Admin OR Teacher | Admin OR Teacher (owner of doc) |
| `/fees` & `/student_fees`| Admin, Student (own), Parent (linked) | Admin only | Owner only (`fees`) / Disabled (`student_fees`) |
| `/financial_transactions`| Admin OR Party user | Admin only | Disabled |
| `/payroll` & `/payouts` | Admin OR Teacher (own) | Admin only | Owner only (`payroll`) / Disabled (`payouts`) |
| `/conversations` | Participants only | Participants only | Disabled |
| `/notifications` | Target receiver user | Admin, Teacher, Student, Parent | Disabled |
| `/audit_logs` | Admin only | Admin OR Teacher | Disabled |

---

## 5. Firestore Database Schemas

### 1. `users` (`/users/{userId}`)
```json
{
  "uid": "String",
  "name": "String",
  "email": "String",
  "role": "owner | super_admin | manager | teacher | student | parent",
  "approvalStatus": "approved | pending | rejected",
  "accountStatus": "active | pending | rejected",
  "phone": "String?",
  "photoUrl": "String?",
  "bio": "String?",
  "deviceToken": "String?",
  "linkedStudentId": "String? (For parent accounts)",
  "assignedClasses": ["String (classIds)"],
  "total_lectures_taken": "int (For teacher payroll tracking)",
  "unpaid_lectures": "int",
  "createdAt": "Timestamp"
}
```

### 2. `classes` (`/classes/{classId}`)
```json
{
  "className": "String",
  "course": "String",
  "semester": "int",
  "section": "String",
  "teacherId": "String",
  "teacherName": "String",
  "teacherIds": ["String"],
  "joinCode": "String (6-char uppercase)",
  "inviteCode": "String (12-char uppercase)",
  "isActive": "bool",
  "memberCount": "int",
  "createdAt": "Timestamp"
}
```

### 3. `lectures` (`/lectures/{lectureId}`)
```json
{
  "classId": "String",
  "className": "String",
  "teacherId": "String",
  "teacherName": "String",
  "subject": "String",
  "startTime": "Timestamp",
  "endTime": "Timestamp",
  "status": "scheduled | completed | cancelled | cancel_pending",
  "cancellationReason": "String?",
  "cancelledBy": "String?",
  "createdAt": "Timestamp"
}
```

### 4. `student_attendance` (`/student_attendance/{id}`)
```json
{
  "lectureId": "String",
  "classId": "String",
  "studentId": "String",
  "studentName": "String",
  "teacherId": "String",
  "date": "Timestamp",
  "status": "present | absent | late | excused",
  "createdAt": "Timestamp"
}
```

### 5. `tests` (`/tests/{testId}`) & `results` (`/results/{resultId}`)
```json
// Test document
{
  "classId": "String",
  "subject": "String",
  "title": "String",
  "maxMarks": "double",
  "testDate": "Timestamp",
  "teacherId": "String"
}

// Result document
{
  "testId": "String",
  "studentId": "String",
  "marksObtained": "double",
  "percentage": "double",
  "grade": "String",
  "remarks": "String?"
}
```

### 6. `study_materials` (`/study_materials/{materialId}`)
```json
{
  "title": "String",
  "description": "String",
  "fileUrl": "String (Cloudinary URL)",
  "fileType": "pdf | image | doc | link",
  "classId": "String",
  "subject": "String",
  "teacherId": "String",
  "teacherName": "String",
  "createdAt": "Timestamp"
}
```

### 7. `fees` & `student_fees`
```json
{
  "studentId": "String",
  "totalAmount": "double",
  "paidAmount": "double",
  "pendingAmount": "double",
  "dueDate": "Timestamp",
  "status": "paid | partial | pending | overdue"
}
```

---

## 6. Service Layer Reference (`lib/services/`)

1. **`AuthService`** ([auth_service.dart](file:///d:/IMS/lib/services/auth_service.dart)):
   - Handles email authentication, registration, user doc creation, role retrieval, and current user streams.

2. **`ClassService`** ([class_service.dart](file:///d:/IMS/lib/services/class_service.dart)):
   - Handles class creation with deterministic IDs (e.g. `BCA_Sem3_A`), join code lookup, teacher-to-class array syncing (`syncTeacherToClasses`), and invite code reset.

3. **`LectureService`** ([lecture_service.dart](file:///d:/IMS/lib/services/lecture_service.dart)):
   - Manages lecture scheduling, status updates (`completed`, `cancelled`), cancellation approval requests, and teacher conflict checks.

4. **`AttendanceService`** ([attendance_service.dart](file:///d:/IMS/lib/services/attendance_service.dart)):
   - Records student attendance, updates teacher lecture metrics, and streams attendance history per student or class.

5. **`FinanceService`** ([finance_service.dart](file:///d:/IMS/lib/services/finance_service.dart)):
   - Creates student fee structures, logs financial transactions, handles receipt generation, and calculates teacher per-lecture payouts.

6. **`CloudinaryService`** ([cloudinary_service.dart](file:///d:/IMS/lib/services/cloudinary_service.dart)):
   - Directly uploads images, PDFs, and media assets to Cloudinary via HTTP multipart requests and returns public CDN URLs.

7. **`ApprovalService`** ([approval_service.dart](file:///d:/IMS/lib/services/approval_service.dart)):
   - Handles staff account approvals (Owner/Manager approving Teachers) and parent link request approvals (Student approving Parent).

8. **`StudyMaterialService`** ([study_material_service.dart](file:///d:/IMS/lib/services/study_material_service.dart)):
   - Uploads and manages study notes and files linked to specific classes or subjects.

9. **`TestService`** & **`ResultService`**:
   - Manages test scheduling, score entry, grade calculation, and report generation.

10. **`NotificationService`**:
    - Dispatches in-app notifications and updates unread count streams.

---

## 7. Navigation & Dynamic Bottom Bar

The main navigation entrypoint uses [GlobalBottomNav](file:///d:/IMS/lib/widgets/global_bottom_nav.dart). The navigation tabs adapt dynamically based on `user.role`:

- **Owner / Super Admin / Manager**: Dashboard, Classes, Users, Finance, Settings.
- **Teacher**: Dashboard, My Classes, Attendance, Study Materials, Profile.
- **Student**: Dashboard, My Classes, Results, Study Materials, Profile.
- **Parent**: Dashboard, Student Performance, Attendance, Fees, Profile.

---

## 8. Development & Build Utility Scripts

- **`launch_web.bat`**: Runs the Flutter app locally in Google Chrome (`flutter run -d chrome`).
- **`launch_multiplatform.bat`**: Script for multi-device launch testing.
- **`setup_firebase.bat`**: Initializes FlutterFire CLI and configures [firebase_options.dart](file:///d:/IMS/lib/firebase_options.dart).
- **`build_all.bat`**: Builds production release bundles across targets.
- **`firebase.json`**: Firebase project settings linking [firestore.rules](file:///d:/IMS/firestore.rules) and [firestore.indexes.json](file:///d:/IMS/firestore.indexes.json).

---

## 9. Guidelines for Future AI Assistants & Developers

1. **Role Normalization**: Always use `.toLowerCase().trim()` when comparing or storing `role` values (`'owner'`, `'teacher'`, `'student'`, etc.) to maintain consistency with `firestore.rules`.
2. **Result Pattern**: Use `Result<T>` from [result.dart](file:///d:/IMS/lib/core/result.dart) for service calls where network failure or permission denial must be caught without throwing unhandled exceptions.
3. **Cloudinary Uploads**: When uploading files or user avatars, always use [CloudinaryService](file:///d:/IMS/lib/services/cloudinary_service.dart) instead of storing raw base64 or local paths in Firestore documents.
4. **Security Rules**: When adding new fields to Firestore collections, ensure any field validation in [firestore.rules](file:///d:/IMS/firestore.rules) uses `.get('field_name', default_value)` to prevent rule evaluation errors for existing documents.
