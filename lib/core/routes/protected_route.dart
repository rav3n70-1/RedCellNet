// lib/core/routes/protected_route.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';

/// A wrapper widget that guards protected pages.
/// If the user is unauthenticated, redirects or shows [LoginPage].
class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final String? redirectNotice;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.redirectNotice,
  });

  @override
  Widget build(BuildContext context) {
    final authService = SupabaseAuthService();

    if (!authService.isAuthenticated) {
      // Unauthenticated access attempt
      if (redirectNotice != null && redirectNotice!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(redirectNotice!),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        });
      }
      return const LoginPage();
    }

    return child;
  }
}
