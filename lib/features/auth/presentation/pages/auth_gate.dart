// lib/features/auth/presentation/pages/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Only import pages directly needed for navigation/display here
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';
import 'package:red_cell_net_final/features/home/presentation/pages/home_page.dart';
// Removed unused imports: google_sign_in, user_profile_service

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle connection state while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is NOT logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage(); // Show Login Page
        }

        // User IS logged in (regardless of method)
        return const HomePage(); // Show Home Page
      },
    );
  }
}
