enum ParkingMode {
  searchAddress,
  nearMe,
}

class ParkingModeConfig {
  final ParkingMode mode;
  final String? searchAddress;

  const ParkingModeConfig({
    required this.mode,
    this.searchAddress,
  });
}
