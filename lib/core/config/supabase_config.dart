// lib/core/config/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration constants and client access for Supabase.
class SupabaseConfig {
  /// Supabase project URL
  static const String url = 'https://gygaensofsguorvyqtag.supabase.co';

  /// Supabase legacy anon JWT key (works universally with REST and Realtime WebSockets)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5Z2FlbnNvZnNndW9ydnlxdGFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM3NjM4NjEsImV4cCI6MjEwOTMzOTg2MX0.SkedU8g6t0Id9pjmlQb_OIfHnL7rb-N-C7BZAZAC3RU';

  /// Supabase publishable key (modern client key)
  static const String publishableKey =
      'sb_publishable_cG6gaMgVMH_1N2dnZQQnHg_Wrj9iC7U';

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
