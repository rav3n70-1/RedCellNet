// lib/features/auth/presentation/pages/register_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Import the UserProfileService
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Instantiate the profile service
  final UserProfileService _userProfileService = UserProfileService();

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      UserCredential? userCredential; // To hold the credential after creation

      try {
        // Step 1: Create the user in Firebase Authentication
        userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Step 2: If Auth creation is successful, create the Firestore profile
        if (userCredential.user != null) {
          try {
            await _userProfileService.createUserProfile(userCredential.user!);
            // Profile created successfully!

            // Show success message and navigate back
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Registration successful! Please login.'),
                  backgroundColor: Colors.green,
                ),
              );
              // Navigate back to the login page after a short delay
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  // Check if we can pop (i.e., if RegisterPage was pushed)
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  // If it can't pop (e.g., deep link), maybe navigate differently
                  // or rely on AuthGate to redirect. Popping is standard here.
                }
              });
            }
          } catch (profileError) {
            // Handle Firestore profile creation error specifically
            setState(() {
              _errorMessage =
                  'Registration succeeded, but failed to create profile. Please contact support.';
            });
            print('Firestore Profile Creation Error: $profileError');
            // Optional: Consider deleting the newly created Auth user for consistency
            // await userCredential.user?.delete(); // Be careful with this
          }
        } else {
          // This case should ideally not happen if createUserWithEmailAndPassword succeeds
          setState(() {
            _errorMessage =
                'Registration failed unexpectedly after user creation.';
          });
        }
      } on FirebaseAuthException catch (e) {
        // Handle Auth errors (same as before)
        if (e.code == 'weak-password') {
          setState(() {
            _errorMessage = 'The password provided is too weak.';
          });
        } else if (e.code == 'email-already-in-use') {
          setState(() {
            _errorMessage = 'An account already exists for that email.';
          });
        } else if (e.code == 'invalid-email') {
          setState(() {
            _errorMessage = 'The email address is not valid.';
          });
        } else {
          setState(() {
            _errorMessage = 'An error occurred during registration.';
          });
          print('Register Error Code: ${e.code}');
          print('Register Error Message: ${e.message}');
        }
      } catch (e) {
        // Handle other non-Firebase errors
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
        });
        print('Generic Register Error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- The build method remains exactly the same as the previous version ---
    // (Including Scaffold, AppBar, Form, TextFormFields, Button, Error Message Display)
    // It only needs the _register logic change above.
    // For brevity, I'll omit repeating the full build method here,
    // just ensure the _register function above replaces the old one.
    // If you prefer, I can paste the full combined file content again.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        leading: IconButton(
          // Back button
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Join RedCellNet',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Help save lives by registering',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Display error message if registration fails
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  // Clear error message when user starts typing
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  // Clear error message when user starts typing
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  // Clear error message when user starts typing
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 24),

                // Register Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _register,
                        child: const Text('Register'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
