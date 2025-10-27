import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/preview_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/preview/preview_dialogs.dart';
import 'package:ada_app/ui/widgets/preview/preview_image_section.dart';
import 'package:ada_app/ui/widgets/preview/preview_bottom_bar.dart';
import 'package:ada_app/ui/widgets/preview/preview_cards.dart';
import 'package:ada_app/ui/screens/equipos_clientes_detail_screen.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
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
          debugPrint('📊 Tamaño: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');

          // ⚠️ ADVERTENCIA si es muy pequeña
          if (bytes.length < 10240) {
            debugPrint('⚠️ ADVERTENCIA: Imagen 1 muy pequeña (< 10 KB)');
          }

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

            // ⚠️ ADVERTENCIA si es muy pequeña
            if (bytes.length < 10240) {
              debugPrint('⚠️ ADVERTENCIA: Imagen 1 muy pequeña (< 10 KB)');
            }

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
          debugPrint('📊 Tamaño: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');

          // ⚠️ ADVERTENCIA si es muy pequeña
          if (bytes.length < 10240) {
            debugPrint('⚠️ ADVERTENCIA: Imagen 2 muy pequeña (< 10 KB)');
          }

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

            // ⚠️ ADVERTENCIA si es muy pequeña
            if (bytes.length < 10240) {
              debugPrint('⚠️ ADVERTENCIA: Imagen 2 muy pequeña (< 10 KB)');
            }

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

    // ✅ CRÍTICO: Marcar como confirmado INMEDIATAMENTE, antes de cualquier otra cosa
    setState(() {
      _yaConfirmado = true;
    });

    if (!viewModel.canConfirm) {
      _mostrarSnackBar('Ya hay un proceso en curso. Por favor espere.', AppColors.warning);
      return;
    }

    final bool? confirmado = await PreviewDialogs.mostrarConfirmacion(context);

    // ✅ Si cancela el diálogo, rehabilitar el botón
    if (confirmado != true) {
      setState(() {
        _yaConfirmado = false;
      });
      return;
    }

    // Ya no necesitamos volver a marcar _yaConfirmado aquí porque ya lo hicimos arriba

    if (!viewModel.canConfirm) {
      _mostrarSnackBar('Ya hay un proceso en curso. Por favor espere.', AppColors.warning);
      setState(() {
        _yaConfirmado = false;
      });
      return;
    }

    // ✅ LOGS PARA DEBUGGING
    debugPrint('🔍 === ESTADO ANTES DE PREPARAR DATOS ===');
    debugPrint('🔍 _imagePath: $_imagePath');
    debugPrint('🔍 _imageBase64 != null: ${_imageBase64 != null}');
    debugPrint('🔍 _imageBase64 length: ${_imageBase64?.length ?? 0}');
    debugPrint('🔍 _imagePath2: $_imagePath2');
    debugPrint('🔍 _imageBase64_2 != null: ${_imageBase64_2 != null}');
    debugPrint('🔍 _imageBase64_2 length: ${_imageBase64_2?.length ?? 0}');
    debugPrint('🔍 widget.datos[imagen_path]: ${widget.datos['imagen_path']}');
    debugPrint('🔍 widget.datos[imagen_base64] != null: ${widget.datos['imagen_base64'] != null}');

    final datosCompletos = Map<String, dynamic>.from(widget.datos);

    // Preparar imagen 1 con logging mejorado
    if (_imagePath != null && _imageBase64 != null) {
      final bytes = base64Decode(_imageBase64!);

      debugPrint('📸 IMAGEN 1 PREPARADA:');
      debugPrint('   Path: $_imagePath');
      debugPrint('   Tamaño: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');

      datosCompletos['imagen_path'] = _imagePath;
      datosCompletos['imagen_base64'] = _imageBase64;
      datosCompletos['tiene_imagen'] = true;
      datosCompletos['imagen_tamano'] = bytes.length;

      debugPrint('✅ datosCompletos actualizado con imagen 1');
    } else {
      debugPrint('⚠️ IMAGEN 1 NO DISPONIBLE');
      debugPrint('   _imagePath: $_imagePath');
      debugPrint('   _imageBase64 != null: ${_imageBase64 != null}');

      datosCompletos['tiene_imagen'] = false;
      datosCompletos['imagen_path'] = null;
      datosCompletos['imagen_base64'] = null;
      datosCompletos['imagen_tamano'] = null;
    }

    // Preparar imagen 2 con logging mejorado
    if (_imagePath2 != null && _imageBase64_2 != null) {
      final bytes2 = base64Decode(_imageBase64_2!);

      debugPrint('📸 IMAGEN 2 PREPARADA:');
      debugPrint('   Path: $_imagePath2');
      debugPrint('   Tamaño: ${bytes2.length} bytes (${(bytes2.length / 1024).toStringAsFixed(2)} KB)');

      datosCompletos['imagen_path2'] = _imagePath2;
      datosCompletos['imagen_base64_2'] = _imageBase64_2;
      datosCompletos['tiene_imagen2'] = true;
      datosCompletos['imagen_tamano2'] = bytes2.length;

      debugPrint('✅ datosCompletos actualizado con imagen 2');
    } else {
      debugPrint('⚠️ IMAGEN 2 NO DISPONIBLE');
      debugPrint('   _imagePath2: $_imagePath2');
      debugPrint('   _imageBase64_2 != null: ${_imageBase64_2 != null}');

      datosCompletos['tiene_imagen2'] = false;
      datosCompletos['imagen_path2'] = null;
      datosCompletos['imagen_base64_2'] = null;
      datosCompletos['imagen_tamano2'] = null;
    }

    debugPrint('🔍 === VERIFICACIÓN FINAL ===');
    debugPrint('🔍 datosCompletos[tiene_imagen]: ${datosCompletos['tiene_imagen']}');
    debugPrint('🔍 datosCompletos[imagen_base64] != null: ${datosCompletos['imagen_base64'] != null}');
    debugPrint('🔍 datosCompletos[imagen_base64] length: ${datosCompletos['imagen_base64']?.toString().length ?? 0}');

    print('🔍 DEBUG: Iniciando confirmación de registro...');
    final resultado = await viewModel.confirmarRegistro(datosCompletos);
    print('🔍 DEBUG: Resultado recibido: $resultado');

    if (mounted) {
      print('🔍 DEBUG: Widget mounted = true');

      if (resultado['success']) {
        print('✅ DEBUG: Resultado success = true');

        // ✅ Navegar INMEDIATAMENTE sin delays
        if (mounted) {
          print('✅ DEBUG: Navegando a detalle del equipo...');
          await _navegarAEquipoClienteDetail();
          print('✅ DEBUG: Navegación completada');
        }
      } else {
        print('❌ DEBUG: Resultado success = false, error: ${resultado['error']}');

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
    } else {
      print('❌ DEBUG: Widget NO mounted inmediatamente después del resultado');
    }
  }

  Future<void> _navegarAEquipoClienteDetail() async {
    try {
      print('=== NAVEGANDO A EQUIPO DETAIL DESPUÉS DE CENSO ===');

      final cliente = widget.datos['cliente'] as Cliente;
      final equipoCompleto = widget.datos['equipo_completo'];

      if (cliente.id == null || equipoCompleto == null) {
        Navigator.of(context).pop(true);
        return;
      }

      final equipoCliente = {
        'id': equipoCompleto['id'],
        'cod_barras': equipoCompleto['cod_barras'],
        'numero_serie': equipoCompleto['numero_serie'],
        'marca_id': equipoCompleto['marca_id'],
        'modelo_id': equipoCompleto['modelo_id'],
        'logo_id': equipoCompleto['logo_id'],
        'cliente_id': cliente.id,
        'marca_nombre': equipoCompleto['marca_nombre'],
        'modelo_nombre': equipoCompleto['modelo_nombre'],
        'logo_nombre': equipoCompleto['logo_nombre'],
        'cliente_nombre': cliente.nombre,
        'cliente_telefono': cliente.telefono,
        'cliente_direccion': cliente.direccion,
        'tipo_estado': widget.datos['ya_asignado'] == true ? 'asignado' : 'pendiente',
      };

      print('Navegando con datos del censo:');
      print('  cliente_id: ${cliente.id}');
      print('  tipo_estado: ${equipoCliente['tipo_estado']}');

      // ✅ CAMBIO: Solo hacer pop 2 veces para cerrar PreviewScreen y FormsScreen
      // Esto te deja en ClienteDetailScreen
      Navigator.of(context).pop(); // Cierra PreviewScreen
      Navigator.of(context).pop(); // Cierra FormsScreen

      // Ahora navega a EquiposClientesDetailScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EquiposClientesDetailScreen(
            equipoCliente: equipoCliente,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error navegando: $e');
      debugPrint('StackTrace: $stackTrace');
      Navigator.of(context).pop(true);
    }
  }

  // ✅ CORRECCIÓN: Cambiar int? a String?
  Future<void> _reintentarEnvioHistorial(String? estadoId) async {
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
    // ✅ CORRECCIÓN: Cambiar int? a String?
    final estadoId = widget.datos['id'] as String?;

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
      // ✅ CORRECCIÓN: Cambiar int? a String?
      final estadoId = widget.datos['id'] as String?;

      return FutureBuilder<Map<String, dynamic>>(
        future: vm.obtenerInfoSincronizacion(estadoId),
        builder: (context, snapshot) {
          final info = snapshot.data;
          // ✅ SOLO mostrar reintentar si el estado es 'error' (no 'creado' o 'pendiente')
          final envioFallido = info?['estado'] == 'error';

          return PreviewBottomBar(
            esHistorial: esHistorial,
            isSaving: vm.isSaving,
            statusMessage: vm.statusMessage,
            cantidadImagenes: cantidadImagenes,
            onVolver: () => Navigator.of(context).pop(),
            onConfirmar: null, // No mostrar confirmar en historial
            onReintentarEnvio: envioFallido && estadoId != null
                ? () => _reintentarEnvioHistorial(estadoId)
                : null,
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
      onConfirmar: _yaConfirmado ? null : _confirmarRegistro,
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

  // ✅ CORRECCIÓN: Cambiar int? a String?
  Widget _buildSyncStatusIndicator(String? estadoId) {
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