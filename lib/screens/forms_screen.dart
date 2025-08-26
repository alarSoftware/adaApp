import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cliente.dart';
import '../repositories/equipo_repository.dart';
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
  final _logoController = TextEditingController();
  final _numeroSerieController = TextEditingController();

  // Estado
  bool _isLoading = false;
  bool _isScanning = false;

  @override
  void dispose() {
    _codigoBarrasController.dispose();
    _modeloController.dispose();
    _logoController.dispose();
    _numeroSerieController.dispose();
    super.dispose();
  }

  // ===============================
  // FUNCIONALIDAD REAL
  // ===============================

  Future<void> _escanearCodigoBarras() async {
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

      if (result.rawContent.isNotEmpty) {
        _codigoBarrasController.text = result.rawContent;
        await _buscarEquipoPorCodigo(result.rawContent);
      }

    } on PlatformException catch (e) {
      if (e.code == BarcodeScanner.cameraAccessDenied) {
        _mostrarSnackBar('Permisos de cámara denegados', Colors.red);
      } else {
        _mostrarSnackBar('Error desconocido: ${e.message}', Colors.red);
      }
    } catch (e) {
      _logger.e('Error escaneando código: $e');
      _mostrarSnackBar('Error al escanear código', Colors.red);
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _buscarEquipoPorCodigo(String codigo) async {
    try {
      _logger.i('Buscando visicooler con código: $codigo');
      _mostrarSnackBar('Buscando visicooler...', Colors.blue);

      final equipoRepo = EquipoRepository();
      final equiposCompletos = await equipoRepo.buscarConFiltros(
        codigoBarras: codigo.trim(),
        soloActivos: true,
      );

      if (equiposCompletos.isNotEmpty) {
        final equipoCompleto = equiposCompletos.first;

        setState(() {
          _modeloController.text = equipoCompleto['modelo'] ?? '';
          _logoController.text = equipoCompleto['logo_nombre'] ?? '';
          _numeroSerieController.text = equipoCompleto['numero_serie'] ?? 'Sin número de serie';
        });

        _logger.i('Visicooler encontrado: ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo']}');
        _mostrarSnackBar('Visicooler encontrado: ${equipoCompleto['marca_nombre']} ${equipoCompleto['modelo']}', Colors.green);

      } else {
        _logger.w('Visicooler no encontrado con código: $codigo');
        _limpiarDatosAutocompletados();
        _mostrarDialogoEquipoNoEncontrado(codigo);
      }

    } catch (e, stackTrace) {
      _logger.e('Error buscando visicooler: $e', stackTrace: stackTrace);
      _limpiarDatosAutocompletados();
      _mostrarSnackBar('Error al consultar la base de datos', Colors.red);
    }
  }

  Future<void> _mostrarDialogoEquipoNoEncontrado(String codigo) async {
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
                color: Colors.orange[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Visicooler no encontrado',
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
                      'Posibles causas:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• El visicooler no está registrado en el sistema'),
                    const Text('• Error en el código escaneado o ingresado'),
                    const Text('• Los datos no están sincronizados con el servidor'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Corregir código'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _codigoBarrasController.clear();
                _limpiarDatosAutocompletados();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Limpiar'),
            ),
          ],
        );
      },
    );
  }

  void _onCodigoChanged(String codigo) {
    if (codigo.isEmpty) {
      _limpiarDatosAutocompletados();
    }
  }

  void _onCodigoSubmitted(String codigo) {
    if (codigo.length >= 3) {
      _buscarEquipoPorCodigo(codigo);
    } else if (codigo.isNotEmpty) {
      _mostrarSnackBar('El código debe tener al menos 3 caracteres', Colors.orange);
    }
  }

  Future<void> _continuarAPreview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _logger.i('Obteniendo ubicación GPS del visicooler...');
      _mostrarSnackBar('Obteniendo ubicación GPS precisa...', Colors.blue);

      final ubicacion = await _obtenerUbicacion();
      _logger.i('Ubicación obtenida: ${ubicacion['latitud']}, ${ubicacion['longitud']}');

      final datosCompletos = {
        'cliente': widget.cliente,
        'codigo_barras': _codigoBarrasController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'logo': _logoController.text.trim(),
        'numero_serie': _numeroSerieController.text.trim(),
        'latitud': ubicacion['latitud'],
        'longitud': ubicacion['longitud'],
        'fecha_registro': DateTime.now().toIso8601String(),
        'timestamp_gps': DateTime.now().millisecondsSinceEpoch,
      };

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(datos: datosCompletos),
        ),
      );

      if (result == true) {
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      _logger.e('Error obteniendo ubicación: $e');
      await _mostrarDialogoErrorGPS(e.toString());

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

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'El servicio de ubicación está deshabilitado. Active el GPS para continuar.';
      }

      // Verificar permisos
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

      // Obtener posición con alta precisión
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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ubicación Requerida',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La ubicación GPS es obligatoria para registrar visicoolers. Asegúrese de estar en la ubicación exacta del equipo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[700],
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
                backgroundColor: Colors.blue[600],
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

  void _limpiarFormulario() {
    _codigoBarrasController.clear();
    _limpiarDatosAutocompletados();
  }

  void _limpiarDatosAutocompletados() {
    _modeloController.clear();
    _logoController.clear();
    _numeroSerieController.clear();
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

  String? _validarLogo(String? value) {
    if (value == null || value.trim().isEmpty) {
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
      title: const Text('Censo de Visicoolers'),
      backgroundColor: Colors.grey[600],
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _limpiarFormulario,
          icon: const Icon(Icons.clear_all),
          tooltip: 'Limpiar formulario',
        ),
      ],
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
            _buildFormulario(),
          ],
        ),
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
              hint: 'Se completará automáticamente...',
              icon: Icons.devices,
              validator: _validarModelo,
              enabled: false,
              backgroundColor: Colors.grey[50],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _logoController,
              label: 'Logo:',
              hint: 'Se completará automáticamente...',
              icon: Icons.branding_watermark,
              validator: _validarLogo,
              enabled: false,
              backgroundColor: Colors.grey[50],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _numeroSerieController,
              label: 'Serie:',
              hint: 'Se completará automáticamente...',
              icon: Icons.confirmation_number,
              validator: _validarNumeroSerie,
              enabled: false,
              backgroundColor: Colors.grey[50],
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
                  hintText: 'Escanea o ingresa y presiona Enter',
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _codigoBarrasController.clear();
                      _limpiarDatosAutocompletados();
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
                color: Colors.orange[600],
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
              borderSide: BorderSide(color: Colors.orange[600]!),
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
                  backgroundColor: Colors.orange[600],
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
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward, size: 20),
                    SizedBox(width: 8),
                    Text('Continuar'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}