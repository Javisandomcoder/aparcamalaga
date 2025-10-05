class ParkingFilter {
  const ParkingFilter({
    this.searchQuery = '',
    this.showOnlyAccessible = false,
    this.ownership,
    this.minSpotCount,
  });

  final String searchQuery;
  final bool showOnlyAccessible;
  final String? ownership;
  final int? minSpotCount;

  ParkingFilter copyWith({
    String? searchQuery,
    bool? showOnlyAccessible,
    String? ownership,
    int? minSpotCount,
  }) {
    return ParkingFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      showOnlyAccessible: showOnlyAccessible ?? this.showOnlyAccessible,
      ownership: ownership ?? this.ownership,
      minSpotCount: minSpotCount ?? this.minSpotCount,
    );
  }

  bool get isActive =>
      searchQuery.isNotEmpty ||
      showOnlyAccessible ||
      ownership != null ||
      minSpotCount != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParkingFilter &&
          runtimeType == other.runtimeType &&
          searchQuery == other.searchQuery &&
          showOnlyAccessible == other.showOnlyAccessible &&
          ownership == other.ownership &&
          minSpotCount == other.minSpotCount;

  @override
  int get hashCode =>
      searchQuery.hashCode ^
      showOnlyAccessible.hashCode ^
      ownership.hashCode ^
      minSpotCount.hashCode;
}
