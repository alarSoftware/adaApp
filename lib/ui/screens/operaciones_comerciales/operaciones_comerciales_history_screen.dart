import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/operaciones_comerciales/operaciones_comerciales_history_viewmodel.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart';

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

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OperacionesComercialesHistoryViewModel>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          title: const Text('Historial de Operaciones'),
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
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Todos'),
              Tab(text: 'Reposición'),
              Tab(text: 'Retiro'),
              Tab(text: 'NDR'),
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
                      children: [
                        _buildOperationList(context, viewModel, null), // Todos
                        _buildOperationList(
                          context,
                          viewModel,
                          TipoOperacion.notaReposicion,
                        ),
                        _buildOperationList(
                          context,
                          viewModel,
                          TipoOperacion.notaRetiro,
                        ),
                        _buildOperationList(
                          context,
                          viewModel,
                          TipoOperacion.notaRetiroDiscontinuos,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationList(
    BuildContext context,
    OperacionesComercialesHistoryViewModel viewModel,
    TipoOperacion? tipoFiltro,
  ) {
    final filteredOps = tipoFiltro == null
        ? viewModel.operaciones
        : viewModel.operaciones
              .where((op) => op.tipoOperacion == tipoFiltro)
              .toList();

    if (filteredOps.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final operacion = filteredOps[index];
        final cliente = viewModel.getCliente(operacion.clienteId);
        return _buildOperacionCard(
          context,
          operacion,
          cliente?.nombre ?? 'Cliente Desconocido',
        );
      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No se encontraron operaciones',
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
