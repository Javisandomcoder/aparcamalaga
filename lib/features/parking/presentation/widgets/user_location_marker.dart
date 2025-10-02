import 'package:flutter/material.dart';

class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({
    super.key,
    required this.isFollowing,
  });

  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    final Color accent = isFollowing
        ? const Color(0xFF00D1C1)
        : const Color(0xFF006494);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: accent, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
      ),
    );
  }
}
