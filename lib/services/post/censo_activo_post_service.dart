import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

import '../../config/constants/server_response.dart';
import '../censo/censo_upload_service.dart';

class CensoActivoPostService {
  static final Logger _logger = Logger();
  static const String _tableName = 'censo_activo';
  static const String _endpoint = '/censoActivo/insertCensoActivo';
  static const Uuid _uuid = Uuid();

  static Future<void> enviarCensoActivo({
    String? censoId,
    String? equipoId,
    String? codigoBarras,
    int? marcaId,
    int? modeloId,
    int? logoId,
    String? numeroSerie,
    bool esNuevoEquipo = false,
    required int clienteId,
    required String edfVendedorId,
    bool crearPendiente = false,
    dynamic pendienteExistente,
    required int usuarioId,
    required double latitud,
    required double longitud,
    String? observaciones,
    bool enLocal = true,
    String? estadoCenso = 'pendiente',
    List<dynamic>? fotos,
    String? clienteNombre,
    String? marca,
    String? modelo,
    String? logo,
    int timeoutSegundos = 60,
    bool guardarLog = false,
    var equipoDataMap
  }) async {
    String? fullUrl;

    try {
      _logger.i('📤 === ENVIANDO CENSO UNIFICADO ===');

      // Usar censoId de BD o generar uno nuevo si no se proporciona
      final now = DateTime.now().toLocal();
      final censoIdFinal = censoId ?? now.millisecondsSinceEpoch.toString();

      if (censoId != null) {
        _logger.i('✅ Usando censo ID de BD: $censoIdFinal');
      } else {
        _logger.w('⚠️ No se proporcionó censoId, generando nuevo: $censoIdFinal');
      }

      final equipoIdFinal = equipoId ?? codigoBarras ?? 'EQUIPO_${censoIdFinal}';

      _logger.i('🔧 Preparando payload unificado...');
      _logger.i('   - Censo ID: $censoIdFinal');
      _logger.i('   - Equipo ID: $equipoIdFinal');
      _logger.i('   - Cliente ID: $clienteId');
      _logger.i('   - Es nuevo equipo: $esNuevoEquipo');
      _logger.i('   - Crear pendiente: $crearPendiente');

      // Construir el JSON unificado
      final payloadUnificado = _construirPayloadUnificado(
        // Equipo
        equipoId: equipoIdFinal,
        codigoBarras: codigoBarras ?? equipoIdFinal,
        marcaId: marcaId,
        modeloId: modeloId,
        logoId: logoId,
        numeroSerie: numeroSerie,
        esNuevoEquipo: esNuevoEquipo,

        // Pendiente
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
        crearPendiente: crearPendiente,
        pendienteExistente: pendienteExistente,

        // Censo
        censoId: censoIdFinal,
        usuarioId: usuarioId,
        latitud: latitud,
        longitud: longitud,
        observaciones: observaciones,
        enLocal: enLocal,
        estadoCenso: estadoCenso,
        fotos: fotos,
        clienteNombre: clienteNombre,
        marca: marca,
        modelo: modelo,
        logo: logo,
        now: now,
          equipoDataMap:equipoDataMap
      );

      _logger.i('📦 Payload size: ${jsonEncode(payloadUnificado).length} caracteres');

      // Envío HTTP
      final baseUrl = await ApiConfigService.getBaseUrl();
      fullUrl = '$baseUrl$_endpoint';

      _logger.i('🌐 Enviando a: $fullUrl');

      // 🔥 GUARDAR LOG TXT (si está habilitado)
      if (guardarLog) {
        await _guardarLogSimple(
          url: fullUrl,
          payload: payloadUnificado,
          timestamp: now.toIso8601String(),
        );
      }

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(payloadUnificado),
      ).timeout(Duration(seconds: timeoutSegundos));

      _logger.i('📥 Response: ${response.statusCode}');

      // Procesar respuesta con validación estricta

      ServerResponse resultObject = ServerResponse.fromHttp(response);

      // 1. Validación de seguridad para evitar saltos inesperados
      if (censoId == null) throw Exception("censoId es nulo");

      if (!resultObject.success) {
        // CASO ERROR: Si NO es duplicado y tiene mensaje -> Marcar error y lanzar excepción
        if (!resultObject.isDuplicate && resultObject.message != '') {
          final estadoEquipoRepository = EstadoEquipoRepository();
          await estadoEquipoRepository.marcarComoError(censoId, resultObject.message);
          throw Exception(resultObject.message);
        }
        // CASO DUPLICADO: Si el servidor dice que ya existe, lo marcamos como éxito localmente
        else if (resultObject.isDuplicate) {
          _logger.w('⚠️ Registro duplicado en servidor, marcando como sincronizado localmente.');
          final censoUploadService = CensoUploadService();
          final fotosSeguras = fotos ?? [];

          await censoUploadService.marcarComoSincronizadoCompleto(
            censoId: censoId,
            equipoId: equipoId,
            clienteId: clienteId,
            esNuevoEquipo: esNuevoEquipo,
            crearPendiente: crearPendiente,
            fotos: fotosSeguras,
          );
        }
      } else {
        // CASO ÉXITO (success == true)
        final censoUploadService = CensoUploadService();
        final fotosSeguras = fotos ?? []; // Evita crash si fotos es null

        await censoUploadService.marcarComoSincronizadoCompleto(
          censoId: censoId,
          equipoId: equipoId,
          clienteId: clienteId,
          esNuevoEquipo: esNuevoEquipo,
          crearPendiente: crearPendiente,
          fotos: fotosSeguras,
        );
      }

    } catch (e, stackTrace) {
      // Aquí puedes descomentar tu manejo de excepciones si lo deseas,
      // pero 'rethrow' está bien para que el servicio de arriba se entere.
      rethrow;
    }
  }

  // =================================================================
  // 🔥 MANEJO UNIFICADO DE ERRORES (sin duplicación)
  // =================================================================

  /// Maneja errores del servidor (serverAction != 100)
  // static Future<void> _manejarErrorServidor(
  //     Map<String, dynamic> result,
  //     String? censoId,
  //     String? fullUrl,
  //     String? userId,
  //     ) async {
  //   final errorCode = result['serverAction']?.toString() ?? 'UNKNOWN';
  //   final errorMessage = result['mensaje'] ?? 'Error del servidor';
  //
  //   // Determinar tipo de error según serverAction
  //   String tipoError;
  //   String codigoError;
  //
  //   if (result['serverAction'] == ServerConstants.STOP_TRANSACTION) {
  //     tipoError = 'business_logic';
  //     codigoError = 'STOP_TRANSACTION_205';
  //   } else if (result['serverAction'] == ServerConstants.ERROR) {
  //     tipoError = 'server_error';
  //     codigoError = 'SERVER_ERROR_-501';
  //   } else {
  //     tipoError = 'server_response';
  //     codigoError = 'UNEXPECTED_ACTION_$errorCode';
  //   }
  //
  //   // 🔥 REGISTRO AUTOMÁTICO POR TIPO
  //   await ErrorLogService.logServerError(
  //     tableName: _tableName,
  //     operation: 'POST_CENSO_ACTIVO_SERVER_ERROR',
  //     errorMessage: 'ServerAction $errorCode: $errorMessage',
  //     errorCode: codigoError,
  //     registroFailId: censoId,
  //     endpoint: fullUrl,
  //     userId: userId,
  //   );
  //
  //   _logger.e('🚫 Error del servidor registrado: $codigoError');
  // }

  /// Maneja todas las excepciones de red/timeout/crash de forma unificada
  // static Future<Map<String, dynamic>> _manejarExcepcion(
  //     dynamic excepcion,
  //     String? censoId,
  //     String? fullUrl,
  //     String? userId,
  //     int timeoutSegundos,
  //     ) async {
  //
  //   String tipoError;
  //   String codigoError;
  //   String mensajeUsuario;
  //   String mensajeDetallado;
  //
  //   // 🎯 CLASIFICAR EXCEPCIÓN AUTOMÁTICAMENTE
  //   if (excepcion is SocketException) {
  //     tipoError = 'network';
  //     codigoError = 'NETWORK_CONNECTION_ERROR';
  //     mensajeUsuario = 'Sin conexión de red';
  //     mensajeDetallado = 'Error de conexión de red: ${excepcion.message}';
  //
  //   } else if (excepcion is TimeoutException) {
  //     tipoError = 'network';
  //     codigoError = 'REQUEST_TIMEOUT_ERROR';
  //     mensajeUsuario = 'Tiempo de espera agotado';
  //     mensajeDetallado = 'Timeout tras ${timeoutSegundos}s: $excepcion';
  //
  //   } else if (excepcion is http.ClientException) {
  //     tipoError = 'network';
  //     codigoError = 'HTTP_CLIENT_ERROR';
  //     mensajeUsuario = 'Error de red: ${excepcion.message}';
  //     mensajeDetallado = 'Error HTTP del cliente: ${excepcion.message}';
  //
  //   } else {
  //     tipoError = 'crash';
  //     codigoError = 'UNEXPECTED_EXCEPTION';
  //     mensajeUsuario = 'Error interno: $excepcion';
  //     mensajeDetallado = 'Excepción no manejada: $excepcion';
  //   }
  //
  //   // 🔥 REGISTRO AUTOMÁTICO UNIFICADO
  //   await ErrorLogService.logError(
  //     tableName: _tableName,
  //     operation: 'POST_CENSO_ACTIVO_EXCEPTION',
  //     errorMessage: mensajeDetallado,
  //     errorType: tipoError,
  //     errorCode: codigoError,
  //     registroFailId: censoId,
  //     endpoint: fullUrl,
  //     userId: userId,
  //   );
  //
  //   _logger.e('🚨 Excepción registrada: $codigoError');
  //
  //   // 🎯 RESPUESTA UNIFICADA DE ERROR
  //   return _errorResponse(mensajeUsuario);
  // }

  // =================================================================
  // LOGGING TXT SIMPLE (estilo CensoLogService original)
  // =================================================================

  /// Guarda un log simple estilo CensoLogService original
  static Future<void> _guardarLogSimple({
    required String url,
    required Map<String, dynamic> payload,
    required String timestamp,
  }) async {
    try {
      _logger.i('═══════════════════════════════════════════════════════');
      _logger.i('🔍 DEBUG LOG: INICIO DE GUARDADO');
      _logger.i('═══════════════════════════════════════════════════════');

      final file = await _obtenerArchivoLog();

      if (file == null) {
        _logger.e('❌ DEBUG LOG: file = NULL (no se pudo obtener archivo)');
        _logger.e('❌ Revisar método _obtenerArchivoLog()');
        return;
      }

      _logger.i('✅ DEBUG LOG: Archivo obtenido');
      _logger.i('📍 Ruta completa: ${file.path}');
      _logger.i('📂 Directorio padre: ${file.parent.path}');
      _logger.i('📂 ¿Directorio existe?: ${await file.parent.exists()}');

      final contenido = _generarContenidoLogSimple(
        url: url,
        payload: payload,
        timestamp: timestamp,
        filePath: file.path,
      );


      await file.writeAsString(contenido);

    } catch (e, stackTrace) {
    }
  }

  /// Genera el contenido del log simple
  static String _generarContenidoLogSimple({
    required String url,
    required Map<String, dynamic> payload,
    required String timestamp,
    required String filePath,
  }) {
    final buffer = StringBuffer();
    final separador = '=' * 80;
    final divisor = '-' * 40;

    // Encabezado
    buffer.writeln(separador);
    buffer.writeln('CENSO ACTIVO - POST REQUEST LOG');
    buffer.writeln(separador);
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('URL: $url');
    buffer.writeln('Archivo: $filePath');
    buffer.writeln('');

    // Headers
    buffer.writeln(divisor);
    buffer.writeln('HEADERS:');
    buffer.writeln(divisor);
    buffer.writeln('Content-Type: application/json');
    buffer.writeln('Accept: application/json');
    buffer.writeln('ngrok-skip-browser-warning: true');
    buffer.writeln('');

    // Resumen del censo
    buffer.writeln(divisor);
    buffer.writeln('RESUMEN DEL CENSO:');
    buffer.writeln(divisor);
    _agregarResumenSimple(buffer, payload);
    buffer.writeln('');

    // JSON completo
    buffer.writeln(divisor);
    buffer.writeln('REQUEST BODY (JSON):');
    buffer.writeln(divisor);
    _agregarBodyJson(buffer, payload);
    buffer.writeln('');

    // Pie
    buffer.writeln(separador);
    buffer.writeln('FIN DEL LOG - ${DateTime.now().toLocal()}');
    buffer.writeln(separador);

    return buffer.toString();
  }

  /// Agrega resumen simple estilo CensoLogService
  static void _agregarResumenSimple(
      StringBuffer buffer,
      Map<String, dynamic> payload,
      ) {
    // 🔥 CASTING SEGURO con Map<String, dynamic>.from()
    final censo = payload['censo_activo'] != null
        ? Map<String, dynamic>.from(payload['censo_activo'] as Map)
        : null;
    final equipo = payload['equipo'] != null
        ? Map<String, dynamic>.from(payload['equipo'] as Map)
        : null;
    final pendiente = payload['equipo_pendiente'] != null
        ? Map<String, dynamic>.from(payload['equipo_pendiente'] as Map)
        : null;

    // Info básica del censo (SIEMPRE presente)
    if (censo != null && censo.isNotEmpty) {
      buffer.writeln('Equipo ID: ${censo['edfEquipoId'] ?? 'N/A'}');
      buffer.writeln('Cliente ID: ${censo['edfClienteId'] ?? 'N/A'}');
      buffer.writeln('Usuario ID: ${censo['usuarioId'] ?? 'N/A'}');
      buffer.writeln('Latitud: ${censo['latitud'] ?? 'N/A'}');
      buffer.writeln('Longitud: ${censo['longitud'] ?? 'N/A'}');
    }

    // Estado de secciones
    final equipoCompleto = equipo != null && equipo.isNotEmpty;
    final pendienteCompleto = pendiente != null && pendiente.isNotEmpty;

    buffer.writeln('Sección equipo: ${equipoCompleto ? 'COMPLETA (nuevo equipo)' : 'VACÍA (equipo existente)'}');
    buffer.writeln('Sección equipo_pendiente: ${pendienteCompleto ? 'COMPLETA (crear asignación)' : 'VACÍA (ya asignado)'}');

    // 🔥 MOSTRAR UUID DEL PENDIENTE
    if (pendienteCompleto && pendiente != null) {
      buffer.writeln('UUID Pendiente (BD): ${pendiente['uuid'] ?? 'NO DISPONIBLE'}');
    }

    buffer.writeln('Sección censo_activo: COMPLETA (siempre)');

    // Info de fotos (del censo_activo)
    if (censo != null && censo.isNotEmpty) {
      final fotosArray = censo['fotos'] as List<dynamic>?;
      final totalFotos = fotosArray?.length ?? 0;
      final tieneImagen1 = censo['tieneImagen'] == true;
      final tieneImagen2 = censo['tieneImagen2'] == true;

      buffer.writeln('Tiene imagen 1: $tieneImagen1');
      buffer.writeln('Tiene imagen 2: $tieneImagen2');
      buffer.writeln('Total fotos: $totalFotos');

      // Tamaños de imágenes base64
      if (censo['imageBase64_1'] != null) {
        final tamano1 = censo['imageBase64_1'].toString().length;
        buffer.writeln('Tamaño imagen 1: ${(tamano1 / 1024).toStringAsFixed(1)} KB');
      }
      if (censo['imageBase64_2'] != null) {
        final tamano2 = censo['imageBase64_2'].toString().length;
        buffer.writeln('Tamaño imagen 2: ${(tamano2 / 1024).toStringAsFixed(1)} KB');
      }

      buffer.writeln('Observaciones: ${censo['observaciones'] ?? 'N/A'}');
      buffer.writeln('Estado censo: ${censo['estadoCenso'] ?? 'N/A'}');
      buffer.writeln('Fecha revisión: ${censo['fechaRevision'] ?? 'N/A'}');
    }
  }

  /// Agrega el JSON completo sin mostrar base64 completo
  static void _agregarBodyJson(
      StringBuffer buffer,
      Map<String, dynamic> payload,
      ) {
    // Crear versión simplificada para el log
    final payloadSimplificado = Map<String, dynamic>.from(payload);

    // Simplificar censo_activo si tiene fotos pesadas
    if (payloadSimplificado.containsKey('censo_activo')) {
      final censo = Map<String, dynamic>.from(payloadSimplificado['censo_activo']);

      // Reemplazar base64 por resumen
      if (censo.containsKey('imageBase64_1')) {
        final tamano1 = censo['imageBase64_1']?.toString().length ?? 0;
        censo['imageBase64_1'] = '[BASE64 - ${(tamano1 / 1024).toStringAsFixed(1)} KB]';
      }
      if (censo.containsKey('imageBase64_2')) {
        final tamano2 = censo['imageBase64_2']?.toString().length ?? 0;
        censo['imageBase64_2'] = '[BASE64 - ${(tamano2 / 1024).toStringAsFixed(1)} KB]';
      }

      // Simplificar array de fotos
      if (censo.containsKey('fotos') && censo['fotos'] is List) {
        final fotosCount = (censo['fotos'] as List).length;
        censo['fotos'] = '[${fotosCount} fotos - contenido omitido del log]';
      }

      payloadSimplificado['censo_activo'] = censo;
    }

    final prettyJson = JsonEncoder.withIndent('  ').convert(payloadSimplificado);
    buffer.writeln(prettyJson);
  }

  /// Obtiene el archivo para guardar el log
  static Future<File?> _obtenerArchivoLog() async {
    try {
      _logger.i('🔍 DEBUG: Obteniendo directorio de descargas...');

      final downloadsDir = await _obtenerDirectorioDescargas();

      if (downloadsDir == null) {
        _logger.e('❌ DEBUG: downloadsDir = NULL');
        return null;
      }

      _logger.i('✅ DEBUG: Directorio obtenido: ${downloadsDir.path}');

      if (!await downloadsDir.exists()) {
        _logger.w('⚠️ DEBUG: Directorio no existe, intentando crear...');
        await downloadsDir.create(recursive: true);
        _logger.i('✅ DEBUG: Directorio creado');
      } else {
        _logger.i('✅ DEBUG: Directorio ya existe');
      }

      final now = DateTime.now();
      final fechaFormateada = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}_'
          '${now.second.toString().padLeft(2, '0')}';

      final fileName = 'censo_activo_post_$fechaFormateada.txt';
      final filePath = '${downloadsDir.path}/$fileName';

      _logger.i('✅ DEBUG: Nombre del archivo: $fileName');
      _logger.i('✅ DEBUG: Ruta completa: $filePath');

      return File(filePath);
    } catch (e, stackTrace) {
      _logger.e('❌ DEBUG: Error en _obtenerArchivoLog: $e');
      _logger.e('StackTrace: $stackTrace');
      return null;
    }
  }

  /// Obtiene el directorio de descargas
  static Future<Directory?> _obtenerDirectorioDescargas() async {
    try {
      _logger.i('🔍 DEBUG: Detectando plataforma...');

      if (Platform.isAndroid) {
        _logger.i('✅ DEBUG: Plataforma = Android');

        var downloadsDir = Directory('/storage/emulated/0/Download');
        _logger.i('🔍 DEBUG: Intentando ruta: ${downloadsDir.path}');

        if (!await downloadsDir.exists()) {
          _logger.w('⚠️ DEBUG: Ruta principal no existe, buscando alternativa...');

          final externalDir = await getExternalStorageDirectory();
          _logger.i('🔍 DEBUG: ExternalStorageDirectory: ${externalDir?.path}');

          downloadsDir = Directory('${externalDir?.path}/Download');
          _logger.i('🔍 DEBUG: Usando ruta alternativa: ${downloadsDir.path}');
        } else {
          _logger.i('✅ DEBUG: Ruta principal existe');
        }

        return downloadsDir;
      } else if (Platform.isIOS) {
        _logger.i('✅ DEBUG: Plataforma = iOS');
        final appDocDir = await getApplicationDocumentsDirectory();
        _logger.i('✅ DEBUG: App Documents Directory: ${appDocDir.path}');
        return appDocDir;
      }

      _logger.w('⚠️ DEBUG: Plataforma no soportada');
      return null;
    } catch (e, stackTrace) {
      _logger.e('❌ DEBUG: Error obteniendo directorio: $e');
      _logger.e('StackTrace: $stackTrace');
      return null;
    }
  }

  // =================================================================
  // CONSTRUCCIÓN DEL PAYLOAD CON 3 SECCIONES
  // =================================================================

  /// Construye el payload unificado con las 3 secciones SIEMPRE (vacías si no aplican)
  static Map<String, dynamic> _construirPayloadUnificado({
    // Equipo
    required String equipoId,
    required String codigoBarras,
    int? marcaId,
    int? modeloId,
    int? logoId,
    String? numeroSerie,
    required bool esNuevoEquipo,

    // Pendiente
    required int clienteId,
    required String edfVendedorId,
    required bool crearPendiente,
    dynamic pendienteExistente,

    // Censo
    required String censoId,
    required int usuarioId,
    required double latitud,
    required double longitud,
    String? observaciones,
    required bool enLocal,
    String? estadoCenso,
    List<dynamic>? fotos,
    String? clienteNombre,
    String? marca,
    String? modelo,
    String? logo,
    required DateTime now,
    var equipoDataMap
  }) {
    // 🔥 SIEMPRE LAS 3 SECCIONES (vacías si no aplican)
    final Map<String, dynamic> payload = {};

    // ═══════════════════════════════════════════════════════════════
    // SECCIÓN EQUIPO (llena si es nuevo equipo, vacía si no)
    // ═══════════════════════════════════════════════════════════════
    if (esNuevoEquipo && marcaId != null && modeloId != null && logoId != null) {
      payload['equipo'] = _construirJsonEquipo(equipoDataMap);
      _logger.i('✅ JSON Equipo agregado (nuevo equipo)');
    } else {
      payload['equipo'] = {}; // 🔥 VACÍO si no es nuevo equipo
      _logger.i('📭 JSON Equipo vacío (equipo existente)');
    }

    // ═══════════════════════════════════════════════════════════════
    // SECCIÓN EQUIPO_PENDIENTE (llena si necesita pendiente, vacía si no)
    // ═══════════════════════════════════════════════════════════════
    if (pendienteExistente != null && (pendienteExistente is List && pendienteExistente.isNotEmpty)) {
      payload['equipo_pendiente'] = _construirJsonEquipoPendiente(pendienteExistente);
      _logger.i('✅ JSON Equipo_Pendiente agregado (crear asignación)');
    } else {
      payload['equipo_pendiente'] = {};
      _logger.i('📭 JSON Equipo_Pendiente vacío (ya asignado)');
    }
    // ═══════════════════════════════════════════════════════════════
    // SECCIÓN CENSO_ACTIVO (SIEMPRE con datos completos)
    // ═══════════════════════════════════════════════════════════════
    payload['censo_activo'] = _construirJsonCensoActivo(
      censoId: censoId,
      equipoId: equipoId,
      clienteId: clienteId,
      usuarioId: usuarioId,
      edfVendedorId: edfVendedorId,
      latitud: latitud,
      longitud: longitud,
      observaciones: observaciones,
      enLocal: enLocal,
      estadoCenso: estadoCenso ?? 'pendiente',
      fotos: fotos,
      codigoBarras: codigoBarras,
      numeroSerie: numeroSerie,
      marca: marca,
      modelo: modelo,
      logo: logo,
      clienteNombre: clienteNombre,
      now: now,
      esNuevoEquipo: esNuevoEquipo,
    );

    _logger.i('✅ JSON Censo_Activo agregado (SIEMPRE completo)');

    return payload;
  }

  /// Construye el JSON del equipo (SOLO camelCase)
  static Map<String, dynamic> _construirJsonEquipo(var equipoDataMap) {
// required String equipoId,
// required String codigoBarras,
// required int marcaId,
// required int modeloId,
// required int logoId,
// String? numeroSerie,
    final now = DateTime.now().toIso8601String();
    var id              = equipoDataMap['id'];
    var edfEquipoId     = equipoDataMap['cod_barras'];
    var codigoBarras    = equipoDataMap['cod_barras'];
    var modeloId     = equipoDataMap['modelo_id'];
    var marcaId         = equipoDataMap['marca_id'];
    var logoId          = equipoDataMap['logo_id'];
    var numeroSerie     = equipoDataMap['numero_serie'];
    var fechaCreacion   = equipoDataMap['fecha_creacion'];
    var appInsert       = equipoDataMap['app_insert'];

    return {
      'id': id,
      'edfEquipoId': edfEquipoId,
      'codigoBarras': codigoBarras,
      'edfModeloId': modeloId,
      'marcaId': marcaId.toString(),
      'logoId': logoId.toString(),
      'serie': numeroSerie ?? '',
      'fechaCreacion': now,
    };
  }

  /// 🔥 Construye el JSON del equipo pendiente CON UUID DE BD
  static Map<String, dynamic> _construirJsonEquipoPendiente(dynamic pendienteExistenteList) {
    var pendienteExistente = pendienteExistenteList[0];
    String id            = pendienteExistente['id'];
    var edfVendedorId = pendienteExistente['edf_vendedor_id'];
    var equipoId      = pendienteExistente['equipo_id'];
    var codigoBarras  = pendienteExistente['codigo_barras'];
    var clienteId     = pendienteExistente['cliente_id'];
    var numeroSerie   = pendienteExistente['numero_serie'];
    var estado        = pendienteExistente['estado'];
    var marcaId       = pendienteExistente['marca_id'];
    var modeloId      = pendienteExistente['modelo_id'];
    var logoId        = pendienteExistente['logo_id'];
    final partes = edfVendedorId.split('_');
    final vendedorIdValue = partes.isNotEmpty ? partes[0] : edfVendedorId;
    int? sucursalIdValue;
    if (partes.length > 1) {
      sucursalIdValue = int.tryParse(partes[1]);
    }
    // ✅ MAPEO COMPLETO SEGÚN TU BACKEND GROOVY
    final Map<String, dynamic> pendiente = {
      'edfEquipoId': equipoId,
      'edfCodigoBarras': codigoBarras,
      'edfClienteId': clienteId.toString(),
      'id': id,
      'estado': estado,
      'edfVendedorSucursalId': edfVendedorId,
      'edfVendedorId': vendedorIdValue,
      'edfSerie': numeroSerie,
      'edfMarcaId': marcaId?.toString(),
      'edfModeloId': modeloId,
      'edfLogoId': logoId,
    };

    if (sucursalIdValue != null) {
      pendiente['edfSucursalId'] = sucursalIdValue;
    }

    return pendiente;
  }

  /// Construye el JSON del censo activo (SOLO camelCase)
  static Map<String, dynamic> _construirJsonCensoActivo({
    required String censoId,
    required String equipoId,
    required int clienteId,
    required int usuarioId,
    required String edfVendedorId,
    required double latitud,
    required double longitud,
    String? observaciones,
    required bool enLocal,
    required String estadoCenso,
    List<dynamic>? fotos,
    String? codigoBarras,
    String? numeroSerie,
    String? marca,
    String? modelo,
    String? logo,
    String? clienteNombre,
    required DateTime now,
    required bool esNuevoEquipo,
  }) {
    String formatearFechaLocal(DateTime fecha) {
      final local = fecha.toLocal();
      return local.toIso8601String().replaceAll('Z', '');
    }

    final censo = {
      'id': censoId,
      'edfVendedorSucursalId': edfVendedorId,
      'edfEquipoId': equipoId,
      'usuarioId': usuarioId,
      'edfClienteId': clienteId,
      'fechaRevision': formatearFechaLocal(now),
      'latitud': latitud,
      'longitud': longitud,
      'enLocal': enLocal,
      'fechaDeRevision': formatearFechaLocal(now),
      'estadoCenso': estadoCenso,
      'esNuevoEquipo': esNuevoEquipo,

      // Información del equipo
      'equipoCodigoBarras': codigoBarras,
      'equipoNumeroSerie': numeroSerie ?? '',
      'equipoModelo': modelo ?? '',
      'equipoMarca': marca ?? '',
      'equipoLogo': logo ?? '',
      'equipoId': equipoId,

      // Información del cliente
      'clienteNombre': clienteNombre ?? '',
      'clienteId': clienteId,

      // Usuario y observaciones
      'usuarioId': usuarioId,
      'observaciones': observaciones ?? '',
      'estadoGeneral': observaciones ?? 'Registro desde APP móvil',

      // Metadata
      'enLocal': enLocal,
      'dispositivo': 'android',
      'esCenso': true,
      'versionApp': '1.0.0',
    };

    // Agregar fotos si existen
    if (fotos != null && fotos.isNotEmpty) {
      censo['fotos'] = fotos;
      censo['totalImagenes'] = fotos.length;

      // Compatibilidad con formato anterior
      for (int i = 0; i < fotos.length && i < 2; i++) {
        final foto = fotos[i];
        if (foto is Map<String, dynamic>) {
          if (i == 0) {
            censo['imageBase64_1'] = foto['base64'];
            censo['tieneImagen'] = true;
          } else if (i == 1) {
            censo['imageBase64_2'] = foto['base64'];
            censo['tieneImagen2'] = true;
          }
        }
      }
    } else {
      censo['fotos'] = [];
      censo['totalImagenes'] = 0;
      censo['tieneImagen'] = false;
      censo['tieneImagen2'] = false;
    }

    return censo;
  }

  /// Procesar respuesta con validación estricta usando ServerConstants
  static Map<String, dynamic> _procesarRespuesta(http.Response response) {
    //ServerResponse.fromHttp(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error del servidor: ${response.statusCode}',
        'status_code': response.statusCode,
      };
    }

    try {
      final responseBody = json.decode(response.body);
      if (responseBody is Map && responseBody.containsKey('serverAction')) {
        final serverAction = responseBody['serverAction'] as int?;

        if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
          _logger.i('✅ Censo activo procesado correctamente (Action 100)');
          return {
            'exito': true,
            'success': true,
            'mensaje': responseBody['resultMessage'] ??
                'Censo activo procesado correctamente',
            'serverAction': serverAction,
            'servidor_id': responseBody['resultId'],
            'id': responseBody['resultId'],
          };
        } else if (serverAction == ServerConstants.ERROR) {
          return {
            'exito': false,
            'success': false,
            'mensaje': responseBody['resultError'],
            'serverAction': serverAction,
          };
        } else {
          _logger.e('❌ Servidor rechazó censo activo (Action: $serverAction)');
          return {
            'exito': false,
            'success': false,
            'mensaje': responseBody['resultError'] ??
                responseBody['resultMessage'] ?? 'Error del servidor',
            'serverAction': serverAction,
          };
        }
      }

      // Fallback para respuestas sin serverAction
      _logger.w('⚠️ Respuesta sin serverAction, asumiendo éxito');
      return {
        'exito': true,
        'success': true,
        'mensaje': 'Censo activo procesado (sin serverAction)',
        'id': responseBody['id'],
      };



    } catch (e) {
      _logger.w('⚠️ Error parseando JSON: $e');
      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error en formato de respuesta',
      };
    }
  }

  static Map<String, dynamic> _errorResponse(String message) {
    return {
      'exito': false,
      'success': false,
      'mensaje': message,
      'error': message,
    };
  }

  // =================================================================
  // MÉTODO PARA COMPATIBILIDAD CON CÓDIGO EXISTENTE
  // =================================================================

  /// Método de compatibilidad para enviar solo cambio de estado (sin equipo/pendiente)
  /// Usado por EquiposClienteDetailScreenViewModel
  // static Future<Map<String, dynamic>> enviarCambioEstado({
  //   required String codigoBarras,
  //   required int clienteId,
  //   required bool enLocal,
  //   required Position position,
  //   String? observaciones,
  //   String? equipoId,
  //   String? clienteNombre,
  //   String? numeroSerie,
  //   String? modelo,
  //   String? marca,
  //   String? logo,
  //   String? estadoCenso = 'pendiente',
  //   int timeoutSegundos = 60,
  //   String? userId,
  //   bool guardarLog = true,
  // }) async {
  //   try {
  //     _logger.i('📤 === ENVIANDO CAMBIO DE ESTADO (COMPATIBILIDAD) ===');
  //
  //     // Obtener vendedorId del AuthService o usar valor por defecto
  //     String edfVendedorId = '40_24'; // Valor por defecto
  //     try {
  //       // TODO: Implementar obtención real del vendedorId desde AuthService
  //       // final usuario = await AuthService().getCurrentUser();
  //       // edfVendedorId = usuario?.edfVendedorId ?? '40_24';
  //     } catch (e) {
  //       _logger.w('⚠️ No se pudo obtener vendedorId, usando valor por defecto: $edfVendedorId');
  //     }
  //
  //     // Obtener usuarioId del AuthService o usar valor por defecto
  //     int usuarioId = 1; // Valor por defecto
  //     try {
  //       // TODO: Implementar obtención real del usuarioId desde AuthService
  //       // final usuario = await AuthService().getCurrentUser();
  //       // usuarioId = usuario?.id ?? 1;
  //     } catch (e) {
  //       _logger.w('⚠️ No se pudo obtener usuarioId, usando valor por defecto: $usuarioId');
  //     }
  //
  //     // Usar el método principal con parámetros para cambio de estado
  //     return await enviarCensoActivo(
  //       equipoId: equipoId ?? codigoBarras,
  //       codigoBarras: codigoBarras,
  //       esNuevoEquipo: false,
  //       clienteId: clienteId,
  //       edfVendedorId: edfVendedorId,
  //       crearPendiente: false,
  //
  //       // Datos del censo (cambio de estado)
  //       usuarioId: usuarioId,
  //       latitud: position.latitude,
  //       longitud: position.longitude,
  //       observaciones: observaciones,
  //       enLocal: enLocal,
  //       estadoCenso: estadoCenso,
  //
  //       // Sin fotos para cambios de estado
  //       fotos: [],
  //
  //       // Datos adicionales del equipo
  //       clienteNombre: clienteNombre,
  //       marca: marca,
  //       modelo: modelo,
  //       logo: logo,
  //       numeroSerie: numeroSerie,
  //
  //       // Control
  //       timeoutSegundos: timeoutSegundos,
  //       userId: userId?.toString(),
  //       guardarLog: guardarLog,
  //     );
  //
  //   } catch (e) {
  //     _logger.e('❌ Error en enviarCambioEstado: $e');
  //     return _errorResponse('Error enviando cambio de estado: $e');
  //   }
  // }
}
//ESTANDARIZAR EL SETEO DE RESPUESTA DEL SERVIDOR, PASANDOLO POR PARAMETRO A UN METODO Y QUE ME DEVUKLEVA UN OBJETO DE UNA CLASE