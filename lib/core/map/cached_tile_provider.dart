import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

class CachedNetworkTileProvider extends TileProvider {
  CachedNetworkTileProvider({
    CacheManager? cacheManager,
    this.maxAge = const Duration(days: 7),
    this.maxTiles = 2000,
  }) : _cacheManager =
           cacheManager ??
           CacheManager(
             Config(
               'mapTileCache',
               stalePeriod: maxAge,
               maxNrOfCacheObjects: maxTiles,
             ),
           );

  final CacheManager _cacheManager;
  final Duration maxAge;
  final int maxTiles;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImageProvider(
      cacheManager: _cacheManager,
      headers: headers,
      url: getTileUrl(coordinates, options),
    );
  }

  Future<void> warmUpTiles(Iterable<Uri> tileUris) async {
    for (final uri in tileUris) {
      await _cacheManager.getSingleFile(uri.toString(), headers: headers);
    }
  }

  Future<void> clear() => _cacheManager.emptyCache();

  @override
  void dispose() {
    _cacheManager.dispose().catchError((Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('Error al cerrar la caché de mapas: ');
        debugPrintStack(stackTrace: stack);
      }
    });
    super.dispose();
  }
}

class _CachedTileImageProvider extends ImageProvider<_CachedTileImageProvider> {
  const _CachedTileImageProvider({
    required this.cacheManager,
    required this.url,
    this.headers,
  });

  final CacheManager cacheManager;
  final String url;
  final Map<String, String>? headers;

  @override
  Future<_CachedTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture<_CachedTileImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTile(key, decode),
      scale: 1,
      debugLabel: url,
    );
  }

  Future<Codec> _loadTile(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final fileInfo = await cacheManager.getFileFromCache(url);
      final File file;
      if (fileInfo != null && fileInfo.validTill.isAfter(DateTime.now())) {
        file = fileInfo.file;
      } else {
        file = await cacheManager.getSingleFile(url, headers: headers);
      }

      final Uint8List bytes = await file.readAsBytes();
      final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('No se pudo cargar el tile : ');
        debugPrintStack(stackTrace: stackTrace);
      }
      final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(
        TileProvider.transparentImage,
      );
      return decode(buffer);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CachedTileImageProvider && other.url == url);

  @override
  int get hashCode => url.hashCode;
}
