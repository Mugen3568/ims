# IMS (Institute Management System) — Manual QA Test Plan

**Purpose:** Give Antigravity (or any tester) a step-by-step script to manually verify account creation, authentication, approval workflows, and every role's feature set, end-to-end against the live Firebase backend.

**How to use this doc:** Work top to bottom. Sections 1–2 must pass before anything else is meaningful (every other feature depends on auth + role + approval state being correct). Each test case has an ID, Steps, and Expected Result — log Pass/Fail/Notes next to each as you go. Anywhere a Firestore write should be *rejected*, that's testing `firestore.rules`, not a bug in the UI — confirm the rejection is a permission-denied error, not a crash.

---

## 0. Test Setup

- [ ] Confirm you're pointed at a **test/staging Firebase project**, not production (check `firebase_options.dart` / the Firebase console project ID before doing anything destructive). This is critical — the seeded Owner account below has full delete/payroll privileges.
- [ ] Have on hand: 1 email you can create multiple `+alias` variants from (e.g. `you+owner@gmail.com`, `you+teacher1@gmail.com`, ...) since Firebase Auth requires unique emails.
- [ ] Prepare test accounts for **all 6 roles**: `owner` (seeded, see below), `super_admin`, `manager`, `teacher` (x2, for conflict tests), `student` (x2, for class/parent tests), `parent`.

### Seeded Test Credentials

| Role | Email | Password | Notes |
|---|---|---|---|
| Owner | `0562619983s@gmail.com` | `12345678` | Pre-existing account, `approvalStatus: approved` expected by default. Use this as the anchor account for all Owner-only actions (APR-01/02/04, CLS-01/04/05, ADM-01/02, FIN-01/02/06/09, TST-06) and to seed the other 5 role accounts during REG-02–REG-05. **Rotate this password after the test cycle** since it's now recorded in this doc. |

All other role accounts referenced below (`teacher1@...`, `student1@...`, `parent1@...`, etc.) should be created fresh during Section 1 using the owner account above to perform any approvals they require.
- [ ] Have a way to directly inspect Firestore (Firebase Console) to verify `approvalStatus`, `accountStatus`, and `role` fields match what the UI implies — don't just trust the UI.
- [ ] Run on at least 2 platforms if possible (e.g. Chrome web + Android) since this is a cross-platform Flutter app — note any platform-specific failures separately.

---

## 1. Registration & Role-Specific Onboarding

| ID | Steps | Expected Result |
|---|---|---|
| REG-01 | Sign up as **Student**: fill form, submit | Account created; Firestore `users/{uid}` has `role: student`, `approvalStatus: approved`, `accountStatus: active`. Lands directly on Student Dashboard — no approval wait. |
| REG-02 | Sign up as **Teacher** | Account created with `approvalStatus: pending`. User is redirected to **PendingApprovalScreen**, cannot reach Teacher Dashboard. |
| REG-03 | Sign up as **Manager** | Same as REG-02 — `pending`, blocked from dashboard until approved. |
| REG-04 | Sign up as **Owner** (if self-registration for Owner is exposed in UI — otherwise seed via console) | `approvalStatus: approved` by default per spec. Confirm this is actually true in Firestore, not just assumed. |
| REG-05 | Sign up as **Parent**: during signup, search/select the linked student | `linkedStudentId` set correctly; parent request appears in the **student's** pending-parent-requests list; parent cannot access Parent Dashboard yet. |
| REG-06 | Attempt signup with an email already in use | Clear error shown, no duplicate `users` doc created. |
| REG-07 | Attempt signup with malformed email / weak password | Client-side validation blocks it before hitting Firebase Auth. |
| REG-08 | Force-kill the app mid-registration (after Auth account created but before Firestore `users` doc write completes) | On relaunch/login, verify the app doesn't crash or infinite-loop on a missing user doc — check how `AuthService` / role retrieval handles a Firebase Auth user with no matching Firestore profile. |

---

## 2. Login & Session

| ID | Steps | Expected Result |
|---|---|---|
| LOGIN-01 | Log in as Owner (`0562619983s@gmail.com` / `12345678`), then repeat for each of the other 5 approved role accounts | Each lands on the **correct role-specific dashboard** (owner/super_admin/manager → admin-style; teacher → Teacher Dashboard; student → Student Dashboard; parent → Parent Dashboard). |
| LOGIN-02 | Log in with a **pending** teacher/manager account | Routed to PendingApprovalScreen, not the dashboard, even though Auth login succeeded. |
| LOGIN-03 | Log in with wrong password | Clear error, no partial navigation. |
| LOGIN-04 | Log in with a **rejected** account (`approvalStatus: rejected` or `accountStatus: rejected`) | User is blocked with an appropriate message — verify they can't route around it by killing/reopening the app. |
| LOGIN-05 | Log out, then relaunch app | Session correctly cleared; app returns to Login screen, no auto-login with stale state. |
| LOGIN-06 | Log in on Device A, then log in with the same account on Device B | Confirm expected behavior (both sessions live, or one invalidated — whatever the app is designed to do) — flag if `deviceToken` handling causes push-notification confusion between devices. |
| LOGIN-07 | Password reset flow (if present) | Reset email sent, new password logs in successfully, old password rejected. |
| LOGIN-08 | Directly manipulate role field in Firestore console while logged in (e.g. change `student` → `teacher` mid-session) | Confirm whether the app picks this up live (stream listener) or only after re-login — either is fine, but document which it is, since stale role caching is a common bug source. |

---

## 3. Approval / Verification Workflows

### 3a. Staff approval (Owner/Manager approving Teacher/Manager)

| ID | Steps | Expected Result |
|---|---|---|
| APR-01 | As Owner (`0562619983s@gmail.com`), open pending staff approvals (`PendingStaffApprovalWidget` / Admin panel) | Newly registered Teacher/Manager appears in the queue. |
| APR-02 | Approve the pending teacher | `approvalStatus` → `approved` in Firestore; teacher can now log in and reach dashboard (test with that teacher's session). |
| APR-03 | Reject a pending teacher instead | `approvalStatus`/`accountStatus` → `rejected`; teacher blocked per LOGIN-04. |
| APR-04 | As **Manager** (not Owner), attempt the same approval | Should succeed per role matrix (`manager` can manage users) — confirm, don't assume. |
| APR-05 | As **Teacher or Student**, try to hit the approval action directly (e.g. via deep link or by re-enabling a hidden button via dev tools) | Firestore rules reject the write — confirms server-side enforcement, not just UI-hidden. |

### 3b. Parent-link approval (Student approving Parent)

| ID | Steps | Expected Result |
|---|---|---|
| APR-06 | As the linked Student, open pending parent requests widget | The parent's request appears with correct name/email. |
| APR-07 | Student approves the request | Parent's access unlocks; log in as that parent and confirm Parent Dashboard now loads with the correct linked student's data. |
| APR-08 | Student rejects instead | Parent remains blocked; verify parent sees an appropriate pending/rejected state, not a crash. |
| APR-09 | As Admin/Owner, approve a parent link directly (bypassing student) | Confirm whether this path is actually supported per the rules — role matrix says student-or-admin can approve. |
| APR-10 | Attempt to have a **different, unlinked student** approve the parent request | Should be blocked by rules (only the linked student or admin can approve). |

---

## 4. Class Management (Teacher/Admin create, Student join)

| ID | Steps | Expected Result |
|---|---|---|
| CLS-01 | As Manager/Owner, create a new class with deterministic ID pattern (e.g. `BCA_Sem3_A`) | Class created; `joinCode` (6-char) and `inviteCode` (12-char) generated and unique. |
| CLS-02 | As Student, join the class using `joinCode` | `memberCount` increments; class appears on Student Dashboard. Confirm student write only touches `memberCount` per the security rule (not arbitrary fields). |
| CLS-03 | As Student, attempt to join using an invalid/expired code | Clear error, no partial join. |
| CLS-04 | As Admin, assign a Teacher to the class (`syncTeacherToClasses`) | Teacher's `assignedClasses` array updates; class's `teacherIds` updates both directions. |
| CLS-05 | As Admin, reset a class's invite code | Old code stops working, new code works. |
| CLS-06 | As Teacher, attempt to create a class directly | Should be rejected — only Admin roles can create classes per the rules matrix. |
| CLS-07 | As Student, attempt to edit class metadata (name, teacher) directly via a crafted write | Rejected by rules — student may only increment `memberCount`. |

---

## 5. Lectures & Attendance

| ID | Steps | Expected Result |
|---|---|---|
| LEC-01 | As Teacher, schedule a lecture for their class | Lecture created with `status: scheduled`. |
| LEC-02 | As Teacher, mark a lecture `completed` | Status transitions correctly; confirm any downstream effect (e.g. `total_lectures_taken` increment) fires. |
| LEC-03 | As Teacher, request cancellation | Status → `cancel_pending` with `cancellationReason` set — per rules, teacher can only set this status, not `cancelled` directly. |
| LEC-04 | As Admin, approve the cancellation | Status → `cancelled`, `cancelledBy` recorded. |
| LEC-05 | Attempt to schedule two lectures for the same teacher at an overlapping time | Confirm the app's conflict-check actually blocks this (per `lecture_service.dart` conflict checks). |
| LEC-06 | As Teacher, mark student attendance for a scheduled lecture | `student_attendance` docs created with correct `status` (present/absent/late/excused); teacher metrics update. |
| LEC-07 | As Student, view own attendance history | Only their own records are visible/queryable — confirm via rules that another student's attendance isn't readable. |
| LEC-08 | As Parent, view linked student's attendance | Visible only for the linked student, not others. |
| LEC-09 | As Teacher, attempt to mark attendance for a class they don't teach | Rejected by rules (teacher can only write "own class" attendance). |
| LEC-10 | Attempt to delete a lecture or attendance record via any role | Should be rejected everywhere — delete is disabled for both collections per the rules matrix. |

---

## 6. Tests & Results

| ID | Steps | Expected Result |
|---|---|---|
| TST-01 | As Teacher, create a test (title, maxMarks, testDate, subject) | Test doc created and visible to enrolled students. |
| TST-02 | As Teacher, enter results for students | `results` docs created with `marksObtained`, `percentage`, `grade` computed correctly. |
| TST-03 | As Student, view own result | Visible, correct grade/percentage shown. |
| TST-04 | As Student, attempt to view another student's result | Blocked by rules. |
| TST-05 | As Parent, view linked student's result | Visible only for linked student. |
| TST-06 | As Admin, delete a test | Allowed (Admin-only delete per matrix). |
| TST-07 | As Teacher, attempt to delete a test | Should be rejected — delete is Admin-only for `tests`. |
| TST-08 | Enter a result with marks exceeding `maxMarks` | Confirm app validates or at least computes percentage sanely (>100%) rather than crashing — flag as a UX bug if unvalidated. |

---

## 7. Study Materials

| ID | Steps | Expected Result |
|---|---|---|
| MAT-01 | As Teacher, upload a study material file (PDF/image/doc) via `CloudinaryService` | File uploads to Cloudinary; `fileUrl` stored in Firestore, **not** raw base64. |
| MAT-02 | As Teacher, upload a `link`-type material (no file, just URL) | Stored correctly with `fileType: link`. |
| MAT-03 | As Student, view/download material for their enrolled class | Accessible; file opens (via `storage_helper.dart` on web vs mobile — test both). |
| MAT-04 | As Teacher (owner of the doc), delete their own uploaded material | Succeeds per rules ("Teacher owner of doc" can delete). |
| MAT-05 | As a **different** Teacher (not the uploader), attempt to delete it | Rejected — only Admin or the owning teacher can delete. |
| MAT-06 | As Student, attempt to upload material | Rejected — write is Admin/Teacher only. |

---

## 8. Finance, Fees & Payroll

| ID | Steps | Expected Result |
|---|---|---|
| FIN-01 | As Admin, create a fee structure for a student | `student_fees`/`fees` doc created with correct `totalAmount`, `pendingAmount`. |
| FIN-02 | As Admin, record a payment | `paidAmount` updates, `status` transitions (`pending` → `partial` → `paid`) correctly at each threshold; `financial_transactions` log entry created. |
| FIN-03 | As Student, view own fee status | Visible, read-only. |
| FIN-04 | As Parent, view linked student's fee status | Visible only for linked student. |
| FIN-05 | As Student, attempt to modify their own fee record | Rejected — `fees`/`student_fees` writes are Admin-only. |
| FIN-06 | As Admin, run teacher payroll calculation (`attendance_pay_service.dart`) | Per-lecture compensation calculated correctly against `total_lectures_taken` / `unpaid_lectures`. |
| FIN-07 | As Teacher, view own payroll/payout summary (`TeacherPayrollWidget`) | Read access works for "own" payroll record. |
| FIN-08 | As Teacher, attempt to view another teacher's payroll | Rejected. |
| FIN-09 | As Admin, issue a payout | `payouts` doc created; confirm `unpaid_lectures` resets/decrements appropriately. |
| FIN-10 | Attempt to delete a `financial_transactions` or `payouts` record as any role | Rejected everywhere — delete disabled per matrix. |
| FIN-11 | As Owner, delete a `payroll` record | Allowed (Owner-only delete per matrix) — confirm Manager cannot do this. |

---

## 9. Chat / Conversations & Notifications

| ID | Steps | Expected Result |
|---|---|---|
| CHT-01 | Start a 1-on-1 conversation between two users (`conversation_service.dart`) | Conversation created; both appear as participants. |
| CHT-02 | Send/receive messages in realtime | Delivered instantly to the other participant while both are online. |
| CHT-03 | As a **non-participant**, attempt to read or write to that conversation | Rejected — participants-only per rules. |
| CHT-04 | Trigger an action that should generate a notification (e.g. lecture cancelled, fee due, parent request approved) | Notification created and delivered to the correct target user only. |
| CHT-05 | As a user, attempt to read another user's notifications | Rejected — target-receiver-only read rule. |
| CHT-06 | Mark a notification as read | Unread badge count (`notification_badge.dart`) updates correctly. |

---

## 10. Admin Panel, Audit Logs & Reports

| ID | Steps | Expected Result |
|---|---|---|
| ADM-01 | As Owner, access user management, grant/change a role | Role updates correctly; confirm `role()` helper's case-insensitivity (`.lower()`) — test setting a role with mixed case in the console and confirm rules still evaluate correctly. |
| ADM-02 | As Owner, delete a user | Allowed (Owner-only per matrix). |
| ADM-03 | As Manager, attempt to delete a user | Rejected — delete is Owner-only, even though Manager can otherwise manage users. |
| ADM-04 | Trigger an auditable action (approval, fee edit, lecture cancellation) | Confirm an `audit_logs` entry is created (via `audit_log_service.dart` and/or `audit_service.dart` — note if both fire redundantly, that may be worth flagging to the dev). |
| ADM-05 | As Teacher, perform an auditable action | Teacher can **write** audit logs but should **not** be able to **read** the audit log collection — confirm both halves. |
| ADM-06 | As Admin, generate a PDF/CSV report (`report_service.dart`) | Report exports correctly with accurate data; test on web (download) and mobile (file save) separately. |
| ADM-07 | Use `role_diagnostic_widget.dart` (if exposed) on an account with a role/approval mismatch | Confirm it correctly surfaces the mismatch for troubleshooting. |

---

## 11. Profile & Settings

| ID | Steps | Expected Result |
|---|---|---|
| PRF-01 | As any role, edit own profile (name, phone, bio, photo) | Saves correctly; photo uploads via Cloudinary. |
| PRF-02 | Attempt to edit own `role` or `approvalStatus` field directly in the profile edit form/request | Rejected by rules — self-write is limited to a safe key subset only. |
| PRF-03 | Attempt to edit another user's profile | Rejected unless Admin. |
| PRF-04 | Change theme (dark/light) in Settings | Persists across app restart. |

---

## 12. Data-Migration & Backfill (if applicable to this test cycle)

| ID | Steps | Expected Result |
|---|---|---|
| MIG-01 | Run `migration_service.dart` against a copy of pre-migration test data | Schema upgrades apply cleanly, no data loss; re-running it is idempotent (running twice doesn't duplicate/corrupt data). |

---

## 13. Cross-Cutting / Negative & Edge Cases

- [ ] **Offline behavior**: put the device in airplane mode mid-action (e.g. marking attendance) — confirm graceful failure/queueing rather than a crash, and that `Result<T>` error handling (`core/result.dart`) surfaces a sensible message instead of an unhandled exception.
- [ ] **Sentry**: intentionally trigger a caught error and confirm it's actually reported to Sentry (check the dashboard), validating `sentry.properties` config is live.
- [ ] **Case sensitivity**: create a user with `role: "Teacher"` (capitalized) directly in Firestore console and confirm the app/rules still treat them correctly via `.lower()`.
- [ ] **Multi-role edge case**: `super_admin` vs `owner` — run a handful of Owner-only actions (delete user, delete payroll) as `super_admin` and confirm the doc's claim of "identical privileges" actually holds in the rules, not just in the description.
- [ ] **Empty states**: new class with zero students, new teacher with zero lectures, etc. — confirm dashboards render sensible empty states, not errors.
- [ ] **Concurrent approval**: two admins approve the same pending teacher at nearly the same time — confirm no duplicate-approval side effects (e.g. double notification).
- [ ] **Invite/join code collision**: force a scenario where generated codes might collide (hard to trigger manually, but worth a note to devs to unit-test separately rather than manually).

---

## Suggested Execution Order for Antigravity

1. Section 0 (setup) → Section 1 (registration for all 6 roles) → Section 2 (login for all states: approved/pending/rejected).
2. Section 3 (approvals) — this unblocks everything else, so do it early.
3. Sections 4–5 (classes → lectures/attendance), since later sections depend on classes existing.
4. Sections 6–9 in any order (tests/results, materials, finance, chat/notifications) — these are largely independent of each other.
5. Section 10 (admin/audit/reports) last, since it depends on activity generated by the earlier sections to have something to report/audit.
6. Section 11 (profile) and Section 13 (edge cases) as a final pass.
7. Section 12 only if a migration is actually part of this test cycle.

For every "attempt X as the wrong role" negative test, the correct result is a **permission-denied error surfaced gracefully**, not a crash and not a silent no-op — flag either of those as a bug even if the write was correctly blocked.
