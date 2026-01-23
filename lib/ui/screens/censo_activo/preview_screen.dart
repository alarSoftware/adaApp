import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/viewmodels/preview_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/preview/preview_dialogs.dart';
import 'package:ada_app/ui/widgets/preview/preview_image_section.dart';
import 'package:ada_app/ui/widgets/preview/preview_bottom_bar.dart';
import 'package:ada_app/ui/widgets/preview/preview_cards.dart';
import 'package:ada_app/ui/screens/menu_principal/equipos_clientes_detail_screen.dart';

import 'package:ada_app/ui/screens/clientes/cliente_detail_screen.dart';

import 'dart:io';
import 'dart:convert';

class PreviewScreen extends StatefulWidget {
  final Map<String, dynamic> datos;
  final dynamic historialItem;

  const PreviewScreen({super.key, required this.datos, this.historialItem});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PreviewScreenViewModel viewModel;
  bool _yaConfirmado = false;
  bool _yaReintentando = false;

  String? _imagePath;
  String? _imageBase64;
  String? _imagePath2;
  String? _imageBase64_2;

  @override
  void initState() {
    super.initState();
    viewModel = PreviewScreenViewModel();
    _cargarImagenInicial();

    if (widget.datos['es_historial'] == true) {
      final estadoId = widget.datos['id'] as String?;
      if (estadoId != null) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            viewModel.iniciarMonitoreoSincronizacion(estadoId);
          }
        });
      }
    }
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

          return;
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

            return;
          }
        } catch (e) {}
      }
    } catch (e) {}
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

          return;
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

            return;
          }
        } catch (e) {}
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    viewModel.detenerMonitoreoSincronizacion();
    viewModel.cancelarProcesoActual();
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirmarRegistro() async {
    if (_yaConfirmado) {
      return;
    }

    setState(() {
      _yaConfirmado = true;
    });

    if (!viewModel.canConfirm) {
      _mostrarSnackBar(
        'Ya hay un proceso en curso. Por favor espere.',
        AppColors.warning,
      );
      return;
    }

    final bool? confirmado = await PreviewDialogs.mostrarConfirmacion(context);

    if (confirmado != true) {
      setState(() {
        _yaConfirmado = false;
      });
      return;
    }

    if (!viewModel.canConfirm) {
      _mostrarSnackBar(
        'Ya hay un proceso en curso. Por favor espere.',
        AppColors.warning,
      );
      setState(() {
        _yaConfirmado = false;
      });
      return;
    }

    final datosCompletos = Map<String, dynamic>.from(widget.datos);

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
        if (mounted) {
          await _navegarAEquipoClienteDetail(resultado);
        }
      } else {
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

  Future<void> _navegarAEquipoClienteDetail(
    Map<String, dynamic> resultado,
  ) async {
    try {
      final estadoId = resultado['estado_id'] as String?;

      if (estadoId == null) {
        Navigator.of(context).pop(true);
        return;
      }

      final datosHistorial = Map<String, dynamic>.from(widget.datos);
      datosHistorial['es_historial'] = true;
      datosHistorial['id'] = estadoId;

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                PreviewScreen(datos: datosHistorial, historialItem: null),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _reintentarEnvioHistorial(String? estadoId) async {
    if (_yaReintentando) {
      return;
    }

    setState(() {
      _yaReintentando = true;
    });

    if (estadoId == null || estadoId.isEmpty) {
      _mostrarSnackBar('Error: ID de estado no disponible', AppColors.error);
      setState(() {
        _yaReintentando = false;
      });
      return;
    }

    if (!viewModel.canConfirm) {
      _mostrarSnackBar(
        'Ya hay un proceso en curso. Por favor espere.',
        AppColors.warning,
      );
      setState(() {
        _yaReintentando = false;
      });
      return;
    }

    final resultado = await viewModel.reintentarEnvio(estadoId);

    if (mounted) {
      setState(() {
        _yaReintentando = false;
      });

      if (resultado['success'] == true) {
        final mensaje = resultado['message'] as String? ?? 'Reintento exitoso';
        _mostrarSnackBar(mensaje, AppColors.success);
      } else {
        final error =
            resultado['error'] as String? ?? 'Error al reintentar envío';

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Error en el Reintento'),
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _volverDesdeHistorial() {
    try {
      final cliente = widget.datos['cliente'];
      final equipoCompleto = widget.datos['equipo_completo'];

      if (cliente == null || cliente is! Cliente) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        return;
      }
      final Map<String, dynamic> equipoCliente;

      if (equipoCompleto != null) {
        equipoCliente = {
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
          'tipo_estado':
              equipoCompleto['tipo_estado'] ??
              widget.datos['tipo_estado_original'] ??
              'asignado',
        };
      } else {
        equipoCliente = {
          'id': null,
          'cod_barras': widget.datos['codigo_barras'],
          'numero_serie': widget.datos['numero_serie'],
          'marca_id': widget.datos['marca_id'],
          'modelo_id': widget.datos['modelo_id'],
          'logo_id': widget.datos['logo_id'],
          'cliente_id': cliente.id,
          'marca_nombre': widget.datos['marca'],
          'modelo_nombre': widget.datos['modelo'],
          'logo_nombre': widget.datos['logo'],
          'cliente_nombre': cliente.nombre,
          'cliente_telefono': cliente.telefono,
          'cliente_direccion': cliente.direccion,
          'tipo_estado': 'pendiente',
        };
      }

      if (mounted) {
        // RECONSTRUIR PILA DE NAVEGACIÓN:
        // 1. Ir a la lista de equipos del cliente (Base)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ClienteDetailScreen(cliente: cliente),
          ),
          (route) => route.isFirst,
        );

        // 2. Poner encima el detalle del equipo (Top)
        // Así, al dar Atrás en Detalle, caerás en la Lista.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                EquiposClientesDetailScreen(equipoCliente: equipoCliente),
          ),
        );
      }
    } catch (e) {
      print('Error al volver desde historial: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
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
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;

              if (!vm.canConfirm) {
                PreviewDialogs.mostrarProcesoEnCurso(context);
                return;
              }

              if (widget.datos['es_historial'] == true) {
                if (widget.datos['es_historial_global'] == true) {
                  Navigator.of(context).pop();
                } else {
                  _volverDesdeHistorial();
                }
              } else {
                Navigator.of(context).pop();
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
      automaticallyImplyLeading: true,
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
    final estadoId = widget.datos['id'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esHistorial) _buildSyncStatusIndicator(estadoId),
          ClientInfoCard(cliente: cliente),
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
      final estadoId = widget.datos['id'] as String?;

      return StreamBuilder<Map<String, dynamic>>(
        stream: vm.syncStatusStream,
        initialData: null,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final envioFallido = info?['envioFallido'] == true;

          return PreviewBottomBar(
            esHistorial: esHistorial,
            isSaving: vm.isSaving,
            statusMessage: vm.statusMessage,
            cantidadImagenes: cantidadImagenes,
            onVolver: () => _volverDesdeHistorial(),
            onConfirmar: null,
            onReintentarEnvio:
                (envioFallido && estadoId != null && !_yaReintentando)
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
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

  Widget _buildSyncStatusIndicator(String? estadoId) {
    if (widget.datos['es_historial'] != true || estadoId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: viewModel.syncStatusStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Verificando estado...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final info = snapshot.data!;
        final mensaje = info['mensaje'] as String;
        final icono = info['icono'] as IconData;
        final color = info['color'] as Color;
        final errorDetalle = info['error_detalle'] as String?;

        return SyncStatusIndicator(
          mensaje: mensaje,
          icono: icono,
          color: color,
          errorDetalle: errorDetalle,
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
