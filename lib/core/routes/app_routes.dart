// lib/core/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/routes/protected_route.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/auth_gate.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/register_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/create_request_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/request_details_page.dart';
import 'package:red_cell_net_final/features/blood_requests/presentation/pages/requests_page.dart';
import 'package:red_cell_net_final/features/educational_content/presentation/pages/content_list_page.dart';
import 'package:red_cell_net_final/features/home/presentation/pages/home_page.dart';
import 'package:red_cell_net_final/features/nearby_map/presentation/pages/map_page.dart';
import 'package:red_cell_net_final/features/notifications/presentation/pages/notifications_page.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/profile_page.dart';

/// Central route definitions and route generation with built-in protection guards.
class AppRoutes {
  // Public routes
  static const String root = '/';
  static const String authGate = '/auth-gate';
  static const String login = '/login';
  static const String register = '/register';

  // Protected routes
  static const String home = '/home';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String requests = '/requests';
  static const String createRequest = '/create-request';
  static const String requestDetails = '/request-details';
  static const String map = '/map';
  static const String notifications = '/notifications';
  static const String admin = '/admin';
  static const String contentList = '/learn';

  /// List of route names that require user to be authenticated.
  static final Set<String> _protectedRoutes = {
    home,
    profile,
    editProfile,
    requests,
    createRequest,
    requestDetails,
    map,
    notifications,
    admin,
  };

  /// Returns true if the given route name is protected.
  static bool isProtected(String? routeName) {
    if (routeName == null) return false;
    return _protectedRoutes.contains(routeName);
  }

  /// Central route factory with automatic protection enforcement.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String? routeName = settings.name;
    final bool isUserAuthenticated = SupabaseAuthService().isAuthenticated;

    // Check protection guard
    if (isProtected(routeName) && !isUserAuthenticated) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ProtectedRoute(
          redirectNotice: 'Please sign in to access this feature.',
          child: LoginPage(),
        ),
      );
    }

    switch (routeName) {
      case root:
      case authGate:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AuthGate(),
        );

      case login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginPage(),
        );

      case register:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RegisterPage(),
        );

      case home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: HomePage()),
        );

      case profile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: ProfilePage()),
        );

      case editProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: EditProfilePage()),
        );

      case requests:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: RequestsPage()),
        );

      case createRequest:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: CreateRequestPage()),
        );

      case requestDetails:
        final requestId = settings.arguments as String?;
        if (requestId == null || requestId.isEmpty) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Center(child: Text('Invalid request ID.')),
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ProtectedRoute(
            child: RequestDetailsPage(requestId: requestId),
          ),
        );

      case map:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: MapPage()),
        );

      case notifications:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: NotificationsPage()),
        );

      case admin:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProtectedRoute(child: AdminDashboardPage()),
        );

      case contentList:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const EducationalContentListPage(),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AuthGate(),
        );
    }
  }
}
