import 'package:flutter/material.dart';

import '../../domain/entities/parking_spot.dart';

class ParkingMarker extends StatelessWidget {
  const ParkingMarker({
    super.key,
    required this.spot,
    required this.isSelected,
    required this.onTap,
    required this.size,
  });

  final ParkingSpot spot;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleSpots = spot.spotCount > 1;
    final double extent = _markerExtent(size, spot.spotCount);
    final IconData iconData = spot.hasAccessibleAccess
        ? Icons.accessible_forward
        : Icons.local_parking;
    final List<Color> gradientColors = isSelected
        ? const [Color(0xFF0D47A1), Color(0xFF00A6FB)]
        : const [Color(0xFF0277BD), Color(0xFF29B6F6)];
    final double iconSize = (size * 0.75).clamp(10, 22).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: extent,
        height: extent,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
                border: Border.all(
                  color: Colors.white,
                  width: size * (isSelected ? 0.16 : 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isSelected ? 0.35 : 0.25,
                    ),
                    blurRadius: isSelected ? 14 : 9,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
            if (hasMultipleSpots)
              Positioned(
                right: -size * 0.2,
                bottom: -size * 0.2,
                child: MarkerBadge(
                  count: spot.spotCount,
                  emphasize: isSelected,
                  parentSize: size,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _markerExtent(double baseSize, int spotCount) {
    final double multiplier = spotCount > 1 ? 1.45 : 1.2;
    return baseSize * multiplier;
  }
}

class MarkerBadge extends StatelessWidget {
  const MarkerBadge({
    super.key,
    required this.count,
    required this.emphasize,
    required this.parentSize,
  });

  final int count;
  final bool emphasize;
  final double parentSize;

  @override
  Widget build(BuildContext context) {
    final double fontSize = (parentSize * 0.32).clamp(10, 16).toDouble();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: parentSize * 0.2,
        vertical: parentSize * 0.12,
      ),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFD54F) : Colors.white,
        borderRadius: BorderRadius.circular(parentSize),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: emphasize ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          color: emphasize ? const Color(0xFF3E2723) : Colors.black87,
        ),
      ),
    );
  }
}
