🎓 Institute Management System (IMS) — Master Documentation

Version: 2.1
Framework: Flutter (Material 3)
Backend: Firebase Authentication & Firestore
Monitoring: Sentry
Package: com.ims.ims_app
Web App: https://ims-app-8e988.web.app

1. System Overview

IMS is a multi-role educational management platform for institutes, schools, and universities.

Roles: Owner, Manager, Teacher, Student, Super Admin

Owner: System administration, financial oversight, verification, payroll
Manager: Administration, scheduling, attendance, moderation
Teacher: Classes, attendance, materials, tests, payroll
Student: Schedules, materials, attendance, tests, class chats
Super Admin: Multi-institute management
2. Role & Permission Matrix
Feature	Owner	Manager	Teacher	Student	Super Admin
User Management	✅	✅	❌	❌	✅
Lecture Scheduling	✅	✅	❌	❌	❌
Class Swaps	✅	✅	✅	❌	❌
Student Attendance	✅	✅	✅	❌	❌
Attendance Viewing	✅	✅	Own	Self	❌
Study Materials	✅	✅	✅	Read	❌
Teacher Payroll	✅	✅	Own	❌	❌
Class / Direct Messaging	✅	✅	✅	✅	❌
Tests & Grading	✅	✅	✅	❌	❌
Test Results	✅	✅	✅	Self	❌
3. Core Features
Authentication & Access
Firebase Email/Password authentication
Role-based user profiles in /users/{userId}
New accounts default to isVerified: false, except students
Admin verification controls operational access
Lecture & Schedule Management
Teacher and class dropdowns loaded from Firestore
Subject auto-fill
Date/time pickers
Optional room assignment
Teacher class-swap request and approval workflow
Attendance
Teachers mark students present/absent
Attendance stored in Firestore
Teacher lecture counters update automatically
Real-time attendance dashboards for teachers and students
Study Materials
Central study_materials collection
Supports Drive, YouTube, OneDrive, Dropbox and external links
Owners, Managers and Teachers can upload materials
Provider-specific material indicators
Teacher Payroll
Per-lecture rate configuration
Automatic lecture and unpaid-lecture tracking
Owner-controlled payout processing
Payout records stored in /payouts
Teacher payroll dashboard
Messaging
Class group chats
One-to-one messaging
In-app alerts and notifications
Tests & Evaluation
Staff can create tests
Test results and grades stored in Firestore
4. Firestore Schema
users/{userId}
name
email
role
isVerified
rate_per_lecture
total_lectures_taken
unpaid_lectures
lectures/{lectureId}
subject
classId
className
teacherId
teacher_uid
teacher_name
date
startTime
endTime
time
room
status
needs_approval
classes/{classId}
className
subject
teacherId
teacherName
joinCode
isActive
memberCount
study_materials/{materialId}
title
description
link
url
classId
className
subject
type
uploadedBy
uploadedByRole
teacherId
createdAt
student_attendance/{attendanceId}
studentId
lectureId
classId
teacherId
subject
date
status
submittedAt
teacher_attendance/{attendanceId}
teacherId
lectureId
classId
subject
date
status
submittedAt
payroll/{teacherId}
teacherId
perLecture
completedLectures
unpaidLectures
pendingSalary
updatedAt
payouts/{payoutId}
teacher_id
teacher_name
unpaid_lectures
rate_per_lecture
total_pay
payment_mode
date
5. Firestore Security

Deploy with:

firebase deploy --only firestore:rules

Rules overview:

Users can update permitted profile information
Owners/Managers have administrative write access
Signed-in users can read lectures and study materials
Teachers, Managers and Owners can manage lectures/materials
Teachers manage attendance for their lectures
Owners/Managers have broader attendance access
6. Build & Deployment

Requirements

Flutter 3.22+
Firebase CLI
google-services.json
firebase_options.dart

Release APK

flutter clean
flutter pub get
flutter build apk --release

Output

build/app/outputs/flutter-apk/app-release.apk

Sentry

flutter pub run sentry_dart_plugin

Integrated using sentry_flutter.

7. Maintenance

Attendance permission errors: Verify Firestore rules are deployed.

Missing teacher names: Ensure teacher_name / teacher is stored during lecture creation.

Theme reset: Theme preferences use shared_preferences; clearing app data resets the theme.

Changes made

The Parent role and all parent-specific functionality have been completely removed, including:

Parent role
Parent permissions
Parent attendance access
Parent test-result access
Parent material access references
linkedStudentId from the user schema
Parent mentions in dashboards and feature descriptions

I also compressed the wording and schema so this reads more like technical project documentation rather than a large product specification, while keeping the important implementation details.
