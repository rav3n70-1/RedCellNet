// lib/features/blood_requests/data/services/hospital_directory_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:red_cell_net_final/core/config/supabase_config.dart';

/// Represents a verified hospital, medical institute, or blood transfusion center.
class HospitalItem {
  final String id;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String facilityType;
  final String? phone;
  final String? operatingHours;
  final bool isVerified;

  const HospitalItem({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.facilityType = 'Hospital',
    this.phone,
    this.operatingHours,
    this.isVerified = true,
  });

  factory HospitalItem.fromSupabase(Map<String, dynamic> data) {
    double lat = 0.0;
    double lng = 0.0;

    if (data['latitude'] != null && data['longitude'] != null) {
      lat = (data['latitude'] as num).toDouble();
      lng = (data['longitude'] as num).toDouble();
    } else if (data['coordinates'] != null && data['coordinates'] is Map) {
      final cMap = data['coordinates'] as Map;
      lat = (cMap['latitude'] ?? cMap['lat'] ?? 0.0).toDouble();
      lng = (cMap['longitude'] ?? cMap['lng'] ?? 0.0).toDouble();
    }

    return HospitalItem(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Medical Center',
      address: data['address']?.toString() ?? 'Address not specified',
      city: data['city']?.toString() ?? 'Dhaka',
      latitude: lat,
      longitude: lng,
      facilityType: data['type']?.toString() ?? 'Donation Center',
      phone: data['contact_number']?.toString() ?? data['contact_info']?.toString(),
      operatingHours: data['operating_hours']?.toString(),
      isVerified: (data['is_verified'] ?? true) == true,
    );
  }

  @override
  String toString() => '$name, $address ($city)';
}

/// Service providing zero-cost hospital directory and nearest-facility proximity searching.
class HospitalDirectoryService {
  static final List<HospitalItem> _offlineCatalog = [
    // --- Dhaka Medical Hubs ---
    const HospitalItem(
      id: 'hosp-dmch',
      name: 'Dhaka Medical College Hospital (DMCH)',
      address: 'Secretariat Road, Ramna, Dhaka-1000',
      city: 'Dhaka',
      latitude: 23.7258,
      longitude: 90.3976,
      facilityType: 'Government Medical College',
      phone: '+8802-55165088',
      operatingHours: '24/7 Emergency & ICU',
    ),
    const HospitalItem(
      id: 'hosp-bsmmu',
      name: 'BSMMU (PG Hospital / Super Specialized)',
      address: 'Shahbag Circle, Kazi Nazrul Islam Ave, Dhaka-1000',
      city: 'Dhaka',
      latitude: 23.7389,
      longitude: 90.3957,
      facilityType: 'University Hospital',
      phone: '+8802-9661051',
      operatingHours: '24/7 Emergency & Transfusion',
    ),
    const HospitalItem(
      id: 'hosp-birdem',
      name: 'BIRDEM General Hospital & Blood Bank',
      address: '122 Kazi Nazrul Islam Ave, Shahbag, Dhaka-1000',
      city: 'Dhaka',
      latitude: 23.7402,
      longitude: 90.3963,
      facilityType: 'Specialized Hospital',
      phone: '+8802-8616641',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-nicvd',
      name: 'National Institute of Cardiovascular Diseases (NICVD)',
      address: 'Sher-e-Bangla Nagar, Agargaon, Dhaka-1207',
      city: 'Dhaka',
      latitude: 23.7712,
      longitude: 90.3705,
      facilityType: 'Specialized Hospital',
      phone: '+8802-9122560',
      operatingHours: '24/7 Cardiac Emergency',
    ),
    const HospitalItem(
      id: 'hosp-nitor',
      name: 'NITOR (Pangu Hospital / Traumatology Institute)',
      address: 'Sher-e-Bangla Nagar, Agargaon, Dhaka-1207',
      city: 'Dhaka',
      latitude: 23.7725,
      longitude: 90.3695,
      facilityType: 'Trauma & Orthopaedic Center',
      phone: '+8802-9114075',
      operatingHours: '24/7 Trauma Emergency',
    ),
    const HospitalItem(
      id: 'hosp-nins',
      name: 'National Institute of Neurosciences & Hospital (NINS)',
      address: 'Sher-e-Bangla Nagar, Agargaon, Dhaka-1207',
      city: 'Dhaka',
      latitude: 23.7745,
      longitude: 90.3688,
      facilityType: 'Neuroscience Center',
      phone: '+8802-9140752',
      operatingHours: '24/7 Neuro Emergency',
    ),
    const HospitalItem(
      id: 'hosp-suhrawardy',
      name: 'Shaheed Suhrawardy Medical College Hospital',
      address: 'Sher-e-Bangla Nagar, Mirpur Road, Dhaka-1207',
      city: 'Dhaka',
      latitude: 23.7698,
      longitude: 90.3712,
      facilityType: 'Government Medical College',
      phone: '+8802-9130800',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-mitford',
      name: 'Sir Salimullah Medical College & Mitford Hospital',
      address: 'Mitford Road, Old Dhaka, Dhaka-1100',
      city: 'Dhaka',
      latitude: 23.7107,
      longitude: 90.4026,
      facilityType: 'Government Medical College',
      phone: '+8802-7319002',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-mugda',
      name: 'Mugda Medical College Hospital',
      address: 'Mugda, Dhaka-1214',
      city: 'Dhaka',
      latitude: 23.7297,
      longitude: 90.4326,
      facilityType: 'Government Medical College',
      phone: '+8802-7275038',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-kurmitola',
      name: 'Kurmitola General Hospital',
      address: 'Dhaka-Mymensingh Road, Cantonment, Dhaka-1206',
      city: 'Dhaka',
      latitude: 23.8222,
      longitude: 90.4035,
      facilityType: 'Government Hospital',
      phone: '+8802-8711234',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-cmh-dhaka',
      name: 'Combined Military Hospital (CMH) Dhaka',
      address: 'Dhaka Cantonment, Dhaka-1206',
      city: 'Dhaka',
      latitude: 23.8175,
      longitude: 90.4011,
      facilityType: 'Military Hospital',
      phone: '+8802-8750011',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-square',
      name: 'Square Hospital Ltd.',
      address: '18/F Bir Uttam Qazi Nuruzzaman Sarak, West Panthapath, Dhaka-1205',
      city: 'Dhaka',
      latitude: 23.7533,
      longitude: 90.3816,
      facilityType: 'Private Tertiary Hospital',
      phone: '+8802-8159457',
      operatingHours: '24/7 Emergency & ICU',
    ),
    const HospitalItem(
      id: 'hosp-evercare-dhaka',
      name: 'Evercare Hospital Dhaka',
      address: 'Plot 81, Block E, Bashundhara R/A, Dhaka-1229',
      city: 'Dhaka',
      latitude: 23.8103,
      longitude: 90.4312,
      facilityType: 'Private Tertiary Hospital',
      phone: '+8809666710678',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-united',
      name: 'United Hospital Limited',
      address: 'Plot 15, Road 71, Gulshan-2, Dhaka-1212',
      city: 'Dhaka',
      latitude: 23.7997,
      longitude: 90.4199,
      facilityType: 'Private Tertiary Hospital',
      phone: '+8802-8836444',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-labaid',
      name: 'Labaid Specialized Hospital',
      address: 'House 06, Road 04, Dhanmondi, Dhaka-1205',
      city: 'Dhaka',
      latitude: 23.7423,
      longitude: 90.3831,
      facilityType: 'Private Specialized Hospital',
      phone: '+8802-9676356',
      operatingHours: '24/7 Emergency & Cardiac Center',
    ),
    const HospitalItem(
      id: 'hosp-asgar-ali',
      name: 'Asgar Ali Hospital',
      address: '111/1/A Distillery Road, Gandaria, Dhaka-1204',
      city: 'Dhaka',
      latitude: 23.7081,
      longitude: 90.4239,
      facilityType: 'Private Tertiary Hospital',
      phone: '+8809666710602',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-ibn-sina',
      name: 'Ibn Sina Specialized Hospital Dhanmondi',
      address: 'House 48, Road 9/A, Dhanmondi, Dhaka-1209',
      city: 'Dhaka',
      latitude: 23.7511,
      longitude: 90.3725,
      facilityType: 'Private Hospital',
      phone: '+8802-9126625',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-popular-dhanmondi',
      name: 'Popular Medical College Hospital Dhanmondi',
      address: 'House 16, Road 2, Dhanmondi, Dhaka-1205',
      city: 'Dhaka',
      latitude: 23.7410,
      longitude: 90.3820,
      facilityType: 'Private Medical College',
      phone: '+8802-9669480',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-ahsania',
      name: 'Ahsania Mission Cancer & General Hospital',
      address: 'Plot 03, Embankment Drive Way, Sector 10, Uttara, Dhaka-1230',
      city: 'Dhaka',
      latitude: 23.8820,
      longitude: 90.3880,
      facilityType: 'Cancer & General Hospital',
      phone: '+8802-55087001',
      operatingHours: '24/7 Oncology & Blood Services',
    ),

    // --- Specialized Blood Banks in Dhaka ---
    const HospitalItem(
      id: 'bb-red-crescent',
      name: 'Bangladesh Red Crescent Blood Center',
      address: '7/5 Aurangzeb Road, Block E, Mohammadpur, Dhaka-1207',
      city: 'Dhaka',
      latitude: 23.7634,
      longitude: 90.3621,
      facilityType: 'Central Blood Bank',
      phone: '+8802-9116563',
      operatingHours: '24/7 Blood Screening & Supply',
    ),
    const HospitalItem(
      id: 'bb-quantum',
      name: 'Quantum Foundation Blood Lab',
      address: '31/V Shilpacharya Zainul Abedin Sarak, Shantinagar, Dhaka-1217',
      city: 'Dhaka',
      latitude: 23.7380,
      longitude: 90.4132,
      facilityType: 'Central Blood Bank',
      phone: '+8802-9351450',
      operatingHours: '24/7 Transfusion & Component Lab',
    ),
    const HospitalItem(
      id: 'bb-bd-blood-bank',
      name: 'Bangladesh Blood Bank & Transfusion Center',
      address: '68/3 Green Road, Panthapath, Dhaka-1205',
      city: 'Dhaka',
      latitude: 23.7516,
      longitude: 90.3862,
      facilityType: 'Blood Bank & Transfusion Center',
      phone: '+8801712-345678',
      operatingHours: '24/7 Blood Screening',
    ),

    // --- Chattogram Division ---
    const HospitalItem(
      id: 'hosp-cmch',
      name: 'Chittagong Medical College Hospital (CMCH)',
      address: '57 K.B. Fazlul Kader Road, Chattogram-4203',
      city: 'Chattogram',
      latitude: 22.3592,
      longitude: 91.8285,
      facilityType: 'Government Medical College',
      phone: '+88031-619400',
      operatingHours: '24/7 Emergency & Blood Bank',
    ),
    const HospitalItem(
      id: 'hosp-evercare-ctg',
      name: 'Evercare Hospital Chattogram',
      address: 'Plot H1, Ananna R/A, Oxygen-Kuaish Road, Chattogram-4337',
      city: 'Chattogram',
      latitude: 22.4042,
      longitude: 91.8329,
      facilityType: 'Private Tertiary Hospital',
      phone: '+8809612310678',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-imperial-ctg',
      name: 'Imperial Hospital Limited',
      address: 'Zakir Hossain Road, Pahartali, Chattogram-4202',
      city: 'Chattogram',
      latitude: 22.3688,
      longitude: 91.8021,
      facilityType: 'Private Tertiary Hospital',
      phone: '+8809612222444',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-maa-shishu-ctg',
      name: 'Chattogram Maa-O-Shishu Hospital',
      address: 'Agrabad, Chattogram-4100',
      city: 'Chattogram',
      latitude: 22.3275,
      longitude: 91.8080,
      facilityType: 'Medical College & Hospital',
      phone: '+88031-711236',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-comilla-mc',
      name: 'Cumilla Medical College Hospital',
      address: 'Kuchaitoli, Cumilla-3500',
      city: 'Cumilla',
      latitude: 23.4498,
      longitude: 91.1843,
      facilityType: 'Government Medical College',
      phone: '+88081-76345',
      operatingHours: '24/7 Emergency',
    ),

    // --- Rajshahi & Rangpur Divisions ---
    const HospitalItem(
      id: 'hosp-rmch',
      name: 'Rajshahi Medical College Hospital (RMCH)',
      address: 'Laxmipur, Rajshahi-6000',
      city: 'Rajshahi',
      latitude: 24.3707,
      longitude: 88.5833,
      facilityType: 'Government Medical College',
      phone: '+880721-772150',
      operatingHours: '24/7 Emergency & Blood Bank',
    ),
    const HospitalItem(
      id: 'hosp-rangpur-mc',
      name: 'Rangpur Medical College Hospital',
      address: 'Medical College Road, Rangpur-5400',
      city: 'Rangpur',
      latitude: 25.7592,
      longitude: 89.2372,
      facilityType: 'Government Medical College',
      phone: '+880521-62288',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-szrmch-bogura',
      name: 'Shaheed Ziaur Rahman Medical College Hospital',
      address: 'Silimpur, Bogura-5800',
      city: 'Bogura',
      latitude: 24.8211,
      longitude: 89.3620,
      facilityType: 'Government Medical College',
      phone: '+88051-66789',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-dinajpur-mc',
      name: 'M Abdur Rahim Medical College Hospital',
      address: 'Dinajpur-5200',
      city: 'Dinajpur',
      latitude: 25.6022,
      longitude: 88.6385,
      facilityType: 'Government Medical College',
      phone: '+880531-64500',
      operatingHours: '24/7 Emergency',
    ),

    // --- Sylhet Division ---
    const HospitalItem(
      id: 'hosp-somch',
      name: 'Sylhet MAG Osmani Medical College Hospital',
      address: 'Medical College Road, Kajolshah, Sylhet-3100',
      city: 'Sylhet',
      latitude: 24.8997,
      longitude: 91.8576,
      facilityType: 'Government Medical College',
      phone: '+880821-713487',
      operatingHours: '24/7 Emergency & Blood Bank',
    ),
    const HospitalItem(
      id: 'hosp-ragib-rabeya',
      name: 'Jalalabad Ragib-Rabeya Medical College Hospital',
      address: 'Tarapur, Pathantula, Sylhet-3100',
      city: 'Sylhet',
      latitude: 24.9120,
      longitude: 91.8540,
      facilityType: 'Private Medical College',
      phone: '+880821-719090',
      operatingHours: '24/7 Emergency',
    ),

    // --- Khulna & Barishal Divisions ---
    const HospitalItem(
      id: 'hosp-kmch',
      name: 'Khulna Medical College Hospital',
      address: 'Boyra Main Road, Khulna-9000',
      city: 'Khulna',
      latitude: 22.8373,
      longitude: 89.5400,
      facilityType: 'Government Medical College',
      phone: '+88041-760350',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-sbmch-barishal',
      name: 'Sher-e-Bangla Medical College Hospital (SBMC)',
      address: 'Band Road, Barishal-8200',
      city: 'Barishal',
      latitude: 22.6896,
      longitude: 90.3639,
      facilityType: 'Government Medical College',
      phone: '+880431-2173541',
      operatingHours: '24/7 Emergency',
    ),
    const HospitalItem(
      id: 'hosp-mmch-mymensingh',
      name: 'Mymensingh Medical College Hospital',
      address: 'Charpara, Mymensingh-2200',
      city: 'Mymensingh',
      latitude: 24.7437,
      longitude: 90.4125,
      facilityType: 'Government Medical College',
      phone: '+88091-66063',
      operatingHours: '24/7 Emergency',
    ),
  ];

  static List<HospitalItem>? _cachedMergedList;

  /// Returns all available hospitals, merging the offline curated catalog with
  /// custom facilities stored in Supabase `donation_centers` table.
  static Future<List<HospitalItem>> getHospitals({bool forceRefresh = false}) async {
    if (_cachedMergedList != null && !forceRefresh) {
      return _cachedMergedList!;
    }

    final Map<String, HospitalItem> merged = {};

    // 1. Populate default curated hospitals
    for (final h in _offlineCatalog) {
      merged[h.name.toLowerCase().trim()] = h;
    }

    // 2. Fetch live centers from Supabase
    try {
      if (SupabaseConfig.isInitialized) {
        final rows = await SupabaseConfig.client
            .from('donation_centers')
            .select()
            .order('name', ascending: true);

        for (final row in rows) {
          try {
            final item = HospitalItem.fromSupabase(Map<String, dynamic>.from(row));
            final key = item.name.toLowerCase().trim();
            if (item.latitude != 0.0 && item.longitude != 0.0) {
              merged[key] = item;
            }
          } catch (e) {
            debugPrint('Error parsing donation center row: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('HospitalDirectoryService Supabase fetch notice: $e (using offline catalog)');
    }

    final list = merged.values.toList();
    _cachedMergedList = list;
    return list;
  }

  /// Synchronous fallback when async is not ready
  static List<HospitalItem> get staticHospitals => List.unmodifiable(_offlineCatalog);

  /// Search matching hospitals by name, city, address, or facility type.
  static List<HospitalItem> searchHospitals(String query, {List<HospitalItem>? source}) {
    final list = source ?? _offlineCatalog;
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return list;

    final tokens = trimmed.split(RegExp(r'\s+'));

    return list.where((item) {
      final name = item.name.toLowerCase();
      final addr = item.address.toLowerCase();
      final city = item.city.toLowerCase();
      final type = item.facilityType.toLowerCase();

      return tokens.every((token) =>
          name.contains(token) ||
          addr.contains(token) ||
          city.contains(token) ||
          type.contains(token));
    }).toList();
  }

  /// Computes distance in kilometers between two GPS coordinates using the Haversine formula.
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R, Earth radius = 6371 km
  }

  /// Calculates nearest hospitals to a user's coordinate and returns them sorted by proximity.
  static List<Map<String, dynamic>> getNearestHospitals({
    required double userLat,
    required double userLng,
    List<HospitalItem>? hospitals,
    int limit = 6,
  }) {
    final list = hospitals ?? _offlineCatalog;

    final results = list.map((h) {
      final dist = calculateDistanceKm(userLat, userLng, h.latitude, h.longitude);
      return {
        'hospital': h,
        'distanceKm': dist,
      };
    }).toList();

    results.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));

    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }
}
