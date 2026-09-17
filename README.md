# 🎓 Institute Management System (IMS) - Complete Master Documentation

**Version:** 2.1  
**Framework:** Flutter (Material 3 Design System)  
**Backend:** Firebase (Authentication & Firestore)  
**Monitoring:** Sentry Error Tracking  
**Target Package:** `com.ims.ims_app`  
**Firebase Project:** `ims-app-8e988`  
web-app-link= https://ims-app-8e988.web.app
---

## 📋 Table of Contents

1. [System Overview](#-system-overview)
2. [Role & Permission Matrix](#-role--permission-matrix)
3. [Core Feature Modules](#-core-feature-modules)
   - [Authentication & Access Control](#1-authentication--access-control)
   - [Lectures & Schedule Management](#2-lectures--schedule-management)
   - [Attendance Tracking](#3-attendance-tracking)
   - [Study Materials & Notes](#4-study-materials--notes)
   - [Teacher Payroll & Financials](#5-teacher-payroll--financials)
   - [Community & Messaging](#6-community--messaging)
   - [Tests & Evaluation](#7-tests--evaluation)
4. [Firestore Database Schema](#-firestore-database-schema)
5. [Firestore Security Rules](#-firestore-security-rules)
6. [Build, Deployment & Sentry Guide](#-build-deployment--sentry-guide)
7. [Troubleshooting & Maintenance](#-troubleshooting--maintenance)

---

## 🚀 System Overview

The **Institute Management System (IMS)** is a multi-role educational management platform designed for schools, coaching institutes, and universities. It unifies operations across six distinct user roles:

- **Owner**: Full system administration, financial oversight, user verification, and payroll management.
- **Manager**: Administrative management, lecture scheduling, attendance oversight, and community moderation.
- **Teacher**: Class management, attendance recording, study material uploads, test creation, and payroll tracking.
- **Student**: View class schedules, access study materials, track personal attendance, take tests, and participate in class chats.
- **Parent**: Monitor student attendance, track academic progress, view fee statements, and communicate with staff.
- **Super Admin**: Enterprise multi-tenant institute management.

---

## 🛡️ Role & Permission Matrix

| Feature Module | Owner | Manager | Teacher | Student | Parent | Super Admin |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **User Verification & Management** | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| **Schedule / Create Lectures** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Request / Volunteer Class Swaps** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Record Student Attendance** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **View Student Attendance** | ✅ | ✅ | ✅ (Own) | ✅ (Self) | ✅ (Child) | ❌ |
| **Upload Study Materials / Links** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Read Study Materials** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Teacher Payroll Oversight** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Personal Payroll Dashboard** | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Class Chats & Direct Messaging** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Create & Grade Tests** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **View Test Results** | ✅ | ✅ | ✅ | ✅ (Self) | ✅ (Child) | ❌ |

---

## 📦 Core Feature Modules

### 1. Authentication & Access Control
- **Email & Password Authentication** via Firebase Auth.
- **Multi-Role User Profile Creation** saved in `/users/{userId}`.
- **Account Verification Safeguard**: New registrations default to `isVerified: false` (except students). Admins verify users in Firestore to grant operational access.

### 2. Lectures & Schedule Management
- **Automated Teacher Dropdown**: Loads active teachers directly from Firestore (`users` where `role == 'teacher'`). Automatically binds `teacher_uid` and `teacher_name`.
- **Class Dropdown & Subject Auto-Fill**: Select active classes from the `classes` collection.
- **Interactive Date & Time Pickers**: Native date/time picker dialogs formatting clean ranges (e.g. `10:00 AM - 11:00 AM`).
- **Room Assignment**: Optional room/location field for lectures.
- **Lecture Swap Workflow**: Teachers can request class swaps; fellow teachers can volunteer; managers/owners approve swaps.

### 3. Attendance Tracking
- **Lecture Attendance Submission**: Teachers select present/absent statuses for students.
- **Automated Teacher Payroll Counter**: Submitting attendance increments `total_lectures_taken` and `unpaid_lectures` for the teacher and updates `/payroll/{teacherId}`.
- **Multi-Role Attendance Dashboards**: Real-time status cards for teachers, students, and parents.

### 4. Study Materials & Notes
- **Unified `study_materials` Firestore Collection**: Supports Google Drive, YouTube, OneDrive, Dropbox, and external cloud storage links.
- **Multi-Role Upload Rights**: Owners, Managers, and Teachers can post resources for specific classes or subjects.
- **Smart Material Icons**: Detects link provider (YouTube, Drive, Dropbox, PDF) and renders custom badges.

### 5. Teacher Payroll & Financials
- **Per-Lecture Rate Configuration**: Owners configure per-lecture rates (`rate_per_lecture`).
- **Payout Processing**: Owners process payouts clearing unpaid lecture counts and generating financial receipts in `/payouts`.
- **Personal Payroll Screen**: Teachers view total lectures conducted, unpaid lectures, per-lecture rate, and total pending payout.

### 6. Community & Messaging
- **Class Group Chats**: Messaging under `/classes/{classId}/messages`.
- **Direct Messages**: Real-time 1-on-1 conversations under `/conversations/{conversationId}`.
- **In-App Notification Banners**: Floating notifications for alerts under `/alerts`.

### 7. Tests & Evaluation
- **Test Creation**: Staff can create test schedules under `/tests`.
- **Grading & Results**: Grade recording stored under `/tests/{testId}/results`.

---

## 🗄️ Firestore Database Schema

### Key Collections:
- **`users/{userId}`**:
  `{ name, email, role, isVerified, rate_per_lecture, total_lectures_taken, unpaid_lectures, linkedStudentId }`
- **`lectures/{lectureId}`**:
  `{ subject, classId, className, teacherId, teacher_uid, teacher, teacher_name, date, startTime, endTime, time, room, status, needs_approval }`
- **`classes/{classId}`**:
  `{ className, subject, teacherId, teacherName, joinCode, isActive, memberCount }`
- **`study_materials/{materialId}`**:
  `{ title, description, link, url, classId, className, subject, type, uploadedBy, uploadedByRole, teacherId, createdAt }`
- **`student_attendance/{attendanceId}`**:
  `{ studentId, lectureId, classId, teacherId, subject, date, status, submittedAt }`
- **`teacher_attendance/{attendanceId}`**:
  `{ teacherId, lectureId, classId, subject, date, status, submittedAt }`
- **`payroll/{teacherId}`**:
  `{ teacherId, perLecture, completedLectures, unpaidLectures, pendingSalary, updatedAt }`
- **`payouts/{payoutId}`**:
  `{ teacher_id, teacher_name, unpaid_lectures, rate_per_lecture, total_pay, payment_mode, date }`

---

## 🔒 Firestore Security Rules

Deploy rules to Firebase using:
```bash
firebase deploy --only firestore:rules
```

Key rule highlights:
- **Users**: Users update their own non-protected profile fields & lecture counters (`total_lectures_taken`, `unpaid_lectures`). Managers/Owners have write access.
- **Lectures**: Read for signed-in users. Create/Update for teachers, managers, and owners.
- **Study Materials**: Read for signed-in users. Create/Update/Delete for teachers, managers, and owners.
- **Attendance**: Teachers create/update student & teacher attendance for their lectures. Owners/Managers have full read/write access.

---

## 🛠️ Build, Deployment & Sentry Guide

### Prerequisites
- Flutter SDK (v3.22+)
- Firebase CLI & Configured Google Services (`google-services.json`, `firebase_options.dart`)

### Building Release APK
Run the build command from project root (`d:\IMS`):
```powershell
flutter clean
flutter pub get
flutter build apk --release
```
- **Output Location**: `d:\IMS\build\app\outputs\flutter-apk\app-release.apk`

### Sentry Production Monitoring
- Integrated via `sentry_flutter` in `lib/main.dart`.
- Upload debug symbols after release build:
  ```powershell
  flutter pub run sentry_dart_plugin
  ```

---

## 🔧 Troubleshooting & Maintenance

1. **Permission Denied on Attendance Submission**:
   - Ensure `firestore.rules` is deployed so teachers can update `total_lectures_taken` and `unpaid_lectures` on `/users/{userId}`.
2. **Missing Teacher Name on Cards**:
   - Check that `teacher_name` or `teacher` field is passed during lecture creation.
3. **Theme Preference Reset**:
   - Theme settings persist in `shared_preferences`. Clean app data will reset to default Light mode.
