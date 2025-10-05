import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aparcamalaga/features/parking/domain/services/distance_calculator.dart'
    as dc;

void main() {
  group('DistanceCalculator', () {
    late dc.DistanceCalculator calculator;

    setUp(() {
      calculator = dc.DistanceCalculator();
    });

    test('calculates distance between two points', () {
      final from = LatLng(36.7213, -4.4217); // Málaga center
      final to = LatLng(36.7255, -4.4203); // ~500m away

      final distance = calculator.calculateDistance(from, to);

      expect(distance, greaterThan(400));
      expect(distance, lessThan(600));
    });

    test('formats distance in meters when less than 1000m', () {
      final formatted = calculator.formatDistance(500);
      expect(formatted, '500 m');
    });

    test('formats distance in kilometers when greater than 1000m', () {
      final formatted = calculator.formatDistance(1500);
      expect(formatted, '1.5 km');
    });

    test('calculates and formats distance', () {
      final from = LatLng(36.7213, -4.4217);
      final to = LatLng(36.7213, -4.4217); // Same point

      final formatted = calculator.getFormattedDistance(from, to);
      expect(formatted, '0 m');
    });
  });
}
