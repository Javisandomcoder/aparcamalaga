import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app.dart';
import '../../domain/models/parking_mode.dart';

class ParkingModeSelectorPage extends StatefulWidget {
  const ParkingModeSelectorPage({super.key});

  @override
  State<ParkingModeSelectorPage> createState() => _ParkingModeSelectorPageState();
}

class _ParkingModeSelectorPageState extends State<ParkingModeSelectorPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation1 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation2 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Solicitar permisos de ubicación al iniciar la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermissions();
    });
  }

  Future<void> _requestLocationPermissions() async {
    // Verificar si el servicio de ubicación está habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // No solicitar permisos si el servicio no está habilitado
    }

    // Verificar el estado actual del permiso
    var permission = await Geolocator.checkPermission();

    // Solo solicitar si está en 'denied' (no solicitado aún)
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToMap(ParkingModeConfig config) {
    context.go('/parking-map', extra: config);
  }

  void _showAddressSearchDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar dirección'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Introduce una dirección...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              // Capitalizar cada palabra
              final text = newValue.text;
              if (text.isEmpty) return newValue;

              final words = text.split(' ');
              final capitalizedWords = words.map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }).join(' ');

              return TextEditingValue(
                text: capitalizedWords,
                selection: newValue.selection,
              );
            }),
          ],
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop();
              _navigateToMap(ParkingModeConfig(
                mode: ParkingMode.searchAddress,
                searchAddress: value.trim(),
              ));
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _navigateToMap(ParkingModeConfig(
                  mode: ParkingMode.searchAddress,
                  searchAddress: textController.text.trim(),
                ));
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Botón de tema en la esquina superior derecha
              Positioned(
                top: 16,
                right: 16,
                child: _ThemeSwitcher(),
              ),
              // Contenido principal
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  // Logo/Header
                  Icon(
                    Icons.local_parking,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AparcaMálaga',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Encuentra aparcamientos de movilidad reducida',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // Opción 1: Buscar dirección
                  SlideTransition(
                    position: _slideAnimation1,
                    child: _ModeOptionCard(
                      icon: Icons.search_rounded,
                      title: 'Buscar dirección',
                      description: 'Encuentra aparcamientos en una ubicación específica',
                      color: theme.colorScheme.primary,
                      onTap: _showAddressSearchDialog,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Opción 2: Cerca de mí
                  SlideTransition(
                    position: _slideAnimation2,
                    child: _ModeOptionCard(
                      icon: Icons.my_location_rounded,
                      title: 'Cerca de mí',
                      description: 'Busca aparcamientos en tu ubicación actual',
                      color: theme.colorScheme.secondary,
                      onTap: () => _navigateToMap(
                        const ParkingModeConfig(mode: ParkingMode.nearMe),
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Theme.of(context).brightness == Brightness.dark
            ? Icons.light_mode
            : Icons.dark_mode,
      ),
      onPressed: () {
        final provider = ThemeModeProvider.of(context);
        if (provider != null) {
          final currentMode = provider.themeMode;
          final newMode = currentMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          provider.onThemeModeChanged(newMode);
        }
      },
      tooltip: Theme.of(context).brightness == Brightness.dark
          ? 'Modo claro'
          : 'Modo oscuro',
    );
  }
}

class _ModeOptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeOptionCard> createState() => _ModeOptionCardState();
}

class _ModeOptionCardState extends State<_ModeOptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        elevation: 4,
        shadowColor: widget.color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () {
            _scaleController.reverse().then((_) {
              _scaleController.forward();
              widget.onTap();
            });
          },
          onTapDown: (_) => _scaleController.reverse(),
          onTapUp: (_) => _scaleController.forward(),
          onTapCancel: () => _scaleController.forward(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withValues(alpha: 0.1),
                  widget.color.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 32,
                    color: widget.color,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
