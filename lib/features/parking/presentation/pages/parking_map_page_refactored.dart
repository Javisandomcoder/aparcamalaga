import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/map/cached_tile_provider.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/parking_spot.dart';
import '../providers/parking_providers.dart';
import '../widgets/drive_assist_card.dart';
import '../widgets/drive_mode_banner.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/info_banner.dart';
import '../widgets/parking_marker.dart';
import '../widgets/spot_details_card.dart';
import '../widgets/user_location_marker.dart';

class ParkingMapPageRefactored extends ConsumerStatefulWidget {
  const ParkingMapPageRefactored({super.key});

  @override
  ConsumerState<ParkingMapPageRefactored> createState() =>
      _ParkingMapPageRefactoredState();
}

class _ParkingMapPageRefactoredState
    extends ConsumerState<ParkingMapPageRefactored> {
  static const _initialCenter = LatLng(36.7213, -4.4217);
  static const _initialZoom = 13.0;
  static const _markerSize = 16.0;
  static const _markerSelectedSize = 20.0;
  static const _markerDriveScale = 1.5;

  late final MapController _mapController;
  late final CachedNetworkTileProvider _tileProvider;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<MapEvent>? _mapEventSubscription;
  String? _locationError;
  bool _locationServiceDisabled = false;
  bool _locationDeniedForever = false;
  bool _isPrefetchingTiles = false;
  bool _isProgrammaticMove = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapEventSubscription =
        _mapController.mapEventStream.listen(_handleMapEvent);
    _tileProvider = CachedNetworkTileProvider(maxAge: const Duration(days: 5));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationTracking();
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    _positionSubscription?.cancel();
    _tileProvider.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDriveMode = ref.watch(driveModeProvider);
    final filteredSpotsAsync = ref.watch(filteredParkingSpotsProvider);

    return Scaffold(
      backgroundColor: isDriveMode ? Colors.black : null,
      appBar: isDriveMode
          ? null
          : AppBar(
              title: const Text('Plazas PMR en Málaga'),
              actions: [
                IconButton(
                  tooltip: 'Filtros',
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterSheet,
                ),
                IconButton(
                  tooltip: 'Opciones de mapa',
                  icon: const Icon(Icons.layers_outlined),
                  onPressed: _showMapOptionsSheet,
                ),
              ],
            ),
      body: filteredSpotsAsync.when(
        data: (spots) => Stack(
          children: [
            _buildMap(context, spots),
            _buildTopMessages(),
            _buildFloatingButtons(context),
            _buildSpotDetailsCard(),
            _buildDriveAssistCard(),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error al cargar las plazas: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(parkingSpotsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<ParkingSpot> spots) {
    final isDriveMode = ref.watch(driveModeProvider);
    final selectedSpot = ref.watch(selectedSpotProvider);
    final userLocation = ref.watch(userLocationProvider);
    final followUser = ref.watch(followUserProvider);
    final Color background = isDriveMode ? Colors.black : Colors.white;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        minZoom: 11,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        backgroundColor: background,
        onTap: (_, __) => ref.read(selectedSpotProvider.notifier).state = null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.aparcamalaga',
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 60,
            size: const Size(50, 50),
            markers: spots.map((spot) {
              final bool isSelected = spot.id == selectedSpot?.id;
              final double baseSize =
                  isSelected ? _markerSelectedSize : _markerSize;
              final double size =
                  isDriveMode ? baseSize * _markerDriveScale : baseSize;
              final double markerExtent = _markerExtent(size, spot.spotCount);

              return Marker(
                point: LatLng(spot.latitude, spot.longitude),
                width: markerExtent,
                height: markerExtent,
                alignment: Alignment.center,
                child: ParkingMarker(
                  spot: spot,
                  isSelected: isSelected,
                  onTap: () => _onMarkerTap(spot),
                  size: size,
                ),
              );
            }).toList(),
            builder: (context, markers) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0277BD),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${markers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation,
                width: 22,
                height: 22,
                alignment: Alignment.center,
                child: UserLocationMarker(
                  isFollowing: followUser,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopMessages() {
    final isDriveMode = ref.watch(driveModeProvider);
    final followUser = ref.watch(followUserProvider);
    final List<Widget> messages = [];

    if (isDriveMode) {
      messages.add(
        DriveModeBanner(
          onExit: _toggleDriveMode,
          followingEnabled: followUser,
        ),
      );
    }

    if (_locationError != null) {
      messages.add(
        InfoBanner(
          message: _locationError!,
          actionLabel: _locationServiceDisabled || _locationDeniedForever
              ? 'Ajustes'
              : 'Permitir',
          color: Colors.orange.shade700,
          onAction: _handleLocationAction,
        ),
      );
    }

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < messages.length; i++) ...[
                messages[i],
                if (i != messages.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons(BuildContext context) {
    final isDriveMode = ref.watch(driveModeProvider);
    final followUser = ref.watch(followUserProvider);
    final filter = ref.watch(parkingFilterProvider);
    final mediaPadding = MediaQuery.of(context).padding.bottom;
    const driveModeOffset = 200.0;
    final bottomOffset = (isDriveMode ? driveModeOffset : 16.0) + mediaPadding;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      right: 16,
      bottom: bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'filterFab',
            tooltip: 'Filtros',
            backgroundColor:
                filter.isActive ? Theme.of(context).colorScheme.primary : null,
            onPressed: _showFilterSheet,
            child: Icon(
              filter.isActive ? Icons.filter_list : Icons.filter_list_outlined,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'refreshFab',
            tooltip: 'Actualizar plazas',
            onPressed: () => ref.refresh(parkingSpotsProvider),
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'cityCenterFab',
            tooltip: 'Centrar en Málaga',
            onPressed: _recenterToCity,
            child: const Icon(Icons.map),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'followFab',
            tooltip: followUser ? 'Dejar de seguirte' : 'Seguir tu posición',
            backgroundColor:
                followUser ? Theme.of(context).colorScheme.primary : null,
            onPressed: _toggleFollowUser,
            child: Icon(
              followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
          ),
          if (!isDriveMode) ...[
            const SizedBox(height: 12),
            FloatingActionButton.small(
              heroTag: 'driveModeFabShortcut',
              tooltip: 'Entrar en modo conducción',
              onPressed: _toggleDriveMode,
              child: const Icon(Icons.directions_car_filled),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotDetailsCard() {
    final isDriveMode = ref.watch(driveModeProvider);
    if (isDriveMode) {
      return const SizedBox.shrink();
    }

    final spot = ref.watch(selectedSpotProvider);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      left: 16,
      right: 16,
      bottom: spot != null ? 24 : -220,
      child: spot == null
          ? const SizedBox.shrink()
          : SpotDetailsCard(
              spot: spot,
              onClose: () =>
                  ref.read(selectedSpotProvider.notifier).state = null,
              onNavigate: () => _openNavigation(spot),
            ),
    );
  }

  Widget _buildDriveAssistCard() {
    final isDriveMode = ref.watch(driveModeProvider);
    if (!isDriveMode) {
      return const SizedBox.shrink();
    }

    final spot = ref.watch(selectedSpotProvider);
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        child: DriveAssistCard(
          spot: spot,
          onNavigate: spot == null ? null : () => _openNavigation(spot),
          onDismiss: spot == null
              ? null
              : () => ref.read(selectedSpotProvider.notifier).state = null,
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  Future<void> _showMapOptionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de mapas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('Descargar zona visible'),
                  subtitle: const Text(
                    'Guarda temporalmente los mosaicos actuales para usarlos sin conexión.',
                  ),
                  trailing: _isPrefetchingTiles
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_isPrefetchingTiles,
                  onTap: _isPrefetchingTiles
                      ? null
                      : () {
                          Navigator.pop(context);
                          _prefetchVisibleTiles();
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: const Text('Vaciar caché'),
                  subtitle: const Text(
                    'Elimina los mosaicos almacenados para liberar espacio.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _clearTileCache();
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Los mosaicos se conservan hasta 7 días y un máximo aproximado de 2.000 elementos.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _prefetchVisibleTiles() async {
    final bounds = _mapController.camera.visibleBounds;
    final int zoom = _mapController.camera.zoom.clamp(11, 18).round();
    final levels = <int>{zoom};
    if (zoom < 18) {
      levels.add(zoom + 1);
    }

    final uris = <Uri>{};
    for (final level in levels) {
      uris.addAll(_tileUrisForBounds(bounds, level));
    }

    if (uris.isEmpty) {
      return;
    }

    setState(() => _isPrefetchingTiles = true);
    try {
      await _tileProvider.warmUpTiles(uris);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se almacenaron ${uris.length} mosaicos en caché.',
          ),
        ),
      );
    } catch (e) {
      logger.e('Error prefetching tiles', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar la zona visible.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrefetchingTiles = false);
      }
    }
  }

  Future<void> _clearTileCache() async {
    await _tileProvider.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caché de mapas vaciada.')),
    );
  }

  Iterable<Uri> _tileUrisForBounds(LatLngBounds bounds, int zoom) sync* {
    final int minX = _lonToTile(bounds.west, zoom);
    final int maxX = _lonToTile(bounds.east, zoom);
    final int minY = _latToTile(bounds.north, zoom);
    final int maxY = _latToTile(bounds.south, zoom);

    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        yield Uri.parse('https://tile.openstreetmap.org/$zoom/$x/$y.png');
      }
    }
  }

  int _lonToTile(double lon, int zoom) {
    final int factor = 1 << zoom;
    final int x = (((lon + 180.0) / 360.0) * factor).floor();
    return x.clamp(0, factor - 1).toInt();
  }

  int _latToTile(double lat, int zoom) {
    final int factor = 1 << zoom;
    final double latRad = lat * math.pi / 180.0;
    final double n = math.log(math.tan(latRad) + 1 / math.cos(latRad));
    final double yDouble = (1 - n / math.pi) / 2 * factor;
    final int y = yDouble.floor();
    return y.clamp(0, factor - 1).toInt();
  }

  Future<void> _initLocationTracking() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      ref.read(userLocationProvider.notifier).state = current;
      setState(() {
        _locationError = null;
      });
      final isDriveMode = ref.read(driveModeProvider);
      final followUser = ref.read(followUserProvider);
      if (followUser) {
        _moveCamera(current, zoom: isDriveMode ? 17 : null);
      }
    } catch (e) {
      logger.e('Error getting current position', error: e);
      if (!mounted) return;
      setState(() {
        _locationError = 'No se pudo obtener tu ubicación actual.';
      });
    }

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        final current = LatLng(position.latitude, position.longitude);
        ref.read(userLocationProvider.notifier).state = current;
        setState(() {
          _locationError = null;
        });
        final followUser = ref.read(followUserProvider);
        final isDriveMode = ref.read(driveModeProvider);
        if (followUser) {
          _moveCamera(current, zoom: isDriveMode ? 17 : null);
        }
      },
      onError: (error) {
        logger.e('Error in position stream', error: error);
        if (!mounted) return;
        setState(() {
          _locationError = 'Perdimos la señal GPS.';
        });
      },
    );
  }

  Future<bool> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      setState(() {
        _locationServiceDisabled = true;
        _locationDeniedForever = false;
        _locationError = 'Activa el GPS para localizarte en el mapa.';
      });
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return false;
      setState(() {
        _locationServiceDisabled = false;
        _locationDeniedForever = false;
        _locationError =
            'Concede permiso de ubicación para seguir tu posición.';
      });
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      setState(() {
        _locationServiceDisabled = false;
        _locationDeniedForever = true;
        _locationError = 'Permite el acceso a la ubicación desde ajustes.';
      });
      return false;
    }

    if (!mounted) return true;
    setState(() {
      _locationServiceDisabled = false;
      _locationDeniedForever = false;
      _locationError = null;
    });
    return true;
  }

  void _handleMapEvent(MapEvent event) {
    if (_isProgrammaticMove) {
      final bool isProgrammaticSource =
          event.source == MapEventSource.mapController ||
              event.source == MapEventSource.fitCamera ||
              event.source == MapEventSource.custom;

      _isProgrammaticMove = false;

      if (isProgrammaticSource) {
        return;
      }
    }

    final followUser = ref.read(followUserProvider);
    if (!followUser) {
      return;
    }

    const userGestureSources = <MapEventSource>{
      MapEventSource.dragStart,
      MapEventSource.onDrag,
      MapEventSource.dragEnd,
      MapEventSource.multiFingerGestureStart,
      MapEventSource.onMultiFinger,
      MapEventSource.multiFingerEnd,
      MapEventSource.doubleTap,
      MapEventSource.doubleTapHold,
      MapEventSource.scrollWheel,
      MapEventSource.cursorKeyboardRotation,
    };

    if (userGestureSources.contains(event.source)) {
      ref.read(followUserProvider.notifier).state = false;
    }
  }

  void _handleLocationAction() {
    if (_locationServiceDisabled) {
      Geolocator.openLocationSettings();
    } else if (_locationDeniedForever) {
      Geolocator.openAppSettings();
    } else {
      _initLocationTracking();
    }
  }

  Future<void> _toggleFollowUser() async {
    final followUser = ref.read(followUserProvider);
    final userLocation = ref.read(userLocationProvider);
    if (!followUser && userLocation == null) {
      await _initLocationTracking();
      if (!mounted || ref.read(userLocationProvider) == null) {
        return;
      }
    }

    ref.read(followUserProvider.notifier).state = !followUser;

    if (!followUser && userLocation != null) {
      final isDriveMode = ref.read(driveModeProvider);
      _moveCamera(userLocation, zoom: isDriveMode ? 17 : null);
    }
  }

  Future<void> _toggleDriveMode() async {
    final isDriveMode = ref.read(driveModeProvider);
    final userLocation = ref.read(userLocationProvider);
    if (!isDriveMode && userLocation == null) {
      await _initLocationTracking();
      if (!mounted || ref.read(userLocationProvider) == null) {
        return;
      }
    }

    ref.read(driveModeProvider.notifier).state = !isDriveMode;
    if (!isDriveMode) {
      ref.read(followUserProvider.notifier).state = true;
    }

    if (!isDriveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (userLocation != null) {
        _moveCamera(userLocation, zoom: 17);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _recenterToCity() {
    ref.read(followUserProvider.notifier).state = false;
    ref.read(selectedSpotProvider.notifier).state = null;
    _mapController.move(_initialCenter, _initialZoom);
  }

  void _onMarkerTap(ParkingSpot spot) {
    ref.read(selectedSpotProvider.notifier).state = spot;
    _moveCamera(LatLng(spot.latitude, spot.longitude), zoom: 17);
  }

  void _moveCamera(LatLng target, {double? zoom}) {
    final double currentZoom = _mapController.camera.zoom;
    _isProgrammaticMove = true;
    _mapController.move(target, zoom ?? currentZoom);
  }

  Future<void> _openNavigation(ParkingSpot spot) async {
    final origin = ref.read(userLocationProvider);
    final query = <String, String>{
      'api': '1',
      'destination': '${spot.latitude},${spot.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };
    if (origin != null) {
      query['origin'] = '${origin.latitude},${origin.longitude}';
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', query);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la app de mapas.')),
      );
    }
  }

  double _markerExtent(double baseSize, int spotCount) {
    final double multiplier = spotCount > 1 ? 1.45 : 1.2;
    return baseSize * multiplier;
  }
}
