import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/logo_repository.dart';
import 'preview_screen.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barcode_scan2/barcode_scan2.dart';

final _logger = Logger();

class FormsScreen extends StatefulWidget {
  final Cliente cliente;

  const FormsScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _codigoBarrasController = TextEditingController();
  final _modeloController = TextEditingController();
  final _numeroSerieController = TextEditingController();

  // ✅ CAMBIO PRINCIPAL: Inicializa en modo CENSO (campos bloqueados)
  bool _isCensoMode = true; // true = censo (campos bloqueados), false = nuevo equipo (campos habilitados)

  List<Map<String, dynamic>> _logos = [];
  int? _logoSeleccionado;

  // Estado
  bool _isLoading = false;
  bool _isScanning = false;

  @override
  void initState(){
    super.initState();
    _cargarLogos();
  }

  Future<void> _cargarLogos() async {
    try {
      final logoRepo = LogoRepository();
      final logos = await logoRepo.obtenerTodos();

      if (mounted) {
        setState(() {
          _logos = logos.map((logo) => {
            'id': logo.id,
            'nombre': logo.nombre,
          }).toList();
        });
      }
      _logger.i('Logos cargados ${_logos.length}');
    } catch (e) {
      _logger.e('Error cargando logos: $e');
      if (mounted) {
        _mostrarSnackBar('Error cargando logos', Colors.red);
      }
    }
  }

  @override
  void dispose() {
    _codigoBarrasController.dispose();
    _modeloController.dispose();
    _numeroSerieController.dispose();
    super.dispose();
  }

  // ===============================
  // FUNCIONALIDAD CORREGIDA
  // ===============================

  Future<void> _escanearCodigoBarras() async {
    if (!mounted) return;

    setState(() {
      _isScanning = true;
    });

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

      if (mounted && result.rawContent.isNotEmpty) {
        _codigoBarrasController.text = result.rawContent;
        await _buscarEquipoPorCodigo(result.rawContent);
      }

    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == BarcodeScanner.cameraAccessDenied) {
          _mostrarSnackBar('Permisos de cámara denegados', Colors.red);
        } else {
          _mostrarSnackBar('Error desconocido: ${e.message}', Colors.red);
        }
      }
    } catch (e) {
      _logger.e('Error escaneando código: $e');
      if (mounted) {
        _mostrarSnackBar('Error al escanear código', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _buscarEquipoPorCodigo(String codigo) async {
    if (!mounted) return;

    try {
      _logger.i('Buscando visicooler con código: $codigo');
      _mostrarSnackBar('Buscando visicooler...', Colors.blue);

      final equipoRepo = EquipoRepository();
      final equiposCompletos = await equipoRepo.buscarConFiltros(
        codigoBarras: codigo.trim(),
        soloActivos: true,
      );

      if (!mounted) return;

      if (equiposCompletos.isNotEmpty) {
        // ✅ EQUIPO ENCONTRADO: Modo censo (campos bloqueados y autocompletados)
        final equipoCompleto = equiposCompletos.first;

        setState(() {
          _isCensoMode = true;  // Mantener en modo censo
          _modeloController.text = equipoCompleto['modelo_nombre'] ?? '';
          _logoSeleccionado = equipoCompleto['logo_id'];
          _numeroSerieController.text = equipoCompleto['numero_serie'] ?? 'Sin número de serie';
        });

        _logger.i('Visicooler encontrado: ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']}');
        _mostrarSnackBar('Visicooler encontrado: ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo_nombre']}', Colors.green);

      } else {
        // ✅ EQUIPO NO ENCONTRADO: Mostrar diálogo
        _logger.w('Visicooler no encontrado con código: $codigo');
        _limpiarDatosAutocompletados();
        _mostrarDialogoEquipoNoEncontrado(codigo);
      }

    } catch (e, stackTrace) {
      _logger.e('Error buscando visicooler: $e', stackTrace: stackTrace);
      if (mounted) {
        _limpiarDatosAutocompletados();
        _mostrarSnackBar('Error al consultar la base de datos', Colors.red);
      }
    }
  }

  Future<void> _mostrarDialogoEquipoNoEncontrado(String codigo) async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.search_off,
                color: Colors.grey[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Equipo no encontrado',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El código "$codigo" no se encuentra en el sistema.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Desea registrar un nuevo equipo?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Complete manualmente los datos del equipo'),
                    const Text('• El código actual se mantendrá'),
                    const Text('• Podrá corregir el código si es necesario'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // ✅ Mantener en modo censo y limpiar el código para que puedan corregirlo
                _codigoBarrasController.clear();
                _limpiarDatosAutocompletados();
              },
              child: const Text('Corregir código'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // ✅ CAMBIAR A MODO NUEVO EQUIPO
                _habilitarModoNuevoEquipo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Registrar nuevo equipo'),
            ),
          ],
        );
      },
    );
  }

  void _onCodigoChanged(String codigo) {
    if (codigo.isEmpty) {
      _limpiarDatosAutocompletados();
      // ✅ Si borra el código, volver a modo censo
      setState(() {
        _isCensoMode = true;
      });
    }
  }

  void _onCodigoSubmitted(String codigo) {
    if (codigo.length >= 3) {
      _buscarEquipoPorCodigo(codigo);
    } else if (codigo.isNotEmpty) {
      _mostrarSnackBar('El código debe tener al menos 3 caracteres', Colors.orange);
    }
  }

  void _habilitarModoNuevoEquipo() {
    if (!mounted) return;

    setState(() {
      _isCensoMode = false;  // ✅ Cambiar a modo nuevo equipo (campos habilitados)
      // No limpiar el código de barras - mantenerlo
      _modeloController.clear();
      _numeroSerieController.clear();
      _logoSeleccionado = null;
    });

    _mostrarSnackBar('Modo: Registrar nuevo equipo. Complete todos los campos', Colors.blue);
  }

  Future<void> _continuarAPreview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _logger.i('Obteniendo ubicación GPS del visicooler...');
      _mostrarSnackBar('Obteniendo ubicación GPS precisa...', Colors.blue);

      final ubicacion = await _obtenerUbicacion();
      _logger.i('Ubicación obtenida: ${ubicacion['latitud']}, ${ubicacion['longitud']}');

      if (!mounted) return;

      final datosCompletos = {
        'cliente': widget.cliente,
        'codigo_barras': _codigoBarrasController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'logo_id': _logoSeleccionado,
        'logo': _logos.firstWhere((logo) => logo['id'] == _logoSeleccionado, orElse: () => {'nombre': ''})['nombre'],
        'numero_serie': _numeroSerieController.text.trim(),
        'latitud': ubicacion['latitud'],
        'longitud': ubicacion['longitud'],
        'fecha_registro': DateTime.now().toIso8601String(),
        'timestamp_gps': DateTime.now().millisecondsSinceEpoch,
        // ✅ Agregar información del modo
        'es_censo': _isCensoMode,
      };

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(datos: datosCompletos),
        ),
      );

      if (mounted && result == true) {
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      _logger.e('Error obteniendo ubicación: $e');
      if (mounted) {
        await _mostrarDialogoErrorGPS(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  Future<void> _mostrarDialogoErrorGPS(String error) async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.gps_off,
                color: Colors.red[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Error de Ubicación',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No se pudo obtener la ubicación GPS del visicooler.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Error: $error',
                style: TextStyle(fontSize: 14, color: Colors.red[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ubicación Requerida',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La ubicación GPS es obligatoria para registrar visicoolers. Asegúrese de estar en la ubicación exacta del equipo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _continuarAPreview();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reintentar GPS'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  void _limpiarDatosAutocompletados() {
    _modeloController.clear();
    _numeroSerieController.clear();
    if (mounted) {
      setState(() {
        _logoSeleccionado = null;
      });
    }
  }

  // ===============================
  // VALIDADORES
  // ===============================

  String? _validarCodigoBarras(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código de barras es requerido';
    }
    if (value.trim().length < 3) {
      return 'El código debe tener al menos 3 caracteres';
    }
    return null;
  }

  String? _validarModelo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El modelo del visicooler es requerido';
    }
    return null;
  }

  String? _validarLogo(int? value) {
    if (value == null) {
      return 'El logo es requerido';
    }
    return null;
  }

  String? _validarNumeroSerie(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El número de serie es requerido';
    }
    return null;
  }

  // ===============================
  // WIDGETS
  // ===============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // ✅ El título cambia según el modo, pero colores neutros
      title: Text(_isCensoMode ? 'Censo de Equipos' : 'Agregar Nuevo Equipo'),
      backgroundColor: Colors.grey[600],
      foregroundColor: Colors.white,
      elevation: 2,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: 16.0 + MediaQuery.of(context).padding.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Agregar indicador de modo
            _buildModeIndicator(),
            const SizedBox(height: 16),
            _buildFormulario(),
          ],
        ),
      ),
    );
  }

  // ✅ Widget para mostrar el modo actual - colores neutros
  Widget _buildModeIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _isCensoMode ? Icons.inventory : Icons.add_box,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCensoMode ? 'Modo: Censo de Equipos' : 'Modo: Registro Nuevo Equipo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  _isCensoMode
                      ? 'Escanee o ingrese un código para buscar equipos existentes'
                      : 'Complete manualmente todos los campos del nuevo equipo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCodigoBarrasField(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _modeloController,
              label: 'Modelo:',
              hint: _isCensoMode ? 'Se completará automáticamente...' : 'Ingrese el modelo del equipo',
              icon: Icons.devices,
              validator: _validarModelo,
              enabled: !_isCensoMode, // ✅ Bloqueado en modo censo
              backgroundColor: _isCensoMode ? Colors.grey[50] : null,
            ),
            const SizedBox(height: 16),
            _buildLogoDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _numeroSerieController,
              label: 'Serie:',
              hint: _isCensoMode ? 'Se completará automáticamente...' : 'Ingrese el número de serie',
              icon: Icons.confirmation_number,
              validator: _validarNumeroSerie,
              enabled: !_isCensoMode, // ✅ Bloqueado en modo censo
              backgroundColor: _isCensoMode ? Colors.grey[50] : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodigoBarrasField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Código de activo:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _codigoBarrasController,
                validator: _validarCodigoBarras,
                onChanged: _onCodigoChanged,
                onFieldSubmitted: _onCodigoSubmitted,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _isCensoMode
                      ? 'Escanea o ingresa y presiona Enter'
                      : 'Código del nuevo equipo',
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _codigoBarrasController.clear();
                      _limpiarDatosAutocompletados();
                      setState(() {
                        _isCensoMode = true; // Volver a modo censo al limpiar
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: _isLoading || _isScanning ? null : _escanearCodigoBarras,
                icon: _isScanning
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: 'Escanear código',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    Color? backgroundColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            fillColor: backgroundColor,
            filled: backgroundColor != null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _continuarAPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Procesando...'),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isCensoMode ? Icons.assignment : Icons.add_box,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_isCensoMode ? 'Registrar Censo' : 'Registrar Nuevo'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          child: DropdownButtonFormField<int>(
            value: _logos.any((logo) => logo['id'] == _logoSeleccionado)
                ? _logoSeleccionado
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.branding_watermark),
              fillColor: _isCensoMode ? Colors.grey[50] : null,
              filled: _isCensoMode,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            hint: Text(
              _isCensoMode ? 'Se completará automáticamente' : 'Seleccionar logo',
              overflow: TextOverflow.ellipsis,
            ),
            items: _logos.map((logo) {
              return DropdownMenuItem<int>(
                value: logo['id'] is int ? logo['id'] : int.tryParse(logo['id'].toString()),
                child: Container(
                  width: double.infinity,
                  child: Text(
                    logo['nombre'],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
            onChanged: _isCensoMode ? null : (value) {
              setState(() {
                _logoSeleccionado = value;
              });
            },
            validator: _validarLogo,
          ),
        ),
      ],
    );
  }
}