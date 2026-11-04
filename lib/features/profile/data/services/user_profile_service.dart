// lib/features/profile/data/services/user_profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';

/// Lightweight wrapper to keep existing UI StreamBuilders compatible without Firestore.
class ProfileSnapshot {
  final Map<String, dynamic>? _data;
  final bool exists;
  final String id;

  ProfileSnapshot(this._data, {String? id})
      : exists = _data != null,
        id = id ?? _data?['id']?.toString() ?? '';

  Map<String, dynamic>? data() => _data;
}

class UserProfileService {
  Map<String, dynamic> _normalizeProfile(Map<String, dynamic> raw) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    m['uid'] ??= m['id'];
    m['bloodType'] ??= m['blood_type'];
    m['blood_type'] ??= m['bloodType'];
    m['locationCity'] ??= m['location_city'];
    m['location_city'] ??= m['locationCity'];
    m['phoneNumber'] ??= m['phone_number'];
    m['phone_number'] ??= m['phoneNumber'];
    m['isAvailableToDonate'] ??= m['is_available_to_donate'];
    m['is_available_to_donate'] ??= m['isAvailableToDonate'];
    m['totalDonations'] ??= m['total_donations'] ?? 0;
    m['total_donations'] ??= m['totalDonations'] ?? 0;
    m['points'] ??= 0;
    m['badges'] ??= [];
    m['verificationStatus'] ??= m['verification_status'] ?? 'unverified';
    m['verification_status'] ??= m['verificationStatus'] ?? 'unverified';
    m['verificationLab'] ??= m['verification_lab'];
    m['verificationCert'] ??= m['verification_cert'];
    m['verificationNotes'] ??= m['verification_notes'];
    m['donationHistory'] ??= m['donation_history'] ?? [];
    m['donation_history'] ??= m['donationHistory'] ?? [];
    m['viewedContentIds'] ??= m['viewed_content_ids'] ?? [];
    m['viewed_content_ids'] ??= m['viewedContentIds'] ?? [];
    m['fcmToken'] ??= m['fcm_token'];
    m['fcm_token'] ??= m['fcmToken'];
    return m;
  }

  Map<String, dynamic> _denormalizeForSupabase(Map<String, dynamic> data) {
    final Map<String, dynamic> out = {};
    data.forEach((key, value) {
      if (key == 'bloodType') {
        out['blood_type'] = value;
      } else if (key == 'locationCity') {
        out['location_city'] = value;
      } else if (key == 'locationCoords') {
        out['location_coords'] = value;
      } else if (key == 'phoneNumber') {
        out['phone_number'] = value;
      } else if (key == 'isAvailableToDonate') {
        out['is_available_to_donate'] = value;
      } else if (key == 'totalDonations') {
        out['total_donations'] = value;
      } else if (key == 'verificationStatus') {
        out['verification_status'] = value;
      } else if (key == 'verificationLab') {
        out['verification_lab'] = value;
      } else if (key == 'verificationCert') {
        out['verification_cert'] = value;
      } else if (key == 'verificationNotes') {
        out['verification_notes'] = value;
      } else if (key == 'verificationRequestedAt') {
        out['verification_requested_at'] = DateTime.now().toUtc().toIso8601String();
      } else if (key == 'donationHistory') {
        out['donation_history'] = value;
      } else if (key == 'viewedContentIds') {
        out['viewed_content_ids'] = value;
      } else if (key == 'fcmToken') {
        out['fcm_token'] = value;
      } else if (key != 'uid') {
        out[key] = value;
      }
    });
    out['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return out;
  }

  Future<void> createUserProfileFromDetails({
    required String uid,
    required String email,
    String? name,
  }) async {
    try {
      await supabase.from('profiles').upsert({
        'id': uid,
        'email': email,
        'name': name ?? '',
        'points': 0,
        'badges': [],
        'is_available_to_donate': false,
        'total_donations': 0,
        'verification_status': 'unverified',
        'donation_history': [],
        'viewed_content_ids': [],
      });
      debugPrint('User profile created/upserted in Supabase for UID: $uid');
    } catch (e) {
      debugPrint('Error creating user profile in Supabase: $e');
    }
  }

  Stream<ProfileSnapshot> getUserProfileStream(String uid) {
    try {
      return supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', uid)
          .map((rows) {
            if (rows.isEmpty) return ProfileSnapshot(null, id: uid);
            return ProfileSnapshot(_normalizeProfile(rows.first), id: uid);
          });
    } catch (e) {
      debugPrint("Error streaming user profile from Supabase: $e");
      return Stream.value(ProfileSnapshot(null, id: uid));
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final payload = _denormalizeForSupabase(data);
      await supabase.from('profiles').update(payload).eq('id', uid);
      debugPrint('User profile updated successfully in Supabase for UID: $uid');
    } catch (e) {
      debugPrint('Error updating user profile in Supabase: $e');
      throw Exception('Failed to update user profile in Supabase.');
    }
  }

  Future<ProfileSnapshot> getUserProfile(String uid) async {
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (res == null) {
        return ProfileSnapshot(null, id: uid);
      }
      return ProfileSnapshot(_normalizeProfile(res), id: uid);
    } catch (e) {
      debugPrint('Error getting user profile from Supabase: $e');
      return ProfileSnapshot(null, id: uid);
    }
  }

  Future<void> saveUserFcmToken(String uid, String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await supabase.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
      debugPrint('User FCM token saved in Supabase for UID: $uid');
    } catch (e) {
      debugPrint('Error saving FCM token in Supabase: $e');
    }
  }

  /// Atomically awards points for viewing content item.
  Future<bool> awardPointsForViewingContent(
      String userId, String contentId) async {
    if (userId.isEmpty || contentId.isEmpty) return false;

    try {
      final profile = await getUserProfile(userId);
      if (!profile.exists) return false;

      final data = profile.data()!;
      final List<dynamic> viewedList = data['viewed_content_ids'] ?? [];
      final List<String> viewedIds = viewedList.map((e) => e.toString()).toList();

      if (viewedIds.contains(contentId)) {
        return false; // Already viewed
      }

      viewedIds.add(contentId);
      final int newPoints = (data['points'] as int? ?? 0) + 1;

      await supabase.from('profiles').update({
        'points': newPoints,
        'viewed_content_ids': viewedIds,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('Error awarding points in Supabase: $e');
      return false;
    }
  }
}
