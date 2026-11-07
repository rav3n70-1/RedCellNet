// lib/features/auth/presentation/pages/auth_gate.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/onboarding_page.dart';
import 'package:red_cell_net_final/features/home/presentation/pages/home_page.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root Authentication Gate that reactively directs the user based on
/// onboarding state, password-recovery state, authentication status, and role.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSub;
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isInitialized) {
      _authSub = SupabaseAuthService().onAuthStateChange.listen((state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          setState(() => _isPasswordRecovery = true);
        } else if (state.event == AuthChangeEvent.signedOut) {
          setState(() => _isPasswordRecovery = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService();

    if (!SupabaseConfig.isInitialized) {
      return ValueListenableBuilder<bool>(
        valueListenable: settings.onboardingCompletedNotifier,
        builder: (context, completed, _) {
          if (!completed) {
            return OnboardingPage(onFinished: () => setState(() {}));
          }
          return const LoginPage();
        },
      );
    }

    if (_isPasswordRecovery) {
      return _PasswordRecoveryScreen(
        onCompleted: () {
          if (mounted) setState(() => _isPasswordRecovery = false);
        },
      );
    }

    final authService = SupabaseAuthService();

    return StreamBuilder<AuthState>(
      stream: authService.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !authService.isAuthenticated) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            body: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return _PasswordRecoveryScreen(
            onCompleted: () {
              if (mounted) setState(() => _isPasswordRecovery = false);
            },
          );
        }

        final session = snapshot.data?.session ?? authService.currentSession;
        if (session == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: settings.onboardingCompletedNotifier,
            builder: (context, completed, _) {
              if (!completed) {
                return OnboardingPage(onFinished: () => setState(() {}));
              }
              return const LoginPage();
            },
          );
        }

        return _RoleBasedSessionRouter(userId: session.user.id);
      },
    );
  }
}

/// Routes authenticated users based on their role in Supabase while letting
/// admins/moderators switch cleanly between the Admin Console and Donor App.
class _RoleBasedSessionRouter extends StatefulWidget {
  final String userId;
  const _RoleBasedSessionRouter({required this.userId});

  @override
  State<_RoleBasedSessionRouter> createState() =>
      _RoleBasedSessionRouterState();
}

class _RoleBasedSessionRouterState extends State<_RoleBasedSessionRouter> {
  final UserProfileService _profileService = UserProfileService();
  Stream<ProfileSnapshot>? _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = _profileService.getUserProfileStream(widget.userId);
  }

  @override
  void didUpdateWidget(covariant _RoleBasedSessionRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _profileStream = _profileService.getUserProfileStream(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService();

    return StreamBuilder<ProfileSnapshot>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldOf(context),
            body: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        final profile = snapshot.data?.data();
        if (profile == null) {
          return const HomePage();
        }

        final isBanned =
            profile['isBanned'] == true || profile['is_banned'] == true;
        if (isBanned) {
          final reason = profile['ban_reason'] ??
              profile['banReason'] ??
              'Your account has been suspended by administration.';
          return _SuspendedAccountScreen(reason: reason.toString());
        }

        final role =
            (profile['role'] ?? 'user').toString().toLowerCase().trim();
        final isStaff = role == 'admin' || role == 'moderator';

        if (isStaff) {
          return ValueListenableBuilder<String>(
            valueListenable: settings.staffWorkspaceModeNotifier,
            builder: (context, mode, _) {
              if (mode == 'donor') {
                return const HomePage();
              }
              return const AdminDashboardPage();
            },
          );
        }

        return const HomePage();
      },
    );
  }
}

/// Dedicated password update screen triggered when opening a Supabase password-recovery deep link.
class _PasswordRecoveryScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const _PasswordRecoveryScreen({required this.onCompleted});

  @override
  State<_PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<_PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseAuthService()
          .updatePassword(_newPassController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onCompleted();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to update password. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService();
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(settings.tr('Set New Password')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset_rounded,
                      size: 56, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    settings.tr('Set New Password'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter a strong new password (at least 6 characters) to secure your RedCellNet account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.critical.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.critical.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.critical,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  TextFormField(
                    controller: _newPassController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPassController,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.check_circle_outline_rounded),
                    ),
                    validator: (v) {
                      if (v != _newPassController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen displayed when an account is banned/suspended
class _SuspendedAccountScreen extends StatelessWidget {
  final String reason;
  const _SuspendedAccountScreen({required this.reason});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.critical
                        .withValues(alpha: isDark ? 0.20 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: AppColors.critical,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Account Suspended',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMutedOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.critical,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await SupabaseAuthService().signOut();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
