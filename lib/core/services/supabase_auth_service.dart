// lib/core/services/supabase_auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service handling Supabase Authentication across the app.
class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Stream of authentication state changes (Signed in, Signed out, Token refreshed, etc.)
  Stream<AuthState> get onAuthStateChange {
    if (!SupabaseConfig.isInitialized) {
      return const Stream.empty();
    }
    return _client.auth.onAuthStateChange;
  }

  /// Returns current authenticated user, or null if unauthenticated.
  User? get currentUser {
    if (!SupabaseConfig.isInitialized) return null;
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Returns current active session, or null if unauthenticated.
  Session? get currentSession {
    if (!SupabaseConfig.isInitialized) return null;
    try {
      return _client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  /// Current user's unique Supabase ID.
  String? get currentUserId => currentUser?.id;

  /// Current user's email address.
  String? get currentUserEmail => currentUser?.email;

  /// Helper boolean indicating whether a valid session is present.
  bool get isAuthenticated {
    try {
      return currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Signs up a new user with email, password, and optional full name.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null && name.trim().isNotEmpty) {
      data['name'] = name.trim();
      data['full_name'] = name.trim();
    }

    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: data.isNotEmpty ? data : null,
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.authCallbackUrl,
      );

      // If session is immediately created (e.g. email confirmations disabled),
      // make sure profile record exists in public.profiles.
      if (response.user != null) {
        await _ensureProfileExists(
          userId: response.user!.id,
          email: response.user!.email ?? email,
          name: name?.trim() ?? '',
        );
      }

      return response;
    } catch (e) {
      debugPrint('SupabaseAuthService.signUp error: $e');
      rethrow;
    }
  }

  /// Signs in an existing user with email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        await _ensureProfileExists(
          userId: response.user!.id,
          email: response.user!.email ?? email,
        );
      }

      return response;
    } catch (e) {
      debugPrint('SupabaseAuthService.signInWithPassword error: $e');
      rethrow;
    }
  }

  /// Sends a magic link / OTP to the user's email address.
  Future<void> signInWithOtp({required String email}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.authCallbackUrl,
      );
    } catch (e) {
      debugPrint('SupabaseAuthService.signInWithOtp error: $e');
      rethrow;
    }
  }

  /// Signs in with Google using native GoogleSignIn + Supabase ID Token exchange.
  Future<AuthResponse?> signInWithGoogle({
    String? webClientId,
    String? serverClientId,
  }) async {
    const String defaultClientId =
        '497080096855-g1anulj44n6s62fhtjs2hescutbeju7k.apps.googleusercontent.com';

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? (webClientId ?? defaultClientId) : null,
      serverClientId: kIsWeb ? null : (serverClientId ?? defaultClientId),
      scopes: ['email', 'profile'],
    );

    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the Google sign-in prompt
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException(
          'Failed to retrieve Google ID Token for authentication.',
        );
      }

      final AuthResponse response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await _ensureProfileExists(
          userId: response.user!.id,
          email: response.user!.email ?? googleUser.email,
          name: googleUser.displayName ?? '',
        );
      }

      return response;
    } catch (e) {
      debugPrint('SupabaseAuthService.signInWithGoogle error: $e');
      await googleSignIn.signOut();
      rethrow;
    }
  }

  /// Sends a password reset email.
  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : SupabaseConfig.resetCallbackUrl,
      );
    } catch (e) {
      debugPrint('SupabaseAuthService.resetPasswordForEmail error: $e');
      rethrow;
    }
  }

  /// Updates current user's password (e.g. after receiving password reset link).
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      debugPrint('SupabaseAuthService.updatePassword error: $e');
      rethrow;
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('SupabaseAuthService.signOut error: $e');
      rethrow;
    }
  }

  /// Helper to ensure a row in public.profiles exists for the user.
  Future<void> _ensureProfileExists({
    required String userId,
    required String email,
    String? name,
  }) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id, name')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('profiles').insert({
          'id': userId,
          'email': email,
          'name': name ?? '',
          'points': 0,
          'badges': [],
          'is_available_to_donate': false,
        });
      } else if (name != null &&
          name.isNotEmpty &&
          (existing['name'] == null ||
              (existing['name'] as String).trim().isEmpty)) {
        await _client
            .from('profiles')
            .update({'name': name})
            .eq('id', userId);
      }

      // Also ensure Firestore user profile exists for existing features
      try {
        await UserProfileService().createUserProfileFromDetails(
          uid: userId,
          email: email,
          name: name,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Non-fatal: Error ensuring profile exists in Supabase: $e');
    }
  }
}
