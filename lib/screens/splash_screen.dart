import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final String? sessionCookie = prefs.getString('session_cookie');
    final bool onboardingComplete =
        prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      // User is logged in -> Dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (onboardingComplete) {
      // User finished onboarding but not logged in -> Login
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // New User -> Onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.sensors,
                        size: 80,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            FadeTransition(
              opacity: _controller,
              child: Column(
                children: [
                  const Text(
                    'Grid Sphere',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    'Industrial Station',
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 2.0,
                      color: Color.fromARGB(221, 42, 42, 42),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Initializing Sensor Grid...',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
