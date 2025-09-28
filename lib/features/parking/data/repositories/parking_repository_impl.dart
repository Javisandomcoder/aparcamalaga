import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_repository.dart';
import '../datasources/parking_local_data_source.dart';
import '../datasources/parking_remote_data_source.dart';
import '../models/parking_spot_model.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  ParkingRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    this.cacheTTL = const Duration(hours: 6),
  });

  final ParkingRemoteDataSource remoteDataSource;
  final ParkingLocalDataSource localDataSource;
  final Duration cacheTTL;

  @override
  Future<List<ParkingSpot>> getParkingSpots({bool forceRefresh = false}) async {
    final now = DateTime.now().toUtc();

    if (!forceRefresh) {
      final cached = await localDataSource.readCache();
      final lastUpdated = await localDataSource.lastUpdated();
      final isCacheValid =
          cached != null &&
          cached.isNotEmpty &&
          lastUpdated != null &&
          now.difference(lastUpdated) <= cacheTTL;

      if (isCacheValid) {
        return cached;
      }
    }

    try {
      final List<ParkingSpotModel> remote = await remoteDataSource
          .fetchParkingSpots();
      await localDataSource.cacheSpots(remote);
      return remote;
    } catch (_) {
      final cached = await localDataSource.readCache();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }
}
