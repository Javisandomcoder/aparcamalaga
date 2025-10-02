import 'package:latlong2/latlong.dart';

class DistanceCalculator {
  static const Distance _distance = Distance();

  /// Calculates distance in meters between two points
  double calculateDistance(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
  }

  /// Formats distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Calculates and formats distance
  String getFormattedDistance(LatLng from, LatLng to) {
    final meters = calculateDistance(from, to);
    return formatDistance(meters);
  }
}
