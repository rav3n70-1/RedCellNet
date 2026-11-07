// lib/core/services/supabase_profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/profile/data/services/user_profile_service.dart';

/// Privacy-safe wrapper delegating profile access to [UserProfileService] and
/// anonymized donor cluster queries via RPC.
class SupabaseProfileService {
  static final SupabaseProfileService _instance =
      SupabaseProfileService._internal();
  factory SupabaseProfileService() => _instance;
  SupabaseProfileService._internal();

  final UserProfileService _delegate = UserProfileService();

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final snap = await _delegate.getUserProfile(userId);
    return snap.data();
  }

  Stream<List<Map<String, dynamic>>> getProfileStream(String userId) {
    return _delegate.getUserProfileStream(userId).map((snap) {
      final d = snap.data();
      return d == null ? const <Map<String, dynamic>>[] : <Map<String, dynamic>>[d];
    });
  }

  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _delegate.updateUserProfile(userId, updates);
  }

  Future<void> saveFcmToken(String userId, String? token) async {
    await _delegate.saveUserFcmToken(userId, token);
  }

  /// Returns privacy-safe anonymized nearby donor availability clusters instead of raw user PII.
  Future<List<Map<String, dynamic>>> getAvailableDonorClusters({
    double lat = 23.8103,
    double lng = 90.4125,
    double radiusKm = 25.0,
    String? bloodType,
  }) async {
    if (!SupabaseConfig.isInitialized) return const [];
    try {
      final res = await SupabaseConfig.client.rpc('get_nearby_donor_clusters', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_blood_type': bloodType,
      });
      if (res is List) {
        return res
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('SupabaseProfileService.getAvailableDonorClusters error: $e');
    }
    return const [];
  }
}
