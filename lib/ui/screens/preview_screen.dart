import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/preview_screen_viewmodel.dart';
import 'dart:io';
import 'dart:convert';

class PreviewScreen extends StatefulWidget {
  final Map<String, dynamic> datos;

  const PreviewScreen({
    super.key,
    required this.datos,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PreviewScreenViewModel viewModel;

  // ✅ CAMBIO 1: AGREGAR VARIABLES PARA SEGUNDA IMAGEN
  String? _imagePath;
  String? _imageBase64;
  String? _imagePath2;     // NUEVA
  String? _imageBase64_2;  // NUEVA

  @override
  void initState() {
    super.initState();
    viewModel = PreviewScreenViewModel();
    _cargarImagenInicial();
  }

  // ✅ CAMBIO 2: ACTUALIZAR MÉTODO PARA CARGAR AMBAS IMÁGENES
  Future<void> _cargarImagenInicial() async {
    // Cargar primera imagen
    final imagenPath = widget.datos['imagen_path'] as String?;
    if (imagenPath != null && imagenPath.isNotEmpty) {
      try {
        final file = File(imagenPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Data = base64Encode(bytes);

          setState(() {
            _imagePath = imagenPath;
            _imageBase64 = base64Data;
          });
        }
      } catch (e) {
        debugPrint('Error cargando imagen 1: $e');
      }
    }

    // Cargar segunda imagen
    final imagenPath2 = widget.datos['imagen_path2'] as String?;
    if (imagenPath2 != null && imagenPath2.isNotEmpty) {
      try {
        final file = File(imagenPath2);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Data = base64Encode(bytes);

          setState(() {
            _imagePath2 = imagenPath2;
            _imageBase64_2 = base64Data;
          });
        }
      } catch (e) {
        debugPrint('Error cargando imagen 2: $e');
      }
    }
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  // ✅ CAMBIO 3: ACTUALIZAR MÉTODO DE CONFIRMACIÓN PARA INCLUIR SEGUNDA IMAGEN
  Future<void> _confirmarRegistro() async {
    final datosCompletos = Map<String, dynamic>.from(widget.datos);

    // Primera imagen
    if (_imagePath != null && _imageBase64 != null) {
      final bytes = base64Decode(_imageBase64!);
      datosCompletos['imagen_path'] = _imagePath;
      datosCompletos['imagen_base64'] = _imageBase64;
      datosCompletos['tiene_imagen'] = true;
      datosCompletos['imagen_tamano'] = bytes.length;
    } else {
      datosCompletos['tiene_imagen'] = false;
      datosCompletos['imagen_path'] = null;
      datosCompletos['imagen_base64'] = null;
      datosCompletos['imagen_tamano'] = null;
    }

    // Segunda imagen
    if (_imagePath2 != null && _imageBase64_2 != null) {
      final bytes2 = base64Decode(_imageBase64_2!);
      datosCompletos['imagen_path2'] = _imagePath2;
      datosCompletos['imagen_base64_2'] = _imageBase64_2;
      datosCompletos['tiene_imagen2'] = true;
      datosCompletos['imagen_tamano2'] = bytes2.length;
    } else {
      datosCompletos['tiene_imagen2'] = false;
      datosCompletos['imagen_path2'] = null;
      datosCompletos['imagen_base64_2'] = null;
      datosCompletos['imagen_tamano2'] = null;
    }

    final resultado = await viewModel.confirmarRegistro(datosCompletos);

    if (mounted) {
      if (resultado['success']) {
        _mostrarSnackBar(resultado['message'], AppColors.success);
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(true);
      } else {
        await _mostrarDialogoErrorConfirmacion(resultado['error']);
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final Cliente cliente = widget.datos['cliente'];

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildBody(cliente),
            Consumer<PreviewScreenViewModel>(
              builder: (context, vm, child) {
                if (!vm.isSaving) return const SizedBox.shrink();
                return _buildSavingOverlay();
              },
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomButtons(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Confirmar Registro'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      shadowColor: AppColors.shadowLight,
    );
  }

  Widget _buildBody(Cliente cliente) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClienteCard(cliente),
          const SizedBox(height: 16),
          _buildEquipoCard(),
          const SizedBox(height: 16),
          _buildUbicacionCard(),
          const SizedBox(height: 16),

          // ✅ CAMBIO 4: AGREGAR SEGUNDA TARJETA DE IMAGEN
          _buildImagenCard(_imagePath, _imageBase64, 'Primera fo', 1),
          const SizedBox(height: 16),
          _buildImagenCard(_imagePath2, _imageBase64_2, 'Segunda Foto', 2),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ✅ CAMBIO 5: MÉTODO REUTILIZABLE PARA MOSTRAR CUALQUIER IMAGEN
  Widget _buildImagenCard(String? imagePath, String? imageBase64, String titulo, int numero) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: numero == 1 ? AppColors.secondary : AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (imagePath != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Incluida',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),

            if (imagePath != null) ...[
              GestureDetector(
                onTap: () => _verImagenCompleta(imagePath),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error cargando imagen',
                                    style: TextStyle(color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              const Text(
                                'Ver',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (imageBase64 != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Imagen preparada para envio (${(base64Decode(imageBase64).length / (1024 * 1024)).toStringAsFixed(1)} MB). Toca para ver completa.',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                  color: Colors.grey[50],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin imagen',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Use "Volver a Editar" para agregar una',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ CAMBIO 6: ACTUALIZAR PARA RECIBIR PATH COMO PARÁMETRO
  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Procesando Censo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<PreviewScreenViewModel>(
                  builder: (context, vm, child) {
                    return Text(
                      vm.statusMessage ?? 'Guardando datos...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verImagenCompleta(String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteCard(Cliente cliente) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppColors.secondary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informacion del Cliente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            _buildInfoRow('Nombre', cliente.nombre, Icons.account_circle),
            _buildInfoRow('Direccion', cliente.direccion, Icons.location_on),
            _buildInfoRow('Telefono', cliente.telefono ?? 'No especificado', Icons.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipoCard() {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.devices,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Datos del Visicooler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            _buildInfoRow(
              'Codigo de Barras',
              widget.datos['codigo_barras'] ?? 'No especificado',
              Icons.qr_code,
            ),
            _buildInfoRow(
              'Modelo del Equipo',
              widget.datos['modelo'] ?? 'No especificado',
              Icons.devices,
            ),
            _buildInfoRow(
              'Logo',
              widget.datos['logo'] ?? 'No especificado',
              Icons.business,
            ),
            if (widget.datos['observaciones'] != null && widget.datos['observaciones'].toString().isNotEmpty)
              _buildInfoRow(
                'Observaciones',
                widget.datos['observaciones'].toString(),
                Icons.note_add,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUbicacionCard() {
    final latitud = widget.datos['latitud'];
    final longitud = widget.datos['longitud'];
    final fechaRegistro = widget.datos['fecha_registro'];

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informacion de Registro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            _buildInfoRow(
              'Latitud',
              latitud != null ? latitud.toStringAsFixed(6) : 'No disponible',
              Icons.explore,
            ),
            _buildInfoRow(
              'Longitud',
              longitud != null ? longitud.toStringAsFixed(6) : 'No disponible',
              Icons.explore_off,
            ),
            Consumer<PreviewScreenViewModel>(
              builder: (context, vm, child) {
                return _buildInfoRow(
                  'Fecha y Hora',
                  vm.formatearFecha(fechaRegistro?.toString()),
                  Icons.access_time,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'No especificado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ CAMBIO 7: ACTUALIZAR TEXTO DEL BOTÓN SEGÚN CANTIDAD DE IMÁGENES
  Widget _buildBottomButtons() {
    return Consumer<PreviewScreenViewModel>(
      builder: (context, vm, child) {
        // Contar imágenes
        int cantidadImagenes = 0;
        if (_imagePath != null) cantidadImagenes++;
        if (_imagePath2 != null) cantidadImagenes++;

        String textoBoton = 'Confirmar Registro';
        if (cantidadImagenes == 1) {
          textoBoton = 'Confirmar con 1 Imagen';
        } else if (cantidadImagenes == 2) {
          textoBoton = 'Confirmar con 2 Imágenes';
        }

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vm.statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: AppColors.info, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: vm.isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Volver a Editar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: vm.isSaving ? null : _confirmarRegistro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: vm.isSaving
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.onPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'Registrando...',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                textoBoton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _mostrarDialogoErrorConfirmacion(String error) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error en Confirmacion',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hubo un problema al procesar el registro:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.error,
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Datos Protegidos',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sus datos estan guardados localmente y no se perderan. Se sincronizaran automaticamente cuando se resuelva el problema.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Entendido'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}