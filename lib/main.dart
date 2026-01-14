import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard.dart';
import 'screens/login_screen.dart';
import 'services/background_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Background Service
  Workmanager().initialize(
      callbackDispatcher, // The top-level function in background_service.dart
      isInDebugMode: true // Set to false for release to stop console logs
      );

  // Register the periodic task to check alerts
  Workmanager().registerPeriodicTask(
    "1",
    "fetchBackgroundTask",
    frequency:
        const Duration(minutes: 15), // Android minimum frequency is 15 mins
    constraints: Constraints(
      networkType: NetworkType.connected, // Only run if internet is available
    ),
  );

  runApp(const IndustrialApp());
}

class IndustrialApp extends StatelessWidget {
  const IndustrialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Industrial Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        primaryColor: const Color(0xFF00B0FF),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B0FF),
          brightness: Brightness.light,
        ).copyWith(
          secondary: const Color(0xFFFFAB00),
          surface: Colors.white,
          error: const Color(0xFFFF5252),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE0E0E0),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
