// lib/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/core/theme/app_theme.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/register_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SupabaseAuthService _authService = SupabaseAuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _login() async {
    if (_isGoogleLoading || _isLoading) return;
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await _authService.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Supabase onAuthStateChange automatically notifies AuthGate to navigate.
      } on AuthException catch (e) {
        setState(() {
          _errorMessage = e.message;
        });
      } catch (e) {
        debugPrint('Generic Login Error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'An unexpected error occurred. Please try again.';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || _isGoogleLoading) return;

    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signInWithGoogle();
      if (response == null) {
        // User cancelled the prompt
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Google Sign-In failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your email address and we will send you a password reset link.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email.'),
                              backgroundColor: AppColors.critical,
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isResetting = true);
                        try {
                          await _authService.resetPasswordForEmail(email);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password reset link sent! Please check your email.',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } on AuthException catch (e) {
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: AppColors.critical,
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error sending reset link.'),
                                backgroundColor: AppColors.critical,
                              ),
                            );
                          }
                        } finally {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isResetting = false);
                          }
                        }
                      },
                child: isResetting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = _isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Brand Hero ---
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.water_drop_rounded,
                                size: 44, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'RedCellNet',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connecting Donors • Saving Lives',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // --- Error Message Banner ---
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.critical, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.critical,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // --- Email Field ---
                  TextFormField(
                    controller: _emailController,
                    enabled: !isBusy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty || !v.contains('@')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passwordController,
                    enabled: !isBusy,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isBusy ? null : _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 8),
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Login Button ---
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isBusy ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Divider ---
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.border, thickness: 1),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.border, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Google Sign In Button ---
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: isBusy ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                            color: AppColors.border, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.primary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 20.0,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.g_mobiledata, size: 24),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- Link to Register Page ---
                  Center(
                    child: InkWell(
                      onTap: isBusy
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const RegisterPage()),
                              );
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign Up',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
