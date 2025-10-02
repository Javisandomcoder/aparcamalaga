import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/logger.dart';

class FavoritesService {
  static const _favoritesKey = 'favorite_parking_spots';

  Future<Set<String>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      return favorites.toSet();
    } catch (e) {
      logger.e('Error loading favorites', error: e);
      return {};
    }
  }

  Future<void> addFavorite(String spotId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      if (!favorites.contains(spotId)) {
        favorites.add(spotId);
        await prefs.setStringList(_favoritesKey, favorites);
        logger.d('Added favorite: $spotId');
      }
    } catch (e) {
      logger.e('Error adding favorite', error: e);
    }
  }

  Future<void> removeFavorite(String spotId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      favorites.remove(spotId);
      await prefs.setStringList(_favoritesKey, favorites);
      logger.d('Removed favorite: $spotId');
    } catch (e) {
      logger.e('Error removing favorite', error: e);
    }
  }

  Future<bool> isFavorite(String spotId) async {
    final favorites = await getFavorites();
    return favorites.contains(spotId);
  }

  Future<void> toggleFavorite(String spotId) async {
    if (await isFavorite(spotId)) {
      await removeFavorite(spotId);
    } else {
      await addFavorite(spotId);
    }
  }
}
