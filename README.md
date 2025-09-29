# PMR Málaga

Aplicación Flutter para encontrar y consultar plazas PMR en la ciudad de Málaga. Permite visualizar las plazas accesibles sobre un mapa, seguir la posición del usuario mientras conduce y obtener indicaciones de navegación hacia cada plaza.

## Características principales

- **Mapa interactivo** con marcadores diferenciados y contador de plazas por ubicación.
- **Modo conducción** que centra el mapa automáticamente, muestra avisos rápidos y habilita un panel asistente.
- **Seguimiento de ubicación** con control manual para dejar de seguir cuando se mueve el mapa de forma manual.
- **Cacheo de mosaicos** para uso offline temporal y limpieza desde la UI.
- **Integración con Google Maps** para iniciar la ruta de navegación a una plaza seleccionada.
- Icono y branding propios (`PMR Málaga`) coherentes en Android, iOS, Web, macOS y Windows.

## Requisitos

- Flutter 3.9.2 o superior
- Dart 3.9.2 o superior
- SDKs/plataformas configuradas para los despliegues deseados (Android, iOS, Web, Escritorio)

## Configuración inicial

1. Clonar el repositorio y entrar al directorio del proyecto.
2. Instalar dependencias:
   ```bash
   flutter pub get
   ```
3. (Opcional) Regenerar iconos si se modifica la imagen base:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

## Ejecución

- Android/iOS:
  ```bash
  flutter run
  ```
- Web:
  ```bash
  flutter run -d chrome
  ```
- Escritorio (ejemplo Windows):
  ```bash
  flutter run -d windows
  ```

Durante el modo conducción, el mapa se vuelve oscuro, se oculta la app bar y se muestra una tarjeta asistente; cualquier gesto manual sobre el mapa desactiva temporalmente el seguimiento hasta que se pulse de nuevo el botón de centrado.

## Estructura destacada

- `lib/features/parking/` – Lógica de dominio, datos y presentación del módulo de aparcamientos.
- `lib/app/app.dart` – Punto de arranque de la interfaz Material.
- `assets/icons/` – Recursos base para los iconos multiplataforma.
- `web/icons/` / `android/app/src/main/res/` / `ios/Runner/Assets.xcassets/` – Iconos generados automáticamente.

## Licencia

Este proyecto se publica para uso interno. Consulta con el responsable del repositorio antes de redistribuirlo o publicarlo.
