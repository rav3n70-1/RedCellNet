// lib/features/blood_requests/data/services/request_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';
import 'package:red_cell_net_final/core/models/supabase_snapshot.dart';
import 'package:red_cell_net_final/core/services/supabase_auth_service.dart';

class RequestService {
  Map<String, dynamic> _normalizeRequest(Map<String, dynamic> raw) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    m['id'] = m['id']?.toString() ?? '';

    m['requesterUserId'] ??= m['requester_user_id']?.toString();
    m['requester_user_id'] ??= m['requesterUserId'];

    final patient = m['patient_identifier'] ??
        m['patientIdentifier'] ??
        m['patient_name'] ??
        m['patientName'] ??
        '';
    m['patientName'] = patient;
    m['patient_name'] = patient;
    m['patientIdentifier'] = patient;
    m['patient_identifier'] = patient;

    final hospital = m['hospital_name'] ?? m['hospitalName'] ?? '';
    m['hospitalName'] = hospital;
    m['hospital_name'] = hospital;

    final address = m['hospital_address'] ?? m['hospitalAddress'] ?? '';
    m['hospitalAddress'] = address;
    m['hospital_address'] = address;

    m['city'] ??= '';

    final contactPerson = m['contact_person'] ?? m['contactPerson'] ?? '';
    m['contactPerson'] = contactPerson;
    m['contact_person'] = contactPerson;

    final phone =
        m['contact_phone'] ?? m['contactPhone'] ?? m['contactNumber'] ?? '';
    m['contactPhone'] = phone;
    m['contact_phone'] = phone;
    m['contactNumber'] = phone;

    m['requiredBloodType'] ??= m['required_blood_type'] ?? '';
    m['required_blood_type'] ??= m['requiredBloodType'];

    final int reqUnits = _asInt(m['requiredUnits'] ?? m['required_units'], 1);
    final int accUnits = _asInt(m['acceptedUnits'] ?? m['accepted_units'], 0);
    final int remUnits = _asInt(
      m['remainingUnits'] ?? m['remaining_units'],
      (reqUnits - accUnits).clamp(0, 999),
    );
    m['requiredUnits'] = reqUnits;
    m['required_units'] = reqUnits;
    m['unitsNeeded'] = reqUnits;
    m['acceptedUnits'] = accUnits;
    m['accepted_units'] = accUnits;
    m['remainingUnits'] = remUnits;
    m['remaining_units'] = remUnits;

    m['urgencyLevel'] ??= m['urgency_level'] ?? 'Medium';
    m['urgency_level'] ??= m['urgencyLevel'];

    m['reason'] ??= '';
    final bool emergency = m['is_emergency'] == true ||
        m['isEmergency'] == true ||
        m['urgencyLevel'] == 'Critical';
    m['isEmergency'] = emergency;
    m['is_emergency'] = emergency;

    m['status'] ??= 'Open';
    m['expiryHours'] = _asInt(m['expiryHours'] ?? m['expiry_hours'], 48);
    m['expiry_hours'] = m['expiryHours'];

    m['componentType'] ??= m['component_type'] ?? 'Whole Blood';
    m['component_type'] ??= m['componentType'];

    m['acceptedDonorIds'] ??= m['accepted_donor_ids'] ?? [];
    m['accepted_donor_ids'] ??= m['acceptedDonorIds'];

    final coords =
        m['location_coords'] ?? m['locationCoords'] ?? m['hospitalCoords'];
    m['location_coords'] = coords;
    m['locationCoords'] = coords;
    m['hospitalCoords'] = coords;

    m['cancellationReason'] ??= m['cancellation_reason'];
    m['cancellation_reason'] ??= m['cancellationReason'];

    m['notifiedDonorCount'] =
        _asInt(m['notifiedDonorCount'] ?? m['notified_donor_count'], 0);
    m['notified_donor_count'] = m['notifiedDonorCount'];

    final rawFulfilledAt = m['fulfilled_at'] ?? m['fulfilledAt'];
    if (rawFulfilledAt != null) {
      m['fulfilledAt'] = AppTimestamp.tryFromValue(rawFulfilledAt);
    }

    final List<dynamic> rawTimeline =
        (m['timeline'] is List) ? List<dynamic>.from(m['timeline'] as List) : [];
    m['timeline'] = rawTimeline.map((item) {
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{};
    }).toList();

    final List<dynamic> rawOffers =
        (m['offers'] is List) ? List<dynamic>.from(m['offers'] as List) : [];
    m['offers'] = rawOffers.map((item) {
      if (item is! Map) return <String, dynamic>{};
      final o = Map<String, dynamic>.from(item);
      o['id'] = o['id']?.toString() ?? o['donorId']?.toString() ?? '';
      o['donorId'] = o['donorId']?.toString() ?? '';
      o['donorName'] = o['donorName']?.toString() ?? 'Volunteer Donor';
      o['donorBloodType'] = o['donorBloodType']?.toString() ?? '';
      o['donorPhone'] = o['donorPhone']?.toString() ?? '';
      o['donorIsVerified'] = o['donorIsVerified'] == true;
      o['offeredUnits'] = _asInt(o['offeredUnits'], 1);
      o['note'] = o['note']?.toString() ?? '';
      o['status'] = o['status']?.toString() ?? 'pending';
      o['donationVerified'] = o['donationVerified'] == true;
      o['certificateId'] = o['certificateId']?.toString();
      o['locationTrackingStatus'] =
          o['locationTrackingStatus']?.toString() ?? 'none';
      o['locationTrackingRequestedAt'] =
          o['locationTrackingRequestedAt']?.toString();
      o['locationTrackingConsentedAt'] =
          o['locationTrackingConsentedAt']?.toString();
      o['donorLatitude'] = (o['donorLatitude'] is num)
          ? (o['donorLatitude'] as num).toDouble()
          : double.tryParse(o['donorLatitude']?.toString() ?? '');
      o['donorLongitude'] = (o['donorLongitude'] is num)
          ? (o['donorLongitude'] as num).toDouble()
          : double.tryParse(o['donorLongitude']?.toString() ?? '');
      o['donorLocationUpdatedAt'] = o['donorLocationUpdatedAt']?.toString();
      o['donorEtaMinutes'] = (o['donorEtaMinutes'] is num)
          ? (o['donorEtaMinutes'] as num).toInt()
          : int.tryParse(o['donorEtaMinutes']?.toString() ?? '');
      o['donorDistanceKm'] = (o['donorDistanceKm'] is num)
          ? (o['donorDistanceKm'] as num).toDouble()
          : double.tryParse(o['donorDistanceKm']?.toString() ?? '');
      return o;
    }).toList();

    final rawCreatedAt = m['created_at'] ?? m['createdAt'];
    final ts = AppTimestamp.fromValue(rawCreatedAt);
    m['createdAt'] = ts;
    m['created_at'] = rawCreatedAt ?? ts.toString();

    final rawExpiry = m['expiry_at'] ?? m['expiryAt'];
    if (rawExpiry != null) {
      final expiryTs = AppTimestamp.tryFromValue(rawExpiry);
      if (expiryTs != null) {
        m['expiryAt'] = expiryTs;
        final expiryDate = expiryTs.toDate();
        final currentStatus = m['status']?.toString() ?? 'Open';
        if (DateTime.now().toUtc().isAfter(expiryDate.toUtc()) &&
            currentStatus != 'Fulfilled' &&
            currentStatus != 'Cancelled') {
          m['status'] = 'Expired';
        }
      }
    }

    m['isVerifiedHospitalCase'] = m['is_verified_hospital_case'] == true ||
        m['isVerifiedHospitalCase'] == true;
    m['is_verified_hospital_case'] = m['isVerifiedHospitalCase'];

    return m;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> _denormalizeForSupabase(Map<String, dynamic> data) {
    final Map<String, dynamic> out = {};

    if (data.containsKey('isVerifiedHospitalCase') ||
        data.containsKey('is_verified_hospital_case')) {
      out['is_verified_hospital_case'] =
          data['isVerifiedHospitalCase'] ?? data['is_verified_hospital_case'];
    }

    if (data.containsKey('requesterUserId') ||
        data.containsKey('requester_user_id')) {
      out['requester_user_id'] =
          data['requesterUserId'] ?? data['requester_user_id'];
    }
    if (data.containsKey('patientName') ||
        data.containsKey('patientIdentifier') ||
        data.containsKey('patient_name') ||
        data.containsKey('patient_identifier')) {
      final pVal = data['patientIdentifier'] ??
          data['patient_identifier'] ??
          data['patientName'] ??
          data['patient_name'] ??
          '';
      out['patient_name'] = pVal;
      out['patient_identifier'] = pVal;
    }
    if (data.containsKey('hospitalName') || data.containsKey('hospital_name')) {
      out['hospital_name'] = data['hospitalName'] ?? data['hospital_name'] ?? '';
    }
    if (data.containsKey('hospitalAddress') ||
        data.containsKey('hospital_address')) {
      out['hospital_address'] =
          data['hospitalAddress'] ?? data['hospital_address'] ?? '';
    }
    if (data.containsKey('city')) {
      out['city'] = data['city'] ?? '';
    }
    if (data.containsKey('contactPerson') ||
        data.containsKey('contact_person')) {
      out['contact_person'] =
          data['contactPerson'] ?? data['contact_person'] ?? '';
    }
    if (data.containsKey('contactPhone') ||
        data.containsKey('contactNumber') ||
        data.containsKey('contact_phone')) {
      out['contact_phone'] = data['contactPhone'] ??
          data['contactNumber'] ??
          data['contact_phone'] ??
          '';
    }
    if (data.containsKey('requiredBloodType') ||
        data.containsKey('required_blood_type')) {
      out['required_blood_type'] =
          data['requiredBloodType'] ?? data['required_blood_type'];
    }
    if (data.containsKey('requiredUnits') ||
        data.containsKey('unitsNeeded') ||
        data.containsKey('required_units')) {
      out['required_units'] = _asInt(
        data['requiredUnits'] ?? data['unitsNeeded'] ?? data['required_units'],
        1,
      );
    }
    if (data.containsKey('acceptedUnits') ||
        data.containsKey('accepted_units')) {
      out['accepted_units'] =
          _asInt(data['acceptedUnits'] ?? data['accepted_units'], 0);
    }
    if (data.containsKey('remainingUnits') ||
        data.containsKey('remaining_units')) {
      out['remaining_units'] =
          _asInt(data['remainingUnits'] ?? data['remaining_units'], 1);
    }
    if (data.containsKey('urgencyLevel') || data.containsKey('urgency_level')) {
      out['urgency_level'] =
          data['urgencyLevel'] ?? data['urgency_level'] ?? 'Medium';
    }
    if (data.containsKey('reason')) {
      out['reason'] = data['reason'] ?? '';
    }
    if (data.containsKey('isEmergency') || data.containsKey('is_emergency')) {
      out['is_emergency'] =
          data['isEmergency'] ?? data['is_emergency'] ?? false;
    }
    if (data.containsKey('status')) {
      out['status'] = data['status'] ?? 'Open';
    }
    if (data.containsKey('expiryHours') || data.containsKey('expiry_hours')) {
      out['expiry_hours'] =
          _asInt(data['expiryHours'] ?? data['expiry_hours'], 48);
    }
    if (data.containsKey('expiry_at')) {
      out['expiry_at'] = data['expiry_at'];
    }
    if (data.containsKey('componentType') ||
        data.containsKey('component_type')) {
      out['component_type'] =
          data['componentType'] ?? data['component_type'] ?? 'Whole Blood';
    }
    if (data.containsKey('acceptedDonorIds') ||
        data.containsKey('accepted_donor_ids')) {
      out['accepted_donor_ids'] =
          data['acceptedDonorIds'] ?? data['accepted_donor_ids'] ?? [];
    }
    if (data.containsKey('timeline')) {
      out['timeline'] = data['timeline'] ?? [];
    }
    if (data.containsKey('offers')) {
      out['offers'] = data['offers'] ?? [];
    }
    if (data.containsKey('locationCoords') ||
        data.containsKey('hospitalCoords') ||
        data.containsKey('location_coords')) {
      out['location_coords'] = data['locationCoords'] ??
          data['hospitalCoords'] ??
          data['location_coords'];
    }
    if (data.containsKey('cancellationReason') ||
        data.containsKey('cancellation_reason')) {
      out['cancellation_reason'] =
          data['cancellationReason'] ?? data['cancellation_reason'];
    }

    out['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return out;
  }

  /// Marks any past-expiry active requests in the database as `'Expired'`.
  Future<int> checkAndExpireRequests() async {
    if (!SupabaseConfig.isInitialized ||
        SupabaseAuthService().currentUserId == null) {
      return 0;
    }
    try {
      final res = await supabase.rpc('check_and_expire_requests');
      if (res is int) return res;
      if (res is num) return res.toInt();
      return 0;
    } catch (e) {
      debugPrint('checkAndExpireRequests notice: $e');
      return 0;
    }
  }

  /// Dispatches smart proximity + compatible-blood notifications via RPC.
  Future<Map<String, dynamic>> dispatchEmergencyNotifications(
    String requestId, {
    double radiusKm = 15.0,
  }) async {
    try {
      final res = await supabase.rpc(
        'dispatch_emergency_request_notifications',
        params: {
          'p_request_id': requestId,
          'p_radius_km': radiusKm,
        },
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': true, 'notified_count': 0};
    } catch (e) {
      debugPrint('dispatchEmergencyNotifications notice: $e');
      return {'success': false, 'notified_count': 0};
    }
  }

  // --- Create Request ---
  Future<String> createBloodRequest(Map<String, dynamic> requestData) async {
    final String? currentUserId = SupabaseAuthService().currentUserId;
    if (currentUserId == null) {
      throw Exception('User must be logged in to create a request.');
    }

    final int totalUnits = _asInt(
      requestData['requiredUnits'] ?? requestData['unitsNeeded'],
      1,
    );
    final int expiryHours = _asInt(requestData['expiryHours'], 48);
    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime expiryDate = nowUtc.add(Duration(hours: expiryHours));

    final payload = _denormalizeForSupabase(requestData);
    payload['requester_user_id'] = currentUserId;
    payload['required_units'] = totalUnits;
    payload['accepted_units'] = 0;
    payload['remaining_units'] = totalUnits;
    payload['status'] = 'Open';
    payload['expiry_hours'] = expiryHours;
    payload['expiry_at'] = expiryDate.toIso8601String();
    payload['created_at'] = nowUtc.toIso8601String();
    payload['is_emergency'] = requestData['isEmergency'] == true ||
        payload['urgency_level'] == 'Critical' ||
        payload['urgency_level'] == 'High';
    payload['accepted_donor_ids'] = [];
    payload['offers'] = [];
    payload['timeline'] = [
      {
        'action': 'created',
        'by': currentUserId,
        'time': nowUtc.toIso8601String(),
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
      throw Exception('Failed to create blood request: $e');
    }
  }

  /// Allows the requester (or staff) to edit an active blood request safely.
  Future<void> updateBloodRequest(
    String requestId,
    Map<String, dynamic> updates,
  ) async {
    final String? currentUserId = SupabaseAuthService().currentUserId;
    if (currentUserId == null) {
      throw Exception('Authentication required.');
    }

    final existing = await supabase
        .from('blood_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (existing == null) {
      throw Exception('Blood request not found.');
    }

    final int acceptedUnits = _asInt(existing['accepted_units'], 0);
    final int newRequiredUnits = _asInt(
      updates['requiredUnits'] ??
          updates['unitsNeeded'] ??
          existing['required_units'],
      1,
    );
    if (newRequiredUnits < acceptedUnits) {
      throw Exception(
        'Required units ($newRequiredUnits) cannot be less than already accepted units ($acceptedUnits).',
      );
    }

    final int newRemaining = newRequiredUnits - acceptedUnits;
    final String currentStatus = existing['status']?.toString() ?? 'Open';
    String nextStatus = currentStatus;
    if (currentStatus == 'Open' ||
        currentStatus == 'Partially Fulfilled' ||
        currentStatus == 'Fulfilled') {
      if (newRemaining == 0 && acceptedUnits > 0) {
        nextStatus = 'Fulfilled';
      } else if (acceptedUnits > 0) {
        nextStatus = 'Partially Fulfilled';
      } else {
        nextStatus = 'Open';
      }
    }

    final payload = _denormalizeForSupabase(updates);
    payload['required_units'] = newRequiredUnits;
    payload['remaining_units'] = newRemaining;
    payload['status'] = nextStatus;

    if (updates.containsKey('expiryHours')) {
      final int expiryHours = _asInt(updates['expiryHours'], 48);
      final createdTs = AppTimestamp.fromValue(existing['created_at']).toDate();
      final candidateExpiry =
          createdTs.toUtc().add(Duration(hours: expiryHours));
      final minExpiry =
          DateTime.now().toUtc().add(Duration(hours: expiryHours));
      payload['expiry_hours'] = expiryHours;
      payload['expiry_at'] = (candidateExpiry.isAfter(DateTime.now().toUtc())
              ? candidateExpiry
              : minExpiry)
          .toIso8601String();
    }

    final List<dynamic> timeline = existing['timeline'] is List
        ? List<dynamic>.from(existing['timeline'] as List)
        : [];
    timeline.add({
      'action': 'request_edited',
      'by': currentUserId,
      'time': DateTime.now().toUtc().toIso8601String(),
    });
    payload['timeline'] = timeline;

    await supabase.from('blood_requests').update(payload).eq('id', requestId);
  }

  // Helper to normalize FIRST (so expired requests become 'Expired') and then filter
  AppQuerySnapshot _filterAndWrapRequests(
    List<dynamic> rows, {
    String? bloodTypeFilter,
    String? ownerUserId,
    String? urgencyLevelFilter,
    String? statusFilter,
  }) {
    List<Map<String, dynamic>> normalized = rows
        .map((r) => _normalizeRequest(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (ownerUserId != null && ownerUserId.isNotEmpty) {
      normalized = normalized
          .where((r) => r['requesterUserId']?.toString() == ownerUserId)
          .toList();
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter != 'All') {
        normalized =
            normalized.where((r) => r['status'] == statusFilter).toList();
      }
    } else if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'All') {
      normalized =
          normalized.where((r) => r['status'] == statusFilter).toList();
    } else {
      normalized = normalized
          .where((r) =>
              r['status'] == 'Open' || r['status'] == 'Partially Fulfilled')
          .toList();
    }

    if (bloodTypeFilter != null &&
        bloodTypeFilter.isNotEmpty &&
        bloodTypeFilter != 'All') {
      normalized = normalized
          .where((r) => r['requiredBloodType'] == bloodTypeFilter)
          .toList();
    }

    if (urgencyLevelFilter != null &&
        urgencyLevelFilter.isNotEmpty &&
        urgencyLevelFilter != 'All') {
      normalized = normalized
          .where((r) => r['urgencyLevel'] == urgencyLevelFilter)
          .toList();
    }

    final docs = normalized
        .map((r) => AppDocSnapshot(r['id']?.toString() ?? '', r))
        .toList();

    return AppQuerySnapshot(docs);
  }

  // --- Get Blood Requests Stream (Resilient with REST Pre-fetch + Realtime) ---
  Stream<AppQuerySnapshot> getBloodRequestsStream({
    String? bloodTypeFilter,
    String? ownerUserId,
    String? urgencyLevelFilter,
    String? statusFilter,
  }) {
    return _getBloodRequestsStreamImpl(
      bloodTypeFilter: bloodTypeFilter,
      ownerUserId: ownerUserId,
      urgencyLevelFilter: urgencyLevelFilter,
      statusFilter: statusFilter,
    ).asBroadcastStream();
  }

  Stream<AppQuerySnapshot> _getBloodRequestsStreamImpl({
    String? bloodTypeFilter,
    String? ownerUserId,
    String? urgencyLevelFilter,
    String? statusFilter,
  }) async* {
    if (!SupabaseConfig.isInitialized) {
      yield AppQuerySnapshot([]);
      return;
    }

    // 1. Initial REST fetch for instant rendering
    try {
      final initialRows = await supabase
          .from('blood_requests')
          .select()
          .order('created_at', ascending: false);
      yield _filterAndWrapRequests(
        initialRows,
        bloodTypeFilter: bloodTypeFilter,
        ownerUserId: ownerUserId,
        urgencyLevelFilter: urgencyLevelFilter,
        statusFilter: statusFilter,
      );
    } catch (e) {
      debugPrint('Initial blood requests REST fetch error: $e');
      yield AppQuerySnapshot([]);
    }

    // 2. Realtime subscription with safe error handling
    try {
      final stream = supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .handleError((e) {
            debugPrint('Handled blood requests realtime error: $e');
          });

      await for (final rows in stream) {
        yield _filterAndWrapRequests(
          rows,
          bloodTypeFilter: bloodTypeFilter,
          ownerUserId: ownerUserId,
          urgencyLevelFilter: urgencyLevelFilter,
          statusFilter: statusFilter,
        );
      }
    } catch (e) {
      debugPrint('Blood requests realtime stream fallback: $e');
    }
  }

  // --- Get Urgent Requests Stream ---
  Stream<AppQuerySnapshot> getUrgentRequestsStream({int limit = 6}) {
    return _getUrgentRequestsStreamImpl(limit: limit).asBroadcastStream();
  }

  Stream<AppQuerySnapshot> _getUrgentRequestsStreamImpl({int limit = 6}) async* {
    if (!SupabaseConfig.isInitialized) {
      yield AppQuerySnapshot([]);
      return;
    }

    AppQuerySnapshot filterUrgent(List<dynamic> rows) {
      final list = rows
          .map((r) => _normalizeRequest(Map<String, dynamic>.from(r as Map)))
          .where((r) {
            final status = r['status'] ?? 'Open';
            final urgency = r['urgencyLevel'] ?? '';
            final isOpen = status == 'Open' || status == 'Partially Fulfilled';
            final isUrgent = urgency == 'Critical' || urgency == 'High';
            return isOpen && isUrgent;
          })
          .take(limit)
          .map((r) => AppDocSnapshot(r['id']?.toString() ?? '', r))
          .toList();
      return AppQuerySnapshot(list);
    }

    // 1. Initial REST fetch
    try {
      final initialRows = await supabase
          .from('blood_requests')
          .select()
          .order('created_at', ascending: false);
      yield filterUrgent(initialRows);
    } catch (e) {
      debugPrint('Initial urgent requests REST fetch error: $e');
      yield AppQuerySnapshot([]);
    }

    // 2. Realtime Stream
    try {
      final stream = supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .handleError((e) {
            debugPrint('Handled urgent requests realtime error: $e');
          });

      await for (final rows in stream) {
        yield filterUrgent(rows);
      }
    } catch (e) {
      debugPrint('Urgent requests realtime stream fallback: $e');
    }
  }

  // --- Get Request Stream by ID ---
  Stream<AppDocSnapshot> getRequestStream(String requestId) {
    return _getRequestStreamImpl(requestId).asBroadcastStream();
  }

  Stream<AppDocSnapshot> _getRequestStreamImpl(String requestId) async* {
    if (requestId.isEmpty || !SupabaseConfig.isInitialized) {
      yield AppDocSnapshot('', null);
      return;
    }

    // 1. Initial REST fetch
    try {
      final row = await supabase
          .from('blood_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();
      if (row != null) {
        yield AppDocSnapshot(requestId, _normalizeRequest(row));
      }
    } catch (e) {
      debugPrint('Initial getRequestStream REST fetch notice: $e');
    }

    // 2. Realtime Stream
    try {
      final stream = supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .eq('id', requestId)
          .handleError((e) {
            debugPrint('Handled getRequestStream realtime error: $e');
          });

      await for (final rows in stream) {
        if (rows.isEmpty) {
          yield AppDocSnapshot(requestId, null);
        } else {
          yield AppDocSnapshot(requestId, _normalizeRequest(rows.first));
        }
      }
    } catch (e) {
      debugPrint('Realtime getRequestStream fallback: $e');
    }
  }

  // --- Get Request Details (Async Direct) ---
  Future<AppDocSnapshot> getRequestDetails(String requestId) async {
    if (requestId.isEmpty) {
      throw ArgumentError('Request ID cannot be empty.');
    }
    final res = await supabase
        .from('blood_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (res == null) {
      throw Exception('Request document does not exist for ID: $requestId');
    }
    return AppDocSnapshot(requestId, _normalizeRequest(res));
  }

  // --- Get Offers Stream for a Request ---
  Stream<AppQuerySnapshot> getOffersStream(String requestId) {
    return _getOffersStreamImpl(requestId).asBroadcastStream();
  }

  Stream<AppQuerySnapshot> _getOffersStreamImpl(String requestId) async* {
    if (requestId.isEmpty || !SupabaseConfig.isInitialized) {
      yield AppQuerySnapshot([]);
      return;
    }

    AppQuerySnapshot extractOffers(List<dynamic> rows) {
      if (rows.isEmpty) return AppQuerySnapshot([]);
      final normalized =
          _normalizeRequest(Map<String, dynamic>.from(rows.first as Map));
      final List<dynamic> rawOffers = normalized['offers'] ?? [];
      final docs = rawOffers.map((o) {
        final Map<String, dynamic> oMap = Map<String, dynamic>.from(o as Map);
        final String oid =
            oMap['id']?.toString() ?? oMap['donorId']?.toString() ?? '';
        oMap['offerTimestamp'] = AppTimestamp.fromValue(oMap['offerTimestamp']);
        return AppDocSnapshot(oid, oMap);
      }).toList();
      return AppQuerySnapshot(docs);
    }

    try {
      final row = await supabase
          .from('blood_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();
      if (row != null) {
        yield extractOffers([row]);
      } else {
        yield AppQuerySnapshot([]);
      }
    } catch (e) {
      debugPrint('Initial getOffersStream REST fetch notice: $e');
      yield AppQuerySnapshot([]);
    }

    try {
      final stream = supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .eq('id', requestId)
          .handleError((e) {
            debugPrint('Handled getOffersStream realtime error: $e');
          });

      await for (final rows in stream) {
        yield extractOffers(rows);
      }
    } catch (e) {
      debugPrint('Realtime getOffersStream fallback: $e');
    }
  }

  // --- Get User Offers Stream ---
  Stream<AppQuerySnapshot> getUserOffersStream(String donorId) {
    return _getUserOffersStreamImpl(donorId).asBroadcastStream();
  }

  Stream<AppQuerySnapshot> _getUserOffersStreamImpl(String donorId) async* {
    if (donorId.isEmpty || !SupabaseConfig.isInitialized) {
      yield AppQuerySnapshot([]);
      return;
    }

    AppQuerySnapshot filterUserOffers(List<dynamic> rows) {
      final List<AppDocSnapshot> userOffers = [];
      for (final r in rows) {
        final Map<String, dynamic> req =
            _normalizeRequest(Map<String, dynamic>.from(r as Map));
        final List<dynamic> rawOffers = req['offers'] ?? [];
        for (final o in rawOffers) {
          if (o is Map && o['donorId']?.toString() == donorId) {
            final Map<String, dynamic> oMap = Map<String, dynamic>.from(o);
            final String oid = oMap['id']?.toString() ?? '';
            oMap['offerTimestamp'] =
                AppTimestamp.fromValue(oMap['offerTimestamp']);
            oMap['requestId'] = req['id'];
            oMap['hospitalName'] = req['hospitalName'] ?? '';
            oMap['requiredBloodType'] = req['requiredBloodType'] ?? '';
            oMap['requestStatus'] = req['status'] ?? 'Open';
            userOffers.add(AppDocSnapshot(oid, oMap));
          }
        }
      }
      return AppQuerySnapshot(userOffers);
    }

    try {
      final initialRows = await supabase
          .from('blood_requests')
          .select()
          .order('created_at', ascending: false);
      yield filterUserOffers(initialRows);
    } catch (e) {
      debugPrint('Initial getUserOffersStream REST fetch error: $e');
      yield AppQuerySnapshot([]);
    }

    try {
      final stream = supabase
          .from('blood_requests')
          .stream(primaryKey: ['id'])
          .handleError((e) {
            debugPrint('Handled getUserOffersStream realtime error: $e');
          });

      await for (final rows in stream) {
        yield filterUserOffers(rows);
      }
    } catch (e) {
      debugPrint('Realtime getUserOffersStream fallback: $e');
    }
  }

  // --- Atomic Multi-Donor Fulfillment RPCs ---

  Future<void> submitOffer({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorBloodType,
    int offeredUnits = 1,
    bool donorIsVerified = false,
    String note = '',
  }) async {
    await supabase.rpc(
      'submit_blood_offer',
      params: {
        'p_request_id': requestId,
        'p_offered_units': offeredUnits,
        'p_note': note,
      },
    );
  }

  Future<void> acceptOffer(
    String requestId,
    String offerId,
    String donorId, {
    int offeredUnits = 1,
  }) async {
    await supabase.rpc(
      'accept_blood_offer',
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
      },
    );
  }

  Future<void> rejectOffer(String requestId, String offerId) async {
    await supabase.rpc(
      'reject_blood_offer',
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
      },
    );
  }

  Future<void> withdrawOffer(String requestId, String offerId) async {
    await supabase.rpc(
      'withdraw_blood_offer',
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
      },
    );
  }

  Future<void> cancelRequest(String requestId) async {
    await cancelBloodRequest(requestId);
  }

  Future<void> cancelBloodRequest(String requestId, {String? reason}) async {
    await supabase.rpc(
      'cancel_blood_request',
      params: {
        'p_request_id': requestId,
        'p_reason': reason ?? 'Cancelled by requester',
      },
    );
  }

  /// Verifies hospital donation completion, awards certificate + points, and sets 90-day cooldown.
  Future<Map<String, dynamic>> completeDonation(
    String requestId,
    String offerId,
  ) async {
    final res = await supabase.rpc(
      'complete_blood_donation',
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
      },
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': true};
  }

  /// Releases an accepted donor slot (e.g. donor could not attend) so remaining units reopen safely.
  Future<Map<String, dynamic>> releaseAcceptedOffer(
    String requestId,
    String offerId, {
    String? reason,
  }) async {
    final res = await supabase.rpc(
      'release_accepted_offer',
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
        'p_reason': reason ?? 'Donor could not attend',
      },
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': true};
  }

  /// Mutual-consent live donor location tracking after an offer is accepted.
  /// Supported actions: 'request_tracking', 'accept_tracking', 'update_location', 'decline_tracking', 'stop_tracking'.
  Future<Map<String, dynamic>> manageOfferLocationTracking({
    required String requestId,
    required String offerId,
    required String action,
    double? latitude,
    double? longitude,
    int? etaMinutes,
    double? distanceKm,
  }) async {
    final res = await supabase.rpc(
      'manage_offer_location_tracking',
      params: {
        'p_request_id': requestId,
        'p_offer_id': offerId,
        'p_action': action,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_eta_minutes': etaMinutes,
        'p_distance_km': distanceKm,
      },
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': true, 'action': action};
  }

  Future<void> deleteBloodRequest(String requestId) async {
    await supabase.from('blood_requests').delete().eq('id', requestId);
  }

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
  }
}
