import 'package:latlong2/latlong.dart';

import '../../data/models/user_location_model.dart';

/// Pusat default peta (Indonesia) saat belum ada marker.
const LatLng kDefaultMapCenter = LatLng(-2.5489, 118.0149);

bool isValidCoordinate(double latitude, double longitude) {
  if (latitude.isNaN || longitude.isNaN) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  return true;
}

List<UserLocationModel> filterValidLocations(
  List<UserLocationModel> locations,
) {
  return locations
      .where(
        (location) =>
            isValidCoordinate(location.latitude, location.longitude),
      )
      .toList();
}

LatLng resolveMapCenter(List<UserLocationModel> locations) {
  final valid = filterValidLocations(locations);
  if (valid.isEmpty) return kDefaultMapCenter;

  final latitude =
      valid.fold<double>(0, (sum, item) => sum + item.latitude) /
      valid.length;
  final longitude =
      valid.fold<double>(0, (sum, item) => sum + item.longitude) /
      valid.length;
  return LatLng(latitude, longitude);
}
