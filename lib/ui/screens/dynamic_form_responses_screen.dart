import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_response.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/ui/screens/dynamic_form_template_list_screen.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/ui/screens/dynamic_form_fill_screen.dart';

/// Pantalla principal que muestra las respuestas guardadas
class DynamicFormResponsesScreen extends StatefulWidget {
  final Cliente cliente;

  const DynamicFormResponsesScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<DynamicFormResponsesScreen> createState() => _DynamicFormResponsesScreenState();
}

class _DynamicFormResponsesScreenState extends State<DynamicFormResponsesScreen> {
  late DynamicFormViewModel _viewModel;
  String _filterStatus = 'all'; // all, completed, pending, synced

  @override
  void initState() {
    super.initState();
    _viewModel = DynamicFormViewModel();
    _loadData();
  }

  Future<void> _loadData() async {
    await _viewModel.loadTemplates();
    await _viewModel.loadSavedResponses(clienteId: widget.cliente.id.toString());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Formularios Dinámicos',
          style: TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.onPrimary),
            onPressed: _navigateToFormList,
            tooltip: 'Nuevo Formulario',
          ),
          IconButton(
            icon: Icon(Icons.sync, color: AppColors.onPrimary),
            onPressed: _syncResponses,
            tooltip: 'Sincronizar con servidor',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.onPrimary),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.containerBackground, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Card de información del cliente
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                child: ClientInfoCard(
                  cliente: widget.cliente,
                ),
              ),
              // Filtros
              _buildFilterChips(),

              // Lista de respuestas
              Expanded(
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, child) {
                    if (_viewModel.isLoading) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      );
                    }

                    if (_viewModel.errorMessage != null) {
                      return _buildErrorView();
                    }

                    final responses = _getFilteredResponses();

                    if (responses.isEmpty) {
                      return _buildEmptyView();
                    }

                    return _buildResponsesList(responses);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Todos', 'all'),
            SizedBox(width: 8),
            _buildFilterChip('Completados', 'completed'),
            SizedBox(width: 8),
            _buildFilterChip('Pendientes', 'pending'), // ✅ CORREGIDO: de 'draft' a 'pending'
            SizedBox(width: 8),
            _buildFilterChip('Sincronizados', 'synced'), // ✅ AGREGADO
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
    );
  }

  List<DynamicFormResponse> _getFilteredResponses() {
    final allResponses = _viewModel.savedResponses;

    switch (_filterStatus) {
      case 'completed':
        return allResponses.where((r) => r.status == 'completed').toList();
      case 'pending':
        return allResponses.where((r) => r.status == 'pending').toList();
      case 'synced':
        return allResponses.where((r) => r.status == 'synced').toList();
      default:
        return allResponses;
    }
  }

  Widget _buildResponsesList(List<DynamicFormResponse> responses) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: responses.length,
        itemBuilder: (context, index) {
          final response = responses[index];
          return _buildResponseCard(response);
        },
      ),
    );
  }

  Widget _buildResponseCard(DynamicFormResponse response) {
    final template = _viewModel.getTemplateById(response.formTemplateId);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewResponse(response),
        onLongPress: () => _deleteResponse(response),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icono de estado
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(response.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(response.status),
                      color: _getStatusColor(response.status),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template?.title ?? 'Formulario #${response.formTemplateId}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        _buildStatusBadge(response.status),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(color: AppColors.border, height: 1),
              SizedBox(height: 12),

              // Información de la respuesta
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text(
                    'Creado: ${dateFormat.format(response.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              if (response.completedAt != null) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Completado: ${dateFormat.format(response.completedAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.assignment, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text(
                    '${response.answers.length} respuestas',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Spacer(),
                  if (response.status != 'synced') ...[
                    Icon(Icons.cloud_upload, size: 14, color: AppColors.warning),
                    SizedBox(width: 4),
                    Text(
                      'Sin sincronizar',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color color;

    switch (status) {
      case 'completed':
        label = 'COMPLETADO';
        color = AppColors.success;
        break;
      case 'pending':
        label = 'PENDIENTE';
        color = AppColors.warning;
        break;
      case 'synced':
        label = 'SINCRONIZADO';
        color = AppColors.info;
        break;
      case 'error':
        label = 'ERROR';
        color = AppColors.error;
        break;
      default:
        label = status.toUpperCase();
        color = AppColors.textSecondary;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No hay respuestas guardadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _getEmptyMessage(),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToFormList,
              icon: Icon(Icons.add),
              label: Text('Crear Nuevo Formulario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error,
            ),
            SizedBox(height: 16),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _viewModel.errorMessage ?? 'Error desconocido',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_filterStatus) {
      case 'completed':
        return 'No hay formularios completados';
      case 'pending':
        return 'No hay formularios pendientes';
      case 'synced':
        return 'No hay formularios sincronizados';
      default:
        return 'Presiona el botón "+" para crear un nuevo formulario';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'synced':
        return AppColors.info;
      case 'error':
        return AppColors.error;
      default:
        return AppColors.neutral400;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'synced':
        return Icons.cloud_done;
      case 'error':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  void _navigateToFormList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFormTemplateListScreen(
          cliente: widget.cliente,
          viewModel: _viewModel,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _viewResponse(DynamicFormResponse response) {
    _viewModel.loadResponseForEditing(response);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFormFillScreen(viewModel: _viewModel),
      ),
    ).then((_) {
      _loadData();
    });
  }

  Future<void> _syncResponses() async {
    final result = await _viewModel.syncPendingResponses();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ ${result['success']} sincronizadas, ${result['failed']} fallidas',
        ),
        backgroundColor: result['failed'] == 0 ? AppColors.success : AppColors.warning,
      ),
    );

    await _loadData();
  }

  Future<void> _deleteResponse(DynamicFormResponse response) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmar eliminación',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar esta respuesta? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _viewModel.deleteResponse(response.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Respuesta eliminada' : '❌ Error al eliminar'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );

      if (success) {
        await _loadData();
      }
    }
  }
}