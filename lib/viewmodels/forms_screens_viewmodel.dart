// viewmodels/forms_screen_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/logo_repository.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:ada_app/repositories/equipo_cliente_repository.dart';

// Eventos UI
abstract class FormsUIEvent {}

class ShowSnackBarEvent extends FormsUIEvent {
  final String message;
  final Color color;

  ShowSnackBarEvent(this.message, this.color);
}

class ShowDialogEvent extends FormsUIEvent {
  final String title;
  final String message;
  final List<DialogAction> actions;

  ShowDialogEvent(this.title, this.message, this.actions);
}

class NavigateToPreviewEvent extends FormsUIEvent {
  final Map<String, dynamic> datos;

  NavigateToPreviewEvent(this.datos);
}

class NavigateBackEvent extends FormsUIEvent {
  final bool result;

  NavigateBackEvent(this.result);
}

class DialogAction {
  final String text;
  final VoidCallback onPressed;
  final bool isDefault;

  DialogAction({
    required this.text,
    required this.onPressed,
    this.isDefault = false,
  });
}

class FormsScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EquipoClienteRepository _equipoClienteRepository = EquipoClienteRepository();

  // Controladores de texto
  final TextEditingController codigoBarrasController = TextEditingController();
  final TextEditingController modeloController = TextEditingController();
  final TextEditingController numeroSerieController = TextEditingController();

  // Estado privado
  bool _isCensoMode = true;
  bool _isLoading = false;
  bool _isScanning = false;
  List<Map<String, dynamic>> _logos = [];
  int? _logoSeleccionado;
  Cliente? _cliente;

  // VARIABLES PARA PASAR AL PREVIEW - AQUÍ GUARDAMOS TODO PARA EL PREVIEW
  Map<String, dynamic>? _equipoCompleto;
  bool _equipoYaAsignado = false;

  // Getters públicos
  bool get isCensoMode => _isCensoMode;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  List<Map<String, dynamic>> get logos => _logos;
  int? get logoSeleccionado => _logoSeleccionado;
  Stream<FormsUIEvent> get uiEvents => _eventController.stream;

  late final StreamController<FormsUIEvent> _eventController;

  // Constructor
  FormsScreenViewModel() {
    _eventController = StreamController<FormsUIEvent>.broadcast();
  }

  // Inicialización
  Future<void> initialize(Cliente cliente) async {
    _cliente = cliente;
    _logger.i('Inicializando FormsScreenViewModel para cliente: ${cliente.nombre}');

    await _cargarLogos();
    _logger.i('Inicialización completa. Logos cargados: ${_logos.length}');
  }

  @override
  void dispose() {
    codigoBarrasController.dispose();
    modeloController.dispose();
    numeroSerieController.dispose();
    _eventController.close();
    super.dispose();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - LOGOS
  // ===============================

  Future<void> _cargarLogos() async {
    try {
      _logger.i('Iniciando carga de logos...');
      final logoRepo = LogoRepository();
      final logos = await logoRepo.obtenerTodos();

      _logos = logos.map((logo) => {
        'id': logo.id,
        'nombre': logo.nombre,
      }).toList();

      _logger.i('Logos cargados exitosamente: ${_logos.length}');
      for (final logo in _logos) {
        _logger.i('Logo: ${logo['id']} - ${logo['nombre']}');
      }

      notifyListeners();
    } catch (e) {
      _logger.e('Error cargando logos: $e');
      _eventController.add(ShowSnackBarEvent('Error cargando logos', Colors.red));
    }
  }

  void setLogoSeleccionado(int? logoId) {
    _logoSeleccionado = logoId;
    notifyListeners();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - SCANNING
  // ===============================

  Future<void> escanearCodigoBarras() async {
    _setScanning(true);

    try {
      final result = await BarcodeScanner.scan(
        options: const ScanOptions(
          strings: {
            'cancel': 'Cancelar',
            'flash_on': 'Flash On',
            'flash_off': 'Flash Off',
          },
        ),
      );

      if (result.rawContent.isNotEmpty) {
        codigoBarrasController.text = result.rawContent;
        await buscarEquipoPorCodigo(result.rawContent);
      }

    } on PlatformException catch (e) {
      if (e.code == BarcodeScanner.cameraAccessDenied) {
        _eventController.add(ShowSnackBarEvent('Permisos de cámara denegados', Colors.red));
      } else {
        _eventController.add(ShowSnackBarEvent('Error desconocido: ${e.message}', Colors.red));
      }
    } catch (e) {
      _logger.e('Error escaneando código: $e');
      _eventController.add(ShowSnackBarEvent('Error al escanear código', Colors.red));
    } finally {
      _setScanning(false);
    }
  }

  void _setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - BÚSQUEDA EQUIPOS (SOLO VALIDACIÓN Y UI)
  // ===============================

  Future<void> buscarEquipoPorCodigo(String codigo) async {
    try {
      _logger.i('Buscando visicooler con código: $codigo');

      final equipoRepo = EquipoRepository();
      final equiposCompletos = await equipoRepo.buscarConFiltros(
        codigoBarras: codigo.trim(),
        soloActivos: true,
      );

      if (equiposCompletos.isNotEmpty) {
        await _procesarEquipoEncontrado(equiposCompletos.first);
      } else {
        _procesarEquipoNoEncontrado(codigo);
      }

    } catch (e, stackTrace) {
      _logger.e('Error buscando visicooler: $e', stackTrace: stackTrace);
      _limpiarDatosAutocompletados();
      _eventController.add(ShowSnackBarEvent('Error al consultar la base de datos', Colors.red));
    }
  }

  // MÉTODO PRINCIPAL - SOLO VALIDACIÓN Y LLENADO DE CAMPOS (NO GUARDAR EN BD)
  Future<void> _procesarEquipoEncontrado(Map<String, dynamic> equipoCompleto) async {
    _logger.i('=== PROCESANDO EQUIPO ENCONTRADO (SOLO VALIDACIÓN) ===');
    _logger.i('Equipo: ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']}');

    try {
      // Verificar si el equipo está asignado al cliente actual
      bool estaAsignado = await _equipoClienteRepository.verificarAsignacionEquipoCliente(
          equipoCompleto['id'],
          _cliente!.id!
      );

      // Rellenar campos en la UI
      _isCensoMode = true;
      modeloController.text = equipoCompleto['modelo_nombre']?.toString() ?? '';
      numeroSerieController.text = equipoCompleto['numero_serie']?.toString() ?? '';

      if (equipoCompleto['logo_id'] != null) {
        final logoExists = _logos.any((logo) => logo['id'] == equipoCompleto['logo_id']);
        if (logoExists) {
          _logoSeleccionado = equipoCompleto['logo_id'] as int?;
        } else {
          _logoSeleccionado = null;
        }
      }

      // ✅ GUARDAR DATOS PARA EL PREVIEW (NO GUARDAR EN BD AÚN)
      _equipoCompleto = equipoCompleto;
      _equipoYaAsignado = estaAsignado;

      // ✅ SOLO MOSTRAR MENSAJES DE ESTADO (NO GUARDAR)
      if (estaAsignado) {
        _eventController.add(ShowSnackBarEvent(
          'Equipo ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']} - YA ASIGNADO ✓',
          Colors.green,
        ));
      } else {
        _eventController.add(ShowSnackBarEvent(
          'Equipo ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']} - LISTO PARA REGISTRAR',
          Colors.blue,
        ));
      }

      notifyListeners();

    } catch (e) {
      _logger.e('Error procesando equipo: $e');
      _eventController.add(ShowSnackBarEvent('Error procesando equipo: $e', Colors.red));
    }
  }

  void _procesarEquipoNoEncontrado(String codigo) {
    _logger.w('Visicooler no encontrado con código: $codigo');
    _limpiarDatosAutocompletados();
    _mostrarDialogoEquipoNoEncontrado(codigo);
  }

  void _mostrarDialogoEquipoNoEncontrado(String codigo) {
    final actions = [
      DialogAction(
        text: 'Registrar nuevo equipo',
        onPressed: habilitarModoNuevoEquipo,
        isDefault: false,
      ),
      DialogAction(
        text: 'Corregir código',
        onPressed: () {
          codigoBarrasController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: codigoBarrasController.text.length,
          );
          _limpiarDatosAutocompletados();
        },
        isDefault: true,
      ),
    ];

    _eventController.add(ShowDialogEvent(
      'Equipo no encontrado',
      'El código "$codigo" no se encuentra en el sistema.',
      actions,
    ));
  }

  // ===============================
  // LÓGICA DE NEGOCIO - MODOS
  // ===============================

  void onCodigoChanged(String codigo) {
    if (codigo.isEmpty) {
      _limpiarDatosAutocompletados();
      _isCensoMode = true;
      notifyListeners();
    }
  }

  void onCodigoSubmitted(String codigo) {
    _logger.i('Código submitted: "$codigo"');
    if (codigo.length >= 3) {
      buscarEquipoPorCodigo(codigo);
    } else if (codigo.isNotEmpty) {
      _eventController.add(ShowSnackBarEvent('El código debe tener al menos 3 caracteres', Colors.orange));
    }
  }

  void habilitarModoNuevoEquipo() {
    _isCensoMode = false;
    modeloController.clear();
    numeroSerieController.clear();
    _logoSeleccionado = null;

    // Limpiar datos del preview ya que es modo nuevo
    _equipoCompleto = null;
    _equipoYaAsignado = false;

    _eventController.add(ShowSnackBarEvent(
        'Modo: Registrar nuevo equipo. Complete todos los campos',
        Colors.blue
    ));

    notifyListeners();
  }

  void limpiarFormulario() {
    codigoBarrasController.clear();
    _limpiarDatosAutocompletados();
    _isCensoMode = true;
    notifyListeners();
  }

  void _limpiarDatosAutocompletados() {
    modeloController.clear();
    numeroSerieController.clear();
    _logoSeleccionado = null;
    // Limpiar datos del preview
    _equipoCompleto = null;
    _equipoYaAsignado = false;
    notifyListeners();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - VALIDACIÓN
  // ===============================

  String? validarCodigoBarras(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código de barras es requerido';
    }
    if (value.trim().length < 3) {
      return 'El código debe tener al menos 3 caracteres';
    }
    return null;
  }

  String? validarModelo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El modelo del visicooler es requerido';
    }
    return null;
  }

  String? validarLogo(int? value) {
    if (value == null) {
      return 'El logo es requerido';
    }
    return null;
  }

  String? validarNumeroSerie(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El número de serie es requerido';
    }
    return null;
  }

  // ===============================
  // LÓGICA DE NEGOCIO - NAVEGACIÓN
  // ===============================

  Future<void> continuarAPreview(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    _setLoading(true);

    try {
      _logger.i('Obteniendo ubicación GPS del visicooler...');

      final ubicacion = await _obtenerUbicacion();
      _logger.i('Ubicación obtenida: ${ubicacion['latitud']}, ${ubicacion['longitud']}');

      final datosCompletos = _construirDatosCompletos(ubicacion);
      _eventController.add(NavigateToPreviewEvent(datosCompletos));

    } catch (e) {
      _logger.e('Error obteniendo ubicación: $e');
      _mostrarDialogoErrorGPS(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Map<String, dynamic> _construirDatosCompletos(Map<String, double> ubicacion) {
    final logoSeleccionado = _logos.firstWhere(
            (logo) => logo['id'] == _logoSeleccionado,
        orElse: () => {'nombre': ''}
    );

    return {
      'cliente': _cliente,
      'codigo_barras': codigoBarrasController.text.trim(),
      'modelo': modeloController.text.trim(),
      'logo_id': _logoSeleccionado,
      'logo': logoSeleccionado['nombre'],
      'numero_serie': numeroSerieController.text.trim(),
      'latitud': ubicacion['latitud'],
      'longitud': ubicacion['longitud'],
      'fecha_registro': DateTime.now().toIso8601String(),
      'timestamp_gps': DateTime.now().millisecondsSinceEpoch,
      'es_censo': _isCensoMode,

      // ✅ DATOS COMPLETOS PARA EL PREVIEW (INCLUIR TODO LO NECESARIO PARA GUARDAR)
      'equipo_completo': _equipoCompleto,
      'ya_asignado': _equipoYaAsignado,
    };
  }

  void onNavigationResult(dynamic result) {
    if (result == true) {
      _eventController.add(NavigateBackEvent(true));
    }
  }

  void cancelar() {
    _eventController.add(NavigateBackEvent(false));
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - GPS
  // ===============================

  Future<Map<String, double>> _obtenerUbicacion() async {
    try {
      _logger.i('Iniciando obtención de ubicación GPS...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'El servicio de ubicación está deshabilitado. Active el GPS para continuar.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permisos de ubicación denegados. Permita el acceso a la ubicación.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Permisos de ubicación denegados permanentemente. Vaya a configuración y habilite la ubicación.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      _logger.i('Ubicación GPS obtenida: ${position.latitude}, ${position.longitude}');
      _logger.i('Precisión: ${position.accuracy}m');

      return {
        'latitud': position.latitude,
        'longitud': position.longitude,
      };

    } catch (e) {
      _logger.e('Error crítico obteniendo ubicación GPS: $e');
      throw 'Error obteniendo ubicación GPS: $e. La ubicación es requerida para registrar el visicooler.';
    }
  }

  void _mostrarDialogoErrorGPS(String error) {
    final actions = [
      DialogAction(
        text: 'Cancelar',
        onPressed: () {},
      ),
      DialogAction(
        text: 'Reintentar GPS',
        onPressed: () => continuarAPreview(GlobalKey<FormState>()),
        isDefault: true,
      ),
    ];

    _eventController.add(ShowDialogEvent(
      'Error de Ubicación',
      'No se pudo obtener la ubicación GPS del visicooler.\n\nError: $error\n\nLa ubicación GPS es obligatoria para registrar visicoolers. Asegúrese de estar en la ubicación exacta del equipo.',
      actions,
    ));
  }

  // ===============================
  // GETTERS PARA LA UI
  // ===============================

  String get titleText => _isCensoMode ? 'Censo de Equipos' : 'Agregar Nuevo Equipo';

  String get modeTitle => _isCensoMode ? 'Modo: Censo de Equipos' : 'Modo: Registro Nuevo Equipo';

  String get modeSubtitle => _isCensoMode
      ? 'Escanee o ingrese un código para buscar equipos existentes'
      : 'Complete manualmente todos los campos del nuevo equipo';

  IconData get modeIcon => _isCensoMode ? Icons.inventory : Icons.add_box;

  String get codigoHint => _isCensoMode
      ? 'Escanea o ingresa y presiona Enter'
      : 'Código del nuevo equipo';

  String get modeloHint => _isCensoMode
      ? 'Se completará automáticamente...'
      : 'Ingrese el modelo del equipo';

  String get serieHint => _isCensoMode
      ? 'Se completará automáticamente...'
      : 'Ingrese el número de serie';

  String get logoHint => _isCensoMode
      ? 'Se completará automáticamente'
      : 'Seleccionar logo';

  String get buttonText => _isCensoMode ? 'Registrar Censo' : 'Registrar Nuevo';

  IconData get buttonIcon => _isCensoMode ? Icons.assignment : Icons.add_box;

  bool get shouldShowCamera => _isCensoMode;

  bool get areFieldsEnabled => !_isCensoMode;

  Color? get fieldBackgroundColor => _isCensoMode ? Colors.grey[50] : null;
}