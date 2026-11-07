// lib/core/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/routes/protected_route.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
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
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:red_cell_net_final/features/profile/presentation/pages/profile_page.dart';

/// Central route definitions and route generation with built-in authentication & RBAC guards.
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
  static const String requestDetailsLegacy = '/request_details';
  static const String map = '/map';
  static const String notifications = '/notifications';
  static const String admin = '/admin';
  static const String contentList = '/learn';

  static final Set<String> _protectedRoutes = {
    home,
    profile,
    editProfile,
    requests,
    createRequest,
    requestDetails,
    requestDetailsLegacy,
    map,
    notifications,
    admin,
  };

  static bool isProtected(String? routeName) {
    if (routeName == null) return false;
    return _protectedRoutes.contains(routeName);
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String? routeName = settings.name;
    final bool isUserAuthenticated = SupabaseAuthService().isAuthenticated;

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
      case requestDetailsLegacy:
        String? requestId;
        final args = settings.arguments;
        if (args is String) {
          requestId = args;
        } else if (args is Map) {
          requestId = (args['id'] ?? args['requestId'])?.toString();
        }
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
            child: RequestDetailsPage(requestId: requestId!),
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
          builder: (_) => const ProtectedRoute(
            child: StaffRoleGuard(child: AdminDashboardPage()),
          ),
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

/// Strict RBAC route wrapper ensuring only verified 'admin' or 'moderator' users
/// can render staff screens.
class StaffRoleGuard extends StatefulWidget {
  final Widget child;
  const StaffRoleGuard({super.key, required this.child});

  @override
  State<StaffRoleGuard> createState() => _StaffRoleGuardState();
}

class _StaffRoleGuardState extends State<StaffRoleGuard> {
  Future<ProfileSnapshot>? _profileFuture;

  @override
  void initState() {
    super.initState();
    final uid = SupabaseAuthService().currentUserId;
    if (uid != null) {
      _profileFuture = UserProfileService().getUserProfile(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profileFuture == null) {
      return const LoginPage();
    }
    return FutureBuilder<ProfileSnapshot>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data?.data();
        final role = (data?['role'] ?? 'user').toString().toLowerCase().trim();
        final isBanned =
            data?['is_banned'] == true || data?['isBanned'] == true;
        final isStaff =
            !isBanned && (role == 'admin' || role == 'moderator');
        if (!isStaff) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            appBar: AppBar(title: const Text('Access Restricted')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_outlined,
                        size: 56, color: AppColors.critical),
                    const SizedBox(height: 16),
                    Text(
                      'Staff Authorization Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Only authorized RedCellNet administrators and moderators may access this console.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(
                              context, AppRoutes.home);
                        }
                      },
                      child: const Text('Return to App'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}
