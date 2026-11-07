// lib/features/donation_centers/data/models/donation_center.dart
import 'package:latlong2/latlong.dart';

class DonationCenter {
  final String id;
  final String name;
  final String address;
  final String? city;
  final LatLng coordinates;
  final bool isVerified;
  final String? contactInfo;
  final String? operatingHours;
  final String facilityType;
  final String operationalStatus;
  final Map<String, dynamic>? bloodInventory;
  final DateTime? updatedAt;

  DonationCenter({
    required this.id,
    required this.name,
    required this.address,
    this.city,
    LatLng? coordinates,
    double? latitude,
    double? longitude,
    required this.isVerified,
    this.contactInfo,
    this.operatingHours,
    this.facilityType = 'Blood Bank',
    this.operationalStatus = 'Open',
    this.bloodInventory,
    this.updatedAt,
  }) : coordinates = coordinates ?? LatLng(latitude ?? 0.0, longitude ?? 0.0);

  double get latitude => coordinates.latitude;
  double get longitude => coordinates.longitude;

  bool get hasValidCoordinates =>
      coordinates.latitude != 0.0 || coordinates.longitude != 0.0;

  factory DonationCenter.fromMap(Map<String, dynamic> data, {String? id}) {
    final String docId = id ?? data['id']?.toString() ?? '';
    final name = (data['name'] ?? 'Unknown Center').toString();
    final address = (data['address'] ?? 'No Address').toString();
    final city = data['city']?.toString();
    final isVerified =
        (data['is_verified'] ?? data['isVerified']) == true;
    final contact = (data['contact_info'] ??
            data['contact_number'] ??
            data['contactInfo'] ??
            data['contactNumber'])
        ?.toString();
    final hours =
        (data['operating_hours'] ?? data['operatingHours'])?.toString();
    final facilityType = (data['facility_type'] ??
            data['facilityType'] ??
            'Blood Bank')
        .toString();
    final operationalStatus = (data['operational_status'] ??
            data['operationalStatus'] ??
            'Open')
        .toString();

    LatLng calculatedCoords = const LatLng(0, 0);

    if (data['latitude'] != null && data['longitude'] != null) {
      final lat = double.tryParse(data['latitude'].toString());
      final lng = double.tryParse(data['longitude'].toString());
      if (lat != null && lng != null) {
        calculatedCoords = LatLng(lat, lng);
      }
    } else if (data['coordinates'] is Map) {
      final cMap = data['coordinates'] as Map;
      final lat = double.tryParse((cMap['latitude'] ?? cMap['lat'] ?? '').toString());
      final lng = double.tryParse((cMap['longitude'] ?? cMap['lng'] ?? '').toString());
      if (lat != null && lng != null) {
        calculatedCoords = LatLng(lat, lng);
      }
    }

    Map<String, dynamic>? inventory;
    final rawInv = data['blood_inventory'] ?? data['bloodInventory'];
    if (rawInv is Map) {
      inventory = Map<String, dynamic>.from(rawInv);
    }

    DateTime? parsedUpdatedAt;
    final rawUpdated = data['updated_at'] ?? data['updatedAt'] ?? data['created_at'];
    if (rawUpdated is DateTime) {
      parsedUpdatedAt = rawUpdated;
    } else if (rawUpdated != null) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated.toString());
    }

    return DonationCenter(
      id: docId,
      name: name,
      address: address,
      city: city,
      coordinates: calculatedCoords,
      isVerified: isVerified,
      contactInfo: contact,
      operatingHours: hours,
      facilityType: facilityType,
      operationalStatus: operationalStatus,
      bloodInventory: inventory,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'is_verified': isVerified,
      'contact_info': contactInfo,
      'contact_number': contactInfo,
      'operating_hours': operatingHours,
      'facility_type': facilityType,
      'operational_status': operationalStatus,
      if (bloodInventory != null) 'blood_inventory': bloodInventory,
    };
  }
}
