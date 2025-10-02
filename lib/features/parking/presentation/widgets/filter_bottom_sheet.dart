import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/parking_filter.dart';
import '../providers/parking_providers.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({
    super.key,
    this.onFiltersApplied,
  });

  final VoidCallback? onFiltersApplied;

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late TextEditingController _searchController;
  late bool _showOnlyAccessible;
  String? _selectedOwnership;
  int? _minSpotCount;

  @override
  void initState() {
    super.initState();
    final currentFilter = ref.read(parkingFilterProvider);
    _searchController = TextEditingController(text: currentFilter.searchQuery);
    _showOnlyAccessible = currentFilter.showOnlyAccessible;
    _selectedOwnership = currentFilter.ownership;
    _minSpotCount = currentFilter.minSpotCount;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(parkingFilterProvider.notifier).state = ParkingFilter(
      searchQuery: _searchController.text,
      showOnlyAccessible: _showOnlyAccessible,
      ownership: _selectedOwnership,
      minSpotCount: _minSpotCount,
    );
    Navigator.pop(context);
    widget.onFiltersApplied?.call();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _showOnlyAccessible = false;
      _selectedOwnership = null;
      _minSpotCount = null;
    });
    ref.read(parkingFilterProvider.notifier).state = const ParkingFilter();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ownerships = ref.watch(availableOwnershipsProvider);
    final isDriveMode = ref.watch(driveModeProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filtros',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isDriveMode)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El mapa no se centrará automáticamente en modo conducción por seguridad',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Nombre o dirección',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _showOnlyAccessible,
              onChanged: (value) {
                setState(() {
                  _showOnlyAccessible = value ?? false;
                });
              },
              title: const Text('Solo con acceso adaptado'),
              secondary: const Icon(Icons.accessible_forward),
            ),
            const SizedBox(height: 8),
            if (ownerships.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: _selectedOwnership,
                decoration: const InputDecoration(
                  labelText: 'Titularidad',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...ownerships.map(
                    (ownership) => DropdownMenuItem<String?>(
                      value: ownership,
                      child: Text(ownership),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedOwnership = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<int?>(
              initialValue: _minSpotCount,
              decoration: const InputDecoration(
                labelText: 'Mínimo de plazas',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Cualquiera'),
                ),
                DropdownMenuItem<int?>(
                  value: 1,
                  child: Text('1 o más'),
                ),
                DropdownMenuItem<int?>(
                  value: 2,
                  child: Text('2 o más'),
                ),
                DropdownMenuItem<int?>(
                  value: 3,
                  child: Text('3 o más'),
                ),
                DropdownMenuItem<int?>(
                  value: 5,
                  child: Text('5 o más'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _minSpotCount = value;
                });
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Aplicar filtros'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
