import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/parking_spot_model.dart';

class ParkingLocalDataSource {
  static const _cacheKey = 'parking_spots_cache_v1';
  static const _timestampKey = 'parking_spots_cache_timestamp_v1';

  Future<void> cacheSpots(List<ParkingSpotModel> spots) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(spots.map((spot) => spot.toJson()).toList());
    await prefs.setString(_cacheKey, serialized);
    await prefs.setString(
      _timestampKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<List<ParkingSpotModel>?> readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = prefs.getString(_cacheKey);
    if (serialized == null) {
      return null;
    }
    try {
      final List<dynamic> rawList = jsonDecode(serialized) as List<dynamic>;
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(ParkingSpotModel.fromJson)
          .toList();
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<DateTime?> lastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_timestampKey);
    if (stored == null) {
      return null;
    }
    return DateTime.tryParse(stored)?.toUtc();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_timestampKey);
  }
}
