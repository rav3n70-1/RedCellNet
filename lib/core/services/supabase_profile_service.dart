// lib/core/services/supabase_profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing user profiles and donor directory stored in Supabase PostgreSQL `profiles` table.
class SupabaseProfileService {
  static final SupabaseProfileService _instance =
      SupabaseProfileService._internal();
  factory SupabaseProfileService() => _instance;
  SupabaseProfileService._internal();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Fetches profile document for a given user id.
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('SupabaseProfileService.getProfile error: $e');
      rethrow;
    }
  }

  /// Realtime stream of user profile changes.
  Stream<List<Map<String, dynamic>>> getProfileStream(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId);
  }

  /// Updates existing user profile fields.
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    final Map<String, dynamic> payload = {
      ...data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _client.from('profiles').update(payload).eq('id', userId);
      debugPrint('Supabase user profile updated for ID: $userId');
    } catch (e) {
      debugPrint('SupabaseProfileService.updateProfile error: $e');
      rethrow;
    }
  }

  /// Saves or updates the user's FCM push notification token.
  Future<void> saveFcmToken(String userId, String? token) async {
    if (token == null || token.trim().isEmpty) return;
    try {
      await _client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
      debugPrint('Saved FCM token to Supabase for ID: $userId');
    } catch (e) {
      debugPrint('SupabaseProfileService.saveFcmToken error: $e');
    }
  }

  /// Fetches available donors with optional blood group and city filters.
  Future<List<Map<String, dynamic>>> getAvailableDonors({
    String? bloodType,
    String? city,
  }) async {
    try {
      var query = _client
          .from('profiles')
          .select()
          .eq('is_available_to_donate', true);

      if (bloodType != null && bloodType.trim().isNotEmpty) {
        query = query.eq('blood_type', bloodType.trim());
      }
      if (city != null && city.trim().isNotEmpty) {
        query = query.ilike('location_city', '%${city.trim()}%');
      }

      final List<dynamic> records = await query;
      return records.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('SupabaseProfileService.getAvailableDonors error: $e');
      return [];
    }
  }
}
