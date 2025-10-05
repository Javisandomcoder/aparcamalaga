import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/parking_spot.dart';
import '../providers/parking_providers.dart';

class SpotDetailsCard extends ConsumerWidget {
  const SpotDetailsCard({
    super.key,
    required this.spot,
    required this.onClose,
    required this.onNavigate,
  });

  final ParkingSpot spot;
  final VoidCallback onClose;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final userLocation = ref.watch(userLocationProvider);
    final calculator = ref.watch(distanceCalculatorProvider);
    final toggleFavorite = ref.read(toggleFavoriteProvider);

    final isFavorite = favoritesAsync.when(
      data: (favorites) => favorites.contains(spot.id.toString()),
      loading: () => false,
      error: (_, __) => false,
    );

    String? distanceText;
    if (userLocation != null) {
      distanceText = calculator.getFormattedDistance(
        userLocation,
        LatLng(spot.latitude, spot.longitude),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    spot.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => toggleFavorite(spot.id.toString()),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(spot.address, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_seat, size: 18),
                const SizedBox(width: 4),
                Text('${spot.spotCount} plaza${spot.spotCount > 1 ? 's' : ''}'),
                const SizedBox(width: 16),
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    spot.ownership ?? 'Titularidad no especificada',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (distanceText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.near_me, size: 18),
                  const SizedBox(width: 4),
                  Text('A $distanceText de ti'),
                ],
              ),
            ],
            if (spot.hasAccessibleAccess) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.accessible_forward, size: 18),
                  SizedBox(width: 4),
                  Text('Acceso adaptado'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation),
                label: const Text('Iniciar ruta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
