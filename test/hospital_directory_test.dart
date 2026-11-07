// test/hospital_directory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:red_cell_net_final/features/blood_requests/data/services/hospital_directory_service.dart';

void main() {
  group('HospitalDirectoryService Tests', () {
    test('Static catalog is loaded with top regional hospitals', () {
      final hospitals = HospitalDirectoryService.staticHospitals;
      expect(hospitals, isNotEmpty);
      expect(hospitals.length, greaterThanOrEqualTo(25));

      final dmch = hospitals.firstWhere(
        (h) => h.name.contains('Dhaka Medical College'),
      );
      expect(dmch.city, 'Dhaka');
      expect(dmch.latitude, closeTo(23.7258, 0.001));
      expect(dmch.longitude, closeTo(90.3976, 0.001));
    });

    test('searchHospitals returns accurate matches by name, city, or address', () {
      final dhakaMatches = HospitalDirectoryService.searchHospitals('dhaka');
      expect(dhakaMatches, isNotEmpty);
      expect(dhakaMatches.any((h) => h.city == 'Dhaka'), isTrue);

      final ctgMatches = HospitalDirectoryService.searchHospitals('chittagong');
      expect(ctgMatches, isNotEmpty);
      expect(ctgMatches.any((h) => h.city == 'Chattogram'), isTrue);

      final bloodBanks = HospitalDirectoryService.searchHospitals('blood');
      expect(bloodBanks, isNotEmpty);
      expect(bloodBanks.any((h) => h.name.toLowerCase().contains('blood') || h.facilityType.toLowerCase().contains('blood')), isTrue);
    });

    test('calculateDistanceKm computes accurate Haversine distance', () {
      // Distance between DMCH (23.7258, 90.3976) and BSMMU (23.7389, 90.3957) is ~1.5 km
      final dist = HospitalDirectoryService.calculateDistanceKm(
        23.7258,
        90.3976,
        23.7389,
        90.3957,
      );
      expect(dist, greaterThan(1.0));
      expect(dist, lessThan(2.0));
    });

    test('getNearestHospitals ranks hospitals ascending by distance', () {
      // Position close to Shahbag, Dhaka
      const double userLat = 23.7385;
      const double userLng = 90.3955;

      final nearest = HospitalDirectoryService.getNearestHospitals(
        userLat: userLat,
        userLng: userLng,
        limit: 5,
      );

      expect(nearest.length, 5);
      final first = nearest[0]['hospital'] as HospitalItem;
      final firstDist = nearest[0]['distanceKm'] as double;
      final secondDist = nearest[1]['distanceKm'] as double;

      // Closest hospital should be BSMMU / BIRDEM
      expect(firstDist, lessThanOrEqualTo(secondDist));
      expect(firstDist, lessThan(0.5)); // Within 500m of Shahbag
      expect(first.name.contains('BSMMU') || first.name.contains('BIRDEM'), isTrue);
    });
  });
}
