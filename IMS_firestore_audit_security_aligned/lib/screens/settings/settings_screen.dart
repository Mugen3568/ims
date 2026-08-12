import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    // Check if the current theme mode is dark
    bool isDarkMode = themeNotifier.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- APPEARANCE SECTION ---
          Text(
            'Appearance',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Dark Mode'),
              subtitle: Text(
                isDarkMode
                    ? 'Currently using Dark Theme'
                    : 'Currently using Light Theme',
              ),
              value: isDarkMode,
              onChanged: (bool value) async {
                await themeNotifier.toggleTheme(value);
              },
            ),
          ),
          const SizedBox(height: 24),

          // --- ACCOUNT SECTION ---
          Text(
            'Account Management',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: theme.colorScheme.primary),
                  title: const Text('My Profile'),
                  subtitle: const Text(
                    'View and edit your personal information',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Safely log out of your IMS account'),
                  onTap: () async {
                    await Provider.of<AuthService>(
                      context,
                      listen: false,
                    ).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
