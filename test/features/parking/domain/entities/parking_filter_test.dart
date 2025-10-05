import 'package:flutter_test/flutter_test.dart';
import 'package:aparcamalaga/features/parking/domain/entities/parking_filter.dart';

void main() {
  group('ParkingFilter', () {
    test('default filter is not active', () {
      const filter = ParkingFilter();
      expect(filter.isActive, false);
    });

    test('filter with search query is active', () {
      const filter = ParkingFilter(searchQuery: 'test');
      expect(filter.isActive, true);
    });

    test('filter with showOnlyAccessible is active', () {
      const filter = ParkingFilter(showOnlyAccessible: true);
      expect(filter.isActive, true);
    });

    test('filter with ownership is active', () {
      const filter = ParkingFilter(ownership: 'Municipal');
      expect(filter.isActive, true);
    });

    test('filter with minSpotCount is active', () {
      const filter = ParkingFilter(minSpotCount: 2);
      expect(filter.isActive, true);
    });

    test('copyWith creates new instance with updated values', () {
      const original = ParkingFilter(searchQuery: 'test');
      final updated = original.copyWith(showOnlyAccessible: true);

      expect(updated.searchQuery, 'test');
      expect(updated.showOnlyAccessible, true);
    });

    test('two identical filters are equal', () {
      const filter1 = ParkingFilter(searchQuery: 'test');
      const filter2 = ParkingFilter(searchQuery: 'test');

      expect(filter1, filter2);
    });

    test('two different filters are not equal', () {
      const filter1 = ParkingFilter(searchQuery: 'test');
      const filter2 = ParkingFilter(searchQuery: 'other');

      expect(filter1, isNot(filter2));
    });
  });
}
