import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tugas_akhir_mobile/core/utils/map_utils.dart';
import 'package:tugas_akhir_mobile/data/models/user_location_model.dart';

void main() {
  group('map_utils', () {
    test('isValidCoordinate accepts normal coordinates', () {
      expect(isValidCoordinate(-6.2, 106.8), isTrue);
    });

    test('isValidCoordinate rejects out-of-range values', () {
      expect(isValidCoordinate(95, 0), isFalse);
      expect(isValidCoordinate(0, 200), isFalse);
      expect(isValidCoordinate(double.nan, 10), isFalse);
    });

    test('filterValidLocations removes invalid entries', () {
      final locations = [
        UserLocationModel(
          userId: 1,
          userName: 'A',
          latitude: -6.2,
          longitude: 106.8,
          locationName: 'Jakarta',
          points: 10,
        ),
        UserLocationModel(
          userId: 2,
          userName: 'B',
          latitude: 999,
          longitude: 10,
          locationName: 'Invalid',
          points: 5,
        ),
      ];

      final valid = filterValidLocations(locations);
      expect(valid, hasLength(1));
      expect(valid.first.userName, 'A');
    });

    test('resolveMapCenter falls back to Indonesia when empty', () {
      expect(resolveMapCenter([]), kDefaultMapCenter);
    });

    test('resolveMapCenter averages valid coordinates', () {
      final center = resolveMapCenter([
        UserLocationModel(
          userId: 1,
          userName: 'A',
          latitude: 0,
          longitude: 0,
          locationName: 'A',
          points: 1,
        ),
        UserLocationModel(
          userId: 2,
          userName: 'B',
          latitude: 10,
          longitude: 20,
          locationName: 'B',
          points: 2,
        ),
      ]);

      expect(center, const LatLng(5, 10));
    });
  });
}
