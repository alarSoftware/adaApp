import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/producto_repository.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class ProductoSyncService extends BaseSyncService {
  static List<dynamic> _ultimosProductos = [];

  static List<dynamic> get ultimosProductosObtenidos =>
      List.from(_ultimosProductos);

  static Future<SyncResult> obtenerProductos({
    int? categoriaId,
    String? estado,
    bool? activo,
    int? limit,
    int? offset,
    String? employeeId,
    String? codigoBarras,
  }) async {
    String? currentEndpoint;

    try {
      final queryParams = _buildQueryParams(
        categoriaId: categoriaId,
        estado: estado,
        activo: activo,
        limit: limit,
        offset: offset,
        employeeId: employeeId,
        codigoBarras: codigoBarras,
      );

      final response = await _makeHttpRequest(queryParams);
      currentEndpoint = response.request?.url.toString();

      if (!_isSuccessStatusCode(response.statusCode)) {
        return _handleErrorResponse(response);
      }

      // Usar Isolate para procesar la respuesta JSON
      final processedResult = await _procesarProductosEnIsolate(response.body);

      // Guardar en BD (esto se hace en el hilo principal por sqflite)
      // Guardar en BD (esto se hace en el hilo principal por sqflite)
      if (processedResult.isNotEmpty) {
        try {
          final repo = ProductoRepositoryImpl();
          await repo.guardarProductosDesdeServidor(processedResult);
        } catch (e) {
          await ErrorLogService.logDatabaseError(
            tableName: 'productos',
            operation: 'guardar_via_repository',
            errorMessage: 'Error guardando productos via repository: $e',
          );
        }
      } else {
        // CORRECCIÓN: Si la lista procesada está vacía, limpiar la tabla local
        try {
          final repo = ProductoRepositoryImpl();
          await repo.limpiarProductosLocales();
        } catch (e) {
          print('Error limpiando productos locales: $e');
        }
      }

      _ultimosProductos = processedResult;

      return SyncResult(
        exito: true,
        mensaje: 'Productos sincronizados correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );
    } on TimeoutException catch (timeoutError) {
      _ultimosProductos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      _ultimosProductos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
      _ultimosProductos = [];
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerProductosActivos() {
    return obtenerProductos(activo: true);
  }

  static Future<SyncResult> obtenerProductosDeCategoria(int categoriaId) {
    return obtenerProductos(categoriaId: categoriaId);
  }

  static Future<SyncResult> buscarPorCodigoBarras(String codigoBarras) {
    return obtenerProductos(codigoBarras: codigoBarras);
  }

  static Map<String, String> _buildQueryParams({
    int? categoriaId,
    String? estado,
    bool? activo,
    int? limit,
    int? offset,
    String? employeeId,
    String? codigoBarras,
  }) {
    final Map<String, String> queryParams = {};

    if (employeeId != null) queryParams['employeeId'] = employeeId;
    if (categoriaId != null)
      queryParams['categoriaId'] = categoriaId.toString();
    if (estado != null) queryParams['estado'] = estado;
    if (activo != null) queryParams['activo'] = activo.toString();
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (codigoBarras != null) queryParams['codigoBarras'] = codigoBarras;

    return queryParams;
  }

  static Future<http.Response> _makeHttpRequest(
    Map<String, String> queryParams,
  ) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse(
      '$baseUrl/api/getProducto',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await http
        .get(uri, headers: BaseSyncService.headers)
        .timeout(BaseSyncService.timeout);
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

  static Map<String, dynamic> _mapApiToLocalFormat(
    Map<String, dynamic> apiProduct,
  ) {
    return {
      'id': _parseIntSafely(apiProduct['id']),
      'codigo': apiProduct['codigo']?.toString(),
      'nombre': apiProduct['nombre']?.toString() ?? '',
      'categoria': apiProduct['categoria']?.toString(),
      'codigo_barras': apiProduct['codigoBarras']?.toString(),
      'unidad_medida': apiProduct['unidadMedida']?.toString(),
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

  static Future<List<Map<String, dynamic>>> _procesarProductosEnIsolate(
    String responseBody,
  ) async {
    return await Isolate.run(() => _parseAndMapProducts(responseBody));
  }

  static List<Map<String, dynamic>> _parseAndMapProducts(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      List<dynamic> productosData = [];

      if (decoded is Map) {
        final responseMap = Map<String, dynamic>.from(decoded);
        if (responseMap['status'] != 'OK') return [];

        final dataValue = responseMap['data'];
        if (dataValue == null) return [];

        if (dataValue is String) {
          try {
            productosData = jsonDecode(dataValue) as List;
          } catch (e) {
            return [];
          }
        } else if (dataValue is List) {
          productosData = dataValue;
        }
      } else if (decoded is List) {
        productosData = decoded;
      }

      final productosParaGuardar = <Map<String, dynamic>>[];

      for (final producto in productosData) {
        if (producto is Map) {
          try {
            final productoMap = Map<String, dynamic>.from(producto);
            final productoParaGuardar = _mapApiToLocalFormat(productoMap);
            productosParaGuardar.add(productoParaGuardar);
          } catch (e) {
            // Error procesando producto individual
          }
        }
      }

      return productosParaGuardar;
    } catch (e) {
      return [];
    }
  }
}
