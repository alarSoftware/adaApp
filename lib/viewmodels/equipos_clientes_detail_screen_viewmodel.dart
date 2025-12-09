import 'package:flutter/foundation.dart';
import 'dart:async';
import '../repositories/censo_activo_repository.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import '../repositories/equipo_repository.dart';
import '../models/censo_activo.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ada_app/services/auth_service.dart';

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
  final List<CensoActivo> historialCambios;
  final List<CensoActivo> historialUltimos5;

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
    bool? equipoEnLocal,
    this.historialCambios = const [],
    this.historialUltimos5 = const [],
  }) : equipoEnLocal =
      equipoEnLocal ?? (equipoCliente['tipo_estado'] == 'asignado');

  EquiposClienteDetailState copyWith({
    dynamic equipoCliente,
    bool? isProcessing,
    bool? equipoEnLocal,
    List<CensoActivo>? historialCambios,
    List<CensoActivo>? historialUltimos5,
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
  final CensoActivoRepository _estadoEquipoRepository;
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

  // ========== MÉTODOS PARA VALIDACIÓN DE DÍA DE RUTA ==========

  String _getDiaActual() {
    final diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final now = DateTime.now();
    return diasSemana[now.weekday - 1];
  }

  bool _validarDiaRuta() {
    // Obtener rutaDia del equipoCliente
    final rutaDia = equipoCliente['ruta_dia']?.toString();

    // Si el cliente no tiene día de ruta asignado, permitir acceso
    if (rutaDia == null || rutaDia.isEmpty) return true;

    final diaActual = _getDiaActual();

    // Validar que el día actual coincida con el día de ruta
    return rutaDia == diaActual;
  }

  bool puedeRealizarCambios() {
    return _validarDiaRuta();
  }

  String obtenerMensajeRestriccionDia() {
    final diaActual = _getDiaActual();
    final rutaDia = equipoCliente['ruta_dia']?.toString() ?? 'sin asignar';

    return 'No puedes realizar cambios hoy.\n'
        'Este cliente corresponde al día: $rutaDia\n'
        'Hoy es: $diaActual';
  }

  // ============================================================

  // ========== INICIALIZAR ESTADO DEL DROPDOWN ==========
  void _initializeState() {
    _estadoUbicacionEquipo = null;
    _hasUnsavedChanges = false;
  }

  // CARGAR ESTADO INICIAL Y HISTORIAL
  Future<void> _loadInitialState() async {
    try {
      // ✅ USAR CÓDIGO DE BARRAS para buscar historial
      final codigoBarras = equipoCliente['cod_barras']?.toString();
      final clienteId = equipoCliente['cliente_id'];

      if (codigoBarras == null || codigoBarras.isEmpty || clienteId == null) {
        return;
      }

      final tipoEstado = equipoCliente['tipo_estado']?.toString();
      CensoActivo? estadoActual;
      List<CensoActivo> historialCompleto = [];

      try {
        historialCompleto = await _estadoEquipoRepository
            .obtenerHistorialDirectoPorEquipoCliente(
          codigoBarras,
          int.parse(clienteId.toString()),
        );
      } catch (e) {
        try {
          historialCompleto = await _estadoEquipoRepository
              .obtenerHistorialCompleto(
            codigoBarras,
            int.parse(clienteId.toString()),
          );
        } catch (e2) {
          historialCompleto = [];
        }
      }

      estadoActual = historialCompleto.isNotEmpty
          ? historialCompleto.first
          : null;

      if (estadoActual == null && tipoEstado == 'asignado') {
        try {
          estadoActual = await _estadoEquipoRepository.obtenerUltimoEstado(
            codigoBarras,
            int.parse(clienteId.toString()),
          );

          if (estadoActual != null) {
            historialCompleto = [estadoActual];
          }
        } catch (e) {
          // Error al obtener estado individual
        }
      }

      if (estadoActual != null) {
        _estadoLocalActual = estadoActual.enLocal ? 1 : 0;
      } else {
        _estadoLocalActual = tipoEstado == 'asignado' ? 1 : 0;
      }

      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
        equipoEnLocal: _estadoLocalActual == 1,
      );

      notifyListeners();
    } catch (e) {
      _estadoLocalActual = equipoCliente['tipo_estado'] == 'asignado' ? 1 : 0;

      _state = _state.copyWith(
        historialCambios: [],
        historialUltimos5: [],
        equipoEnLocal: _estadoLocalActual == 1,
      );

      notifyListeners();
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
  bool get saveButtonEnabled => _estadoUbicacionEquipo != null;

  String get saveButtonText {
    if (_estadoUbicacionEquipo == null) return 'Seleccione ubicación';
    return 'Guardar cambios';
  }

  List<CensoActivo> get historialUltimos5 => _state.historialUltimos5;
  List<CensoActivo> get historialCompleto => _state.historialCambios;
  int get totalCambios => _state.historialCambios.length;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== MÉTODOS PARA DROPDOWN ==========

  // Getter para saber si el dropdown debe estar habilitado
  bool get dropdownHabilitado => _validarDiaRuta();

  void cambiarUbicacionEquipo(bool? nuevaUbicacion) {
    // VALIDAR DÍA DE RUTA ANTES DE PERMITIR CAMBIOS
    if (!_validarDiaRuta()) {
      _eventController.add(ShowMessageEvent(
        obtenerMensajeRestriccionDia(),
        MessageType.error,
      ));
      return;
    }

    _estadoUbicacionEquipo = nuevaUbicacion;
    _hasUnsavedChanges = _estadoUbicacionEquipo != null;
    notifyListeners();
  }

  Future<void> toggleEquipoEnLocal(bool value) async {
    cambiarUbicacionEquipo(value);
  }

  Future<void> recargarHistorial() async {
    try {
      final equipoId = equipoCliente['id'];
      final clienteId = equipoCliente['cliente_id'];

      if (equipoId == null || clienteId == null) {
        return;
      }

      final tipoEstado = equipoCliente['tipo_estado']?.toString();
      List<CensoActivo> historialCompleto = [];

      historialCompleto = await _estadoEquipoRepository
          .obtenerHistorialCompleto(
        equipoId.toString(),
        int.parse(clienteId.toString()),
      );

      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
      );

      notifyListeners();
    } catch (e) {
      // Error recargando historial
    }
  }

  // ========== GUARDAR CAMBIOS ==========
  Future<void> saveAllChanges() async {
    // VALIDAR DÍA DE RUTA ANTES DE GUARDAR
    if (!_validarDiaRuta()) {
      _eventController.add(ShowMessageEvent(
        obtenerMensajeRestriccionDia(),
        MessageType.error,
      ));
      return;
    }

    if (_estadoUbicacionEquipo == null) {
      _eventController.add(
        ShowMessageEvent(
          'Debe seleccionar una ubicación para el equipo antes de guardar',
          MessageType.error,
        ),
      );
      return;
    }

    _state = _state.copyWith(isProcessing: true);
    notifyListeners();

    try {
      late final Position position;
      try {
        position = await _locationService.getCurrentLocationRequired(
          timeout: Duration(seconds: 30),
        );
      } on LocationException catch (e) {
        _state = _state.copyWith(isProcessing: false);
        notifyListeners();
        _eventController.add(
          ShowMessageEvent('GPS requerido: ${e.message}', MessageType.error),
        );
        return;
      }

      final clienteId = equipoCliente['cliente_id'];
      final codigoBarras = equipoCliente['cod_barras']?.toString();

      if (clienteId == null || codigoBarras == null || codigoBarras.isEmpty) {
        throw Exception('Código de barras o cliente no disponible');
      }

      final nuevoEstado = await _estadoEquipoRepository.crearCensoActivo(
        equipoId: codigoBarras,
        clienteId: int.parse(clienteId.toString()),
        enLocal: _estadoUbicacionEquipo!,
        fechaRevision: DateTime.now(),
        latitud: position.latitude,
        longitud: position.longitude,
      );

      // 2. Sincronizar con el servidor
      try {
        final currentUser = await AuthService().getCurrentUser();
        if (currentUser != null &&
            currentUser.id != null &&
            currentUser.edfVendedorId != null) {
          final resultadoSync = await CensoActivoPostService.enviarCambioEstado(
            codigoBarras: codigoBarras,
            clienteId: int.parse(clienteId.toString()),
            enLocal: _estadoUbicacionEquipo!,
            position: position,
            observaciones: nuevoEstado.observaciones,
            equipoId: equipoCliente['equipo_id']?.toString() ?? codigoBarras,
            clienteNombre: equipoCliente['cliente_nombre']?.toString() ?? '',
            numeroSerie: equipoCliente['numero_serie']?.toString() ?? '',
            modelo: equipoCliente['modelo_nombre']?.toString() ?? '',
            marca: equipoCliente['marca_nombre']?.toString() ?? '',
            logo: equipoCliente['logo_nombre']?.toString() ?? '',
            usuarioId: currentUser.id!,
            edfVendedorId: currentUser.edfVendedorId!,
          );

          if (resultadoSync['exito']) {
            if (nuevoEstado.id != null) {
              await _estadoEquipoRepository.marcarComoMigrado(nuevoEstado.id!);
            }
          }
        }
      } catch (syncError) {
        // El guardado local ya se hizo, así que continuamos
      }

      _estadoLocalActual = _estadoUbicacionEquipo! ? 1 : 0;
      _estadoUbicacionEquipo = null;
      _hasUnsavedChanges = false;

      final historialActualizado = [nuevoEstado, ..._state.historialCambios];
      final ultimos5Actualizado = historialActualizado.take(5).toList();

      _state = _state.copyWith(
        equipoEnLocal: _estadoLocalActual == 1,
        historialCambios: historialActualizado,
        historialUltimos5: ultimos5Actualizado,
        isProcessing: false,
      );

      notifyListeners();

      _eventController.add(
        ShowMessageEvent(
          'Cambios guardados con ubicación GPS',
          MessageType.success,
        ),
      );
    } catch (e) {
      _state = _state.copyWith(isProcessing: false);
      notifyListeners();
      _eventController.add(
        ShowMessageEvent('Error al guardar los cambios: $e', MessageType.error),
      );
    }
  }

  bool canSaveChanges() {
    return _estadoUbicacionEquipo != null;
  }

  void resetChanges() {
    _estadoUbicacionEquipo = null;
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
    return '${equipoCliente['marca_nombre'] ?? ''} ${equipoCliente['modelo_nombre'] ?? ''}'
        .trim();
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
      'clienteNombre':
      'Cliente ID: ${equipoCliente['cliente_id'] ?? "No asignado"}',
    };
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
}