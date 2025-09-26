import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../repositories/censo_activo_repository.dart';
import '../repositories/equipo_repository.dart';
import '../models/censo_activo.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

// ========== EVENTOS PARA LA UI ==========
abstract class EquiposClienteDetailUIEvent {}

class ShowMessageEvent extends EquiposClienteDetailUIEvent {
  final String message;
  final MessageType type;
  ShowMessageEvent(this.message, this.type);
}

class ShowRetireConfirmationDialogEvent extends EquiposClienteDetailUIEvent {
  final dynamic equipoCliente;
  ShowRetireConfirmationDialogEvent(this.equipoCliente);
}

enum MessageType { error, success, info, warning }

// ========== ESTADO PURO ==========
class EquiposClienteDetailState {
  final dynamic equipoCliente;
  final bool isProcessing;
  final bool equipoEnLocal;
  final List<EstadoEquipo> historialCambios;
  final List<EstadoEquipo> historialUltimos5;

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
    bool? equipoEnLocal,
    this.historialCambios = const [],
    this.historialUltimos5 = const [],
  }): equipoEnLocal = equipoEnLocal ?? (equipoCliente['tipo_estado'] == 'asignado');

  EquiposClienteDetailState copyWith({
    dynamic equipoCliente,
    bool? isProcessing,
    bool? equipoEnLocal,
    List<EstadoEquipo>? historialCambios,
    List<EstadoEquipo>? historialUltimos5,
  }) {
    return EquiposClienteDetailState(
      equipoCliente: equipoCliente ?? this.equipoCliente,
      isProcessing: isProcessing ?? this.isProcessing,
      equipoEnLocal: equipoEnLocal ?? this.equipoEnLocal,
      historialCambios: historialCambios ?? this.historialCambios,
      historialUltimos5: historialUltimos5 ?? this.historialUltimos5,
    );
  }
}

// ========== VIEWMODEL LIMPIO ==========
class EquiposClienteDetailScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final EquipoRepository _equipoRepository;
  final LocationService _locationService = LocationService();

  // ========== ESTADO INTERNO ==========
  EquiposClienteDetailState _state;

  // ========== NUEVOS CAMPOS PARA DROPDOWN ==========
  bool? _estadoUbicacionEquipo;
  bool _hasUnsavedChanges = false;
  int _estadoLocalActual;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<EquiposClienteDetailUIEvent> _eventController =
  StreamController<EquiposClienteDetailUIEvent>.broadcast();
  Stream<EquiposClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== CONSTRUCTOR ==========
  EquiposClienteDetailScreenViewModel(
      dynamic equipoCliente,
      this._estadoEquipoRepository,
      this._equipoRepository,
      ) : _state = EquiposClienteDetailState(equipoCliente: equipoCliente),
        _estadoLocalActual = _determinarEstadoInicial(equipoCliente) {
    _initializeState();
    _loadInitialState();
    _logDebugInfo();
  }

  // ========== HELPER METHOD ==========
  static int _determinarEstadoInicial(dynamic equipoCliente) {
    final tipoEstado = equipoCliente['tipo_estado']?.toString();
    if (tipoEstado == 'asignado') {
      return 1;
    } else {
      return 0;
    }
  }

  // ========== INICIALIZAR ESTADO DEL DROPDOWN ==========
  void _initializeState() {
    _estadoUbicacionEquipo = _estadoLocalActual == 1;
    _hasUnsavedChanges = false;
    _logger.i('Estado inicial - _estadoLocalActual: $_estadoLocalActual');
    _logger.i('Estado inicial - _estadoUbicacionEquipo: $_estadoUbicacionEquipo');
  }

  // CARGAR ESTADO INICIAL Y HISTORIAL
// CARGAR ESTADO INICIAL Y HISTORIAL
// Reemplaza el método _loadInitialState en tu ViewModel

  Future<void> _loadInitialState() async {
    try {
      final equipoId = equipoCliente['cod_barras'];
      final clienteId = equipoCliente['cliente_id'];

      print('🔍 BUSCANDO HISTORIAL PARA:');
      print('   equipoId: $equipoId (tipo: ${equipoId.runtimeType})');
      print('   clienteId: $clienteId (tipo: ${clienteId.runtimeType})');
      print('   tipo_estado: ${equipoCliente['tipo_estado']}');

      if (equipoId == null || clienteId == null) {
        _logger.w('No se encontró ID del equipo o cliente');
        return;
      }

      final tipoEstado = equipoCliente['tipo_estado']?.toString();
      EstadoEquipo? estadoActual;
      List<EstadoEquipo> historialCompleto = [];

      _logger.i(
          '📋 Cargando historial para equipo: $equipoId, cliente: $clienteId, tipo: $tipoEstado');

      // CAMBIO 1: Usar el mismo método para ambos casos
      try {
        // Intentar obtener historial directo primero (funciona para asignados y censados)
        historialCompleto =
        await _estadoEquipoRepository.obtenerHistorialDirectoPorEquipoCliente(
            equipoId,
            int.parse(clienteId.toString())
        );

        _logger.i('📈 Historial directo obtenido: ${historialCompleto
            .length} registros');
      } catch (e) {
        _logger.w(
            '⚠️ Error con historial directo, intentando método alternativo: $e');

        // Fallback: usar método alternativo
        try {
          historialCompleto =
          await _estadoEquipoRepository.obtenerHistorialCompleto(
              equipoId.toString(),
              int.parse(clienteId.toString())
          );
          _logger.i('📈 Historial alternativo obtenido: ${historialCompleto
              .length} registros');
        } catch (e2) {
          _logger.e('❌ Error con ambos métodos de historial: $e2');
          historialCompleto = [];
        }
      }

      // CAMBIO 2: Obtener estado actual del primer elemento del historial
      estadoActual =
      historialCompleto.isNotEmpty ? historialCompleto.first : null;

      // CAMBIO 3: Si no hay historial, intentar obtener último estado individualmente
      if (estadoActual == null && tipoEstado == 'asignado') {
        try {
          estadoActual = await _estadoEquipoRepository.obtenerUltimoEstado(
              equipoId,
              int.parse(clienteId.toString())
          );
          _logger.i('📍 Estado individual obtenido para equipo asignado');

          // Si se obtuvo un estado individual, agregarlo al historial
          if (estadoActual != null) {
            historialCompleto = [estadoActual];
          }
        } catch (e) {
          _logger.w('⚠️ No se pudo obtener estado individual: $e');
        }
      }

      // CAMBIO 4: Determinar estado local actual basado en historial o tipo
      if (estadoActual != null) {
        _estadoLocalActual = estadoActual.enLocal ? 1 : 0;
        _logger.i(
            '🏠 Estado local determinado por historial: $_estadoLocalActual (${estadoActual
                .enLocal ? "En local" : "Fuera del local"})');
      } else {
        // Fallback al tipo de estado original
        _estadoLocalActual = tipoEstado == 'asignado' ? 1 : 0;
        _logger.i('🏠 Estado local por defecto: $_estadoLocalActual');
      }

      // CAMBIO 5: Actualizar el estado del dropdown
      _estadoUbicacionEquipo = _estadoLocalActual == 1;

      // CAMBIO 6: Tomar últimos 5 para la UI
      final ultimos5 = historialCompleto.take(5).toList();

      // CAMBIO 7: Actualizar el estado interno
      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
        equipoEnLocal: _estadoLocalActual == 1,
      );

      notifyListeners();

      // CAMBIO 8: Log detallado del resultado
      _logger.i('✅ Estado inicial cargado:');
      _logger.i(
          '   - Historial completo: ${historialCompleto.length} registros');
      _logger.i('   - Últimos 5: ${ultimos5.length} registros');
      _logger.i('   - Estado actual: ${estadoActual != null
          ? "Encontrado"
          : "No encontrado"}');
      _logger.i('   - Estado local actual: $_estadoLocalActual');
      _logger.i('   - Estado dropdown: $_estadoUbicacionEquipo');

      // Debug: mostrar detalles de los registros
      for (int i = 0; i < ultimos5.length; i++) {
        final registro = ultimos5[i];
        _logger.i('   Registro $i: ${registro.enLocal
            ? "En local"
            : "Fuera"} - ${registro.fechaRevision}');
      }
    } catch (e) {
      _logger.e('❌ Error crítico cargando estado inicial: $e');

      // Estado de emergencia
      _estadoLocalActual = equipoCliente['tipo_estado'] == 'asignado' ? 1 : 0;
      _estadoUbicacionEquipo = _estadoLocalActual == 1;

      _state = _state.copyWith(
        historialCambios: [],
        historialUltimos5: [],
        equipoEnLocal: _estadoLocalActual == 1,
      );

      notifyListeners();
    }
    print('📊 RESULTADOS:');
    print('   historialCompleto.length: ${historialCompleto.length}');
    for (int i = 0; i < historialCompleto.length; i++) {
      final h = historialCompleto[i];
      print('   [$i] id:${h.id}, enLocal:${h.enLocal}, sync:${h
          .estaSincronizado}');
    }
  }

  // ========== GETTERS PÚBLICOS ==========
  EquiposClienteDetailState get state => _state;
  dynamic get equipoCliente => _state.equipoCliente;
  bool get isProcessing => _state.isProcessing;
  bool get isEquipoActivo {
    final tipoEstado = equipoCliente['tipo_estado']?.toString();
    return tipoEstado == 'asignado';
  }
  bool? get estadoUbicacionEquipo => _estadoUbicacionEquipo;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get saveButtonEnabled => _estadoUbicacionEquipo != null && _hasUnsavedChanges;

  String get saveButtonText {
    if (_estadoUbicacionEquipo == null) return 'Seleccione ubicación';
    if (!_hasUnsavedChanges) return 'Sin cambios';
    return 'Guardar cambios';
  }

  List<EstadoEquipo> get historialUltimos5 => _state.historialUltimos5;
  List<EstadoEquipo> get historialCompleto => _state.historialCambios;
  int get totalCambios => _state.historialCambios.length;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== MÉTODOS PARA DROPDOWN ==========
  void cambiarUbicacionEquipo(bool? nuevaUbicacion) {
    if (_estadoUbicacionEquipo != nuevaUbicacion) {
      _estadoUbicacionEquipo = nuevaUbicacion;
      final estadoActual = _estadoLocalActual == 1;
      _hasUnsavedChanges = _estadoUbicacionEquipo != estadoActual;
      notifyListeners();
      _logger.i('🔄 Dropdown cambiado a: $nuevaUbicacion (pendiente de guardar)');
    }
  }

  Future<void> toggleEquipoEnLocal(bool value) async {
    cambiarUbicacionEquipo(value);
  }

  Future<void> recargarHistorial() async {
    try {
      _logger.i('🔄 Recargando historial completo...');

      if (equipoCliente['id'] == null) {
        _logger.w('⚠️ equipoCliente id es null, no se puede recargar historial');
        return;
      }

      final tipoEstado = equipoCliente['tipo_estado']?.toString();
      List<EstadoEquipo> historialCompleto = [];

      if (tipoEstado == 'asignado') {
        final clienteId = equipoCliente['cliente_id'];
        if (clienteId != null) {
          historialCompleto = await _estadoEquipoRepository.obtenerHistorialCompleto(
              equipoCliente['id'], clienteId
          );
        }
      } else {
        historialCompleto = await _estadoEquipoRepository.obtenerHistorialCompleto(
          equipoCliente['id'].toString(),
          int.parse(equipoCliente['cliente_id'].toString()),
        );
      }

      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
      );

      notifyListeners();
      _logger.i('✅ Historial recargado: ${historialCompleto.length} registros');

    } catch (e) {
      _logger.e('❌ Error recargando historial: $e');
    }
  }

  // ========== GUARDAR CAMBIOS - CORREGIDO ==========
  Future<void> saveAllChanges() async {
    if (_estadoUbicacionEquipo == null) {
      _eventController.add(ShowMessageEvent(
        'Debe seleccionar una ubicación para el equipo antes de guardar',
        MessageType.error,
      ));
      return;
    }

    if (!_hasUnsavedChanges) {
      _eventController.add(ShowMessageEvent(
        'No hay cambios para guardar',
        MessageType.info,
      ));
      return;
    }

    _state = _state.copyWith(isProcessing: true);
    notifyListeners();

    try {
      _logger.i('Guardando cambios: enLocal=$_estadoUbicacionEquipo');

      late final Position position;
      try {
        position = await _locationService.getCurrentLocationRequired(
          timeout: Duration(seconds: 30),
        );

        _logger.i('Ubicación GPS obtenida: ${_locationService.formatCoordinates(position)}');

      } on LocationException catch (e) {
        _state = _state.copyWith(isProcessing: false);
        notifyListeners();

        _eventController.add(ShowMessageEvent(
          'GPS requerido: ${e.message}',
          MessageType.error,
        ));

        return;
      }

      // SIMPLIFICADO: Un solo método para ambos tipos
      final clienteId = equipoCliente['cliente_id'];
      final equipoId = equipoCliente['id']?.toString();

      if (clienteId == null || equipoId == null || equipoId.isEmpty) {
        throw Exception('ID del equipo o cliente no disponible');
      }

      _logger.i('Usando equipoId: $equipoId, clienteId: $clienteId');

      final nuevoEstado = await _estadoEquipoRepository.crearNuevoEstado(
        equipoId: equipoId,
        clienteId: int.parse(clienteId.toString()),
        enLocal: _estadoUbicacionEquipo!,
        fechaRevision: DateTime.now(),
        latitud: position.latitude,
        longitud: position.longitude,
      );

      _estadoLocalActual = _estadoUbicacionEquipo! ? 1 : 0;
      _hasUnsavedChanges = false;

      final historialActualizado = [nuevoEstado, ..._state.historialCambios];
      final ultimos5Actualizado = historialActualizado.take(5).toList();

      _state = _state.copyWith(
        equipoEnLocal: _estadoUbicacionEquipo!,
        historialCambios: historialActualizado,
        historialUltimos5: ultimos5Actualizado,
        isProcessing: false,
      );

      notifyListeners();

      _eventController.add(ShowMessageEvent(
        'Cambios guardados con ubicación GPS',
        MessageType.success,
      ));

    } catch (e) {
      _logger.e('Error al guardar cambios: $e');

      _state = _state.copyWith(isProcessing: false);
      notifyListeners();

      _eventController.add(ShowMessageEvent(
        'Error al guardar los cambios: $e',
        MessageType.error,
      ));
    }
  }

  bool canSaveChanges() {
    return _estadoUbicacionEquipo != null && _hasUnsavedChanges;
  }

  void resetChanges() {
    _estadoUbicacionEquipo = _estadoLocalActual == 1;
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  bool get isEquipoEnLocal {
    return _estadoUbicacionEquipo ?? _state.equipoEnLocal;
  }

  String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String formatearFechaHora(DateTime fecha) {
    return '${formatearFecha(fecha)} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  String formatearFechaHistorial(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours}h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return formatearFechaHora(fecha);
    }
  }

  String getNombreCompletoEquipo() {
    return '${equipoCliente['marca_nombre'] ?? ''} ${equipoCliente['modelo_nombre'] ?? ''}'.trim();
  }

  bool shouldShowMarca() {
    return equipoCliente['marca_nombre'] != null &&
        equipoCliente['marca_nombre']!.isNotEmpty;
  }

  bool shouldShowModelo() {
    return equipoCliente['modelo_nombre'] != null &&
        equipoCliente['modelo_nombre']!.isNotEmpty;
  }

  bool shouldShowCodBarras() {
    return equipoCliente['cod_barras'] != null &&
        equipoCliente['cod_barras']!.isNotEmpty;
  }


  String getMarcaText() {
    return equipoCliente['marca_nombre'] ?? '';
  }

  String getModeloText() {
    return equipoCliente['modelo_nombre'] ?? '';
  }

  String getCodBarrasText() {
    return equipoCliente['cod_barras'] ?? '';
  }

  String getLogoText() {
    return equipoCliente['logo_nombre'] ?? '';
  }

  String getTiempoAsignadoText() {
    final fechaString = equipoCliente['fecha_creacion'];
    if (fechaString == null) return '0 días';

    try {
      final fecha = DateTime.parse(fechaString);
      final diferencia = DateTime.now().difference(fecha);
      return '${diferencia.inDays} días';
    } catch (e) {
      return '0 días';
    }
  }

  String getFechaRetiroText() {
    return 'No disponible';
  }

  String getEstadoText() {
    final tipoEstado = equipoCliente['tipo_estado']?.toString();

    if (tipoEstado == 'asignado') {
      return _estadoLocalActual == 1 ? 'En local' : 'Fuera del local';
    } else if (tipoEstado == 'pendiente') {
      return 'Pendiente';
    } else {
      return 'Sin estado';
    }
  }

  Map<String, String> getRetireDialogData() {
    return {
      'equipoNombre': getNombreCompletoEquipo(),
      'equipoCodigo': equipoCliente['cod_barras'] ?? 'Sin código',
      'clienteNombre': 'Cliente ID: ${equipoCliente['cliente_id'] ?? "No asignado"}',
    };
  }

  void _logDebugInfo() {
    _logger.i('DEBUG - Equipo Marca: ${equipoCliente['marca_nombre']}');
    _logger.i('DEBUG - Equipo Modelo: ${equipoCliente['modelo_nombre']}');
    _logger.i('DEBUG - Nombre completo calculado: ${getNombreCompletoEquipo()}');
    _logger.i('DEBUG - En local: ${_state.equipoEnLocal}');
    _logger.i('DEBUG - Estado dropdown: $_estadoUbicacionEquipo');
    _logger.i('DEBUG - Estado local actual: $_estadoLocalActual');
    _logger.i('DEBUG - Tipo estado: ${equipoCliente['tipo_estado']}');
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'equipo_id': equipoCliente['id'],
      'cliente_id': equipoCliente['cliente_id'],
      'tipo_estado': equipoCliente['tipo_estado'],
      'equipo_marca': equipoCliente['marca_nombre'],
      'equipo_modelo': equipoCliente['modelo_nombre'],
      'codigo_barras': equipoCliente['cod_barras'],
      'cliente_nombre': equipoCliente['cliente_nombre'],
      'is_processing': _state.isProcessing,
      'equipo_en_local': _state.equipoEnLocal,
      'estado_dropdown': _estadoUbicacionEquipo,
      'estado_local_actual': _estadoLocalActual,
      'has_unsaved_changes': _hasUnsavedChanges,
      'total_cambios_historial': _state.historialCambios.length,
      'ultimos_5_cambios': _state.historialUltimos5.length,
    };
  }

  void logDebugInfo() {
    _logger.d('EquiposClienteDetailScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}