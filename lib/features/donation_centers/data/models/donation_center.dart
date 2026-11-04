// lib/features/donation_centers/data/models/donation_center.dart
import 'package:latlong2/latlong.dart';

class DonationCenter {
  final String id;
  final String name;
  final String address;
  final LatLng coordinates;
  final bool isVerified;
  final String? contactInfo;
  final String? operatingHours;
  final Map<String, dynamic>? bloodInventory;

  DonationCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.coordinates,
    required this.isVerified,
    this.contactInfo,
    this.operatingHours,
    this.bloodInventory,
  });

  factory DonationCenter.fromMap(Map<String, dynamic> data, {String? id}) {
    final String docId = id ?? data['id']?.toString() ?? '';
    final name = data['name'] as String? ?? 'Unknown Center';
    final address = data['address'] as String? ?? 'No Address';
    final isVerified = (data['is_verified'] ?? data['isVerified']) as bool? ?? false;
    final contact = (data['contact_info'] ?? data['contactInfo']) as String?;
    final hours = (data['operating_hours'] ?? data['operatingHours']) as String?;

    LatLng calculatedCoords = const LatLng(0, 0);

    // Direct latitude and longitude fields
    if (data['latitude'] != null && data['longitude'] != null) {
      final lat = data['latitude'];
      final lng = data['longitude'];
      if (lat is num && lng is num) {
        calculatedCoords = LatLng(lat.toDouble(), lng.toDouble());
      }
    } else if (data['coordinates'] != null && data['coordinates'] is Map) {
      final cMap = data['coordinates'] as Map;
      final lat = cMap['latitude'] ?? cMap['lat'];
      final lng = cMap['longitude'] ?? cMap['lng'];
      if (lat is num && lng is num) {
        calculatedCoords = LatLng(lat.toDouble(), lng.toDouble());
      }
    }

    final inventory = (data['blood_inventory'] ?? data['bloodInventory']) as Map<String, dynamic>?;

    return DonationCenter(
      id: docId,
      name: name,
      address: address,
      coordinates: calculatedCoords,
      isVerified: isVerified,
      contactInfo: contact,
      operatingHours: hours,
      bloodInventory: inventory,
    );
  }
}
