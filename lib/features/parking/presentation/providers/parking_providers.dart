import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/datasources/parking_local_data_source.dart';
import '../../data/datasources/parking_remote_data_source.dart';
import '../../data/repositories/parking_repository_impl.dart';
import '../../domain/entities/parking_filter.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_repository.dart';
import '../../domain/services/distance_calculator.dart' as dc;
import '../../domain/services/favorites_service.dart';

// Data sources
final parkingRemoteDataSourceProvider = Provider<ParkingRemoteDataSource>((ref) {
  return ParkingRemoteDataSource();
});

final parkingLocalDataSourceProvider = Provider<ParkingLocalDataSource>((ref) {
  return ParkingLocalDataSource();
});

// Repository
final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepositoryImpl(
    remoteDataSource: ref.watch(parkingRemoteDataSourceProvider),
    localDataSource: ref.watch(parkingLocalDataSourceProvider),
  );
});

// Services
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

final distanceCalculatorProvider = Provider<dc.DistanceCalculator>((ref) {
  return dc.DistanceCalculator();
});

// State: All parking spots
final parkingSpotsProvider = FutureProvider<List<ParkingSpot>>((ref) async {
  final repository = ref.watch(parkingRepositoryProvider);
  return repository.getParkingSpots();
});

// State: Filter
final parkingFilterProvider = StateProvider<ParkingFilter>((ref) {
  return const ParkingFilter();
});

// State: Favorites
final favoritesProvider = FutureProvider<Set<String>>((ref) async {
  final service = ref.watch(favoritesServiceProvider);
  return service.getFavorites();
});

// State: Selected spot
final selectedSpotProvider = StateProvider<ParkingSpot?>((ref) => null);

// State: User location
final userLocationProvider = StateProvider<LatLng?>((ref) => null);

// State: Follow user
final followUserProvider = StateProvider<bool>((ref) => true);

// State: Drive mode
final driveModeProvider = StateProvider<bool>((ref) => true);

// Computed: Filtered spots
final filteredParkingSpotsProvider = Provider<AsyncValue<List<ParkingSpot>>>((ref) {
  final spotsAsync = ref.watch(parkingSpotsProvider);
  final filter = ref.watch(parkingFilterProvider);
  final userLocation = ref.watch(userLocationProvider);
  final calculator = ref.watch(distanceCalculatorProvider);

  return spotsAsync.when(
    data: (spots) {
      var filtered = spots;

      // Search query
      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        filtered = filtered.where((spot) {
          return spot.name.toLowerCase().contains(query) ||
              spot.address.toLowerCase().contains(query);
        }).toList();
      }

      // Accessible filter
      if (filter.showOnlyAccessible) {
        filtered = filtered.where((spot) => spot.hasAccessibleAccess).toList();
      }

      // Ownership filter
      if (filter.ownership != null) {
        filtered = filtered
            .where((spot) => spot.ownership == filter.ownership)
            .toList();
      }

      // Spot count filter
      if (filter.minSpotCount != null) {
        filtered = filtered
            .where((spot) => spot.spotCount >= filter.minSpotCount!)
            .toList();
      }

      // Sort by distance if user location available
      if (userLocation != null) {
        filtered.sort((a, b) {
          final distA = calculator.calculateDistance(
            userLocation,
            LatLng(a.latitude, a.longitude),
          );
          final distB = calculator.calculateDistance(
            userLocation,
            LatLng(b.latitude, b.longitude),
          );
          return distA.compareTo(distB);
        });
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Computed: Available ownership values
final availableOwnershipsProvider = Provider<List<String>>((ref) {
  final spotsAsync = ref.watch(parkingSpotsProvider);
  return spotsAsync.when(
    data: (spots) {
      final ownerships = spots
          .map((spot) => spot.ownership)
          .where((ownership) => ownership != null)
          .cast<String>()
          .toSet()
          .toList();
      ownerships.sort();
      return ownerships;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Actions: Toggle favorite
final toggleFavoriteProvider = Provider<Future<void> Function(String)>((ref) {
  return (String spotId) async {
    final service = ref.read(favoritesServiceProvider);
    await service.toggleFavorite(spotId);
    ref.invalidate(favoritesProvider);
  };
});

// Actions: Refresh spots
final refreshSpotsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repository = ref.read(parkingRepositoryProvider);
    await repository.getParkingSpots(forceRefresh: true);
    ref.invalidate(parkingSpotsProvider);
  };
});
