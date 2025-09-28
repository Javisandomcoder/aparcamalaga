import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parking_spot_model.dart';

class ParkingRemoteDataSource {
  ParkingRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  static const _endpoint =
      'https://datosabiertos.malaga.eu/recursos/transporte/trafico/da_aparcamientosMovilidadReducida-4326.geojson';

  final http.Client _client;

  Future<List<ParkingSpotModel>> fetchParkingSpots() async {
    final uri = Uri.parse(_endpoint);
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw HttpException('Error remoto  al obtener plazas PMR.');
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final features = payload['features'] as List<dynamic>?;

    if (features == null) {
      throw const FormatException('Respuesta sin listado de plazas PMR.');
    }

    return features
        .whereType<Map<String, dynamic>>()
        .map(ParkingSpotModel.fromGeoJsonFeature)
        .toList();
  }

  void dispose() {
    _client.close();
  }
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;

  @override
  String toString() => message;
}
