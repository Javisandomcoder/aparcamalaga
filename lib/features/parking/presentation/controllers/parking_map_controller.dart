import 'package:flutter/material.dart';

import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_repository.dart';

class ParkingMapController extends ChangeNotifier {
  ParkingMapController({required ParkingRepository repository})
    : _repository = repository;

  final ParkingRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  List<ParkingSpot> _spots = const [];
  ParkingSpot? _selectedSpot;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ParkingSpot> get spots => List.unmodifiable(_spots);
  ParkingSpot? get selectedSpot => _selectedSpot;

  Future<void> loadSpots({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _repository.getParkingSpots(
        forceRefresh: forceRefresh,
      );
      _spots = results;
      if (_selectedSpot != null) {
        _selectedSpot = results.firstWhere(
          (spot) => spot.id == _selectedSpot!.id,
          orElse: () => _selectedSpot!,
        );
      }
    } catch (error) {
      _errorMessage = _humanErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSpot(ParkingSpot? spot) {
    _selectedSpot = spot;
    notifyListeners();
  }

  String _humanErrorMessage(Object error) {
    return 'No se pudieron cargar las plazas PMR. Comprueba tu conexión e inténtalo de nuevo.';
  }
}
