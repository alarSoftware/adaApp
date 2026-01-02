import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/logo_repository.dart';
import 'package:ada_app/repositories/models_repository.dart';
import 'package:ada_app/repositories/marca_repository.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:ada_app/services/device/image_service.dart';
import 'package:ada_app/services/device/location_service.dart';
import 'dart:io';

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
  final EquipoRepository _equipoRepository = EquipoRepository();
  final ImageService _imageService = ImageService();
  final LocationService _locationService = LocationService();

  final TextEditingController codigoBarrasController = TextEditingController();
  final TextEditingController numeroSerieController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  String _ultimoCodigoBuscado = '';

  bool _isCensoMode = true;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isTakingPhoto = false;

  List<Map<String, dynamic>> _marcas = [];
  int? _marcaSeleccionada;

  List<Map<String, dynamic>> _modelos = [];
  int? _modeloSeleccionado;

  List<Map<String, dynamic>> _logos = [];
  int? _logoSeleccionado;
  Cliente? _cliente;
  File? _imagenSeleccionada;
  File? _imagenSeleccionada2;

  Map<String, dynamic>? _equipoCompleto;
  bool _equipoYaAsignado = false;

  bool get isCensoMode => _isCensoMode;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;

  List<Map<String, dynamic>> get marcas => _marcas;
  int? get marcaSeleccionada => _marcaSeleccionada;

  List<String> get marcasParaUI =>
      _marcas.map((m) => m['nombre'] as String).toList();

  List<Map<String, dynamic>> get modelos => _modelos;
  int? get modeloSeleccionado => _modeloSeleccionado;

  List<String> get modelosParaUI =>
      _modelos.map((m) => m['nombre'] as String).toList();

  List<Map<String, dynamic>> get logos => _logos;
  int? get logoSeleccionado => _logoSeleccionado;

  List<String> get logosParaUI =>
      _logos.map((l) => l['nombre'] as String).toList();

  String? get marcaSeleccionadaNombre {
    if (_marcaSeleccionada == null) return null;
    final marca = _marcas.firstWhere(
      (m) => m['id'] == _marcaSeleccionada,
      orElse: () => {'nombre': null},
    );
    return marca['nombre'] as String?;
  }

  String? get modeloSeleccionadoNombre {
    if (_modeloSeleccionado == null) return null;
    final modelo = _modelos.firstWhere(
      (m) => m['id'] == _modeloSeleccionado,
      orElse: () => {'nombre': null},
    );
    return modelo['nombre'] as String?;
  }

  String? get logoSeleccionadoNombre {
    if (_logoSeleccionado == null) return null;
    final logo = _logos.firstWhere(
      (l) => l['id'] == _logoSeleccionado,
      orElse: () => {'nombre': null},
    );
    return logo['nombre'] as String?;
  }

  File? get imagenSeleccionada => _imagenSeleccionada;
  File? get imagenSeleccionada2 => _imagenSeleccionada2;

  Stream<FormsUIEvent> get uiEvents => _eventController.stream;

  late final StreamController<FormsUIEvent> _eventController;

  FormsScreenViewModel() {
    _eventController = StreamController<FormsUIEvent>.broadcast();
  }

  Future<void> initialize(Cliente cliente) async {
    _cliente = cliente;

    await Future.wait([_cargarMarcas(), _cargarLogos(), _cargarModelos()]);
  }

  @override
  void dispose() {
    codigoBarrasController.dispose();
    numeroSerieController.dispose();
    observacionesController.dispose();
    _eventController.close();
    super.dispose();
  }

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

  Future<void> _cargarMarcas() async {
    try {
      final marcaRepo = MarcaRepository();
      final marcas = await marcaRepo.obtenerTodos();

      _marcas = marcas
          .map((marca) => {'id': marca.id, 'nombre': marca.nombre})
          .toList();

      notifyListeners();
    } catch (e) {
      _showError('No se pudieron cargar las marcas disponibles');
    }
  }

  void setMarcaSeleccionada(int? marcaId) {
    _marcaSeleccionada = marcaId;
    notifyListeners();
  }

  Future<void> _cargarLogos() async {
    try {
      final logoRepo = LogoRepository();
      final logos = await logoRepo.obtenerTodos();

      _logos = logos
          .map((logo) => {'id': logo.id, 'nombre': logo.nombre})
          .toList();
      notifyListeners();
    } catch (e) {
      _showError('No se pudieron cargar los logos disponibles');
    }
  }

  void setLogoSeleccionado(int? logoId) {
    _logoSeleccionado = logoId;
    notifyListeners();
  }

  Future<void> _cargarModelos() async {
    try {
      final modeloRepo = ModeloRepository();
      final modelos = await modeloRepo.obtenerTodos();

      _modelos = modelos
          .map((modelo) => {'id': modelo.id, 'nombre': modelo.nombre})
          .toList();

      notifyListeners();
    } catch (e) {
      _showError('No se pudieron cargar los modelos disponibles');
    }
  }

  void setModeloSeleccionado(int? modeloId) {
    _modeloSeleccionado = modeloId;
    notifyListeners();
  }

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
        _showError('Se requieren permisos de cámara para escanear códigos');
      } else {
        _showError('Error al escanear: ${e.message}');
      }
    } catch (e) {
      _showError('No se pudo escanear el código de barras');
    } finally {
      _setScanning(false);
    }
  }

  void _setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }

  Future<void> buscarEquipoSiHuboCambios() async {
    if (!_isCensoMode) {
      return;
    }

    final codigoActual = codigoBarrasController.text.trim();

    if (codigoActual.length < 3) {
      return;
    }

    if (codigoActual == _ultimoCodigoBuscado) {
      return;
    }

    await buscarEquipoPorCodigo(codigoActual);
  }

  Future<void> buscarEquipoPorCodigo(String codigo) async {
    if (!_isCensoMode) {
      return;
    }

    _ultimoCodigoBuscado = codigo.trim();

    try {
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
      _limpiarDatosAutocompletados();
      _showError('No se pudo buscar el equipo. Verifique su conexión');
    }
  }

  Future<void> _procesarEquipoEncontrado(
    Map<String, dynamic> equipoCompleto,
  ) async {
    try {
      await _verificarAsignacionEquipo(equipoCompleto);
      _llenarCamposFormulario(equipoCompleto);
      _prepararDatosPreview(equipoCompleto);
      _mostrarEstadoEquipo(equipoCompleto);

      notifyListeners();
    } catch (e) {
      _showError('Error procesando equipo: $e');
    }
  }

  Future<void> _verificarAsignacionEquipo(Map<String, dynamic> equipo) async {
    try {
      final String equipoId = equipo['id'].toString();
      final int clienteId = _cliente!.id is int
          ? _cliente!.id!
          : int.parse(_cliente!.id!.toString());

      final yaAsignado = await _equipoRepository
          .verificarAsignacionEquipoCliente(equipoId, clienteId);

      _equipoYaAsignado = yaAsignado;
    } catch (e) {
      _equipoYaAsignado = false;
      throw 'Error verificando asignación del equipo';
    }
  }

  void _llenarCamposFormulario(Map<String, dynamic> equipoCompleto) {
    _marcaSeleccionada = equipoCompleto['marca_id'];
    _modeloSeleccionado = equipoCompleto['modelo_id'];
    numeroSerieController.text = equipoCompleto['numero_serie'] ?? '';
    _logoSeleccionado = equipoCompleto['logo_id'];

    notifyListeners();
  }

  void _prepararDatosPreview(Map<String, dynamic> equipoCompleto) {
    _equipoCompleto = equipoCompleto;
  }

  void _mostrarEstadoEquipo(Map<String, dynamic> equipoCompleto) {
    if (_equipoYaAsignado) {
      _showSuccess('¡Equipo encontrado!');
    } else {
      _showWarning(
        'Equipo encontrado pero no asignado al cliente, se censara como pendiente',
      );
    }
  }

  void _procesarEquipoNoEncontrado(String codigo) {
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

    _eventController.add(
      ShowDialogEvent(
        'Equipo no encontrado',
        'No existe un equipo registrado con el código "$codigo".\n\n'
            '¿Desea registrarlo como un equipo nuevo?',
        actions,
      ),
    );
  }

  Future<void> tomarFoto({required bool esPrimeraFoto}) async {
    if (_isTakingPhoto) {
      _showWarning('Espere a que termine la captura actual');
      return;
    }

    _isTakingPhoto = true;
    notifyListeners();

    try {
      final File? foto = await _imageService.tomarFoto();

      if (foto != null) {
        await _procesarImagenSeleccionada(foto, esPrimeraFoto: esPrimeraFoto);
      }
    } catch (e) {
      _showError('No se pudo capturar la foto');
    } finally {
      _isTakingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> _procesarImagenSeleccionada(
    File imagen, {
    required bool esPrimeraFoto,
  }) async {
    try {
      if (!_imageService.esImagenValida(imagen)) {
        _showError('El archivo seleccionado no es válido');
        return;
      }

      final double tamanoMB = await _imageService.obtenerTamanoImagen(imagen);
      if (tamanoMB > 15.0) {
        _showError(
          'La imagen es muy grande (${tamanoMB.toStringAsFixed(1)}MB). Máximo: 15MB',
        );
        return;
      }

      final String codigoEquipo = codigoBarrasController.text.trim().isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : codigoBarrasController.text.trim();

      final String sufijo = esPrimeraFoto ? '_foto1' : '_foto2';
      final File imagenGuardada = await _imageService.guardarImagenEnApp(
        imagen,
        '$codigoEquipo$sufijo',
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

      _showSuccess(
        'Foto ${esPrimeraFoto ? "1" : "2"} capturada correctamente (${tamanoMB.toStringAsFixed(1)}MB)',
      );
      notifyListeners();
    } catch (e) {
      _showError('No se pudo procesar la foto capturada');
    }
  }

  void eliminarImagen({required bool esPrimeraFoto}) {
    if (esPrimeraFoto) {
      _imagenSeleccionada = null;
    } else {
      _imagenSeleccionada2 = null;
    }
    notifyListeners();
  }

  void _eliminarImagenTemporal() {
    _imagenSeleccionada = null;
    _imagenSeleccionada2 = null;
    notifyListeners();
  }

  void onCodigoChanged(String codigo) {
    if (_isCensoMode && codigo.length >= 3) {
      _isCensoMode = true;
      notifyListeners();
    }

    if (codigo.trim().isEmpty) {
      _ultimoCodigoBuscado = '';
    }
  }

  void onCodigoSubmitted(String codigo) {
    if (codigo.length >= 3) {
      buscarEquipoPorCodigo(codigo);
    } else if (codigo.isNotEmpty) {
      _showWarning('Ingrese un código de al menos 3 caracteres');
    }
  }

  void habilitarModoNuevoEquipo() {
    _isCensoMode = false;

    _marcaSeleccionada = null;
    _modeloSeleccionado = null;
    numeroSerieController.clear();
    _logoSeleccionado = null;

    _equipoCompleto = null;
    _equipoYaAsignado = false;

    _ultimoCodigoBuscado = '';

    _showInfo(
      'Ahora puede registrar un equipo nuevo completando todos los campos',
    );
    notifyListeners();
  }

  void limpiarFormulario() {
    codigoBarrasController.clear();
    observacionesController.clear();
    _limpiarDatosAutocompletados();
    _isCensoMode = true;

    _ultimoCodigoBuscado = '';

    notifyListeners();
  }

  void _limpiarDatosAutocompletados() {
    _marcaSeleccionada = null;
    _modeloSeleccionado = null;
    numeroSerieController.clear();
    _logoSeleccionado = null;
    _eliminarImagenTemporal();
    _equipoCompleto = null;
    _equipoYaAsignado = false;
    notifyListeners();
  }

  String? _validarCampo(
    String? value,
    String nombreCampo, {
    int minLength = 1,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$nombreCampo es requerido';
    }
    if (value.trim().length < minLength) {
      return '$nombreCampo debe tener al menos $minLength caracteres';
    }
    return null;
  }

  String? validarCodigoBarras(String? value) =>
      _validarCampo(value, 'El código de barras', minLength: 3);

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

  String? validarNumeroSerie(String? value) =>
      _validarCampo(value, 'El número de serie');

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
      return 'Debe capturar al menos una foto del equipo para continuar';
    }

    return null;
  }

  Future<void> continuarAPreview(GlobalKey<FormState> formKey) async {
    await Future.delayed(const Duration(milliseconds: 150));

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
      final ubicacion = await _obtenerUbicacion();

      final datosCompletos = _construirDatosCompletos(ubicacion);
      _eventController.add(NavigateToPreviewEvent(datosCompletos));
    } catch (e) {
      _mostrarDialogoErrorGPS(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Map<String, dynamic> _construirDatosCompletos(Map<String, double> ubicacion) {
    final marcaSeleccionadaData = _marcas.firstWhere(
      (marca) => marca['id'] == _marcaSeleccionada,
      orElse: () => {'nombre': ''},
    );

    final logoSeleccionado = _logos.firstWhere(
      (logo) => logo['id'] == _logoSeleccionado,
      orElse: () => {'nombre': ''},
    );

    final modeloSeleccionadoData = _modelos.firstWhere(
      (modelo) => modelo['id'] == _modeloSeleccionado,
      orElse: () => {'nombre': ''},
    );

    return {
      'cliente': _cliente,
      'codigo_barras': codigoBarrasController.text.trim(),

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
      DialogAction(text: 'Cancelar', onPressed: () {}),
      DialogAction(
        text: 'Reintentar GPS',
        onPressed: () => continuarAPreview(GlobalKey<FormState>()),
        isDefault: true,
      ),
    ];

    _eventController.add(
      ShowDialogEvent(
        'Error de Ubicación',
        'No se pudo obtener la ubicación GPS del equipo.\n\nError: $error\n\nLa ubicación GPS es obligatoria. Asegúrese de tener el GPS activado y estar en la ubicación exacta del equipo.',
        actions,
      ),
    );
  }

  String get titleText =>
      _isCensoMode ? 'Censo de Equipos' : 'Agregar Nuevo Equipo';

  String get modeTitle =>
      _isCensoMode ? 'Modo: Censo de Equipos' : 'Modo: Registro Nuevo Equipo';

  String get modeSubtitle => _isCensoMode
      ? 'Escanee o ingrese un código para buscar equipos existentes'
      : 'Complete manualmente todos los campos del nuevo equipo';

  IconData get modeIcon => _isCensoMode ? Icons.inventory : Icons.add_box;

  String get codigoHint => _isCensoMode
      ? 'Escanea o ingresa y presiona Enter'
      : 'Código del nuevo equipo';

  String get marcaHint =>
      _isCensoMode ? 'Se completará automáticamente' : 'Seleccionar marca';

  String get modeloHint =>
      _isCensoMode ? 'Se completará automáticamente' : 'Seleccionar modelo';

  String get serieHint => _isCensoMode
      ? 'Se completará automáticamente...'
      : 'Ingrese el número de serie';

  String get logoHint =>
      _isCensoMode ? 'Se completará automáticamente' : 'Seleccionar logo';

  String get fotoRequerimiento =>
      _equipoYaAsignado ? 'Fotos (Opcional)' : 'Fotos (Requerida al menos 1)';

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
