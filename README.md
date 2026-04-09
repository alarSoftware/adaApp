# ADA App - Gestión Operatividad en Campo

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Version](https://img.shields.io/badge/version-3.0.0-green.svg?style=for-the-badge)

Una solución móvil robusta desarrollada con Flutter para la gestión integral de operaciones comerciales, censos y control de inventario en campo. Diseñada para trabajar en entornos críticos, garantizando la integridad de los datos incluso sin conexión.

## Características Principales

*   **Gestión de Operaciones**: Creación y seguimiento de notas de retiro y reposición. Nuevo flujo de acceso por App Route sin reposición para clientes específicos.
*   **Modo Offline**: Soporte completo mediante base de datos local SQLite.
*   **Sincronización Inteligente**: Comunicación bidireccional con el servidor/Odoo.
*   **Censos y Activos**: Módulo avanzado para la toma de censos y gestión de equipos en puntos de venta.
*   **Notificaciones**: Sistema de alertas y seguimiento en tiempo real.
*   **Información del Dispositivo**: Pantalla técnica con detalles del hardware y estado del celular.

## Stack Tecnológico

*   **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.8.1)
*   **Gestión de Estado**: [Provider](https://pub.dev/packages/provider)
*   **Base de Datos Local**: [sqflite](https://pub.dev/packages/sqflite)
*   **Networking**: [http](https://pub.dev/packages/http) y [stomp_dart_client](https://pub.dev/packages/stomp_dart_client) (WebSockets).
*   **Arquitectura**: MVVM (Model-View-ViewModel).

## Estructura del Proyecto

*   `lib/models/`: Definiciones de datos y lógica de serialización.
*   `lib/viewmodels/`: Lógica de negocio y manejo de estado de las pantallas.
*   `lib/ui/`: Componentes de interfaz de usuario, pantallas y widgets.
*   `lib/services/`: Capa de servicios (API, Auth, Sync, Notifications).
*   `lib/repositories/`: Capa de abstracción de datos entre servicios y viewmodels.
*   `lib/utils/`: Helpers, constantes y utilidades generales.

## Comenzando

### Requisitos
*   Flutter SDK >= 3.8.1
*   Dart SDK >= 3.x

### Instalación
1.  Clona el repositorio.
2.  Ejecuta `flutter pub get` para instalar las dependencias.
3.  Genera el código para modelos (si aplica): `dart run build_runner build`.
4.  Ejecuta la aplicación: `flutter run`.

## Historial de Versiones

### v3.0.0
- **Nuevas Funcionalidades**:
    - Implementación de acceso por App Route sin reposición orientado a clientes contados.
    - Nuevo módulo de notificaciones y gestión de mensajes en tiempo real.
    - Nueva pantalla de información detallada del celular/dispositivo.
- **Infraestructura**:
    - Cambio de URL Base para el entorno de producción.
- **Mejoras**:
    - Estabilización de los flujos de sincronización.

### v2.0.1
- Mejora en login con sincronización automática.
- Rediseño de card de descarga de formularios dinámicos.

### v2.0.0
- Versión estable inicial.

---
© 2026 - **ADA Development Team**