# 🎓 Institute Management System (IMS)

A multi-role educational management platform built with Flutter, Firebase, and Sentry.

**Version:** 2.1  
**Framework:** Flutter (Material 3)  
**Backend:** Firebase Authentication & Firestore  
**Monitoring:** Sentry  
**Web App:** https://ims-app-8e988.web.app

---

## 👥 Roles

| Role | Responsibilities |
|---|---|
| **Owner** | System administration, financial oversight, verification, payroll |
| **Manager** | Administration, scheduling, attendance, moderation |
| **Teacher** | Classes, attendance, materials, tests, payroll |
| **Student** | Schedules, materials, attendance, tests, class chats |
| **Super Admin** | Multi-institute management |

---

## 🛡️ Role & Permission Matrix

| Feature | Owner | Manager | Teacher | Student | Super Admin |
|---|:---:|:---:|:---:|:---:|:---:|
| User Management | ✅ | ✅ | ❌ | ❌ | ✅ |
| Lecture Scheduling | ✅ | ✅ | ❌ | ❌ | ❌ |
| Class Swaps | ✅ | ✅ | ✅ | ❌ | ❌ |
| Student Attendance | ✅ | ✅ | ✅ | ❌ | ❌ |
| Attendance Viewing | ✅ | ✅ | Own | Self | ❌ |
| Study Materials | ✅ | ✅ | ✅ | Read | ❌ |
| Teacher Payroll | ✅ | ✅ | Own | ❌ | ❌ |
| Class / Direct Messaging | ✅ | ✅ | ✅ | ✅ | ❌ |
| Tests & Grading | ✅ | ✅ | ✅ | ❌ | ❌ |
| Test Results | ✅ | ✅ | ✅ | Self | ❌ |

---

## 📦 Core Features

### 1. Authentication & Access

- Firebase Email/Password authentication
- Role-based user profiles in `/users/{userId}`
- New accounts default to `isVerified: false`, except students
- Admin verification controls operational access

### 2. Lecture & Schedule Management

- Teacher and class dropdowns loaded from Firestore
- Subject auto-fill
- Date/time pickers
- Optional room assignment
- Teacher class-swap request and approval workflow

### 3. Attendance

- Teachers mark students present/absent
- Attendance stored in Firestore
- Teacher lecture counters update automatically
- Real-time attendance dashboards for teachers and students

### 4. Study Materials

- Central `study_materials` collection
- Supports Google Drive, YouTube, OneDrive, Dropbox, and external links
- Owners, Managers, and Teachers can upload materials
- Provider-specific material indicators

### 5. Teacher Payroll

- Per-lecture rate configuration
- Automatic lecture and unpaid-lecture tracking
- Owner-controlled payout processing
- Payout records stored in `/payouts`
- Teacher payroll dashboard

### 6. Messaging

- Class group chats
- One-to-one messaging
- In-app alerts and notifications

### 7. Tests & Evaluation

- Staff can create tests
- Test results and grades stored in Firestore

---

## 🗄️ Firestore Schema

### `users/{userId}`

```text
name
email
role
isVerified
rate_per_lecture
total_lectures_taken
unpaid_lectures
