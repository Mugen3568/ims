import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'core/theme.dart';
import 'screens/auth/auth_wrapper.dart';

// Create a simple ThemeNotifier to handle the Light/Dark toggle with persistence
class ThemeNotifier extends ChangeNotifier {
  static const String _themePrefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system; // Defaults to user's OS preference
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;

  // Initialize and load saved theme preference
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadThemePreference();
  }

  // Load theme preference from storage
  Future<void> _loadThemePreference() async {
    final savedTheme = _prefs?.getString(_themePrefKey);
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
      notifyListeners();
    }
  }

  // Save theme preference to storage
  Future<void> _saveThemePreference(String theme) async {
    await _prefs?.setString(_themePrefKey, theme);
  }

  // Toggle theme and persist the change
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _saveThemePreference(isDark ? 'dark' : 'light');
    notifyListeners();
  }

  // Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await _saveThemePreference(modeString);
    notifyListeners();
  }
}

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://e95327418e515a2c00631ef10785fb39@o4511808003375104.ingest.us.sentry.io/4511808059539456';
      options.sendDefaultPii = true;
      options.enableLogs = true;
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await dotenv.load(fileName: ".env");
      } catch (_) {}

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint('Firebase Auth web persistence set to LOCAL.');
        } catch (e) {
          debugPrint('Error setting auth persistence: $e');
        }
      }

      // Enable offline persistence for instant-load feel
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Initialize theme notifier and load saved preference
      final themeNotifier = ThemeNotifier();
      await themeNotifier.initialize();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider.value(value: themeNotifier),
          ],
          child: const IMSApp(),
        ),
      );
    },
  );
}

class IMSApp extends StatelessWidget {
  const IMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'IMS Academy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
