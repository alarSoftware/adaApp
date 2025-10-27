import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/equipos_clientes_detail_screen_viewmodel.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/services/database_helper.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:ada_app/ui/screens/preview_screen.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/cliente_repository.dart';


class EquiposClientesDetailScreen extends StatefulWidget {
  final dynamic equipoCliente;

  const EquiposClientesDetailScreen({
    super.key,
    required this.equipoCliente,
  });
  @override
  State<EquiposClientesDetailScreen> createState() => _EquiposClientesDetailScreenState();
}

class _EquiposClientesDetailScreenState extends State<EquiposClientesDetailScreen> {
  late EquiposClienteDetailScreenViewModel _viewModel;
  late StreamSubscription<EquiposClienteDetailUIEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
    _viewModel = EquiposClienteDetailScreenViewModel(
      widget.equipoCliente,
      EstadoEquipoRepository(),
      EquipoRepository(), // Agregar esta línea
    );
    _setupEventListener();
  }

  void _checkDatabase() async {
    final db = DatabaseHelper();
    try {
      final tablas = await db.obtenerNombresTablas();
      print('Tablas disponibles: $tablas');

      if (tablas.contains('censo_activo')) {
        final esquema = await db.obtenerEsquemaTabla('censo_activo');
        print('Esquema censo_activo: $esquema');
      } else {
        print('Tabla censo_activo NO existe');
      }
    } catch (e) {
      print('Error verificando DB: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription = _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowMessageEvent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.message),
            backgroundColor: _getMessageColor(event.type),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    });
  }

  Color _getMessageColor(MessageType type) {
    switch (type) {
      case MessageType.success:
        return AppColors.success;
      case MessageType.error:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Detalle del Equipo',
          style: TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
          // SOLO MOSTRAR BOTÓN DE GUARDAR PARA EQUIPOS ACTIVOS/ASIGNADOS
          if (_viewModel.isEquipoActivo)
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, child) {
                final canSave = _viewModel.saveButtonEnabled;
                final buttonText = _viewModel.saveButtonText;

                return TextButton.icon(
                  onPressed: canSave ? _showSaveConfirmation : null,
                  icon: Icon(
                    Icons.save,
                    color: canSave ? AppColors.onPrimary : AppColors.onPrimary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  label: Text(
                    buttonText,
                    style: TextStyle(
                      color: canSave ? AppColors.onPrimary : AppColors.onPrimary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 16.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClienteInfo(),
              SizedBox(height: 32),
              _buildEquipoInfo(),
              SizedBox(height: 32),
              _buildActionButtons(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClienteInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipo asignado a: ${widget.equipoCliente['cliente_nombre'] ?? 'Cliente'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipoInfo() {
    return Card(
      elevation: 3,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del equipo
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.kitchen,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _viewModel.getNombreCompletoEquipo(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: _viewModel.equipoCliente['tipo_estado'] == 'asignado'
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _viewModel.equipoCliente['tipo_estado'] == 'asignado'
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _viewModel.getEstadoText(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _viewModel.equipoCliente['tipo_estado'] == 'asignado'
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Información del equipo en grid
            _buildInfoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final infoItems = <Map<String, String>>[];

    // Agregar campos solo si tienen datos
    if (_viewModel.shouldShowMarca()) {
      infoItems.add({
        'label': 'Marca',
        'value': _viewModel.getMarcaText(),
      });
    }

    if (_viewModel.shouldShowModelo()) {
      infoItems.add({
        'label': 'Modelo',
        'value': _viewModel.getModeloText(),
      });
    }

    if (_viewModel.shouldShowCodBarras()) {
      infoItems.add({
        'label': 'Código de Barras',
        'value': _viewModel.getCodBarrasText(),
      });
    }

    infoItems.addAll([
      {
        'label': 'Logo',
        'value': _viewModel.getLogoText(),
      },
    ]);


    return Column(
      children: [
        // Construir filas de 2 elementos cada una
        for (int i = 0; i < infoItems.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCompactInfoItem(
                      label: infoItems[i]['label']!,
                      value: infoItems[i]['value']!,
                    ),
                  ),
                  if (i + 1 < infoItems.length) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactInfoItem(
                        label: infoItems[i + 1]['label']!,
                        value: infoItems[i + 1]['value']!,
                      ),
                    ),
                  ] else
                    Expanded(child: SizedBox()), // Espacio vacío si es impar
                ],
              ),
            ),
          )],
    );
  }

  Widget _buildCompactInfoItem({
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Column(
          children: [
            // Mostrar control de ubicación solo para equipos activos
            if (_viewModel.isEquipoActivo) ...[
              _buildLocationControlCard(),
              SizedBox(height: 20),
            ],

            // Mostrar historial para TODOS los equipos (activos e inactivos)
            _buildHistorialCard(),

          ],
        );
      },
    );
  }

  Widget _buildLocationControlCard() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final estadoUbicacion = _viewModel.estadoUbicacionEquipo;

        // CAMBIO: Color basado en si hay selección o no
        Color statusColor = estadoUbicacion == null
            ? AppColors.neutral400
            : (estadoUbicacion ? AppColors.success : AppColors.warning);

        return Card(
          elevation: 3,
          color: AppColors.surface,
          shadowColor: AppColors.shadowLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, color: statusColor, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ubicación del Equipo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // CAMBIO: Mostrar badge solo si hay selección
                    if (estadoUbicacion != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'LISTO PARA GUARDAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 16),

                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: double.infinity),
                  child: DropdownButtonFormField<bool?>(
                    initialValue: estadoUbicacion,  // Será null inicialmente
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    hint: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '-- Seleccionar ubicación --',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    items: [
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off, color: AppColors.warning, size: 20),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Fuera del local',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) => _viewModel.cambiarUbicacionEquipo(value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NUEVA SECCIÓN DEL HISTORIAL
  Widget _buildHistorialCard() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final historial = _viewModel.historialUltimos5;
        final totalCambios = _viewModel.totalCambios;

        return Card(
          elevation: 3,
          color: AppColors.surface,
          shadowColor: AppColors.shadowLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del historial
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historial de Cambios',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (totalCambios > 0)
                            Text(
                              '${totalCambios} cambio${totalCambios == 1 ? '' : 's'} en total',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (historial.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Últimos ${historial.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 16),

                // Lista del historial
                if (historial.isEmpty)
                  _buildEmptyHistorial()
                else
                  _buildHistorialList(historial),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistorial() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.neutral100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neutral300,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 40,
              color: AppColors.neutral400,
            ),
            SizedBox(height: 8),
            Text(
              'Sin cambios registrados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Los cambios de ubicación aparecerán aquí',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHistorialList(List<dynamic> historial) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: historial.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.border,
        ),
        itemBuilder: (context, index) {
          final cambio = historial[index];
          final isFirst = index == 0;

          return InkWell(
            onTap: () => _navegarAPreview(cambio), // ← CAMBIO AQUÍ
            borderRadius: BorderRadius.circular(12),
            child: _buildHistorialItem(cambio, isFirst),
          );
        },
      ),
    );
  }

  void _navegarAPreview(dynamic historialItem) async {
    try {
      // Debug: Log de los datos antes de procesarlos
      print('=== DEBUG _navegarAPreview ===');
      print('historialItem: ${historialItem.toString()}');
      print('equipoCliente keys: ${widget.equipoCliente.keys.toList()}');
      print('cliente_id type: ${widget.equipoCliente['cliente_id'].runtimeType}');
      print('cliente_id value: ${widget.equipoCliente['cliente_id']}');

      // Mostrar indicador de carga mientras se consulta la BD
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Preparar datos para PreviewScreen consultando la base de datos
      final datosParaPreview = await _prepararDatosHistorialParaPreview(historialItem);

      // Cerrar indicador de carga
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('Datos preparados exitosamente, navegando...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(datos: datosParaPreview),
        ),
      );
    } catch (e, stackTrace) {
      // Cerrar indicador de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Log detallado del error
      print('ERROR en _navegarAPreview: $e');
      print('StackTrace: $stackTrace');
      print('historialItem data: $historialItem');
      print('equipoCliente data: ${widget.equipoCliente}');

      // Mostrar error más específico al usuario
      String errorMessage = 'Error al cargar detalles del historial';
      if (e.toString().contains('Cliente no encontrado')) {
        errorMessage = 'Cliente no encontrado en la base de datos';
      } else if (e.toString().contains('ID de cliente inválido')) {
        errorMessage = 'ID de cliente inválido';
      } else if (e.toString().contains('int')) {
        errorMessage = 'Error de tipo de datos en el historial';
      } else if (e.toString().contains('null')) {
        errorMessage = 'Datos faltantes en el registro del historial';
      } else {
        errorMessage = 'Error al cargar detalles: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              SizedBox(height: 4),
              Text(
                'Detalles técnicos: ${e.toString()}',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _prepararDatosHistorialParaPreview(dynamic historialItem) async {
    try {
      print('DEBUG: Iniciando _prepararDatosHistorialParaPreview con consulta a BD');

      final clienteIdRaw = widget.equipoCliente['cliente_id'];
      print('DEBUG: clienteIdRaw = $clienteIdRaw (tipo: ${clienteIdRaw.runtimeType})');

      int? clienteIdInt;
      try {
        if (clienteIdRaw == null) {
          throw Exception('cliente_id es null');
        } else if (clienteIdRaw is int) {
          clienteIdInt = clienteIdRaw;
        } else {
          clienteIdInt = int.tryParse(clienteIdRaw.toString());
          if (clienteIdInt == null) {
            throw Exception('No se pudo convertir cliente_id a int: $clienteIdRaw');
          }
        }
      } catch (e) {
        print('DEBUG: Error convirtiendo clienteId: $e');
        throw Exception('ID de cliente inválido: $clienteIdRaw');
      }

      print('DEBUG: Consultando cliente con ID: $clienteIdInt');

      final clienteRepository = ClienteRepository();
      final cliente = await clienteRepository.obtenerPorId(clienteIdInt);

      if (cliente == null) {
        throw Exception('Cliente no encontrado en la base de datos con ID: $clienteIdInt');
      }

      print('DEBUG: Cliente encontrado: ${cliente.toString()}');

      final equipoIdRaw = widget.equipoCliente['equipo_id'] ?? widget.equipoCliente['id'];
      String equipoIdStr = equipoIdRaw?.toString() ?? '';

      print('DEBUG: equipoIdStr = $equipoIdStr');

      final equipoCompleto = {
        'id': equipoIdStr,
        'cod_barras': widget.equipoCliente['cod_barras']?.toString() ?? '',
        'numero_serie': widget.equipoCliente['numero_serie']?.toString() ?? '',
        'modelo_nombre': widget.equipoCliente['modelo_nombre']?.toString() ?? '',
        'logo_nombre': widget.equipoCliente['logo_nombre']?.toString() ?? '',
        'marca_nombre': widget.equipoCliente['marca_nombre']?.toString() ?? '',
      };

      print('DEBUG: equipoCompleto creado');

      dynamic latitudSafe, longitudSafe, fechaRevisionSafe, enLocalSafe;
      try {
        latitudSafe = historialItem?.latitud;
        longitudSafe = historialItem?.longitud;
        fechaRevisionSafe = historialItem?.fechaRevision;
        enLocalSafe = historialItem?.enLocal ?? false;
      } catch (e) {
        print('DEBUG: Error accediendo datos del historial: $e');
        latitudSafe = null;
        longitudSafe = null;
        fechaRevisionSafe = null;
        enLocalSafe = false;
      }

      print('DEBUG: Datos del historial extraídos - lat: $latitudSafe, lon: $longitudSafe, fecha: $fechaRevisionSafe, enLocal: $enLocalSafe');

      // ✅ NUEVA LÓGICA: Obtener fotos desde el repositorio
      String? imagenPath;
      String? imagenBase64;
      bool tieneImagen = false;
      int? imagenTamano;

      String? imagenPath2;
      String? imagenBase64_2;
      bool tieneImagen2 = false;
      int? imagenTamano2;

      if (historialItem?.id != null) {
        print('DEBUG: Obteniendo fotos para estado_equipo ID: ${historialItem.id}');

        try {
          final censoActivoFotoRepo = CensoActivoFotoRepository();
          final fotos = await censoActivoFotoRepo.obtenerFotosPorCenso(historialItem.id);

          print('DEBUG: Se encontraron ${fotos.length} fotos');

          // Primera foto
          if (fotos.isNotEmpty) {
            final primeraFoto = fotos.first;
            imagenPath = primeraFoto.imagenPath;
            imagenBase64 = primeraFoto.imagenBase64;
            tieneImagen = primeraFoto.tieneImagen;
            imagenTamano = primeraFoto.imagenTamano;
            print('DEBUG: Primera foto cargada - path: $imagenPath, tiene imagen: $tieneImagen');
          }

          // Segunda foto
          if (fotos.length > 1) {
            final segundaFoto = fotos[1];
            imagenPath2 = segundaFoto.imagenPath;
            imagenBase64_2 = segundaFoto.imagenBase64;
            tieneImagen2 = segundaFoto.tieneImagen;
            imagenTamano2 = segundaFoto.imagenTamano;
            print('DEBUG: Segunda foto cargada - path: $imagenPath2, tiene imagen: $tieneImagen2');
          }

        } catch (e) {
          print('ERROR: No se pudieron cargar las fotos: $e');
          // Las variables ya están inicializadas en null/false
        }
      }

      final datosFinales = {
        'id': historialItem?.id,
        'cliente': cliente,
        'equipo_completo': equipoCompleto,
        'latitud': latitudSafe,
        'longitud': longitudSafe,
        'fecha_registro': fechaRevisionSafe?.toString(),
        'timestamp_gps': fechaRevisionSafe?.toString(),

        'codigo_barras': widget.equipoCliente['cod_barras']?.toString() ?? 'No especificado',
        'modelo': widget.equipoCliente['modelo_nombre']?.toString() ?? 'No especificado',
        'logo': widget.equipoCliente['logo_nombre']?.toString() ?? 'No especificado',
        'numero_serie': widget.equipoCliente['numero_serie']?.toString() ?? 'No especificado',

        'observaciones': historialItem?.observaciones ?? 'Sin observaciones',

        // ✅ Usar las fotos obtenidas del repositorio
        'imagen_path': imagenPath,
        'imagen_base64': imagenBase64,
        'tiene_imagen': tieneImagen,
        'imagen_tamano': imagenTamano,

        'imagen_path2': imagenPath2,
        'imagen_base64_2': imagenBase64_2,
        'tiene_imagen2': tieneImagen2,
        'imagen_tamano2': imagenTamano2,

        'es_censo': false,
        'es_historial': true,
        'historial_item': historialItem,
      };

      print('DEBUG: Datos finales preparados exitosamente con cliente real desde BD y fotos cargadas');
      return datosFinales;

    } catch (e, stackTrace) {
      print('ERROR CRÍTICO en _prepararDatosHistorialParaPreview: $e');
      print('StackTrace: $stackTrace');
      print('historialItem: $historialItem');
      print('equipoCliente: ${widget.equipoCliente}');
      rethrow;
    }
  }


  Widget _buildHistorialItem(dynamic cambio, bool isFirst) {
    final enLocal = cambio.enLocal;
    final fecha = cambio.fechaRevision;
    final statusColor = enLocal ? AppColors.success : AppColors.neutral500;
    final statusIcon = enLocal ? Icons.store : Icons.location_off;
    final statusText = enLocal ? 'EN LOCAL' : 'FUERA DEL LOCAL';

    // Información de ubicación GPS (solo para mostrar información)
    final tieneUbicacion = cambio.latitud != null && cambio.longitud != null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFirst
            ? statusColor.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          // Indicador visual
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: isFirst
                  ? Border.all(color: statusColor, width: 2)
                  : null,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),

          SizedBox(width: 12),

          // Información del cambio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFirst) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ACTUAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _viewModel.formatearFechaHistorial(fecha),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Indicadores en columna
          Column(
            children: [
              // Indicador de sincronización
              if (!cambio.estaSincronizado)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              // Indicador GPS (solo visual)
              if (tieneUbicacion) ...[
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.gps_fixed,
                    size: 12,
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),

          // Flecha indicando que es clickeable para preview
          SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  void _showSaveConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar guardado'),
        content: Text('¿Estás seguro de que quieres guardar los cambios realizados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _viewModel.saveAllChanges();
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }
}