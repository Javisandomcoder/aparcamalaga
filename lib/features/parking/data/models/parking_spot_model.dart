import '../../domain/entities/parking_spot.dart';

class ParkingSpotModel extends ParkingSpot {
  ParkingSpotModel({
    required super.id,
    required super.name,
    required super.address,
    required super.latitude,
    required super.longitude,
    super.description,
    super.ownership,
    super.hasAccessibleAccess = true,
    super.spotCount = 1,
  });

  factory ParkingSpotModel.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>?;

    if (geometry == null || properties == null) {
      throw const FormatException('GeoJSON incompleto para la plaza PMR.');
    }

    final coordinates = geometry['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.length < 2) {
      throw const FormatException('Coordenadas inválidas en la respuesta.');
    }

    final rawSpots = properties['NROPLAZAS']?.toString();
    final parsedSpots = int.tryParse(rawSpots ?? '1') ?? 1;
    final accesopmr = properties['ACCESOPMR']?.toString().toLowerCase().trim();

    return ParkingSpotModel(
      id: _parseId(properties['ID']),
      name: (properties['NOMBRE']?.toString() ?? '').trim().isEmpty
          ? 'Plaza PMR sin nombre'
          : properties['NOMBRE'].toString().trim(),
      address: (properties['DIRECCION']?.toString() ?? '').trim().isEmpty
          ? 'Dirección no disponible'
          : properties['DIRECCION'].toString().trim(),
      latitude: _parseCoordinate(coordinates, index: 1),
      longitude: _parseCoordinate(coordinates, index: 0),
      description: properties['DESCRIPCION']?.toString(),
      ownership: properties['TITULARIDAD']?.toString(),
      hasAccessibleAccess: accesopmr == 'si' || accesopmr == 'sí',
      spotCount: parsedSpots,
    );
  }

  factory ParkingSpotModel.fromJson(Map<String, dynamic> json) {
    return ParkingSpotModel(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
      ownership: json['ownership'] as String?,
      hasAccessibleAccess: json['hasAccessibleAccess'] as bool? ?? true,
      spotCount: json['spotCount'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'ownership': ownership,
      'hasAccessibleAccess': hasAccessibleAccess,
      'spotCount': spotCount,
    };
  }

  static int _parseId(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseCoordinate(
    List<dynamic> coordinates, {
    required int index,
  }) {
    if (coordinates.length <= index) {
      throw const FormatException('Coordenadas insuficientes.');
    }
    final value = coordinates[index];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}
