import 'package:flutter/material.dart';

import '../../domain/entities/parking_spot.dart';

class DriveAssistCard extends StatelessWidget {
  const DriveAssistCard({
    super.key,
    required this.spot,
    this.onNavigate,
    this.onDismiss,
  });

  final ParkingSpot? spot;
  final VoidCallback? onNavigate;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ParkingSpot? currentSpot = spot;
    final bool hasSpot = currentSpot != null;
    final String titleText =
        currentSpot?.name ?? 'Mantén la vista en la carretera';
    final String subtitleText = currentSpot?.address ??
        'Usa el modo conducción para recibir avisos rápidos y centrar el mapa en tu posición.';

    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titleText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasSpot && onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (hasSpot && onNavigate != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Iniciar ruta'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
