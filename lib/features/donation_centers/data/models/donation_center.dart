// lib/features/donation_centers/data/models/donation_center.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// Import LatLng from Google Maps package
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DonationCenter {
  final String id;
  final String name;
  final String address;
  // Change storage type to LatLng (from Google Maps package)
  final LatLng coordinates;
  final bool isVerified;
  final String? contactInfo;
  final String? operatingHours;

  DonationCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.coordinates, // Now expects LatLng
    required this.isVerified,
    this.contactInfo,
    this.operatingHours,
  });

  // Factory constructor to create a DonationCenter from a Firestore document
  factory DonationCenter.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception("Donation center data was null for doc ID: ${doc.id}");
    }

    // --- Logging Added ---
    print("Doc ID: ${doc.id} -- All received keys: ${data.keys.toList()}");
    final dynamic coordinatesData =
        data['coordinates']; // Get the raw field data
    print(
        "Doc ID: ${doc.id} -- Raw Coords Type: ${coordinatesData?.runtimeType}, Value: $coordinatesData");
    // --- End Logging ---

    LatLng calculatedCoords; // Use Google Maps LatLng

    // --- MODIFIED Check ---
    // Trust the runtimeType if it looks like a GeoPoint, or use default
    // We check runtimeType string because `is GeoPoint` was failing
    if (coordinatesData != null &&
        coordinatesData.runtimeType.toString() == 'GeoPoint') {
      try {
        // Directly access latitude/longitude assuming it's a GeoPoint
        // Cast to dynamic first to avoid static analysis complaints if type is complex
        final lat = (coordinatesData as dynamic).latitude;
        final lng = (coordinatesData as dynamic).longitude;
        // Ensure they are doubles before creating LatLng
        if (lat is double && lng is double) {
          calculatedCoords = LatLng(lat, lng);
          print(
              "Successfully extracted coordinates for ${doc.id}: $calculatedCoords");
        } else {
          print("!!! Lat/Lng were not doubles for ${doc.id}. Using default.");
          calculatedCoords = const LatLng(0, 0); // Default on parsing failure
        }
      } catch (e) {
        print(
            "!!! Error accessing lat/lng from potential GeoPoint for ${doc.id}: $e. Using default.");
        calculatedCoords = const LatLng(0, 0); // Default on error
      }
    } else {
      print(
          "!!! Coordinates field was null or not runtimeType GeoPoint for ${doc.id}. Using default.");
      calculatedCoords =
          const LatLng(0, 0); // Default if null or unexpected type
    }
    // --- End MODIFIED Check ---

    // Get other fields normally
    final name = data['name'] as String? ?? 'Unknown Center';
    final address = data['address'] as String? ?? 'No Address';
    final isVerified = data['isVerified'] as bool? ?? false;

    return DonationCenter(
      id: doc.id,
      name: name,
      address: address,
      coordinates: calculatedCoords, // Assign the calculated LatLng
      isVerified: isVerified,
      contactInfo: data['contactInfo'] as String?,
      operatingHours: data['operatingHours'] as String?,
    );
  }
}
