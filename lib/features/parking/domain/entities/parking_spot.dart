class ParkingSpot {
  const ParkingSpot({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.description,
    this.ownership,
    this.hasAccessibleAccess = true,
    this.spotCount = 1,
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? description;
  final String? ownership;
  final bool hasAccessibleAccess;
  final int spotCount;

  ParkingSpot copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? description,
    String? ownership,
    bool? hasAccessibleAccess,
    int? spotCount,
  }) {
    return ParkingSpot(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      ownership: ownership ?? this.ownership,
      hasAccessibleAccess: hasAccessibleAccess ?? this.hasAccessibleAccess,
      spotCount: spotCount ?? this.spotCount,
    );
  }
}
