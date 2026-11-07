// lib/features/donation_centers/data/services/donation_center_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';

class DonationCenterService {
  /// Offline-only fallback centers used strictly when Supabase is unreachable or uninitialized.
  static final List<DonationCenter> _offlineFallbackCenters = [
    DonationCenter(
      id: '62905021-36ee-4959-80e7-dd86a584b22f',
      name: 'Dhaka Medical College Blood Bank',
      address: 'Secretariat Road, Ramna, Dhaka 1000',
      city: 'Dhaka',
      contactInfo: '+8802-55165088',
      operatingHours: 'Open 24 Hours / 7 Days',
      facilityType: 'Hospital Transfusion Dept',
      operationalStatus: '24/7 Open',
      latitude: 23.7258,
      longitude: 90.3976,
      isVerified: true,
      bloodInventory: {'A+': 12, 'B+': 15, 'O+': 20, 'AB+': 6, 'O-': 4},
    ),
    DonationCenter(
      id: 'fdf3be45-6bad-472c-b817-fcc2ca5b0897',
      name: 'Bangladesh Red Crescent Society',
      address: '684-686, Red Crescent Sarak, Bara Moghbazar, Dhaka',
      city: 'Dhaka',
      contactInfo: '+8802-48310188',
      operatingHours: '9:00 AM – 8:00 PM',
      facilityType: 'Red Crescent Center',
      operationalStatus: 'Open',
      latitude: 23.7499,
      longitude: 90.4089,
      isVerified: true,
      bloodInventory: {'A+': 8, 'B+': 10, 'O+': 14, 'AB+': 4, 'O-': 2},
    ),
    DonationCenter(
      id: '36d385f6-11e8-4ef6-9211-fa0b4c137deb',
      name: 'Chittagong Medical College Hospital',
      address: '57 K.B. Fazlul Kader Rd, Chattogram 4203',
      city: 'Chattogram',
      contactInfo: '+88031-619400',
      operatingHours: 'Open 24 Hours / 7 Days',
      facilityType: 'Hospital Transfusion Dept',
      operationalStatus: '24/7 Open',
      latitude: 22.3592,
      longitude: 91.8215,
      isVerified: true,
      bloodInventory: {'A+': 10, 'B+': 12, 'O+': 16, 'AB+': 5},
    ),
    DonationCenter(
      id: 'ad20a3a9-193b-455c-a3c5-948ea6fc66f7',
      name: 'Rajshahi Medical College Hospital',
      address: 'Laxmipur, Rajshahi 6000',
      city: 'Rajshahi',
      contactInfo: '+880721-772150',
      operatingHours: 'Open 24 Hours / 7 Days',
      facilityType: 'Hospital Transfusion Dept',
      operationalStatus: '24/7 Open',
      latitude: 24.3705,
      longitude: 88.5834,
      isVerified: true,
      bloodInventory: {'A+': 6, 'B+': 8, 'O+': 11, 'AB+': 3},
    ),
  ];

  Stream<List<DonationCenter>> getDonationCentersStream() {
    return _getDonationCentersStreamImpl().asBroadcastStream();
  }

  Stream<List<DonationCenter>> _getDonationCentersStreamImpl() async* {
    if (!SupabaseConfig.isInitialized) {
      yield _offlineFallbackCenters;
      return;
    }

    // 1. Initial REST fetch
    try {
      final rows = await supabase
          .from('donation_centers')
          .select()
          .order('name', ascending: true);

      yield rows.map((r) => DonationCenter.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Donation centers REST notice: $e (using offline fallback)');
      yield _offlineFallbackCenters;
    }

    // 2. Realtime Stream
    try {
      final stream = supabase
          .from('donation_centers')
          .stream(primaryKey: ['id'])
          .handleError((e) {
            debugPrint('Handled donation centers realtime error: $e');
          });

      await for (final rows in stream) {
        final mapped = rows.map((r) => DonationCenter.fromMap(r)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        yield mapped;
      }
    } catch (e) {
      debugPrint('Donation centers realtime stream fallback: $e');
    }
  }

  Stream<List<DonationCenter>> getVerifiedCentersStream() {
    return getDonationCentersStream()
        .map((list) => list.where((c) => c.isVerified).toList())
        .asBroadcastStream();
  }

  Future<DonationCenter?> getCenter(String docId) async {
    if (!SupabaseConfig.isInitialized) {
      final match = _offlineFallbackCenters.where((c) => c.id == docId);
      return match.isNotEmpty ? match.first : null;
    }
    try {
      final res = await supabase
          .from('donation_centers')
          .select()
          .eq('id', docId)
          .maybeSingle();
      if (res != null) {
        return DonationCenter.fromMap(res);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching single center $docId: $e');
      final match = _offlineFallbackCenters.where((c) => c.id == docId);
      return match.isNotEmpty ? match.first : null;
    }
  }

  Map<String, dynamic> _preparePayload(Map<String, dynamic> data) {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
    if (payload.containsKey('contact_info') && !payload.containsKey('contact_number')) {
      payload['contact_number'] = payload['contact_info'];
    } else if (payload.containsKey('contact_number') && !payload.containsKey('contact_info')) {
      payload['contact_info'] = payload['contact_number'];
    }
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return payload;
  }

  Future<void> addCenter(Map<String, dynamic> data) async {
    try {
      final payload = _preparePayload(data);
      final inserted = await supabase
          .from('donation_centers')
          .insert(payload)
          .select('id, name')
          .maybeSingle();
      try {
        await supabase.rpc('record_admin_log', params: {
          'p_action_type': 'create_facility',
          'p_target_type': 'facility',
          'p_target_id': inserted?['id']?.toString() ?? '',
          'p_details': {'name': payload['name']},
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Error adding donation center: $e');
      rethrow;
    }
  }

  Future<void> updateCenter(String id, Map<String, dynamic> data) async {
    try {
      final payload = _preparePayload(data);
      await supabase.from('donation_centers').update(payload).eq('id', id);
      try {
        await supabase.rpc('record_admin_log', params: {
          'p_action_type': 'update_facility',
          'p_target_type': 'facility',
          'p_target_id': id,
          'p_details': {'name': payload['name']},
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Error updating donation center: $e');
      rethrow;
    }
  }

  Future<void> deleteCenter(String id) async {
    try {
      await supabase.from('donation_centers').delete().eq('id', id);
      try {
        await supabase.rpc('record_admin_log', params: {
          'p_action_type': 'delete_facility',
          'p_target_type': 'facility',
          'p_target_id': id,
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Error deleting donation center: $e');
      rethrow;
    }
  }
}
