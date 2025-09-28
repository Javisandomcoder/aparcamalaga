import 'dart:io';

import 'package:aparcamalaga/features/parking/data/datasources/parking_remote_data_source.dart';

Future<void> main() async {
  final dataSource = ParkingRemoteDataSource();
  stdout.writeln('Descargando datos de plazas PMR del ayuntamiento...');
  try {
    final spots = await dataSource.fetchParkingSpots();
    stdout.writeln('Total de plazas parseadas: ${spots.length}');
    if (spots.isNotEmpty) {
      final first = spots.first;
      stdout.writeln('Primer registro:');
      stdout.writeln('  id: ${first.id}');
      stdout.writeln('  nombre: ${first.name}');
      stdout.writeln('  dirección: ${first.address}');
      stdout.writeln('  coordenadas: ${first.latitude}, ${first.longitude}');
      stdout.writeln('Ejemplos adicionales:');
      for (final spot in spots.skip(1).take(4)) {
        stdout.writeln(
          '  - ${spot.name} | ${spot.address} | plazas: ${spot.spotCount} | accesible: ${spot.hasAccessibleAccess}',
        );
      }
    }
  } catch (error, stackTrace) {
    stderr.writeln('Error validando dataset: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    dataSource.dispose();
  }
}
