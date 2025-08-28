import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage_cleaner_app/screens/cleaner_success_screen.dart';
import 'package:storage_cleaner_app/screens/home_screen.dart';
import 'package:storage_cleaner_app/screens/new_results_screen.dart';
import 'package:storage_cleaner_app/screens/onboarding_screen.dart';
import 'package:storage_cleaner_app/screens/permission_request_screen.dart';
import 'package:storage_cleaner_app/screens/results_screen.dart';
import 'package:storage_cleaner_app/screens/scan_screen.dart';
import 'package:storage_cleaner_app/screens/scan_screen_fixed_final.dart';
import 'package:storage_cleaner_app/screens/settings_screen.dart';
import 'package:storage_cleaner_app/theme/theme.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if onboarding has been completed and permissions granted
  final prefs = await SharedPreferences.getInstance();
  final bool showOnboarding = !(prefs.getBool('isOnboardingCompleted') ?? false);
  final bool permissionsGranted = prefs.getBool('storagePermissionsGranted') ?? false;
  
  String initialRoute;
  if (showOnboarding) {
    initialRoute = '/onboarding';
  } else if (!permissionsGranted) {
    initialRoute = '/permissions';
  } else {
    initialRoute = '/home';
  }
  
  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({
    super.key, 
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Cleaner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Follows system theme by default
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/permissions': (context) => const PermissionRequestScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanScreenFixed(), // Use the fixed scan screen
        '/old_scan': (context) => const ScanScreen(), // Keep old scan for backup
        '/results': (context) => const NewResultsScreen(), // Use the new results screen
        '/old_results': (context) => const ResultsScreen(), // Keep old results for backup
        '/cleaner_success': (context) => const CleanerSuccessScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
