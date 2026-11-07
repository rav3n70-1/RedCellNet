// lib/core/config/supabase_config.example.dart
//
// Copy this file to `lib/core/config/supabase_config.dart` for local builds,
// OR pass credentials at compile time using:
//   flutter run --dart-define-from-file=.env
//   flutter build apk --dart-define-from-file=.env
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration constants and client access for Supabase.
class SupabaseConfig {
  /// Supabase project URL (override via --dart-define=SUPABASE_URL=...)
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT_REF.supabase.co',
  );

  /// Supabase legacy anon JWT key (override via --dart-define=SUPABASE_ANON_KEY=...)
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  /// Supabase publishable key (override via --dart-define=SUPABASE_PUBLISHABLE_KEY=...)
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_YOUR_KEY',
  );

  /// Deep link scheme for mobile OAuth / Magic link redirects
  static const String redirectScheme = 'io.supabase.redcellnet';
  static const String authCallbackUrl = '$redirectScheme://login-callback';
  static const String resetCallbackUrl = '$redirectScheme://reset-callback';

  /// Returns true if Supabase.initialize has completed.
  static bool get isInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shortcut to the initialized Supabase client
  static SupabaseClient get client => Supabase.instance.client;

  /// Safe accessor that returns null if Supabase has not been initialized.
  static SupabaseClient? get clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

/// Global shortcut to Supabase client
SupabaseClient get supabase => SupabaseConfig.client;

