import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/operaciones_comerciales/operaciones_comerciales_history_viewmodel.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/censo_activo.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart';
import 'package:ada_app/ui/screens/censo_activo/preview_screen.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';

class OperacionesComercialesHistoryScreen extends StatelessWidget {
  const OperacionesComercialesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OperacionesComercialesHistoryViewModel()..init(),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView();

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TipoOperacion? _selectedOperationType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OperacionesComercialesHistoryViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text('Historial de Actividad'),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () => _pickDate(context, viewModel),
            tooltip: 'Filtrar por fecha',
          ),
          if (viewModel.selectedDate != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              onPressed: viewModel.limpiarFiltro,
              tooltip: 'Limpiar filtro',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Censos'),
            Tab(text: 'Operaciones'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterStatus(viewModel),
          Expanded(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Pestaña de Censos
                      _buildCensosList(context, viewModel),
                      // Pestaña de Operaciones con Filtros
                      _buildOperacionesView(context, viewModel),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCensosList(
    BuildContext context,
    OperacionesComercialesHistoryViewModel viewModel,
  ) {
    final censos = viewModel.censos;

    if (censos.isEmpty) {
      return _buildEmptyState('No se encontraron censos');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: censos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final censo = censos[index];
        final cliente = viewModel.getCliente(censo.clienteId);
        return _buildCensoCard(
          context,
          censo,
          cliente?.nombre ?? 'Cliente Desconocido',
        );
      },
    );
  }

  Widget _buildOperacionesView(
    BuildContext context,
    OperacionesComercialesHistoryViewModel viewModel,
  ) {
    final filteredOps = _selectedOperationType == null
        ? viewModel.operaciones
        : viewModel.operaciones
              .where((op) => op.tipoOperacion == _selectedOperationType)
              .toList();

    return Column(
      children: [
        // Filtros (Chips)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip(TipoOperacion.notaReposicion, 'Reposición'),
                const SizedBox(width: 8),
                _buildFilterChip(TipoOperacion.notaRetiro, 'Retiro'),
                const SizedBox(width: 8),
                _buildFilterChip(TipoOperacion.notaRetiroDiscontinuos, 'NDR'),
              ],
            ),
          ),
        ),

        // Lista
        Expanded(
          child: filteredOps.isEmpty
              ? _buildEmptyState('No se encontraron operaciones')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOps.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final operacion = filteredOps[index];
                    final cliente = viewModel.getCliente(operacion.clienteId);
                    return _buildOperacionCard(
                      context,
                      operacion,
                      cliente?.nombre ?? 'Cliente Desconocido',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(TipoOperacion? type, String label) {
    final isSelected = _selectedOperationType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedOperationType = type;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildFilterStatus(OperacionesComercialesHistoryViewModel viewModel) {
    if (viewModel.selectedDate == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Filtrado por: ',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            DateFormat(
              'EEEE d, MMMM yyyy',
              'es',
            ).format(viewModel.selectedDate!),
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCensoCard(
    BuildContext context,
    CensoActivo censo,
    String clienteNombre,
  ) {
    final fechaCreacionStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(censo.fechaCreacion);

    String syncStatus = 'migrado'; // Default por defecto si no es error/creado
    if (censo.tieneError) syncStatus = 'error';
    if (censo.estaCreado) syncStatus = 'pendiente';
    // Si viene 'migrado' explícito
    if (censo.estaMigrado) syncStatus = 'migrado';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Mostrar indicador de carga rápido
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              // Obtener fotos
              final repo = CensoActivoRepository();
              final fotos = await repo.obtenerFotos(censo.id ?? '');

              // Obtener datos completos del equipo
              // Necesitamos importar EquipoRepository
              final equipoRepo = EquipoRepository();
              final equipoFull = await equipoRepo.obtenerEquipoCompletoPorId(
                censo.equipoId,
              );

              if (!context.mounted) return;
              Navigator.pop(context); // Cerrar loading

              // Preparar datos para PreviewScreen
              final viewModel = context
                  .read<OperacionesComercialesHistoryViewModel>();
              final cliente = viewModel.getCliente(censo.clienteId);

              if (cliente == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: Cliente no encontrado')),
                );
                return;
              }

              final datos = <String, dynamic>{
                'cliente': cliente,
                'es_historial': true,
                'es_historial_global': true, // FLAG CLAVE
                'id': censo.id,
                'equipo_id': censo.equipoId,
                'observaciones': censo.observaciones,
                'fecha_creacion': censo.fechaCreacion.toIso8601String(),
                'latitud': censo.latitud,
                'longitud': censo.longitud,
                'en_local': censo.enLocal,

                // Datos del equipo completos
                'marca': equipoFull?['marca_nombre'] ?? 'Sin Marca',
                'modelo': equipoFull?['modelo_nombre'] ?? 'Sin Modelo',
                'logo': equipoFull?['logo_nombre'] ?? 'Sin Logo',
                'codigo_barras': equipoFull?['cod_barras'] ?? '',
                'numero_serie': equipoFull?['numero_serie'] ?? '',
                'tipo_estado': 'asignado',

                // Si el preview lo requiere
                'imagen_path': null,
                'imagen_base64': null,
                'tiene_imagen': false,
              };

              // Mapear fotos
              for (var foto in fotos) {
                final orden = foto['orden'] as int? ?? 1;
                final suffix = orden == 1 ? '' : '2';

                datos['imagen_path$suffix'] = foto['imagen_path'];
                datos['imagen_base64$suffix'] = foto['imagen_base64'];
                datos['tiene_imagen$suffix'] = true;

                // Si falta imagen principal en root
                if (orden == 1) {
                  datos['imagen_path'] = foto['imagen_path'];
                  datos['imagen_base64'] = foto['imagen_base64'];
                  datos['tiene_imagen'] = true;
                }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PreviewScreen(datos: datos, historialItem: censo),
                ),
              );
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cargar detalle: $e')),
                );
              }
            }
          },

          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.store_mall_directory_rounded,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clienteNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildSyncBadge(syncStatus),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Censo de Activos',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            censo.observaciones ?? 'Sin observaciones',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontStyle: censo.observaciones == null
                                  ? FontStyle.italic
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Creado:',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          fechaCreacionStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey.shade300),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperacionCard(
    BuildContext context,
    OperacionComercial operacion,
    String clienteNombre,
  ) {
    // Corporate style: Always black/dark icons
    final iconColor = const Color(0xFF333333);

    final fechaCreacionStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(operacion.fechaCreacion);

    final isReposicion =
        operacion.tipoOperacion == TipoOperacion.notaReposicion;
    final fechaRetiroLabel = isReposicion ? 'F. Entrega' : 'F. Retiro';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final vm = context.read<OperacionesComercialesHistoryViewModel>();
            final cliente = vm.getCliente(operacion.clienteId);

            if (cliente != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OperacionComercialFormScreen(
                    cliente: cliente,
                    tipoOperacion: operacion.tipoOperacion,
                    operacionExistente: operacion,
                    isViewOnly: true,
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Name Header
                Row(
                  children: [
                    Icon(
                      Icons.store_mall_directory_rounded,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clienteNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildSyncBadge(operacion.syncStatus),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Operation Type
                          Text(
                            operacion.tipoOperacion.displayName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Identifiers
                          if (operacion.odooName != null &&
                              operacion.odooName!.isNotEmpty)
                            Text(
                              'Odoo: ${operacion.odooName}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          if (operacion.adaSequence != null &&
                              operacion.adaSequence!.isNotEmpty)
                            Text(
                              'Seq: ${operacion.adaSequence}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          if ((operacion.odooName == null ||
                                  operacion.odooName!.isEmpty) &&
                              (operacion.adaSequence == null ||
                                  operacion.adaSequence!.isEmpty))
                            Text(
                              'Sin Identificadores',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Creado:',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          fechaCreacionStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (operacion.fechaRetiro != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '$fechaRetiroLabel:',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(operacion.fechaRetiro!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey.shade300),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'migrado':
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'error':
        color = AppColors.error;
        icon = Icons.error_rounded;
        break;
      default:
        color = AppColors.warning;
        icon = Icons.sync;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    OperacionesComercialesHistoryViewModel viewModel,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      viewModel.seleccionarFecha(picked);
    }
  }
}
