import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/logo_repository.dart';
import 'package:logger/logger.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/image_service.dart';
import 'package:ada_app/services/location_service.dart';
import 'dart:io';

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
  final EquipoRepository _equipoRepository = EquipoRepository();
  final ImageService _imageService = ImageService();
  final LocationService _locationService = LocationService(); // AGREGADO

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
  File? _imagenSeleccionada;


  // VARIABLES PARA PASAR AL PREVIEW
  Map<String, dynamic>? _equipoCompleto;
  bool _equipoYaAsignado = false;

  // Getters públicos
  bool get isCensoMode => _isCensoMode;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  List<Map<String, dynamic>> get logos => _logos;
  int? get logoSeleccionado => _logoSeleccionado;
  File? get imagenSeleccionada => _imagenSeleccionada;
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
  // MÉTODOS AUXILIARES PARA EVENTOS UI
  // ===============================

  void _showError(String message) {
    _eventController.add(ShowSnackBarEvent(message, Colors.red));
  }

  void _showSuccess(String message) {
    _eventController.add(ShowSnackBarEvent(message, Colors.green));
  }

  void _showInfo(String message) {
    _eventController.add(ShowSnackBarEvent(message, Colors.blue));
  }

  void _showWarning(String message) {
    _eventController.add(ShowSnackBarEvent(message, Colors.orange));
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
      notifyListeners();
    } catch (e) {
      _logger.e('Error cargando logos: $e');
      _showError('Error cargando logos');
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
        _showError('Permisos de cámara denegados');
      } else {
        _showError('Error desconocido: ${e.message}');
      }
    } catch (e) {
      _logger.e('Error escaneando código: $e');
      _showError('Error al escanear código');
    } finally {
      _setScanning(false);
    }
  }

  void _setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - BÚSQUEDA EQUIPOS
  // ===============================

  Future<void> buscarEquipoPorCodigo(String codigo) async {
    try {
      _logger.i('Buscando visicooler con código: $codigo');

      final equipoRepo = EquipoRepository();
      final equiposCompletos = await equipoRepo.buscarPorCodigoExacto(
        codigoBarras: codigo.trim(),
      );

      if (equiposCompletos.isNotEmpty) {
        await _procesarEquipoEncontrado(equiposCompletos.first);
      } else {
        _procesarEquipoNoEncontrado(codigo);
      }

    } catch (e, stackTrace) {
      _logger.e('Error buscando visicooler: $e', stackTrace: stackTrace);
      _limpiarDatosAutocompletados();
      _showError('Error al consultar la base de datos');
    }
  }

  // MÉTODO PRINCIPAL REFACTORIZADO - DIVIDIDO EN MÉTODOS MÁS PEQUEÑOS
  Future<void> _procesarEquipoEncontrado( Map<String, dynamic> equipoCompleto) async {
    _logger.i('=== PROCESANDO EQUIPO ENCONTRADO ===');
    _logger.i('Equipo: ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']}');

    try {
      await _verificarAsignacionEquipo(equipoCompleto);
      _llenarCamposFormulario(equipoCompleto);
      _prepararDatosPreview(equipoCompleto);
      _mostrarEstadoEquipo(equipoCompleto);
      notifyListeners();

    } catch (e) {
      _logger.e('Error procesando equipo: $e');
      _showError('Error procesando equipo: $e');
    }
  }
  Future<void> _verificarAsignacionEquipo(Map<String, dynamic> equipo) async {
    try {
      // Convertir IDs a int de manera directa
      int equipoId;
      int clienteId;

      // Manejar equipo['id']
      if (equipo['id'] is int) {
        equipoId = equipo['id'];
      } else {
        equipoId = int.parse(equipo['id'].toString());
      }

      // Manejar cliente.id
      if (_cliente!.id! is int) {
        clienteId = _cliente!.id!;
      } else {
        clienteId = int.parse(_cliente!.id!.toString());
      }

      _logger.i('Verificando asignación - EquipoID: $equipoId, ClienteID: $clienteId');

      _equipoYaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(
          equipo['id'].toString(),  // Mantener como String
          clienteId  // Solo clienteId como int
      );

      _logger.i('Resultado verificación: $_equipoYaAsignado');

    } catch (e) {
      _logger.e('Error verificando asignación de equipo: $e');
      _logger.e('equipo[id]: ${equipo['id']} (${equipo['id'].runtimeType})');
      _logger.e('cliente.id: ${_cliente!.id!} (${_cliente!.id!.runtimeType})');

      // En caso de error, asumir que no está asignado
      _equipoYaAsignado = false;
    }
  }

// In FormsScreenViewModel.dart

  void _llenarCamposFormulario(Map<String, dynamic> equipo) {
    _isCensoMode = true;
    modeloController.text = equipo['modelo_nombre']?.toString() ?? '';
    numeroSerieController.text = equipo['numero_serie']?.toString() ?? '';

    // Handle logo_id - VERSIÓN ROBUSTA
    if (equipo['logo_id'] != null) {
      final equipoLogoId = equipo['logo_id'];

      // Buscar el logo utilizando comparación flexible (int o String)
      final logoEncontrado = _logos.firstWhere(
            (logo) {
          // Comparar tanto como int como String para máxima compatibilidad
          return logo['id'] == equipoLogoId ||
              logo['id'].toString() == equipoLogoId.toString();
        },
        orElse: () => <String, dynamic>{}, // Retornar mapa vacío si no se encuentra
      );

      if (logoEncontrado.isNotEmpty) {
        // Intentar convertir a int si es posible, sino mantener el tipo original
        if (equipoLogoId is int) {
          _logoSeleccionado = equipoLogoId;
        } else {
          final int? parsedLogoId = int.tryParse(equipoLogoId.toString());
          _logoSeleccionado = parsedLogoId;
        }

        _logger.i("Logo encontrado: ${logoEncontrado['nombre']} (ID: ${_logoSeleccionado})");
      } else {
        _logger.w("Logo con ID '${equipoLogoId}' no encontrado en la lista de logos.");
        _logoSeleccionado = null;
      }
    } else {
      _logoSeleccionado = null;
    }

    notifyListeners();
  }


  void _prepararDatosPreview(Map<String, dynamic> equipo) {
    _equipoCompleto = equipo;
  }

  void _mostrarEstadoEquipo(Map<String, dynamic> equipo) {
    final nombreEquipo = '${equipo['marca_nombre']} ${equipo['modelo_nombre']}';
    final clienteIdEquipo = equipo['cliente_id'];

    if (_equipoYaAsignado) {
      _showSuccess('Equipo $nombreEquipo - YA ASIGNADO ✓');
    } else if (clienteIdEquipo != null && clienteIdEquipo.toString() != '0' && clienteIdEquipo.toString().isNotEmpty) {
      _showWarning('Equipo $nombreEquipo - PERTENECE A OTRO CLIENTE (quedará PENDIENTE)');
    } else {
      _showInfo('Equipo $nombreEquipo - SIN ASIGNAR (quedará PENDIENTE)');
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
  // LÓGICA DE NEGOCIO - IMÁGENES
  // ===============================

  Future<void> tomarFoto() async {
    try {
      _logger.i('Iniciando captura de foto...');

      final File? foto = await _imageService.tomarFoto();

      if (foto != null) {
        await _procesarImagenSeleccionada(foto);
      } else {
        _logger.i('Usuario canceló la captura de foto');
      }
    } catch (e) {
      _logger.e('Error tomando foto: $e');
      _showError('Error al tomar la foto: $e');
    }
  }

  Future<void> _procesarImagenSeleccionada(File imagen) async {
    try {
      // Validar que sea una imagen válida
      if (!_imageService.esImagenValida(imagen)) {
        _showError('El archivo seleccionado no es una imagen válida');
        return;
      }

      // Verificar tamaño de imagen
      final double tamanoMB = await _imageService.obtenerTamanoImagen(imagen);
      if (tamanoMB > 15.0) {
        _showError('La imagen es demasiado grande (${tamanoMB.toStringAsFixed(1)}MB). Máximo 15MB.');
        return;
      }

      // Guardar imagen en el directorio de la app
      final String codigoEquipo = codigoBarrasController.text.trim().isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : codigoBarrasController.text.trim();

      final File imagenGuardada = await _imageService.guardarImagenEnApp(imagen, codigoEquipo);

      // Eliminar imagen anterior si existe
      if (_imagenSeleccionada != null) {
        await _imageService.eliminarImagen(_imagenSeleccionada!);
      }

      _imagenSeleccionada = imagenGuardada;
      _logger.i('Imagen procesada exitosamente: ${imagenGuardada.path}');

      _showSuccess('Imagen agregada correctamente (${tamanoMB.toStringAsFixed(1)}MB)');
      notifyListeners();

    } catch (e) {
      _logger.e('Error procesando imagen: $e');
      _showError('Error al procesar la imagen: $e');
    }
  }

  Future<void> _eliminarImagenTemporal() async {
    if (_imagenSeleccionada != null) {
      try {
        await _imageService.eliminarImagen(_imagenSeleccionada!);
      } catch (e) {
        _logger.w('No se pudo eliminar imagen temporal: $e');
      }
      _imagenSeleccionada = null;
    }
  }

  Future<void> eliminarImagen() async {
    if (_imagenSeleccionada != null) {
      try {
        await _imageService.eliminarImagen(_imagenSeleccionada!);
        _imagenSeleccionada = null;
        _showWarning('Imagen eliminada');
        notifyListeners();
      } catch (e) {
        _logger.e('Error eliminando imagen: $e');
        _showError('Error al eliminar la imagen');
      }
    }
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
      _showWarning('El código debe tener al menos 3 caracteres');
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

    _showInfo('Modo: Registrar nuevo equipo. Complete todos los campos');
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
    // Limpiar imagen
    _eliminarImagenTemporal();
    // Limpiar datos del preview
    _equipoCompleto = null;
    _equipoYaAsignado = false;
    notifyListeners();
  }

  // ===============================
  // VALIDACIONES SIMPLIFICADAS
  // ===============================

  String? _validarCampo(String? value, String nombreCampo, {int minLength = 1}) {
    if (value == null || value.trim().isEmpty) {
      return '$nombreCampo es requerido';
    }
    if (value.trim().length < minLength) {
      return '$nombreCampo debe tener al menos $minLength caracteres';
    }
    return null;
  }

  String? validarCodigoBarras(String? value) => _validarCampo(value, 'El código de barras', minLength: 3);
  String? validarModelo(String? value) => _validarCampo(value, 'El modelo del visicooler');
  String? validarNumeroSerie(String? value) => _validarCampo(value, 'El número de serie');

  String? validarLogo(int? value) {
    if (value == null) {
      return 'El logo es requerido';
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
      'imagen_path': _imagenSeleccionada?.path,
      'latitud': ubicacion['latitud'],
      'longitud': ubicacion['longitud'],
      'fecha_registro': DateTime.now().toIso8601String(),
      'timestamp_gps': DateTime.now().millisecondsSinceEpoch,
      'es_censo': _isCensoMode,
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
  // LÓGICA DE NEGOCIO - GPS (OPTIMIZADA)
  // ===============================

  Future<Map<String, double>> _obtenerUbicacion() async {
    try {
      return await _locationService.getCurrentLocationAsMap(
        timeout: const Duration(seconds: 30),
      );
    } on LocationException catch (e) {
      throw 'Error obteniendo ubicación GPS: ${e.message}';
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