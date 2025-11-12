import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/producto_repository.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

/// Servicio de sincronización de productos
/// Formato del API: {"data": "[{...}]", "status": "OK"}
class ProductoSyncService extends BaseSyncService {

  // Variables estáticas para almacenar los últimos productos obtenidos
  static List<dynamic> _ultimosProductos = [];

  // Getter para acceder a los datos
  static List<dynamic> get ultimosProductosObtenidos => List.from(_ultimosProductos);

  /// Método principal para obtener productos desde el servidor
  static Future<SyncResult> obtenerProductos({
    int? categoriaId,
    String? estado,
    bool? activo,
    int? limit,
    int? offset,
    String? edfVendedorId,
    String? codigoBarras,
  }) async {
    String? currentEndpoint;

    try {
      BaseSyncService.logger.i('Obteniendo productos desde el servidor...');

      final queryParams = _buildQueryParams(
        categoriaId: categoriaId,
        estado: estado,
        activo: activo,
        limit: limit,
        offset: offset,
        edfVendedorId: edfVendedorId,
        codigoBarras: codigoBarras,
      );

      final response = await _makeHttpRequest(queryParams);
      currentEndpoint = response.request?.url.toString();
      BaseSyncService.logger.i('📡 Llamando a: $currentEndpoint');

      if (!_isSuccessStatusCode(response.statusCode)) {
        BaseSyncService.logger.e('❌ Error del servidor: ${response.statusCode}');

        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'productos',
          operation: 'sync_from_server',
          errorMessage: BaseSyncService.extractErrorMessage(response),
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
          userId: edfVendedorId,
        );

        return _handleErrorResponse(response);
      }

      final productosData = await _parseProductResponse(response);
      BaseSyncService.logger.i('✅ Productos parseados: ${productosData.length}');

      final processedResult = await _processAndSaveProducts(productosData);

      // Guardar los datos para acceso posterior
      _ultimosProductos = processedResult;

      return SyncResult(
        exito: true,
        mensaje: 'Productos sincronizados correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );

    } on TimeoutException catch (timeoutError) {
      BaseSyncService.logger.e('⏰ Timeout obteniendo productos: $timeoutError');

      await ErrorLogService.logNetworkError(
        tableName: 'productos',
        operation: 'sync_from_server',
        errorMessage: 'Timeout de conexión: $timeoutError',
        endpoint: currentEndpoint,
        userId: edfVendedorId,
      );

      _ultimosProductos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      BaseSyncService.logger.e('📡 Error de red: $socketError');

      await ErrorLogService.logNetworkError(
        tableName: 'productos',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión de red: $socketError',
        endpoint: currentEndpoint,
        userId: edfVendedorId,
      );

      _ultimosProductos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo productos: $e');

      await ErrorLogService.logError(
        tableName: 'productos',
        operation: 'sync_from_server',
        errorMessage: 'Error general: $e',
        errorType: 'unknown',
        errorCode: 'GENERAL_ERROR',
        endpoint: currentEndpoint,
        userId: edfVendedorId,
      );

      _ultimosProductos = [];
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // Métodos de conveniencia
  static Future<SyncResult> obtenerProductosActivos() {
    return obtenerProductos(activo: true);
  }

  static Future<SyncResult> obtenerProductosDeCategoria(int categoriaId) {
    return obtenerProductos(categoriaId: categoriaId);
  }

  static Future<SyncResult> buscarPorCodigoBarras(String codigoBarras) {
    return obtenerProductos(codigoBarras: codigoBarras);
  }

  // ========== MÉTODOS PRIVADOS ==========

  static Map<String, String> _buildQueryParams({
    int? categoriaId,
    String? estado,
    bool? activo,
    int? limit,
    int? offset,
    String? edfVendedorId,
    String? codigoBarras,
  }) {
    final Map<String, String> queryParams = {};

    if (edfVendedorId != null) queryParams['edfvendedorId'] = edfVendedorId;
    if (categoriaId != null) queryParams['categoriaId'] = categoriaId.toString();
    if (estado != null) queryParams['estado'] = estado;
    if (activo != null) queryParams['activo'] = activo.toString();
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (codigoBarras != null) queryParams['codigoBarras'] = codigoBarras;

    return queryParams;
  }

  static Future<http.Response> _makeHttpRequest(Map<String, String> queryParams) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/getProducto')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await http.get(
      uri,
      headers: BaseSyncService.headers,
    ).timeout(BaseSyncService.timeout);
  }

  static bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  static SyncResult _handleErrorResponse(http.Response response) {
    final mensaje = BaseSyncService.extractErrorMessage(response);
    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  static Future<List<dynamic>> _parseProductResponse(http.Response response) async {
    try {
      final responseBody = jsonDecode(response.body);

      if (responseBody is Map) {
        final responseMap = Map<String, dynamic>.from(responseBody);

        final status = responseMap['status'];
        if (status != 'OK') {
          return [];
        }

        final dataValue = responseMap['data'];
        if (dataValue == null) return [];

        if (dataValue is String) {
          try {
            final parsed = jsonDecode(dataValue) as List;
            return parsed;
          } catch (e) {
            BaseSyncService.logger.e('Error parseando data como JSON: $e');
            return [];
          }
        } else if (dataValue is List) {
          return dataValue;
        }

        return [];
      } else if (responseBody is List) {
        return responseBody;
      }

      return [];
    } catch (e) {
      BaseSyncService.logger.e('Error parseando respuesta: $e');
      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Procesar y guardar productos usando el repository
  static Future<List<Map<String, dynamic>>> _processAndSaveProducts(
      List<dynamic> productosData,
      ) async {
    if (productosData.isEmpty) return [];

    // Convertir datos del API al formato local
    final productosParaGuardar = <Map<String, dynamic>>[];

    for (final producto in productosData) {
      if (producto is Map) {
        try {
          final productoMap = Map<String, dynamic>.from(producto);
          final productoParaGuardar = _mapApiToLocalFormat(productoMap);
          productosParaGuardar.add(productoParaGuardar);
        } catch (e) {
          BaseSyncService.logger.e('Error procesando producto ID ${producto['id']}: $e');
        }
      }
    }

    // 🆕 Usar el repository para guardar
    if (productosParaGuardar.isNotEmpty) {
      try {
        final repo = ProductoRepositoryImpl();
        await repo.guardarProductosDesdeServidor(productosParaGuardar);
        BaseSyncService.logger.i('✅ ${productosParaGuardar.length} productos guardados vía repository');
      } catch (e) {
        BaseSyncService.logger.e('❌ Error guardando en repository: $e');

        // Log error pero no fallar, los datos se obtuvieron correctamente
        await ErrorLogService.logDatabaseError(
          tableName: 'productos',
          operation: 'guardar_via_repository',
          errorMessage: 'Error guardando productos via repository: $e',
        );
      }
    }

    return productosParaGuardar;
  }

  static Map<String, dynamic> _mapApiToLocalFormat(Map<String, dynamic> apiProduct) {
    return {
      'id': apiProduct['id']?.toString(),
      'codigo': apiProduct['codigo']?.toString() ?? '',
      'nombre': apiProduct['nombre']?.toString() ?? '',
      'categoria': apiProduct['categoria']?.toString(),
      'codigo_barras': apiProduct['codigoBarras']?.toString(),
    };
  }

  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}