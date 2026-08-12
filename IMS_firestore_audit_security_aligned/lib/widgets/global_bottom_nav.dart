import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import dashboards
import '../screens/student/student_dashboard.dart';
import '../screens/teacher/teacher_dashboard.dart';
import '../screens/manager/manager_dashboard.dart';
import '../screens/parent/parent_dashboard.dart';
// Import other screens
import '../screens/lectures/lectures_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/community/classes_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/study_materials/study_materials_screen.dart';
import '../screens/academic/attendance_screen.dart';
import '../screens/academic/tests_screen.dart';
import '../screens/admin/reports_screen.dart';
import '../screens/admin/super_admin_dashboard.dart';
import '../screens/finance/fees_screen.dart';
// Import widgets
import '../widgets/notification_badge.dart';

// Helper class to bind a Screen, its Tab Icon, and its Title together
class _NavData {
  final Widget screen;
  final BottomNavigationBarItem item;
  final String title;

  _NavData({
    required this.screen,
    required this.item,
    required this.title,
  });
}

class GlobalBottomNav extends StatefulWidget {
  final String userRole;
  final String userId;

  const GlobalBottomNav({
    super.key,
    required this.userRole,
    required this.userId,
  });

  @override
  State<GlobalBottomNav> createState() => _GlobalBottomNavState();
}

class _GlobalBottomNavState extends State<GlobalBottomNav> {
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _startListeningForInAppNotifications();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  // GLOBAL LISTENER FOR IN-APP NOTIFICATIONS
  void _startListeningForInAppNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _alertSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          String title = data['title'] ?? 'New Notification';
          String message = data['body'] ?? data['message'] ?? 'You have a new update.';
          _showPopUpBanner(title, message, change.doc.id);
        }
      }
    });
  }

  // THE POP-UP UI
  void _showPopUpBanner(String title, String message, String alertId) {
    if (!mounted) return;
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.black,
          backgroundColor: theme.colorScheme.primary,
          onPressed: () {
            FirebaseFirestore.instance.collection('notifications').doc(alertId).update(
              {'isRead': true},
            );
          },
        ),
      ),
    );
  }

  // BUILD TABS DYNAMICALLY BASED ON ROLE
  List<_NavData> _getTabs() {
    final role = widget.userRole;
    if (role == 'super_admin') {
      return [
        _NavData(
          screen: const SuperAdminDashboard(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Institutes',
          ),
          title: 'Super Admin',
        ),
        _NavData(
          screen: const SettingsScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          title: 'Settings',
        ),
      ];
    }
    final isStaff = role == 'owner' || role == 'manager' || role == 'teacher';
    final canViewFees = role == 'owner' || role == 'manager' || role == 'parent';

    List<_NavData> tabs = [
      _NavData(
        screen: _getDashboardScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        title: 'Dashboard',
      ),
    ];

    // ✅ LECTURES TAB - ONLY FOR STAFF (Removed for students & parents)
    if (isStaff) {
      tabs.add(
        _NavData(
          screen: LecturesScreen(userRole: role, currentUserId: widget.userId),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Lectures',
          ),
          title: 'Lectures',
        ),
      );
    }

    if (role == 'owner' || role == 'manager') {
      tabs.add(
        _NavData(
          screen: const ReportsScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          title: 'Reports & Analytics',
        ),
      );
    }

    if (role != 'parent') {
      tabs.add(
        _NavData(
          screen: const ClassesScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.class_outlined),
            activeIcon: Icon(Icons.class_),
            label: 'Classes',
          ),
          title: 'My Classes',
        ),
      );
    }

    String attendanceTitle = 'Attendance';
    if (role == 'owner' || role == 'manager') {
      attendanceTitle = 'Attendance Reports';
    } else if (role == 'teacher') {
      attendanceTitle = 'Take Attendance';
    }

    tabs.add(
      _NavData(
        screen: AttendanceScreen(userRole: role),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.check_circle_outline),
          activeIcon: Icon(Icons.check_circle),
          label: 'Attendance',
        ),
        title: attendanceTitle,
      ),
    );

    tabs.add(
      _NavData(
        screen: TestsScreen(userRole: role),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment),
          label: 'Tests',
        ),
        title: 'Tests & Results',
      ),
    );

    // Finance is deliberately parent/staff-only; students have no fee route.
    if (canViewFees) {
      tabs.add(
        _NavData(
          screen: FeesScreen(userRole: role),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_outlined),
            activeIcon: Icon(Icons.monetization_on),
            label: 'Fees',
          ),
          title: 'Fees & Pay',
        ),
      );
    }

    tabs.add(
      _NavData(
        screen: StudyMaterialsScreen(userRole: role),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          activeIcon: Icon(Icons.description),
          label: 'Notes',
        ),
        title: 'Study Materials',
      ),
    );

    tabs.add(
      _NavData(
        screen: const SettingsScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
        title: 'Settings',
      ),
    );

    return tabs;
  }

  Widget _getDashboardScreen() {
    switch (widget.userRole) {
      case 'super_admin':
        return const SuperAdminDashboard();
      case 'owner':
      case 'manager':
        return const ManagerDashboard();
      case 'teacher':
        return const TeacherDashboard();
      case 'parent':
        return const ParentDashboard();
      case 'student':
      default:
        return const StudentDashboard();
    }
  }

  // BUILD COMMUNITY ACTION FOR APP BAR
  Widget _buildCommunityAppBarAction() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.forum_outlined),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CommunityScreen()),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return IconButton(
          icon: Badge(
            isLabelVisible: hasUnread,
            backgroundColor: Colors.red,
            smallSize: 8,
            child: const Icon(Icons.forum_outlined),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunityScreen()),
          ),
        );
      },
    );
  }

  // CUSTOM LEFT-ALIGNED BOTTOM NAVIGATION BAR
  Widget _buildLeftAlignedBottomNav(
      ThemeData theme, List<_NavData> tabs, int safeIndex) {
    return SafeArea(
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(tabs.length, (index) {
              final item = tabs[index].item;
              final isSelected = safeIndex == index;
              final color = isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant;

              return InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          color: color,
                          size: 24,
                        ),
                        child: isSelected ? item.activeIcon : item.icon,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label ?? '',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Generate the correct tabs for the user's role
    final tabs = _getTabs();
    
    // Safety check in case a hot-reload shifts the index out of bounds
    final safeIndex = _currentIndex < tabs.length ? _currentIndex : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[safeIndex].title),
        actions: [
          _buildCommunityAppBarAction(),
          const NotificationBadge(),
        ],
      ),
      body: tabs[safeIndex].screen,
      bottomNavigationBar: _buildLeftAlignedBottomNav(Theme.of(context), tabs, safeIndex),
    );
  }
}
