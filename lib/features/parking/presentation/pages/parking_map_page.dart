import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/datasources/parking_local_data_source.dart';
import '../../data/datasources/parking_remote_data_source.dart';
import '../../data/repositories/parking_repository_impl.dart';
import '../../domain/entities/parking_spot.dart';
import '../../../../core/map/cached_tile_provider.dart';
import '../controllers/parking_map_controller.dart';

class ParkingMapPage extends StatefulWidget {
  const ParkingMapPage({super.key});

  @override
  State<ParkingMapPage> createState() => _ParkingMapPageState();
}

class _ParkingMapPageState extends State<ParkingMapPage> {
  static const _initialCenter = LatLng(36.7213, -4.4217);
  static const _initialZoom = 13.0;
  static const _markerSize = 16.0;
  static const _markerSelectedSize = 20.0;
  static const _markerDriveScale = 1.5;

  late final MapController _mapController;
  late final ParkingRemoteDataSource _remoteDataSource;
  late final ParkingRepositoryImpl _repository;
  late final ParkingMapController _controller;
  late final CachedNetworkTileProvider _tileProvider;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<MapEvent>? _mapEventSubscription;
  LatLng? _userLocation;
  String? _locationError;
  bool _locationServiceDisabled = false;
  bool _locationDeniedForever = false;
  bool _followUser = true;
  bool _isDriveMode = true;
  bool _isPrefetchingTiles = false;
  bool _isProgrammaticMove = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapEventSubscription =
        _mapController.mapEventStream.listen(_handleMapEvent);
    _remoteDataSource = ParkingRemoteDataSource();
    _repository = ParkingRepositoryImpl(
      remoteDataSource: _remoteDataSource,
      localDataSource: ParkingLocalDataSource(),
    );
    _controller = ParkingMapController(repository: _repository)..loadSpots();
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
    _controller.dispose();
    _tileProvider.dispose();
    _remoteDataSource.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDriveMode ? Colors.black : null,
      appBar: _isDriveMode
          ? null
          : AppBar(
              title: const Text('Plazas PMR en Málaga'),
              actions: [
                IconButton(
                  tooltip: 'Opciones de mapa',
                  icon: const Icon(Icons.layers_outlined),
                  onPressed: () => _showMapOptionsSheet(),
                ),
              ],
            ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.spots.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              _buildMap(context),
              _buildTopMessages(),
              _buildFloatingButtons(context),
              _buildSpotDetailsCard(),
              _buildDriveAssistCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final spots = _controller.spots;
    final Color background = _isDriveMode ? Colors.black : Colors.white;

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
        onTap: (_, __) => _controller.selectSpot(null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.aparcamalaga',
        ),
        MarkerLayer(
          markers: spots.map((spot) {
            final bool isSelected =
                spot.id == _controller.selectedSpot?.id;
            final double baseSize =
                isSelected ? _markerSelectedSize : _markerSize;
            final double size =
                _isDriveMode ? baseSize * _markerDriveScale : baseSize;
            final double markerExtent =
                _markerExtent(size, spot.spotCount);

            return Marker(
              point: LatLng(spot.latitude, spot.longitude),
              width: markerExtent,
              height: markerExtent,
              alignment: Alignment.center,
              child: _ParkingMarker(
                spot: spot,
                isSelected: isSelected,
                onTap: () => _onMarkerTap(spot),
                size: size,
              ),
            );
          }).toList(),
        ),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 22,
                height: 22,
                alignment: Alignment.center,
                child: _UserLocationMarker(
                  isFollowing: _followUser,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopMessages() {
    final List<Widget> messages = [];

    if (_isDriveMode) {
      messages.add(
        _DriveModeBanner(
          onExit: _toggleDriveMode,
          followingEnabled: _followUser,
        ),
      );
    }

    if (_controller.errorMessage != null) {
      messages.add(
        _ErrorBanner(
          message: _controller.errorMessage!,
          onRetry: () => _controller.loadSpots(forceRefresh: true),
        ),
      );
    }

    if (_locationError != null) {
      messages.add(
        _InfoBanner(
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
    final mediaPadding = MediaQuery.of(context).padding.bottom;
    const driveModeOffset = 200.0;
    final bottomOffset = (_isDriveMode ? driveModeOffset : 16.0) + mediaPadding;

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
            heroTag: 'refreshFab',
            tooltip: 'Actualizar plazas',
            onPressed: () => _controller.loadSpots(forceRefresh: true),
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
            tooltip: _followUser
                ? 'Dejar de seguirte'
                : 'Seguir tu posición',
            backgroundColor: _followUser
                ? Theme.of(context).colorScheme.primary
                : null,
            onPressed: _toggleFollowUser,
            child: Icon(
              _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
          ),
          if (!_isDriveMode) ...[
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
    if (_isDriveMode) {
      return const SizedBox.shrink();
    }

    final spot = _controller.selectedSpot;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      left: 16,
      right: 16,
      bottom: spot != null ? 24 : -220,
      child: spot == null
          ? const SizedBox.shrink()
          : _SpotDetailsCard(
              spot: spot,
              onClose: () => _controller.selectSpot(null),
              onNavigate: () => _openNavigation(spot),
            ),
    );
  }

  Widget _buildDriveAssistCard() {
    if (!_isDriveMode) {
      return const SizedBox.shrink();
    }

    final spot = _controller.selectedSpot;
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        child: _DriveAssistCard(
          spot: spot,
          onNavigate: spot == null ? null : () => _openNavigation(spot),
          onDismiss: spot == null ? null : () => _controller.selectSpot(null),
        ),
      ),
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
    } catch (_) {
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
      setState(() {
        _userLocation = current;
      });
      if (_followUser && _userLocation != null) {
        _moveCamera(current, zoom: _isDriveMode ? 17 : null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'No se pudo obtener tu ubicación actual.';
      });
    }

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) {
            if (!mounted) return;
            final current = LatLng(position.latitude, position.longitude);
            setState(() {
              _userLocation = current;
              _locationError = null;
            });
            if (_followUser) {
              _moveCamera(current, zoom: _isDriveMode ? 17 : null);
            }
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _locationError = 'Perdimos la se\u00f1al GPS.';
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

    if (!_followUser) {
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
      setState(() {
        _followUser = false;
      });
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
    if (!_followUser && _userLocation == null) {
      await _initLocationTracking();
      if (!mounted || _userLocation == null) {
        return;
      }
    }

    setState(() {
      _followUser = !_followUser;
    });

    if (_followUser && _userLocation != null) {
      _moveCamera(_userLocation!, zoom: _isDriveMode ? 17 : null);
    }
  }

  Future<void> _toggleDriveMode() async {
    if (!_isDriveMode && _userLocation == null) {
      await _initLocationTracking();
      if (!mounted || _userLocation == null) {
        return;
      }
    }

    setState(() {
      _isDriveMode = !_isDriveMode;
      if (_isDriveMode) {
        _followUser = true;
      }
    });

    if (_isDriveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (_userLocation != null) {
        _moveCamera(_userLocation!, zoom: 17);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _recenterToCity() {
    setState(() {
      _followUser = false;
    });
    _controller.selectSpot(null);
    _mapController.move(_initialCenter, _initialZoom);
  }

  void _onMarkerTap(ParkingSpot spot) {
    _controller.selectSpot(spot);
    _moveCamera(LatLng(spot.latitude, spot.longitude), zoom: 17);
  }

  void _moveCamera(LatLng target, {double? zoom}) {
    final double currentZoom = _mapController.camera.zoom;
    _isProgrammaticMove = true;
    _mapController.move(target, zoom ?? currentZoom);
  }

  Future<void> _openNavigation(ParkingSpot spot) async {
    final origin = _userLocation;
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
}

double _markerExtent(double baseSize, int spotCount) {
  final double multiplier = spotCount > 1 ? 1.45 : 1.2;
  return baseSize * multiplier;
}

class _ParkingMarker extends StatelessWidget {
  const _ParkingMarker({
    required this.spot,
    required this.isSelected,
    required this.onTap,
    required this.size,
  });

  final ParkingSpot spot;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleSpots = spot.spotCount > 1;
    final double extent = _markerExtent(size, spot.spotCount);
    final IconData iconData = spot.hasAccessibleAccess
        ? Icons.accessible_forward
        : Icons.local_parking;
    final List<Color> gradientColors = isSelected
        ? const [Color(0xFF0D47A1), Color(0xFF00A6FB)]
        : const [Color(0xFF0277BD), Color(0xFF29B6F6)];
    final double iconSize = (size * 0.75).clamp(10, 22).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: extent,
        height: extent,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
                border: Border.all(
                  color: Colors.white,
                  width: size * (isSelected ? 0.16 : 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isSelected ? 0.35 : 0.25,
                    ),
                    blurRadius: isSelected ? 14 : 9,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
            if (hasMultipleSpots)
              Positioned(
                right: -size * 0.2,
                bottom: -size * 0.2,
                child: _MarkerBadge(
                  count: spot.spotCount,
                  emphasize: isSelected,
                  parentSize: size,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarkerBadge extends StatelessWidget {
  const _MarkerBadge({
    required this.count,
    required this.emphasize,
    required this.parentSize,
  });

  final int count;
  final bool emphasize;
  final double parentSize;

  @override
  Widget build(BuildContext context) {
    final double fontSize = (parentSize * 0.32).clamp(10, 16).toDouble();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: parentSize * 0.2,
        vertical: parentSize * 0.12,
      ),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFD54F) : Colors.white,
        borderRadius: BorderRadius.circular(parentSize),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: emphasize ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          color: emphasize ? const Color(0xFF3E2723) : Colors.black87,
        ),
      ),
    );
  }
}
class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker({required this.isFollowing});

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

class _SpotDetailsCard extends StatelessWidget {
  const _SpotDetailsCard({
    required this.spot,
    required this.onClose,
    required this.onNavigate,
  });

  final ParkingSpot spot;
  final VoidCallback onClose;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    spot.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text(spot.address, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_seat, size: 18),
                const SizedBox(width: 4),
                Text('Plazas: '),
                const SizedBox(width: 16),
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    spot.ownership ?? 'Titularidad no especificada',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (spot.hasAccessibleAccess) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.accessible_forward, size: 18),
                  SizedBox(width: 4),
                  Text('Acceso adaptado'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation),
                label: const Text('Iniciar ruta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveModeBanner extends StatelessWidget {
  const _DriveModeBanner({
    required this.onExit,
    required this.followingEnabled,
  });

  final VoidCallback onExit;
  final bool followingEnabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102542),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Modo conducci\u00f3n activo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    followingEnabled
                        ? 'El mapa te seguirá automáticamente.'
                        : 'Activa el seguimiento para centrarte en tu ruta.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onExit,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveAssistCard extends StatelessWidget {
  const _DriveAssistCard({required this.spot, this.onNavigate, this.onDismiss});

  final ParkingSpot? spot;
  final VoidCallback? onNavigate;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ParkingSpot? currentSpot = spot;
    final bool hasSpot = currentSpot != null;
    final String titleText =
        currentSpot?.name ?? 'Mantén la vista en la carretera';
    final String subtitleText =
        currentSpot?.address ??
        'Usa el modo conducci\u00f3n para recibir avisos rápidos y centrar el mapa en tu posición.';

    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titleText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasSpot && onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (hasSpot && onNavigate != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Iniciar ruta'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.onAction,
    required this.color,
    required this.actionLabel,
  });

  final String message;
  final VoidCallback onAction;
  final Color color;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.red.shade700,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
