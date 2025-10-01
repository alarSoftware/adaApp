import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/preview_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/preview/preview_dialogs.dart';
import 'package:ada_app/ui/widgets/preview/preview_image_section.dart';
import 'package:ada_app/ui/widgets/preview/preview_bottom_bar.dart';
import 'package:ada_app/ui/widgets/preview/preview_cards.dart';
import 'dart:io';
import 'dart:convert';


class PreviewScreen extends StatefulWidget {
  final Map<String, dynamic> datos;
  final dynamic historialItem;

  const PreviewScreen({
    super.key,
    required this.datos,
    this.historialItem,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PreviewScreenViewModel viewModel;
  bool _yaConfirmado = false; // Bandera para bloquear después del primer tap

  String? _imagePath;
  String? _imageBase64;
  String? _imagePath2;
  String? _imageBase64_2;

  @override
  void initState() {
    super.initState();
    viewModel = PreviewScreenViewModel();
    _cargarImagenInicial();
  }

  Future<void> _cargarImagenInicial() async {
    await _cargarImagen1();
    await _cargarImagen2();
  }

  Future<void> _cargarImagen1() async {
    try {
      final imagenPath = widget.datos['imagen_path'] as String?;
      if (imagenPath != null && imagenPath.isNotEmpty) {
        final file = File(imagenPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Data = base64Encode(bytes);

          setState(() {
            _imagePath = imagenPath;
            _imageBase64 = base64Data;
          });

          debugPrint('✅ Imagen 1 cargada desde archivo: $imagenPath');
          return;
        } else {
          debugPrint('⚠️ Archivo de imagen 1 no encontrado: $imagenPath');
        }
      }

      final imagenBase64DB = widget.datos['imagen_base64'] as String?;
      if (imagenBase64DB != null && imagenBase64DB.isNotEmpty) {
        try {
          final bytes = base64Decode(imagenBase64DB);
          if (bytes.isNotEmpty) {
            setState(() {
              _imagePath = null;
              _imageBase64 = imagenBase64DB;
            });

            debugPrint('✅ Imagen 1 cargada desde base64 (${bytes.length} bytes)');
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error decodificando base64 imagen 1: $e');
        }
      }

      debugPrint('ℹ️ No se encontró imagen 1 válida');
    } catch (e) {
      debugPrint('❌ Error cargando imagen 1: $e');
    }
  }

  Future<void> _cargarImagen2() async {
    try {
      final imagenPath2 = widget.datos['imagen_path2'] as String?;
      if (imagenPath2 != null && imagenPath2.isNotEmpty) {
        final file = File(imagenPath2);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Data = base64Encode(bytes);

          setState(() {
            _imagePath2 = imagenPath2;
            _imageBase64_2 = base64Data;
          });

          debugPrint('✅ Imagen 2 cargada desde archivo: $imagenPath2');
          return;
        } else {
          debugPrint('⚠️ Archivo de imagen 2 no encontrado: $imagenPath2');
        }
      }

      final imagenBase64DB_2 = widget.datos['imagen_base64_2'] as String?;
      if (imagenBase64DB_2 != null && imagenBase64DB_2.isNotEmpty) {
        try {
          final bytes = base64Decode(imagenBase64DB_2);
          if (bytes.isNotEmpty) {
            setState(() {
              _imagePath2 = null;
              _imageBase64_2 = imagenBase64DB_2;
            });

            debugPrint('✅ Imagen 2 cargada desde base64 (${bytes.length} bytes)');
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error decodificando base64 imagen 2: $e');
        }
      }

      debugPrint('ℹ️ No se encontró imagen 2 válida');
    } catch (e) {
      debugPrint('❌ Error cargando imagen 2: $e');
    }
  }

  @override
  void dispose() {
    viewModel.cancelarProcesoActual();
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirmarRegistro() async {
    // Verificar si ya se confirmó antes
    if (_yaConfirmado) {
      return; // Ignorar silenciosamente
    }

    if (!viewModel.canConfirm) {
      _mostrarSnackBar('Ya hay un proceso en curso. Por favor espere.', AppColors.warning);
      return;
    }

    final bool? confirmado = await PreviewDialogs.mostrarConfirmacion(context);
    if (confirmado != true) return;

    // Marcar como confirmado inmediatamente después de aceptar el diálogo
    setState(() {
      _yaConfirmado = true;
    });

    if (!viewModel.canConfirm) {
      _mostrarSnackBar('Ya hay un proceso en curso. Por favor espere.', AppColors.warning);
      return;
    }

    final datosCompletos = Map<String, dynamic>.from(widget.datos);

    // Preparar imagen 1
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

    // Preparar imagen 2
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
        // Si hay error, desbloquear para permitir reintentar
        setState(() {
          _yaConfirmado = false;
        });

        await PreviewDialogs.mostrarErrorConReintentar(
          context,
          resultado['error'],
          _confirmarRegistro,
        );
      }
    }
  }

  Future<void> _reintentarEnvioHistorial(int? estadoId) async {
    if (estadoId == null) {
      _mostrarSnackBar('Error: ID de estado no disponible', AppColors.error);
      return;
    }

    final resultado = await viewModel.reintentarEnvio(estadoId);

    if (mounted) {
      if (resultado['success']) {
        _mostrarSnackBar(resultado['message'], AppColors.success);
        setState(() {});
      } else {
        await PreviewDialogs.mostrarErrorConReintentar(
          context,
          resultado['error'],
              () => _reintentarEnvioHistorial(estadoId),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Cliente cliente = widget.datos['cliente'];

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<PreviewScreenViewModel>(
        builder: (context, vm, child) {
          return PopScope(
            canPop: vm.canConfirm,
            onPopInvoked: (didPop) {
              if (!didPop && !vm.canConfirm) {
                PreviewDialogs.mostrarProcesoEnCurso(context);
              }
            },
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: AppColors.background,
                  appBar: _buildAppBar(vm),
                  body: _buildBody(cliente),
                  bottomNavigationBar: _buildBottomBar(vm),
                ),
                if (vm.isSaving) _buildSavingOverlay(vm),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(PreviewScreenViewModel vm) {
    final esHistorial = widget.datos['es_historial'] == true;

    return AppBar(
      title: Text(esHistorial ? 'Detalle del Historial' : 'Confirmar Registro'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      shadowColor: AppColors.shadowLight,
      automaticallyImplyLeading: vm.canConfirm,
      leading: vm.canConfirm
          ? null
          : Container(
        margin: const EdgeInsets.all(12),
        child: CircularProgressIndicator(
          color: AppColors.onPrimary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildBody(Cliente cliente) {
    final esHistorial = widget.datos['es_historial'] == true;
    final estadoId = widget.datos['id'] as int?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esHistorial) _buildSyncStatusIndicator(estadoId),
          PreviewClienteCard(cliente: cliente),
          const SizedBox(height: 16),
          PreviewEquipoCard(datos: widget.datos),
          const SizedBox(height: 16),
          PreviewUbicacionCard(
            datos: widget.datos,
            formatearFecha: viewModel.formatearFecha,
          ),
          const SizedBox(height: 16),
          PreviewImageSection(
            imagePath: _imagePath,
            imageBase64: _imageBase64,
            titulo: 'Primera Foto',
            numero: 1,
            esHistorial: esHistorial,
          ),
          const SizedBox(height: 16),
          PreviewImageSection(
            imagePath: _imagePath2,
            imageBase64: _imageBase64_2,
            titulo: 'Segunda Foto',
            numero: 2,
            esHistorial: esHistorial,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomBar(PreviewScreenViewModel vm) {
    final esHistorial = widget.datos['es_historial'] == true;

    int cantidadImagenes = 0;
    if (_imagePath != null || _imageBase64 != null) cantidadImagenes++;
    if (_imagePath2 != null || _imageBase64_2 != null) cantidadImagenes++;

    if (esHistorial) {
      final estadoId = widget.datos['id'] as int?;

      return FutureBuilder<bool>(
        future: vm.verificarSincronizacionPendiente(estadoId),
        builder: (context, snapshot) {
          final envioFallido = snapshot.data ?? false;

          return PreviewBottomBar(
            esHistorial: esHistorial,
            isSaving: vm.isSaving,
            statusMessage: vm.statusMessage,
            cantidadImagenes: cantidadImagenes,
            onVolver: () => Navigator.of(context).pop(),
            onConfirmar: null,
            onReintentarEnvio: envioFallido ? () => _reintentarEnvioHistorial(estadoId) : null,
          );
        },
      );
    }

    return PreviewBottomBar(
      esHistorial: esHistorial,
      isSaving: vm.isSaving,
      statusMessage: vm.statusMessage,
      cantidadImagenes: cantidadImagenes,
      onVolver: () => Navigator.of(context).pop(),
      onConfirmar: _confirmarRegistro,
      onReintentarEnvio: null,
    );
  }

  Widget _buildSavingOverlay(PreviewScreenViewModel vm) {
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
                Text(
                  vm.statusMessage ?? 'Guardando datos...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusIndicator(int? estadoId) {
    if (widget.datos['es_historial'] != true || estadoId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: viewModel.obtenerInfoSincronizacion(estadoId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final info = snapshot.data!;
        final mensaje = info['mensaje'] as String;
        final icono = info['icono'] as IconData;
        final color = info['color'] as Color;

        return SyncStatusIndicator(
          mensaje: mensaje,
          icono: icono,
          color: color,
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