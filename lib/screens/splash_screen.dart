// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fouad_stock/screens/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() async {
    // Wait for a few seconds to show the splash screen
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      // Navigate to the main dashboard, replacing the splash screen in the navigation stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- MODIFIED: Set the background to match the new dark teal theme ---
      backgroundColor: Colors.teal.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Ｔ & Ｇ 𝓤𝓷𝓲𝓯𝓸𝓻𝓶',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo', 
                fontSize: 40, // Increased font size for more impact
                fontWeight: FontWeight.bold,
                color: Colors.white, 
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black.withOpacity(0.4),
                    offset: const Offset(2.0, 3.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '✦ يونيفورمك عندنا ✦',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18, // Increased font size
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 50), // Increased spacing
            CircularProgressIndicator(
              // --- MODIFIED: Use the vibrant accent color from the onboarding theme ---
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.tealAccent.shade100,
              ),
              strokeWidth: 3.0, // Made the spinner slightly thicker
            ),
          ],
        ),
      ),
    );
  }
}