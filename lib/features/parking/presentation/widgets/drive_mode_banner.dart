import 'package:flutter/material.dart';

class DriveModeBanner extends StatelessWidget {
  const DriveModeBanner({
    super.key,
    required this.onExit,
    required this.followingEnabled,
  });

  final VoidCallback onExit;
  final bool followingEnabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102542),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Modo conducción activo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    followingEnabled
                        ? 'El mapa te seguirá automáticamente.'
                        : 'Activa el seguimiento para centrarte en tu ruta.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onExit,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }
}
