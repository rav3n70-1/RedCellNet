// lib/features/auth/presentation/pages/login_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/register_page.dart';
// Imports for Google Sign In
import 'package:google_sign_in/google_sign_in.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
// Import kIsWeb for platform checking
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final UserProfileService _profileService = UserProfileService();
  bool _isLoading = false; // Loading for Email/Pass login
  bool _isGoogleLoading = false; // Loading for Google Sign In
  String? _errorMessage;

  // Login with Email/Password (Fully Expanded)
  Future<void> _login() async {
    if (_isGoogleLoading || _isLoading) return; // Check both flags
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // AuthGate handles navigation on success
        // No need to set _isLoading = false here because widget will unmount
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          _errorMessage = 'Incorrect email or password.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'Invalid email address.';
        } else {
          _errorMessage = 'Login failed. Please try again.';
          print('Login Error: ${e.code}');
        }
        if (mounted) setState(() {}); // Show error
      } catch (e) {
        print('Generic Login Error: $e');
        if (mounted)
          setState(() {
            _errorMessage = 'An unexpected error occurred.';
          });
      } finally {
        if (mounted)
          setState(() {
            _isLoading = false;
          });
      } // Ensure loading stops
    }
  }

  // Sign in with Google Logic (Fully Expanded)
  Future<void> signInWithGoogle(BuildContext context) async {
    if (_isLoading || _isGoogleLoading) return; // Check both flags

    final FirebaseAuth auth = FirebaseAuth.instance;
    // Initialize GoogleSignIn with clientId for web
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: kIsWeb
          ? "497080096855-g1anulj44n6s62fhtjs2hescutbeju7k.apps.googleusercontent.com"
          : null, // <-- REPLACE PLACEHOLDER
    );

    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    print("Attempting Google Sign-In...");

    try {
      // Start Google Sign In process
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      // Handle user cancelling the flow
      if (googleUser == null) {
        print("Google Sign-In cancelled.");
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }
      print("Google User Acquired: ${googleUser.email}");

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print("Google Auth Tokens Acquired.");

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      print("Signing in to Firebase...");
      final UserCredential userCredential =
          await auth.signInWithCredential(credential);
      print("Firebase Google Sign-In successful: ${userCredential.user?.uid}");

      // Create Firestore profile ONLY if it's a new user
      if (userCredential.user != null) {
        final bool isNewUser =
            userCredential.additionalUserInfo?.isNewUser ?? false;
        print("Is new Google user: $isNewUser");
        if (isNewUser) {
          print("Creating Firestore profile for new Google user...");
          try {
            await _profileService.createUserProfile(userCredential.user!,
                name: googleUser.displayName ?? '');
          } // Use Google name
          catch (e) {
            print("Error creating Firestore profile: $e");
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Error setting up profile: $e"),
                    backgroundColor: Colors.red),
              );
          }
        }
      }
      // AuthGate handles navigation on success
      // No need to set _isGoogleLoading = false here if successful login triggers unmount
    } catch (e) {
      print("Error during Google Sign-In: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Google Sign-In failed: ${e.toString()}"),
              backgroundColor: Colors.red),
        );
      }
      await googleSignIn
          .signOut(); // Sign out from Google if Firebase part fails
      if (mounted)
        setState(() {
          _isGoogleLoading = false;
        }); // Set loading false on error
    }
    // Removed finally block here as successful navigation unmounts the widget
    // If navigation doesn't happen for some reason, you might need it back:
    // finally { if (mounted) setState(() { _isGoogleLoading = false; }); }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Combined loading state
    bool isBusy = _isLoading || _isGoogleLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login to RedCellNet'),
        centerTitle: true,
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
                // --- Header Text ---
                Text(
                  'Welcome Back!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // --- Error Message Display ---
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

                // --- Email Field ---
                TextFormField(
                  controller: _emailController,
                  enabled: !isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty || !v.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),

                // --- Password Field ---
                TextFormField(
                  controller: _passwordController,
                  enabled: !isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 24),

                // --- Login Button ---
                // Show loader specifically for email/pass login
                _isLoading
                    ? const Center(
                        child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: isBusy
                            ? null
                            : _login, // Disable if any login process is active
                        child: const Text('Login'),
                      ),
                const SizedBox(height: 16),

                // --- OR Separator ---
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                      thickness: 1,
                      endIndent: 10,
                    )),
                    Text("OR", style: TextStyle(color: Colors.grey[600])),
                    Expanded(
                        child: Divider(
                      thickness: 1,
                      indent: 10,
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Google Sign In Button ---
                _isGoogleLoading
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : ElevatedButton.icon(
                        icon: Image.asset('assets/images/google_logo.png',
                            height: 22.0), // Ensure asset exists
                        label: const Text('Sign in with Google'),
                        onPressed: isBusy
                            ? null
                            : () => signInWithGoogle(
                                context), // Call Google sign-in
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            backgroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            elevation: 1,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                      ),
                const SizedBox(height: 20),

                // --- Link to Register Page ---
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegisterPage()),
                          );
                        },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Don\'t have an account? ',
                      style: TextStyle(color: Colors.black87),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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
