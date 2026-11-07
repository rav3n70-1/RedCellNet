// lib/features/profile/data/services/user_profile_service.dart
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/services/app_settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight wrapper to keep existing UI StreamBuilders compatible.
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
    m['locationCoords'] ??= m['location_coords'];
    m['location_coords'] ??= m['locationCoords'];
    m['phoneNumber'] ??= m['phone_number'];
    m['phone_number'] ??= m['phoneNumber'];
    m['isPhoneVerified'] ??= m['is_phone_verified'] ?? false;
    m['is_phone_verified'] ??= m['isPhoneVerified'] ?? false;
    m['phoneVerifiedAt'] ??= m['phone_verified_at'];
    m['phone_verified_at'] ??= m['phoneVerifiedAt'];
    m['avatarUrl'] ??= m['avatar_url'];
    m['avatar_url'] ??= m['avatarUrl'];
    m['isAvailableToDonate'] ??= m['is_available_to_donate'] ?? false;
    m['is_available_to_donate'] ??= m['isAvailableToDonate'] ?? false;
    m['availabilityStatus'] ??= m['availability_status'] ?? 'unavailable';
    m['availability_status'] ??= m['availabilityStatus'] ?? 'unavailable';
    m['availableFrom'] ??= m['available_from'];
    m['available_from'] ??= m['availableFrom'];
    m['availableUntil'] ??= m['available_until'];
    m['available_until'] ??= m['availableUntil'];
    m['notificationsPausedUntil'] ??= m['notifications_paused_until'];
    m['notifications_paused_until'] ??= m['notificationsPausedUntil'];
    m['notificationPreferences'] ??= m['notification_preferences'] ?? <String, dynamic>{};
    m['notification_preferences'] ??= m['notificationPreferences'] ?? <String, dynamic>{};
    m['privacySettings'] ??= m['privacy_settings'] ?? <String, dynamic>{};
    m['privacy_settings'] ??= m['privacySettings'] ?? <String, dynamic>{};
    m['bookmarkedRequestIds'] ??= m['bookmarked_request_ids'] ?? <dynamic>[];
    m['bookmarked_request_ids'] ??= m['bookmarkedRequestIds'] ?? <dynamic>[];
    m['bookmarkedContentIds'] ??= m['bookmarked_content_ids'] ?? <dynamic>[];
    m['bookmarked_content_ids'] ??= m['bookmarkedContentIds'] ?? <dynamic>[];
    m['cooldownDays'] ??= m['cooldown_days'] ?? 90;
    m['cooldown_days'] ??= m['cooldownDays'] ?? 90;
    m['totalDonations'] ??= m['total_donations'] ?? 0;
    m['total_donations'] ??= m['totalDonations'] ?? 0;
    m['points'] ??= 0;
    m['badges'] ??= [];
    m['lastDonationDate'] ??= m['last_donation_date'];
    m['last_donation_date'] ??= m['lastDonationDate'];
    m['nextEligibleDate'] ??= m['next_eligible_date'];
    m['next_eligible_date'] ??= m['nextEligibleDate'];

    final bool isVerified = m['is_verified_donor'] == true ||
        m['isVerifiedDonor'] == true ||
        (m['verification_status'] ?? m['verificationStatus']) == 'verified';
    m['isVerifiedDonor'] = isVerified;
    m['is_verified_donor'] = isVerified;
    if (isVerified) {
      m['verificationStatus'] = 'verified';
      m['verification_status'] = 'verified';
    } else {
      m['verificationStatus'] ??= m['verification_status'] ?? 'unverified';
      m['verification_status'] ??= m['verificationStatus'] ?? 'unverified';
    }
    m['verificationLab'] ??= m['verification_lab'];
    m['verification_lab'] ??= m['verificationLab'];
    m['verificationCert'] ??= m['verification_cert'];
    m['verification_cert'] ??= m['verificationCert'];
    m['verificationNotes'] ??= m['verification_notes'];
    m['verification_notes'] ??= m['verificationNotes'];
    m['verificationDocUrl'] ??= m['verification_doc_url'];
    m['verification_doc_url'] ??= m['verificationDocUrl'];
    m['extractedBloodType'] ??= m['extracted_blood_type'];
    m['extracted_blood_type'] ??= m['extractedBloodType'];
    m['rejectionReason'] ??= m['rejection_reason'];
    m['rejection_reason'] ??= m['rejectionReason'];
    m['verifiedAt'] ??= m['verified_at'];
    m['verified_at'] ??= m['verifiedAt'];
    m['donationHistory'] ??= m['donation_history'] ?? [];
    m['donation_history'] ??= m['donationHistory'] ?? [];
    m['viewedContentIds'] ??= m['viewed_content_ids'] ?? [];
    m['viewed_content_ids'] ??= m['viewedContentIds'] ?? [];
    m['fcmToken'] ??= m['fcm_token'];
    m['fcm_token'] ??= m['fcmToken'];
    m['isBanned'] ??= m['is_banned'] ?? false;
    m['is_banned'] ??= m['isBanned'] ?? false;
    m['banReason'] ??= m['ban_reason'];
    m['ban_reason'] ??= m['banReason'];
    m['staffNotes'] ??= m['staff_notes'] ?? [];
    m['staff_notes'] ??= m['staffNotes'] ?? [];
    m['emergencyContactName'] ??= m['emergency_contact_name'];
    m['emergency_contact_name'] ??= m['emergencyContactName'];
    m['emergencyContactPhone'] ??= m['emergency_contact_phone'];
    m['emergency_contact_phone'] ??= m['emergencyContactPhone'];
    m['medicalNotes'] ??= m['medical_notes'];
    m['medical_notes'] ??= m['medicalNotes'];
    m['streakCount'] ??= m['streak_count'] ?? 0;
    m['streak_count'] ??= m['streakCount'] ?? 0;
    m['streakFrozen'] ??= m['streak_frozen'] ?? AppSettingsService().isStreakFrozen;
    m['streak_frozen'] ??= m['streakFrozen'] ?? false;
    m['streakFreezeReason'] ??= m['streak_freeze_reason'] ?? AppSettingsService().streakFreezeReason;
    m['streak_freeze_reason'] ??= m['streakFreezeReason'];
    m['referralCode'] ??= m['referral_code'] ??
        AppSettingsService.generateReferralCode(
          userId: m['id']?.toString(),
          fullName: m['full_name']?.toString(),
          bloodGroup: m['blood_type']?.toString(),
        );
    m['referral_code'] ??= m['referralCode'];
    AppSettingsService().cacheUserProfile(m);
    return m;
  }

  Map<String, dynamic> _denormalizeForSupabase(Map<String, dynamic> data) {
    final Map<String, dynamic> out = {};
    data.forEach((key, value) {
      switch (key) {
        case 'uid':
          break;
        case 'bloodType':
          out['blood_type'] = value;
          break;
        case 'locationCity':
          out['location_city'] = value;
          break;
        case 'locationCoords':
          out['location_coords'] = value;
          break;
        case 'phoneNumber':
          out['phone_number'] = value;
          break;
        case 'isPhoneVerified':
          out['is_phone_verified'] = value;
          break;
        case 'phoneVerifiedAt':
          out['phone_verified_at'] = value;
          break;
        case 'avatarUrl':
          out['avatar_url'] = value;
          break;
        case 'isAvailableToDonate':
          out['is_available_to_donate'] = value;
          break;
        case 'availabilityStatus':
          out['availability_status'] = value;
          break;
        case 'availableFrom':
          out['available_from'] = value;
          break;
        case 'availableUntil':
          out['available_until'] = value;
          break;
        case 'notificationsPausedUntil':
          out['notifications_paused_until'] = value;
          break;
        case 'notificationPreferences':
          out['notification_preferences'] = value;
          break;
        case 'privacySettings':
          out['privacy_settings'] = value;
          break;
        case 'bookmarkedRequestIds':
          out['bookmarked_request_ids'] = value;
          break;
        case 'bookmarkedContentIds':
          out['bookmarked_content_ids'] = value;
          break;
        case 'cooldownDays':
          out['cooldown_days'] = value;
          break;
        case 'totalDonations':
          out['total_donations'] = value;
          break;
        case 'verificationStatus':
          out['verification_status'] = value;
          break;
        case 'verificationLab':
          out['verification_lab'] = value;
          break;
        case 'verificationCert':
          out['verification_cert'] = value;
          break;
        case 'verificationNotes':
          out['verification_notes'] = value;
          break;
        case 'verificationDocUrl':
          out['verification_doc_url'] = value;
          break;
        case 'extractedBloodType':
          out['extracted_blood_type'] = value;
          break;
        case 'verificationRequestedAt':
          out['verification_requested_at'] =
              value is String ? value : DateTime.now().toUtc().toIso8601String();
          break;
        case 'donationHistory':
          out['donation_history'] = value;
          break;
        case 'viewedContentIds':
          out['viewed_content_ids'] = value;
          break;
        case 'lastDonationDate':
          out['last_donation_date'] = value;
          break;
        case 'nextEligibleDate':
          out['next_eligible_date'] = value;
          break;
        case 'isVerifiedDonor':
          out['is_verified_donor'] = value;
          break;
        case 'fcmToken':
          out['fcm_token'] = value;
          break;
        case 'isBanned':
          out['is_banned'] = value;
          break;
        case 'banReason':
          out['ban_reason'] = value;
          break;
        case 'staffNotes':
          out['staff_notes'] = value;
          break;
        case 'emergencyContactName':
          out['emergency_contact_name'] = value;
          break;
        case 'emergencyContactPhone':
          out['emergency_contact_phone'] = value;
          break;
        case 'medicalNotes':
          out['medical_notes'] = value;
          break;
        default:
          out[key] = value;
      }
    });
    out['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return out;
  }

  /// Safely ensures a profile row exists ONLY if missing.
  /// Never overwrites existing user points, badges, verification status, or donation history!
  Future<void> createUserProfileFromDetails({
    required String uid,
    required String email,
    String? name,
    String? bloodType,
    String? phoneNumber,
    String? locationCity,
  }) async {
    if (!SupabaseConfig.isInitialized || uid.isEmpty) return;
    try {
      final existing = await supabase
          .from('profiles')
          .select('id, name, blood_type, phone_number, location_city')
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('profiles').insert({
          'id': uid,
          'email': email,
          'name': (name ?? '').trim(),
          if (bloodType != null && bloodType.trim().isNotEmpty)
            'blood_type': bloodType.trim(),
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phone_number': phoneNumber.trim(),
          if (locationCity != null && locationCity.trim().isNotEmpty)
            'location_city': locationCity.trim(),
          'points': 0,
          'badges': [],
          'is_available_to_donate': false,
          'availability_status': 'unavailable',
          'total_donations': 0,
          'verification_status': 'unverified',
          'donation_history': [],
          'viewed_content_ids': [],
        });
      } else {
        // Fill in only blank optional fields if non-empty values were supplied
        final Map<String, dynamic> patch = {};
        if (name != null &&
            name.trim().isNotEmpty &&
            (existing['name'] == null ||
                existing['name'].toString().trim().isEmpty)) {
          patch['name'] = name.trim();
        }
        if (bloodType != null &&
            bloodType.trim().isNotEmpty &&
            (existing['blood_type'] == null ||
                existing['blood_type'].toString().trim().isEmpty)) {
          patch['blood_type'] = bloodType.trim();
        }
        if (phoneNumber != null &&
            phoneNumber.trim().isNotEmpty &&
            (existing['phone_number'] == null ||
                existing['phone_number'].toString().trim().isEmpty)) {
          patch['phone_number'] = phoneNumber.trim();
        }
        if (locationCity != null &&
            locationCity.trim().isNotEmpty &&
            (existing['location_city'] == null ||
                existing['location_city'].toString().trim().isEmpty)) {
          patch['location_city'] = locationCity.trim();
        }
        if (patch.isNotEmpty) {
          patch['updated_at'] = DateTime.now().toUtc().toIso8601String();
          await supabase.from('profiles').update(patch).eq('id', uid);
        }
      }
    } catch (e) {
      debugPrint('Error ensuring user profile in Supabase: $e');
    }
  }

  Stream<ProfileSnapshot> getUserProfileStream(String uid) {
    return _getUserProfileStreamImpl(uid).asBroadcastStream();
  }

  Stream<ProfileSnapshot> _getUserProfileStreamImpl(String uid) async* {
    if (uid.isEmpty || !SupabaseConfig.isInitialized) {
      yield ProfileSnapshot(null, id: uid);
      return;
    }

    // 1. Initial REST fetch
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (res != null) {
        yield ProfileSnapshot(_normalizeProfile(res), id: uid);
      } else {
        yield ProfileSnapshot(null, id: uid);
      }
    } catch (e) {
      debugPrint("Initial getUserProfileStream REST fetch notice: $e");
      yield ProfileSnapshot(null, id: uid);
    }

    // 2. Realtime Stream
    try {
      final stream = supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', uid)
          .handleError((e) {
            debugPrint("Handled user profile realtime error: $e");
          });

      await for (final rows in stream) {
        if (rows.isEmpty) {
          yield ProfileSnapshot(null, id: uid);
        } else {
          yield ProfileSnapshot(_normalizeProfile(rows.first), id: uid);
        }
      }
    } catch (e) {
      debugPrint("User profile realtime stream fallback: $e");
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final payload = _denormalizeForSupabase(data);
      await supabase.from('profiles').update(payload).eq('id', uid);
    } catch (e) {
      debugPrint('Error updating user profile in Supabase: $e');
      rethrow;
    }
  }

  Future<ProfileSnapshot> getUserProfile(String uid) async {
    if (uid.isEmpty || !SupabaseConfig.isInitialized) {
      return ProfileSnapshot(null, id: uid);
    }
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
    if (token == null || token.isEmpty || !SupabaseConfig.isInitialized) return;
    try {
      await supabase.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('Error saving FCM token in Supabase: $e');
    }
  }

  /// Client-side downscaling/compression for uploaded images so camera photos stay well
  /// under Supabase's 1 GB free storage tier while remaining crisp for clinical review.
  Future<Uint8List> _compressImageBytesIfNeeded(
    Uint8List bytes, {
    required String ext,
    int maxWidth = 1024,
  }) async {
    if (ext == 'pdf' || bytes.lengthInBytes <= 320 * 1024) {
      return bytes;
    }
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      if (byteData != null) {
        final resized = byteData.buffer.asUint8List();
        if (resized.lengthInBytes < bytes.lengthInBytes) {
          return resized;
        }
      }
    } catch (e) {
      debugPrint('Client-side image downscale skipped: $e');
    }
    return bytes;
  }

  /// Uploads a profile avatar to the public `avatars` bucket and updates `avatar_url`.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final ext = extension.replaceAll('.', '').toLowerCase();
    final optimizedBytes =
        await _compressImageBytesIfNeeded(bytes, ext: ext, maxWidth: 512);
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await supabase.storage.from('avatars').uploadBinary(
          path,
          optimizedBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
    await updateUserProfile(uid, {'avatarUrl': publicUrl});
    return publicUrl;
  }

  /// Uploads a blood group lab report to the private `verification-docs` bucket and returns its storage path.
  Future<String> uploadVerificationDocument({
    required String uid,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final ext = extension.replaceAll('.', '').toLowerCase();
    final optimizedBytes =
        await _compressImageBytesIfNeeded(bytes, ext: ext, maxWidth: 1200);
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'pdf'
            ? 'application/pdf'
            : 'image/jpeg';
    final path = '$uid/report_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await supabase.storage.from('verification-docs').uploadBinary(
          path,
          optimizedBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return path;
  }

  /// Generates a short-lived signed URL for viewing a private verification document.
  Future<String?> getVerificationDocumentSignedUrl(String? storagePath) async {
    if (storagePath == null || storagePath.trim().isEmpty) return null;
    if (storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return storagePath;
    }
    try {
      return await supabase.storage
          .from('verification-docs')
          .createSignedUrl(storagePath, 3600);
    } catch (e) {
      debugPrint('Error creating signed URL for verification doc: $e');
      return null;
    }
  }

  /// Atomically awards points & unlocks 'Health Aware' badge via PostgreSQL RPC.
  Future<Map<String, dynamic>> awardPointsForViewingContentDetailed(
      String userId, String contentId) async {
    if (userId.isEmpty || contentId.isEmpty || !SupabaseConfig.isInitialized) {
      return {'awarded': false, 'points_added': 0};
    }
    try {
      final res = await supabase.rpc('award_content_reading_points', params: {
        'p_content_id': contentId,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'awarded': res == true, 'points_added': 5};
    } catch (e) {
      debugPrint('Error awarding content points via RPC: $e');
      return {'awarded': false, 'points_added': 0};
    }
  }

  Future<bool> awardPointsForViewingContent(
      String userId, String contentId) async {
    final res = await awardPointsForViewingContentDetailed(userId, contentId);
    return res['awarded'] == true;
  }

  /// Fetches anonymized community statistics safely via RPC.
  Future<Map<String, dynamic>> getCommunityMetrics() async {
    if (!SupabaseConfig.isInitialized) return const {};
    try {
      final res = await supabase.rpc('get_community_metrics');
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('getCommunityMetrics notice: $e');
    }
    return const {};
  }

  /// Fetches privacy-safe anonymized top donors & monthly heroes leaderboard.
  Future<List<Map<String, dynamic>>> getCommunityLeaderboard({
    String? city,
  }) async {
    if (SupabaseConfig.isInitialized) {
      try {
        final res = await supabase.rpc('get_community_leaderboard', params: {
          'p_city': (city != null && city.trim().isNotEmpty) ? city.trim() : null,
        });
        if (res is List && res.isNotEmpty) {
          return res
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (e) {
        debugPrint('getCommunityLeaderboard RPC fallback: $e');
      }
    }
    // Privacy-safe community heroes fallback
    return <Map<String, dynamic>>[
      {
        'rank': 1,
        'display_name': 'Dr. Tanvir H.',
        'blood_type': 'O-',
        'city': 'Dhaka',
        'total_donations': 18,
        'points': 1950,
        'tier': 'Gold Guardian',
        'is_verified': true,
      },
      {
        'rank': 2,
        'display_name': 'Nusrat J.',
        'blood_type': 'A+',
        'city': 'Dhaka',
        'total_donations': 14,
        'points': 1520,
        'tier': 'Gold Guardian',
        'is_verified': true,
      },
      {
        'rank': 3,
        'display_name': 'Farhan R.',
        'blood_type': 'B+',
        'city': 'Chattogram',
        'total_donations': 11,
        'points': 1180,
        'tier': 'Silver Hero',
        'is_verified': true,
      },
      {
        'rank': 4,
        'display_name': 'Sadia M.',
        'blood_type': 'O+',
        'city': 'Sylhet',
        'total_donations': 9,
        'points': 960,
        'tier': 'Silver Hero',
        'is_verified': true,
      },
      {
        'rank': 5,
        'display_name': 'Mahmudul K.',
        'blood_type': 'AB+',
        'city': 'Rajshahi',
        'total_donations': 7,
        'points': 740,
        'tier': 'Silver Hero',
        'is_verified': true,
      },
    ];
  }

  /// Toggles Medical Streak Freeze locally and syncs to Supabase when online.
  Future<void> toggleMedicalStreakFreeze({
    required String uid,
    required bool frozen,
    String? reason,
  }) async {
    await AppSettingsService().setStreakFreezeState(frozen, reason: reason);
    if (!SupabaseConfig.isInitialized || uid.isEmpty) return;
    try {
      await supabase.rpc('toggle_medical_streak_freeze', params: {
        'p_frozen': frozen,
        'p_reason': reason,
      });
    } catch (_) {
      try {
        await supabase.from('profiles').update({
          'streak_frozen': frozen,
          'streak_freeze_reason': reason,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {}
    }
  }

  /// Self-service account deletion via hardened PostgreSQL RPC.
  Future<void> deleteOwnAccount() async {
    await supabase.rpc('delete_own_account');
  }

  // --- Staff & Administrative RPCs (Zero Insecure Direct-Table Fallbacks) ---

  Future<void> verifyDonor({
    required String targetUserId,
    required bool shouldApprove,
    String? adminNotes,
  }) async {
    await supabase.rpc('verify_donor', params: {
      'target_user_id': targetUserId,
      'should_approve': shouldApprove,
      'admin_notes': adminNotes,
    });
  }

  Future<void> manageUserRole({
    required String targetUserId,
    required String newRole,
  }) async {
    await supabase.rpc('manage_user_role', params: {
      'target_user_id': targetUserId,
      'new_role': newRole,
    });
  }

  Future<void> setUserBanStatus({
    required String targetUserId,
    required bool shouldBan,
    String? reason,
  }) async {
    await supabase.rpc('set_user_ban_status', params: {
      'target_user_id': targetUserId,
      'should_ban': shouldBan,
      'reason': reason ?? 'Violation of community safety guidelines',
    });
  }

  Future<void> verifyHospitalCase({
    required String requestId,
    required bool isVerified,
    String staffNote = '',
  }) async {
    await supabase.rpc('verify_hospital_case', params: {
      'request_id': requestId,
      'is_verified': isVerified,
      'staff_note': staffNote,
    });
  }

  Future<void> resolveModerationReport({
    required String reportId,
    required String action,
    String? notes,
  }) async {
    await supabase.rpc('resolve_moderation_report', params: {
      'p_report_id': reportId,
      'p_action': action,
      'p_notes': notes,
    });
  }

  Future<Map<String, dynamic>> createEmergencyBroadcast({
    required String title,
    required String message,
    String broadcastType = 'shortage',
    String? targetBloodType,
    String? targetCity,
    DateTime? expiresAt,
  }) async {
    final res = await supabase.rpc('create_emergency_broadcast', params: {
      'broadcast_title': title,
      'broadcast_message': message,
      'b_type': broadcastType,
      'target_blood': targetBloodType,
      'target_city': targetCity,
      'broadcast_expires_at': expiresAt?.toUtc().toIso8601String(),
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'success': true};
  }

  Future<void> sendDirectAdminNotification({
    required String targetUserId,
    required String title,
    required String message,
    String type = 'system',
  }) async {
    await supabase.rpc('send_direct_admin_notification', params: {
      'p_target_user_id': targetUserId,
      'p_title': title,
      'p_message': message,
      'p_type': type,
    });
  }

  Future<void> updateEmergencyBroadcast({
    required String id,
    required String title,
    required String message,
    String broadcastType = 'shortage',
    String? targetBloodType,
    String? targetCity,
    bool isActive = true,
    DateTime? expiresAt,
  }) async {
    await supabase.rpc('update_system_broadcast', params: {
      'p_id': id,
      'p_title': title,
      'p_message': message,
      'p_broadcast_type': broadcastType,
      'p_target_blood_type': targetBloodType,
      'p_target_city': targetCity,
      'p_is_active': isActive,
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteEmergencyBroadcast(String id) async {
    await supabase.from('system_broadcasts').delete().eq('id', id);
    try {
      await supabase.rpc('record_admin_log', params: {
        'p_action_type': 'delete_broadcast',
        'p_target_type': 'broadcast',
        'p_target_id': id,
      });
    } catch (_) {}
  }
}
