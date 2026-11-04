// lib/features/blood_requests/data/services/request_service.dart
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';
import 'package:red_cell_net_final/features/notifications/data/services/notification_service.dart';

class RequestService {
  Map<String, dynamic> _normalizeRequest(Map<String, dynamic> raw) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    m['id'] = m['id']?.toString() ?? '';

    m['requesterUserId'] ??= m['requester_user_id'];
    m['requester_user_id'] ??= m['requesterUserId'];

    m['patientName'] ??= m['patient_name'] ?? '';
    m['patient_name'] ??= m['patientName'];

    m['hospitalName'] ??= m['hospital_name'] ?? '';
    m['hospital_name'] ??= m['hospitalName'];

    m['city'] ??= '';

    m['requiredBloodType'] ??= m['required_blood_type'] ?? '';
    m['required_blood_type'] ??= m['requiredBloodType'];

    m['requiredUnits'] ??= m['required_units'] ?? 1;
    m['required_units'] ??= m['requiredUnits'];
    m['unitsNeeded'] ??= m['requiredUnits'];

    m['acceptedUnits'] ??= m['accepted_units'] ?? 0;
    m['accepted_units'] ??= m['acceptedUnits'];

    m['remainingUnits'] ??= m['remaining_units'] ?? m['requiredUnits'];
    m['remaining_units'] ??= m['remainingUnits'];

    m['contactPhone'] ??= m['contact_phone'] ?? '';
    m['contact_phone'] ??= m['contactPhone'];

    m['urgencyLevel'] ??= m['urgency_level'] ?? 'Medium';
    m['urgency_level'] ??= m['urgencyLevel'];

    m['reason'] ??= '';
    m['isEmergency'] ??= m['is_emergency'] ?? false;
    m['is_emergency'] ??= m['isEmergency'];

    m['status'] ??= 'Open';
    m['expiryHours'] ??= m['expiry_hours'] ?? 48;
    m['expiry_hours'] ??= m['expiryHours'];

    m['componentType'] ??= m['component_type'] ?? 'Whole Blood';
    m['component_type'] ??= m['componentType'];

    m['acceptedDonorIds'] ??= m['accepted_donor_ids'] ?? [];
    m['accepted_donor_ids'] ??= m['acceptedDonorIds'];

    m['timeline'] ??= [];
    m['offers'] ??= [];

    final rawCreatedAt = m['created_at'];
    final ts = AppTimestamp.fromValue(rawCreatedAt);
    m['createdAt'] = ts;
    m['created_at'] = rawCreatedAt ?? ts.toString();

    final rawExpiry = m['expiry_at'];
    if (rawExpiry != null) {
      m['expiryAt'] = AppTimestamp.fromValue(rawExpiry);
    }

    return m;
  }

  Map<String, dynamic> _denormalizeForSupabase(Map<String, dynamic> data) {
    final Map<String, dynamic> out = {};
    data.forEach((k, v) {
      if (k == 'requesterUserId') {
        out['requester_user_id'] = v;
      } else if (k == 'patientName') {
        out['patient_name'] = v;
      } else if (k == 'hospitalName') {
        out['hospital_name'] = v;
      } else if (k == 'requiredBloodType') {
        out['required_blood_type'] = v;
      } else if (k == 'requiredUnits' || k == 'unitsNeeded') {
        out['required_units'] = v;
      } else if (k == 'acceptedUnits') {
        out['accepted_units'] = v;
      } else if (k == 'remainingUnits') {
        out['remaining_units'] = v;
      } else if (k == 'contactPhone') {
        out['contact_phone'] = v;
      } else if (k == 'urgencyLevel') {
        out['urgency_level'] = v;
      } else if (k == 'isEmergency') {
        out['is_emergency'] = v;
      } else if (k == 'expiryHours') {
        out['expiry_hours'] = v;
      } else if (k == 'componentType') {
        out['component_type'] = v;
      } else if (k == 'acceptedDonorIds') {
        out['accepted_donor_ids'] = v;
      } else if (k == 'locationCoords') {
        out['location_coords'] = v;
      } else if (k == 'createdAt' || k == 'expiryAt') {
        // Skip timestamp conversion handled directly
      } else {
        out[k] = v;
      }
    });
    out['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return out;
  }

  // --- Create Request ---
  Future<String> createBloodRequest(Map<String, dynamic> requestData) async {
    final String? currentUserId = SupabaseAuthService().currentUserId;
    if (currentUserId == null) {
      throw Exception("User must be logged in to create a request.");
    }

    final int totalUnits =
        (requestData['requiredUnits'] ?? requestData['unitsNeeded'] ?? 1) as int;
    final int expiryHours = (requestData['expiryHours'] ?? 48) as int;
    final DateTime expiryDate = DateTime.now().add(Duration(hours: expiryHours));

    final payload = _denormalizeForSupabase(requestData);
    payload['requester_user_id'] = currentUserId;
    payload['required_units'] = totalUnits;
    payload['accepted_units'] = 0;
    payload['remaining_units'] = totalUnits;
    payload['status'] = 'Open';
    payload['expiry_hours'] = expiryHours;
    payload['expiry_at'] = expiryDate.toUtc().toIso8601String();
    payload['created_at'] = DateTime.now().toUtc().toIso8601String();
    payload['accepted_donor_ids'] = [];
    payload['offers'] = [];
    payload['timeline'] = [
      {
        'action': 'created',
        'by': currentUserId,
        'time': DateTime.now().toUtc().toIso8601String(),
      }
    ];

    try {
      final res = await supabase
          .from('blood_requests')
          .insert(payload)
          .select('id')
          .single();
      final String newId = res['id'].toString();
      debugPrint('Blood request created in Supabase with ID: $newId');
      return newId;
    } catch (e) {
      debugPrint('Error creating blood request in Supabase: $e');
      throw Exception('Failed to create blood request in Supabase: $e');
    }
  }

  // --- Get Request Stream by ID ---
  Stream<AppDocSnapshot> getRequestStream(String requestId) {
    try {
      return supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .eq('id', requestId)
          .map((rows) {
            if (rows.isEmpty) return AppDocSnapshot(requestId, null);
            return AppDocSnapshot(requestId, _normalizeRequest(rows.first));
          });
    } catch (e) {
      debugPrint("Error streaming request $requestId: $e");
      return Stream.value(AppDocSnapshot(requestId, null));
    }
  }

  // --- Get Request Details ---
  Future<AppDocSnapshot> getRequestDetails(String requestId) async {
    if (requestId.isEmpty) {
      throw ArgumentError("Request ID cannot be empty.");
    }
    try {
      final res = await supabase
          .from('blood_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();

      if (res == null) {
        throw Exception('Request document does not exist for ID: $requestId');
      }
      return AppDocSnapshot(requestId, _normalizeRequest(res));
    } catch (e) {
      debugPrint('Error getting request details for $requestId: $e');
      rethrow;
    }
  }

  // --- Get Request Stream ---
  Stream<AppQuerySnapshot> getBloodRequestsStream({
    String? bloodTypeFilter,
    String? ownerUserId,
    String? urgencyLevelFilter,
    String? statusFilter,
  }) {
    try {
      return supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
            List<Map<String, dynamic>> filtered = rows;

            if (ownerUserId != null && ownerUserId.isNotEmpty) {
              filtered = filtered
                  .where((r) =>
                      r['requester_user_id'] == ownerUserId ||
                      r['requesterUserId'] == ownerUserId)
                  .toList();
            } else if (statusFilter != null && statusFilter.isNotEmpty) {
              filtered = filtered
                  .where((r) => r['status'] == statusFilter)
                  .toList();
            } else {
              filtered = filtered
                  .where((r) =>
                      r['status'] == 'Open' ||
                      r['status'] == 'Partially Fulfilled')
                  .toList();
            }

            if (bloodTypeFilter != null &&
                bloodTypeFilter.isNotEmpty &&
                bloodTypeFilter != 'All') {
              filtered = filtered
                  .where((r) =>
                      r['required_blood_type'] == bloodTypeFilter ||
                      r['requiredBloodType'] == bloodTypeFilter)
                  .toList();
            }

            if (urgencyLevelFilter != null &&
                urgencyLevelFilter.isNotEmpty &&
                urgencyLevelFilter != 'All') {
              filtered = filtered
                  .where((r) =>
                      r['urgency_level'] == urgencyLevelFilter ||
                      r['urgencyLevel'] == urgencyLevelFilter)
                  .toList();
            }

            final docs = filtered
                .map((r) => AppDocSnapshot(
                    r['id']?.toString() ?? '', _normalizeRequest(r)))
                .toList();

            return AppQuerySnapshot(docs);
          });
    } catch (e) {
      debugPrint("Error streaming blood_requests from Supabase: $e");
      return Stream.value(AppQuerySnapshot([]));
    }
  }

  // --- Get Urgent Requests Stream ---
  Stream<AppQuerySnapshot> getUrgentRequestsStream({int limit = 4}) {
    try {
      return supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
            final urgent = rows.where((r) {
              final status = r['status'] ?? 'Open';
              final urgency = r['urgency_level'] ?? r['urgencyLevel'] ?? '';
              final isOpen = status == 'Open' || status == 'Partially Fulfilled';
              final isUrgent = urgency == 'Critical' || urgency == 'High';
              return isOpen && isUrgent;
            }).take(limit);

            final docs = urgent
                .map((r) => AppDocSnapshot(
                    r['id']?.toString() ?? '', _normalizeRequest(r)))
                .toList();

            return AppQuerySnapshot(docs);
          });
    } catch (e) {
      debugPrint("Error streaming urgent requests from Supabase: $e");
      return Stream.value(AppQuerySnapshot([]));
    }
  }

  // --- Get Offers Stream ---
  Stream<AppQuerySnapshot> getOffersStream(String requestId) {
    try {
      return supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .eq('id', requestId)
          .map((rows) {
            if (rows.isEmpty) return AppQuerySnapshot([]);
            final req = rows.first;
            final List<dynamic> rawOffers = req['offers'] ?? [];
            final docs = rawOffers.map((o) {
              final Map<String, dynamic> oMap =
                  Map<String, dynamic>.from(o as Map);
              final String oid = oMap['id']?.toString() ??
                  oMap['donorId']?.toString() ??
                  '';
              oMap['offerTimestamp'] =
                  AppTimestamp.fromValue(oMap['offerTimestamp']);
              return AppDocSnapshot(oid, oMap);
            }).toList();
            return AppQuerySnapshot(docs);
          });
    } catch (e) {
      debugPrint("Error streaming offers from Supabase: $e");
      return Stream.value(AppQuerySnapshot([]));
    }
  }

  // --- Get User Offers Stream ---
  Stream<AppQuerySnapshot> getUserOffersStream(String donorId) {
    try {
      return supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .map((rows) {
            final List<AppDocSnapshot> userOffers = [];
            for (final r in rows) {
              final List<dynamic> rawOffers = r['offers'] ?? [];
              for (final o in rawOffers) {
                if (o is Map && o['donorId'] == donorId) {
                  final Map<String, dynamic> oMap =
                      Map<String, dynamic>.from(o);
                  final String oid = oMap['id']?.toString() ?? '';
                  oMap['offerTimestamp'] =
                      AppTimestamp.fromValue(oMap['offerTimestamp']);
                  oMap['requestId'] = r['id'];
                  userOffers.add(AppDocSnapshot(oid, oMap));
                }
              }
            }
            return AppQuerySnapshot(userOffers);
          });
    } catch (e) {
      debugPrint("Error streaming user offers from Supabase: $e");
      return Stream.value(AppQuerySnapshot([]));
    }
  }

  // --- Submit Offer ---
  Future<void> submitOffer({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorBloodType,
    int offeredUnits = 1,
    bool donorIsVerified = false,
  }) async {
    final req = await supabase
        .from('blood_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (req == null) throw Exception("Request does not exist.");

    final status = req['status'] ?? 'Open';
    if (status != 'Open' && status != 'Partially Fulfilled') {
      throw Exception(
          "This blood request is no longer accepting offers ($status).");
    }

    final int remaining = req['remaining_units'] ?? req['required_units'] ?? 1;
    if (offeredUnits > remaining) {
      throw Exception(
          "Offered units ($offeredUnits) exceed remaining requirement ($remaining).");
    }

    final List<dynamic> offers = List<dynamic>.from(req['offers'] ?? []);
    final newOfferId = DateTime.now().millisecondsSinceEpoch.toString();

    final offerData = {
      'id': newOfferId,
      'donorId': donorId,
      'donorName': donorName,
      'donorBloodType': donorBloodType,
      'offeredUnits': offeredUnits,
      'donorIsVerified': donorIsVerified,
      'status': 'pending',
      'offerTimestamp': DateTime.now().toUtc().toIso8601String(),
    };

    offers.add(offerData);

    await supabase.from('blood_requests').update({
      'offers': offers,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);

    // Notify requester
    final String? requesterId = req['requester_user_id'];
    if (requesterId != null && requesterId.isNotEmpty) {
      await NotificationService().createNotification(
        userId: requesterId,
        title: 'New Blood Donation Offer',
        body:
            '$donorName ($donorBloodType) offered $offeredUnits unit(s) for your request.',
        screen: '/request_details',
        resourceId: requestId,
      );
    }
  }

  // --- Accept Offer ---
  Future<void> acceptOffer(
    String requestId,
    String offerId,
    String donorId, {
    int offeredUnits = 1,
  }) async {
    final req = await supabase
        .from('blood_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (req == null) throw Exception("Request not found.");

    final int required = req['required_units'] ?? 1;
    final int currentAccepted = req['accepted_units'] ?? 0;
    final int currentRemaining = required - currentAccepted;

    if (offeredUnits > currentRemaining) {
      throw Exception(
          "Cannot accept $offeredUnits unit(s). Only $currentRemaining unit(s) remaining.");
    }

    final int newAccepted = currentAccepted + offeredUnits;
    final int newRemaining = required - newAccepted;
    final String newStatus =
        (newRemaining <= 0) ? 'Fulfilled' : 'Partially Fulfilled';

    final List<dynamic> offers = List<dynamic>.from(req['offers'] ?? []);
    for (int i = 0; i < offers.length; i++) {
      if (offers[i] is Map &&
          (offers[i]['id'] == offerId || offers[i]['donorId'] == donorId)) {
        final Map<String, dynamic> o = Map<String, dynamic>.from(offers[i]);
        o['status'] = 'accepted';
        o['acceptedAt'] = DateTime.now().toUtc().toIso8601String();
        offers[i] = o;
        break;
      }
    }

    final List<dynamic> acceptedDonors =
        List<dynamic>.from(req['accepted_donor_ids'] ?? []);
    if (!acceptedDonors.contains(donorId)) {
      acceptedDonors.add(donorId);
    }

    final List<dynamic> timeline = List<dynamic>.from(req['timeline'] ?? []);
    timeline.add({
      'action': 'offer_accepted',
      'donorId': donorId,
      'units': offeredUnits,
      'time': DateTime.now().toUtc().toIso8601String(),
    });

    await supabase.from('blood_requests').update({
      'accepted_units': newAccepted,
      'remaining_units': newRemaining,
      'status': newStatus,
      'offers': offers,
      'accepted_donor_ids': acceptedDonors,
      'timeline': timeline,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);

    // Notify donor
    await NotificationService().createNotification(
      userId: donorId,
      title: 'Offer Accepted! 🎉',
      body:
          'Your blood donation offer of $offeredUnits unit(s) has been accepted by the patient family.',
      screen: '/request_details',
      resourceId: requestId,
    );
  }

  // --- Cancel Request ---
  Future<void> cancelRequest(String requestId) async {
    await cancelBloodRequest(requestId);
  }

  Future<void> cancelBloodRequest(String requestId, {String? reason}) async {
    await supabase.from('blood_requests').update({
      'status': 'Cancelled',
      if (reason != null) 'cancellation_reason': reason,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  // --- Withdraw Offer ---
  Future<void> withdrawOffer(String requestId, String offerId) async {
    final req = await supabase
        .from('blood_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (req == null) return;

    final List<dynamic> offers = List<dynamic>.from(req['offers'] ?? []);
    final updated = offers.where((o) {
      if (o is Map) {
        return o['id']?.toString() != offerId;
      }
      return true;
    }).toList();

    await supabase.from('blood_requests').update({
      'offers': updated,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  // --- Reject Offer ---
  Future<void> rejectOffer(String requestId, String offerId) async {
    final req = await supabase
        .from('blood_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (req == null) return;

    final List<dynamic> offers = List<dynamic>.from(req['offers'] ?? []);
    for (int i = 0; i < offers.length; i++) {
      if (offers[i] is Map && offers[i]['id']?.toString() == offerId) {
        final Map<String, dynamic> o = Map<String, dynamic>.from(offers[i]);
        o['status'] = 'declined';
        o['declinedAt'] = DateTime.now().toUtc().toIso8601String();
        offers[i] = o;
        break;
      }
    }

    await supabase.from('blood_requests').update({
      'offers': offers,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  // --- Delete Blood Request ---
  Future<void> deleteBloodRequest(String requestId) async {
    await supabase.from('blood_requests').delete().eq('id', requestId);
  }

  // --- Report Content ---
  Future<void> reportContent({
    required String reportedType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final currentUserId = SupabaseAuthService().currentUserId;
    await supabase.from('reports').insert({
      'reporter_user_id': currentUserId ?? 'anonymous',
      'reported_type': reportedType,
      'target_id': targetId,
      'reason': reason,
      'details': details ?? '',
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    debugPrint("Report submitted to Supabase for $reportedType ($targetId)");
  }
}
