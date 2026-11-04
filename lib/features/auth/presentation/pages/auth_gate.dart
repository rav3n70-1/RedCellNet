// lib/features/auth/presentation/pages/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';
import 'package:red_cell_net_final/features/home/presentation/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root Authentication Gate that reactively switches between [LoginPage] and [HomePage]
/// based on Supabase session state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isInitialized) {
      return const LoginPage();
    }

    final authService = SupabaseAuthService();

    return StreamBuilder<AuthState>(
      stream: authService.onAuthStateChange,
      builder: (context, snapshot) {
        // While checking initial local session
        if (snapshot.connectionState == ConnectionState.waiting &&
            !authService.isAuthenticated) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        // Active session check
        final session = snapshot.data?.session ?? authService.currentSession;
        if (session == null) {
          return const LoginPage();
        }

        // User is authenticated
        return const HomePage();
      },
    );
  }
}
