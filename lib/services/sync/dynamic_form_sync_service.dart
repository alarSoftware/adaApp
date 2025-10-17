import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/dynamic_form_repository.dart';

class DynamicFormSyncService extends BaseSyncService {

  /// Obtener todos los formularios dinámicos
  static Future<SyncResult> obtenerFormulariosDinamicos({
    String? estado,
    int? limit,
    int? offset,
  }) async {
    try {
      BaseSyncService.logger.i('📋 Obteniendo formularios dinámicos desde el servidor...');

      final Map<String, String> queryParams = {};

      if (estado != null) queryParams['estado'] = estado;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final baseUrl = await BaseSyncService.getBaseUrl();

      // 1. OBTENER FORMULARIOS
      final uri = Uri.parse('$baseUrl/api/getDynamicForm')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta getDynamicForm: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> formulariosData = [];

        try {
          final responseBody = jsonDecode(response.body);

          if (responseBody is Map && responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];

            if (dataValue is String) {
              formulariosData = jsonDecode(dataValue) as List;
            } else if (dataValue is List) {
              formulariosData = dataValue;
            }
          } else if (responseBody is List) {
            formulariosData = responseBody;
          }
        } catch (e) {
          BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Formularios parseados: ${formulariosData.length}');

        // GUARDAR FORMULARIOS EN BD LOCAL
        if (formulariosData.isNotEmpty) {
          try {
            final repo = DynamicFormRepository();
            final formulariosComoMap = formulariosData.map((e) => e as Map<String, dynamic>).toList();
            final guardados = await repo.guardarFormulariosDesdeServidor(formulariosComoMap);
            BaseSyncService.logger.i('💾 Formularios guardados en BD local: $guardados');

            // 2. AHORA OBTENER Y GUARDAR LOS DETALLES
            BaseSyncService.logger.i('📋 Obteniendo detalles de formularios...');

            final uriDetalles = Uri.parse('$baseUrl/api/getDynamicFormDetail');

            final responseDetalles = await http.get(
              uriDetalles,
              headers: BaseSyncService.headers,
            ).timeout(BaseSyncService.timeout);

            BaseSyncService.logger.i('📥 Respuesta getDynamicFormDetail: ${responseDetalles.statusCode}');

            if (responseDetalles.statusCode >= 200 && responseDetalles.statusCode < 300) {
              List<dynamic> detallesData = [];

              try {
                final responseBodyDetalles = jsonDecode(responseDetalles.body);

                if (responseBodyDetalles is Map && responseBodyDetalles.containsKey('data')) {
                  final dataValue = responseBodyDetalles['data'];

                  if (dataValue is String) {
                    detallesData = jsonDecode(dataValue) as List;
                  } else if (dataValue is List) {
                    detallesData = dataValue;
                  }
                } else if (responseBodyDetalles is List) {
                  detallesData = responseBodyDetalles;
                }
              } catch (e) {
                BaseSyncService.logger.e('❌ Error parseando detalles: $e');
              }

              BaseSyncService.logger.i('✅ Detalles parseados: ${detallesData.length}');

              // GUARDAR DETALLES EN BD LOCAL
              if (detallesData.isNotEmpty) {
                final detallesComoMap = detallesData.map((e) => e as Map<String, dynamic>).toList();
                final detallesGuardados = await repo.guardarTodosLosDetallesDesdeServidor(detallesComoMap);
                BaseSyncService.logger.i('💾 Detalles guardados en BD local: $detallesGuardados');
              }
            }

            return SyncResult(
              exito: true,
              mensaje: 'Formularios y detalles obtenidos correctamente',
              itemsSincronizados: guardados,
              totalEnAPI: formulariosData.length,
            );
          } catch (e) {
            BaseSyncService.logger.e('❌ Error guardando en BD local: $e');
            return SyncResult(
              exito: false,
              mensaje: 'Error guardando formularios: $e',
              itemsSincronizados: 0,
            );
          }
        } else {
          BaseSyncService.logger.w('⚠️ No se encontraron formularios en la respuesta');
          return SyncResult(
            exito: true,
            mensaje: 'No hay formularios disponibles',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo formularios: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }



  /// Obtener formulario específico por ID
  static Future<SyncResult> obtenerFormularioPorId(int formId) async {
    try {
      BaseSyncService.logger.i('📋 Obteniendo formulario ID: $formId');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final response = await http.get(
        Uri.parse('$baseUrl/api/getFormularios/$formId'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        Map<String, dynamic> formData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            formData = responseData['data'];
          } else {
            formData = responseData;
          }
        } else {
          throw 'Formato de respuesta inesperado';
        }

        // Guardar en BD
        final repo = DynamicFormRepository();
        await repo.guardarFormulariosDesdeServidor([formData]);

        BaseSyncService.logger.i('✅ Formulario obtenido: ID ${formData['id']}');

        return SyncResult(
          exito: true,
          mensaje: 'Formulario obtenido correctamente',
          itemsSincronizados: 1,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Formulario no encontrado: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('❌ Error obteniendo formulario por ID: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener detalles de un formulario específico
  static Future<SyncResult> obtenerDetallesFormulario(String formId) async {
    try {
      BaseSyncService.logger.i('📋 Obteniendo detalles del formulario ID: $formId');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final uri = Uri.parse('$baseUrl/api/getDynamicFormDetail')
          .replace(queryParameters: {'dynamicFormId': formId});

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta getDynamicFormDetail: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> detallesData = [];

        try {
          final responseBody = jsonDecode(response.body);

          if (responseBody is Map && responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];

            if (dataValue is String) {
              detallesData = jsonDecode(dataValue) as List;
            } else if (dataValue is List) {
              detallesData = dataValue;
            }
          } else if (responseBody is List) {
            detallesData = responseBody;
          }
        } catch (e) {
          BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Detalles parseados: ${detallesData.length}');

        // GUARDAR EN BASE DE DATOS LOCAL
        if (detallesData.isNotEmpty) {
          try {
            final repo = DynamicFormRepository();
            final detallesComoMap = detallesData.map((e) => e as Map<String, dynamic>).toList();
            final guardados = await repo.guardarDetallesDesdeServidor(detallesComoMap, formId);
            BaseSyncService.logger.i('💾 Detalles guardados en BD local: $guardados');

            return SyncResult(
              exito: true,
              mensaje: 'Detalles obtenidos correctamente',
              itemsSincronizados: guardados,
              totalEnAPI: detallesData.length,
            );
          } catch (e) {
            BaseSyncService.logger.e('❌ Error guardando en BD local: $e');
            return SyncResult(
              exito: false,
              mensaje: 'Error guardando detalles: $e',
              itemsSincronizados: 0,
            );
          }
        } else {
          BaseSyncService.logger.w('⚠️ No se encontraron detalles en la respuesta');
          return SyncResult(
            exito: true,
            mensaje: 'No hay detalles disponibles',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo detalles: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Sincronizar todos los detalles de todos los formularios
  static Future<SyncResult> sincronizarTodosLosDetalles() async {
    try {
      BaseSyncService.logger.i('📋 Sincronizando todos los detalles de formularios...');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final uri = Uri.parse('$baseUrl/api/getDynamicFormDetail');

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> detallesData = [];

        try {
          final responseBody = jsonDecode(response.body);

          if (responseBody is Map && responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];

            if (dataValue is String) {
              detallesData = jsonDecode(dataValue) as List;
            } else if (dataValue is List) {
              detallesData = dataValue;
            }
          } else if (responseBody is List) {
            detallesData = responseBody;
          }
        } catch (e) {
          BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Detalles parseados: ${detallesData.length}');

        if (detallesData.isNotEmpty) {
          try {
            final repo = DynamicFormRepository();
            final detallesComoMap = detallesData.map((e) => e as Map<String, dynamic>).toList();

            // Guardar todos los detalles (sin filtrar por formId)
            final guardados = await repo.guardarTodosLosDetallesDesdeServidor(detallesComoMap);
            BaseSyncService.logger.i('💾 Detalles guardados en BD local: $guardados');

            return SyncResult(
              exito: true,
              mensaje: 'Detalles sincronizados correctamente',
              itemsSincronizados: guardados,
              totalEnAPI: detallesData.length,
            );
          } catch (e) {
            BaseSyncService.logger.e('❌ Error guardando en BD local: $e');
            return SyncResult(
              exito: false,
              mensaje: 'Error guardando detalles: $e',
              itemsSincronizados: 0,
            );
          }
        } else {
          return SyncResult(
            exito: true,
            mensaje: 'No hay detalles disponibles',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error sincronizando detalles: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener respuestas de formularios dinámicos desde el servidor
  static Future<SyncResult> obtenerRespuestasFormularios({
    String? contactoId,
    String? dynamicFormId,
    String? estado,
    String? edfvendedorId,
  }) async {
    try {
      BaseSyncService.logger.i('📥 Obteniendo respuestas de formularios desde el servidor...');

      final Map<String, String> queryParams = {};

      if (contactoId != null) queryParams['contactoId'] = contactoId;
      if (dynamicFormId != null) queryParams['dynamicFormId'] = dynamicFormId;
      if (estado != null) queryParams['estado'] = estado;
      if (edfvendedorId != null) queryParams['edfvendedorId'] = edfvendedorId;

      final baseUrl = await BaseSyncService.getBaseUrl();

      final uri = Uri.parse('$baseUrl/api/getDynamicFormResponse')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta getDynamicFormResponse: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> responsesData = [];

        try {
          final responseBody = jsonDecode(response.body);

          if (responseBody is Map && responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];

            if (dataValue is String) {
              responsesData = jsonDecode(dataValue) as List;
            } else if (dataValue is List) {
              responsesData = dataValue;
            }
          } else if (responseBody is List) {
            responsesData = responseBody;
          }
        } catch (e) {
          BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Respuestas parseadas: ${responsesData.length}');

        // GUARDAR RESPUESTAS EN BD LOCAL
        if (responsesData.isNotEmpty) {
          try {
            final repo = DynamicFormRepository();
            final responsesComoMap = responsesData.map((e) => e as Map<String, dynamic>).toList();
            final guardados = await repo.guardarRespuestasDesdeServidor(responsesComoMap);
            BaseSyncService.logger.i('💾 Respuestas guardadas en BD local: $guardados');

            return SyncResult(
              exito: true,
              mensaje: 'Respuestas descargadas correctamente',
              itemsSincronizados: guardados,
              totalEnAPI: responsesData.length,
            );
          } catch (e) {
            BaseSyncService.logger.e('❌ Error guardando en BD local: $e');
            return SyncResult(
              exito: false,
              mensaje: 'Error guardando respuestas: $e',
              itemsSincronizados: 0,
            );
          }
        } else {
          BaseSyncService.logger.w('⚠️ No se encontraron respuestas en la respuesta');
          return SyncResult(
            exito: true,
            mensaje: 'No hay respuestas disponibles',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo respuestas: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Método de conveniencia para obtener respuestas por vendedor
  static Future<SyncResult> obtenerRespuestasPorVendedor(String edfvendedorId) {
    return obtenerRespuestasFormularios(edfvendedorId: edfvendedorId);
  }

  /// Obtener todas las respuestas completadas
  static Future<SyncResult> obtenerRespuestasCompletadas({String? edfvendedorId}) {
    return obtenerRespuestasFormularios(
      edfvendedorId: edfvendedorId,
      estado: 'completed',
    );
  }

  /// Métodos simples de acceso
  static Future<SyncResult> obtenerFormulariosActivos() {
    return obtenerFormulariosDinamicos(estado: 'ACTIVO');
  }

  static Future<SyncResult> obtenerFormulariosBorrador() {
    return obtenerFormulariosDinamicos(estado: 'BORRADOR');
  }
}