# ada_app

Una aplicación móvil desarrollada con Flutter para la gestión integral de operaciones comerciales, censos y control de inventario en campo.

## Características Principales

- **Gestión de Operaciones Comerciales**: Creación y seguimiento de notas de retiro, reposición y retiro de productos discontinuos.
- **Modo Offline**: Soporte completo para trabajar sin conexión a internet mediante base de datos local (SQLite).
- **Sincronización Inteligente**: Sincronización automática y manual de datos con el servidor/Odoo.
- **Censos y Activos**: Módulo para la toma de censos y gestión de equipos/activos en puntos de venta.
- **Formularios Dinámicos**: Capacidad para renderizar y completar formularios configurables desde el servidor.
- **Geolocalización**: Registro de ubicación en cada operación realizada.
- **Escaneo de Código de Barras**: Integración con cámara para la búsqueda rápida de productos.
- **Notificaciones en tiempo real**: Sistema de alertas locales y notificaciones de estado de sincronización.

## Stack Tecnológico

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.8.1)
- **Gestión de Estado**: [Provider](https://pub.dev/packages/provider)
- **Base de Datos Local**: [sqflite](https://pub.dev/packages/sqflite)
- **Networking**: [http](https://pub.dev/packages/http) y [stomp_dart_client](https://pub.dev/packages/stomp_dart_client) (WebSockets).
- **Arquitectura**: MVVM (Model-View-ViewModel).

## Estructura del Proyecto

- `lib/models/`: Definiciones de datos y lógica de serialización.
- `lib/viewmodels/`: Lógica de negocio y manejo de estado de las pantallas.
- `lib/ui/`: Componentes de interfaz de usuario, pantallas y widgets.
- `lib/services/`: Capa de servicios (API, Auth, Local Storage, Sync).
- `lib/repositories/`: Capa de abstracción de datos entre servicios y viewmodels.
- `lib/utils/`: Helpers, constantes y utilidades generales.

## Comenzando

### Requisitos
- Flutter SDK >= 3.8.1
- Dart SDK >= 3.x

### Instalación
1. Clona el repositorio.
2. Ejecuta `flutter pub get` para instalar las dependencias.
3. Genera el código para modelos (si aplica): `dart run build_runner build`.
4. Ejecuta la aplicación: `flutter run`.

## Historial de Versiones
## Unrealesed
- **v2.0.1**: Mejora en login con sincronización automática y rediseño de card de descarga de formularios dinámicos.

## Released
- **v2.0.0**: Versión estable inicial.

---
© 2026 - ada_app