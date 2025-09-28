import '../entities/parking_spot.dart';

abstract class ParkingRepository {
  Future<List<ParkingSpot>> getParkingSpots({bool forceRefresh = false});
}
