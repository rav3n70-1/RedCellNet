// lib/features/donation_centers/data/services/donation_center_service.dart
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/features/donation_centers/data/models/donation_center.dart';

class DonationCenterService {
  Stream<List<DonationCenter>> getVerifiedCentersStream() {
    try {
      return supabase
          .from('donation_centers')
          .stream(primaryKey: ['id'])
          .eq('is_verified', true)
          .map((rows) => rows.map((r) => DonationCenter.fromMap(r)).toList());
    } catch (e) {
      debugPrint("Error streaming verified donation centers: $e");
      return Stream.value([]);
    }
  }

  Stream<List<DonationCenter>> getDonationCentersStream() {
    try {
      return supabase
          .from('donation_centers')
          .stream(primaryKey: ['id'])
          .map((rows) => rows.map((r) => DonationCenter.fromMap(r)).toList());
    } catch (e) {
      debugPrint("Error streaming donation centers: $e");
      return Stream.value([]);
    }
  }

  Future<DonationCenter?> getCenter(String docId) async {
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
      debugPrint("Error fetching single center $docId: $e");
      return null;
    }
  }

  Future<void> addCenter(Map<String, dynamic> data) async {
    try {
      await supabase.from('donation_centers').insert(data);
    } catch (e) {
      debugPrint("Error adding donation center: $e");
      rethrow;
    }
  }

  Future<void> updateCenter(String id, Map<String, dynamic> data) async {
    try {
      await supabase.from('donation_centers').update(data).eq('id', id);
    } catch (e) {
      debugPrint("Error updating donation center: $e");
      rethrow;
    }
  }

  Future<void> deleteCenter(String id) async {
    try {
      await supabase.from('donation_centers').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error deleting donation center: $e");
      rethrow;
    }
  }
}
