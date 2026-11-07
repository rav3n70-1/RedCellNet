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

  /// Stream of authentication state changes (Signed in, Signed out, Password recovery, etc.)
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

  String? get currentUserId => currentUser?.id;
  String? get currentUserEmail => currentUser?.email;

  bool get isAuthenticated {
    try {
      return currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Signs up a new user with email, password, and optional initial donor metadata.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
    String? bloodType,
    String? phoneNumber,
    String? locationCity,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null && name.trim().isNotEmpty) {
      data['name'] = name.trim();
      data['full_name'] = name.trim();
    }
    if (bloodType != null && bloodType.trim().isNotEmpty) {
      data['blood_type'] = bloodType.trim();
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      data['phone_number'] = phoneNumber.trim();
    }
    if (locationCity != null && locationCity.trim().isNotEmpty) {
      data['location_city'] = locationCity.trim();
    }

    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: data.isNotEmpty ? data : null,
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.authCallbackUrl,
      );

      // Only ensure profile if session is active (authenticated RLS context).
      // Database trigger `on_auth_user_created` also creates the row automatically.
      if (response.user != null && response.session != null) {
        await _ensureProfileExists(
          userId: response.user!.id,
          email: response.user!.email ?? email,
          name: name?.trim(),
          bloodType: bloodType?.trim(),
          phoneNumber: phoneNumber?.trim(),
          locationCity: locationCity?.trim(),
        );
      }

      return response;
    } catch (e) {
      debugPrint('SupabaseAuthService.signUp error: $e');
      rethrow;
    }
  }

  /// Signs in an existing user with email and password without overwriting existing profile data.
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
          name: googleUser.displayName,
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

  /// Updates current user's password.
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

  /// Safely ensures a row in `public.profiles` exists without EVER overwriting
  /// existing points, badges, verification status, or donation history.
  Future<void> _ensureProfileExists({
    required String userId,
    required String email,
    String? name,
    String? bloodType,
    String? phoneNumber,
    String? locationCity,
  }) async {
    try {
      await UserProfileService().createUserProfileFromDetails(
        uid: userId,
        email: email,
        name: name,
        bloodType: bloodType,
        phoneNumber: phoneNumber,
        locationCity: locationCity,
      );
    } catch (e) {
      debugPrint('Non-fatal: Error ensuring profile exists in Supabase: $e');
    }
  }
}
