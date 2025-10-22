import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/logo_repository.dart';
import 'package:ada_app/repositories/models_repository.dart';
import 'package:ada_app/repositories/marca_repository.dart'; // NUEVO: Importar MarcaRepository
import 'package:logger/logger.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
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
  final LocationService _locationService = LocationService();

  // Controladores de texto
  final TextEditingController codigoBarrasController = TextEditingController();
  final TextEditingController numeroSerieController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  // Estado privado
  bool _isCensoMode = true;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isTakingPhoto = false;

  // NUEVO: Lista de marcas y marca seleccionada
  List<Map<String, dynamic>> _marcas = [];
  int? _marcaSeleccionada;

  // Lista de modelos y modelo seleccionado
  List<Map<String, dynamic>> _modelos = [];
  int? _modeloSeleccionado;

  List<Map<String, dynamic>> _logos = [];
  int? _logoSeleccionado;
  Cliente? _cliente;
  File? _imagenSeleccionada;
  File? _imagenSeleccionada2;

  // VARIABLES PARA PASAR AL PREVIEW
  Map<String, dynamic>? _equipoCompleto;
  bool _equipoYaAsignado = false;

  // Getters públicos
  bool get isCensoMode => _isCensoMode;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;

  // NUEVO: Getters para marcas
  List<Map<String, dynamic>> get marcas => _marcas;
  int? get marcaSeleccionada => _marcaSeleccionada;

  // Getters para modelos
  List<Map<String, dynamic>> get modelos => _modelos;
  int? get modeloSeleccionado => _modeloSeleccionado;

  List<Map<String, dynamic>> get logos => _logos;
  int? get logoSeleccionado => _logoSeleccionado;
  File? get imagenSeleccionada => _imagenSeleccionada;
  File? get imagenSeleccionada2 => _imagenSeleccionada2;

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

    // MODIFICADO: Ahora cargamos marcas, logos y modelos
    await Future.wait([
      _cargarMarcas(), // NUEVO
      _cargarLogos(),
      _cargarModelos(),
    ]);

    _logger.i('Inicialización completa. Marcas: ${_marcas.length}, Logos: ${_logos.length}, Modelos: ${_modelos.length}');
  }

  @override
  void dispose() {
    codigoBarrasController.dispose();
    numeroSerieController.dispose();
    observacionesController.dispose();
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
  // NUEVO: LÓGICA DE NEGOCIO - MARCAS
  // ===============================

  Future<void> _cargarMarcas() async {
    try {
      _logger.i('Iniciando carga de marcas...');
      final marcaRepo = MarcaRepository();
      final marcas = await marcaRepo.obtenerTodos();

      _marcas = marcas.map((marca) => {
        'id': marca.id,
        'nombre': marca.nombre,
      }).toList();

      _logger.i('Marcas cargadas exitosamente: ${_marcas.length}');
      notifyListeners();
    } catch (e) {
      _logger.e('Error cargando marcas: $e');
      _showError('Error cargando marcas');
    }
  }

  void setMarcaSeleccionada(int? marcaId) {
    _marcaSeleccionada = marcaId;
    _logger.i('Marca seleccionada: $marcaId');
    notifyListeners();
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
  // LÓGICA DE NEGOCIO - MODELOS
  // ===============================

  Future<void> _cargarModelos() async {
    try {
      _logger.i('Iniciando carga de modelos...');
      final modeloRepo = ModeloRepository();
      final modelos = await modeloRepo.obtenerTodos();

      _modelos = modelos.map((modelo) => {
        'id': modelo.id,
        'nombre': modelo.nombre,
      }).toList();

      _logger.i('Modelos cargados exitosamente: ${_modelos.length}');
      notifyListeners();
    } catch (e) {
      _logger.e('Error cargando modelos: $e');
      _showError('Error cargando modelos');
    }
  }

  void setModeloSeleccionado(int? modeloId) {
    _modeloSeleccionado = modeloId;
    _logger.i('Modelo seleccionado: $modeloId');
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

  Future<void> _procesarEquipoEncontrado(Map<String, dynamic> equipoCompleto) async {
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
      final String equipoId = equipo['id'].toString();
      final int clienteId = _cliente!.id is int
          ? _cliente!.id!
          : int.parse(_cliente!.id!.toString());

      _logger.i('Verificando asignación - EquipoID: "$equipoId" (String), ClienteID: $clienteId (int)');

      final yaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(
        equipoId,
        clienteId,
      );

      _equipoYaAsignado = yaAsignado;

      if (yaAsignado) {
        _logger.i('✅ Equipo YA ESTÁ asignado al cliente ${_cliente!.nombre}');
      } else {
        _logger.w('⚠️ Equipo NO está asignado al cliente ${_cliente!.nombre}');
      }

    } catch (e) {
      _logger.e('Error verificando asignación: $e');
      _equipoYaAsignado = false;
      throw 'Error verificando asignación del equipo';
    }
  }

  void _llenarCamposFormulario(Map<String, dynamic> equipoCompleto) {
    // NUEVO: Llenar marca seleccionada
    _marcaSeleccionada = equipoCompleto['marca_id'];
    _logger.i('Marca seleccionada del equipo: $_marcaSeleccionada');

    // Llenar modelo seleccionado
    _modeloSeleccionado = equipoCompleto['modelo_id'];
    _logger.i('Modelo seleccionado del equipo: $_modeloSeleccionado');

    numeroSerieController.text = equipoCompleto['numero_serie'] ?? '';
    _logoSeleccionado = equipoCompleto['logo_id'];

    _logger.i('Campos autocompletados: Marca ID=$_marcaSeleccionada, Modelo ID=$_modeloSeleccionado, Serie=${numeroSerieController.text}, Logo ID=$_logoSeleccionado');
  }

  void _prepararDatosPreview(Map<String, dynamic> equipoCompleto) {
    _equipoCompleto = equipoCompleto;
    _logger.i('Datos del equipo preparados para preview');
  }

  void _mostrarEstadoEquipo(Map<String, dynamic> equipoCompleto) {
    final nombreCompleto = '${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']}';

    if (_equipoYaAsignado) {
      _showSuccess(
        '✅ Equipo encontrado y YA ASIGNADO a ${_cliente!.nombre}\n'
            'Modelo: $nombreCompleto\n'
            'Las fotos son OPCIONALES',
      );
    } else {
      _showWarning(
        '⚠️ Equipo encontrado pero AÚN NO ASIGNADO a ${_cliente!.nombre}\n'
            'Modelo: $nombreCompleto\n'
            '📸 Debe tomar AL MENOS UNA FOTO para asignar el equipo',
      );
    }
  }

  void _procesarEquipoNoEncontrado(String codigo) {
    _logger.w('Equipo no encontrado con código: $codigo');

    final actions = [
      DialogAction(
        text: 'Cancelar',
        onPressed: () {
          codigoBarrasController.clear();
          _limpiarDatosAutocompletados();
        },
      ),
      DialogAction(
        text: 'Registrar Nuevo',
        onPressed: habilitarModoNuevoEquipo,
        isDefault: true,
      ),
    ];

    _eventController.add(ShowDialogEvent(
      'Equipo no encontrado',
      'No se encontró ningún equipo con el código "$codigo" en la base de datos.\n\n'
          '¿Desea registrar este código como un nuevo equipo?',
      actions,
    ));
  }

  // ===============================
  // LÓGICA DE NEGOCIO - IMÁGENES
  // ===============================

  Future<void> tomarFoto({required bool esPrimeraFoto}) async {
    if (_isTakingPhoto) {
      _showWarning('Ya hay una captura en proceso');
      return;
    }

    _isTakingPhoto = true;
    notifyListeners();

    try {
      _logger.i('Iniciando captura de foto ${esPrimeraFoto ? "1" : "2"}...');

      final File? foto = await _imageService.tomarFoto();

      if (foto != null) {
        await _procesarImagenSeleccionada(foto, esPrimeraFoto: esPrimeraFoto);
      } else {
        _logger.i('Usuario canceló la captura de foto');
      }
    } catch (e) {
      _logger.e('Error tomando foto: $e');
      _showError('Error al tomar la foto: $e');
    } finally {
      _isTakingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> _procesarImagenSeleccionada(File imagen, {required bool esPrimeraFoto}) async {
    try {
      if (!_imageService.esImagenValida(imagen)) {
        _showError('El archivo seleccionado no es una imagen válida');
        return;
      }

      final double tamanoMB = await _imageService.obtenerTamanoImagen(imagen);
      if (tamanoMB > 15.0) {
        _showError('La imagen es demasiado grande (${tamanoMB.toStringAsFixed(1)}MB). Máximo 15MB.');
        return;
      }

      final String codigoEquipo = codigoBarrasController.text.trim().isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : codigoBarrasController.text.trim();

      final String sufijo = esPrimeraFoto ? '_foto1' : '_foto2';
      final File imagenGuardada = await _imageService.guardarImagenEnApp(
          imagen,
          '$codigoEquipo$sufijo'
      );

      if (esPrimeraFoto) {
        if (_imagenSeleccionada != null) {
          await _imageService.eliminarImagen(_imagenSeleccionada!);
        }
        _imagenSeleccionada = imagenGuardada;
      } else {
        if (_imagenSeleccionada2 != null) {
          await _imageService.eliminarImagen(_imagenSeleccionada2!);
        }
        _imagenSeleccionada2 = imagenGuardada;
      }

      _logger.i('Imagen ${esPrimeraFoto ? "1" : "2"} procesada: ${imagenGuardada.path}');
      _showSuccess('Foto ${esPrimeraFoto ? "1" : "2"} agregada (${tamanoMB.toStringAsFixed(1)}MB)');
      notifyListeners();

    } catch (e) {
      _logger.e('Error procesando imagen: $e');
      _showError('Error al procesar la imagen');
    }
  }

  void eliminarImagen({required bool esPrimeraFoto}) {
    if (esPrimeraFoto) {
      _imagenSeleccionada = null;
      _logger.i('Imagen 1 eliminada');
    } else {
      _imagenSeleccionada2 = null;
      _logger.i('Imagen 2 eliminada');
    }
    notifyListeners();
  }

  void _eliminarImagenTemporal() {
    _imagenSeleccionada = null;
    _imagenSeleccionada2 = null;
    notifyListeners();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - FORMULARIO
  // ===============================

  void onCodigoChanged(String codigo) {
    if (_isCensoMode && codigo.length >= 3) {
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

    // MODIFICADO: Limpiar marca y modelo seleccionados
    _marcaSeleccionada = null;
    _modeloSeleccionado = null;
    numeroSerieController.clear();
    _logoSeleccionado = null;

    _equipoCompleto = null;
    _equipoYaAsignado = false;

    _showInfo('Modo: Registrar nuevo equipo. Complete todos los campos');
    notifyListeners();
  }

  void limpiarFormulario() {
    codigoBarrasController.clear();
    observacionesController.clear();
    _limpiarDatosAutocompletados();
    _isCensoMode = true;
    notifyListeners();
  }

  void _limpiarDatosAutocompletados() {
    // MODIFICADO: Limpiar marca y modelo seleccionados
    _marcaSeleccionada = null;
    _modeloSeleccionado = null;
    numeroSerieController.clear();
    _logoSeleccionado = null;
    _eliminarImagenTemporal();
    _equipoCompleto = null;
    _equipoYaAsignado = false;
    notifyListeners();
  }

  // ===============================
  // VALIDACIONES
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

  // NUEVO: Validar marca
  String? validarMarca(int? value) {
    if (value == null) {
      return 'La marca es requerida';
    }
    return null;
  }

  String? validarModelo(int? value) {
    if (value == null) {
      return 'El modelo es requerido';
    }
    return null;
  }

  String? validarNumeroSerie(String? value) => _validarCampo(value, 'El número de serie');

  String? validarLogo(int? value) {
    if (value == null) {
      return 'El logo es requerido';
    }
    return null;
  }

  String? validarFotos() {
    if (_equipoYaAsignado) {
      return null;
    }

    if (_imagenSeleccionada == null && _imagenSeleccionada2 == null) {
      return 'Debe tomar al menos una foto del equipo';
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

    final errorFotos = validarFotos();
    if (errorFotos != null) {
      _showError(errorFotos);
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
    // NUEVO: Obtener el nombre de la marca seleccionada
    final marcaSeleccionadaData = _marcas.firstWhere(
            (marca) => marca['id'] == _marcaSeleccionada,
        orElse: () => {'nombre': ''}
    );

    final logoSeleccionado = _logos.firstWhere(
            (logo) => logo['id'] == _logoSeleccionado,
        orElse: () => {'nombre': ''}
    );

    final modeloSeleccionadoData = _modelos.firstWhere(
            (modelo) => modelo['id'] == _modeloSeleccionado,
        orElse: () => {'nombre': ''}
    );

    return {
      'cliente': _cliente,
      'codigo_barras': codigoBarrasController.text.trim(),

      // NUEVO: Incluir datos de marca
      'marca': marcaSeleccionadaData['nombre'],
      'marca_id': _marcaSeleccionada,

      'modelo': modeloSeleccionadoData['nombre'],
      'modelo_id': _modeloSeleccionado,

      'logo_id': _logoSeleccionado,
      'logo': logoSeleccionado['nombre'],
      'numero_serie': numeroSerieController.text.trim(),
      'observaciones': observacionesController.text.trim(),
      'imagen_path': _imagenSeleccionada?.path,
      'imagen_path2': _imagenSeleccionada2?.path,
      'latitud': ubicacion['latitud'],
      'longitud': ubicacion['longitud'],
      'fecha_registro': DateTime.now().toIso8601String(),
      'timestamp_gps': DateTime.now().millisecondsSinceEpoch,
      'es_censo': _isCensoMode,
      'es_nuevo_equipo': !_isCensoMode,
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

  // NUEVO: Hint para el dropdown de marca
  String get marcaHint => _isCensoMode
      ? 'Se completará automáticamente'
      : 'Seleccionar marca';

  String get modeloHint => _isCensoMode
      ? 'Se completará automáticamente'
      : 'Seleccionar modelo';

  String get serieHint => _isCensoMode
      ? 'Se completará automáticamente...'
      : 'Ingrese el número de serie';

  String get logoHint => _isCensoMode
      ? 'Se completará automáticamente'
      : 'Seleccionar logo';

  String get fotoRequerimiento => _equipoYaAsignado
      ? 'Fotos (Opcional)'
      : 'Fotos (Requerida al menos 1)';

  String get observacionesHint => _isCensoMode
      ? 'Comentarios u observaciones...'
      : 'Comentarios u observaciones...';

  String get observacionesLabel => 'Observaciones';

  bool get sonFotosObligatorias => !_equipoYaAsignado;

  String get buttonText => _isCensoMode ? 'Registrar Censo' : 'Registrar Nuevo';

  IconData get buttonIcon => _isCensoMode ? Icons.assignment : Icons.add_box;

  bool get observacionesEnabled => true;

  bool get shouldShowCamera => _isCensoMode;

  bool get areFieldsEnabled => !_isCensoMode;

  Color? get fieldBackgroundColor => _isCensoMode ? Colors.grey[50] : null;

  bool get isTakingPhoto => _isTakingPhoto;
}