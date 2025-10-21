import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_response.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/ui/screens/dynamic_form_template_list_screen.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/ui/screens/dynamic_form_fill_screen.dart';
import 'package:ada_app/services/auth_service.dart';

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
  String _filterStatus = 'all';
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _viewModel = DynamicFormViewModel();
    _loadData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _viewModel.loadTemplates();
    await _viewModel.loadSavedResponsesWithSync(
      clienteId: widget.cliente.id.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
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
              _buildClientInfo(),
              _buildFilterChips(),
              _buildResponsesList(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== APP BAR ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Formularios Dinámicos',
        style: TextStyle(color: AppColors.onPrimary),
      ),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      actions: [
        IconButton(
          icon: Icon(Icons.cloud_download, color: AppColors.onPrimary),
          onPressed: _downloadTemplates,
          tooltip: 'Descargar formularios del servidor',
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: AppColors.onPrimary),
          onPressed: _navigateToFormList,
          tooltip: 'Nuevo Formulario',
        ),
      ],
    );
  }

  // ==================== CLIENT INFO ====================

  Widget _buildClientInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: ClientInfoCard(cliente: widget.cliente),
    );
  }

  // ==================== FILTER CHIPS ====================

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
            _buildFilterChip('Pendientes', 'pending'),
            SizedBox(width: 8),
            _buildFilterChip('Sincronizados', 'synced'),
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

  // ==================== RESPONSES LIST ====================

  Widget _buildResponsesList() {
    return Expanded(
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

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: responses.length,
              itemBuilder: (context, index) => _buildResponseCard(responses[index]),
            ),
          );
        },
      ),
    );
  }

  List<DynamicFormResponse> _getFilteredResponses() {
    final allResponses = _viewModel.savedResponses;

    switch (_filterStatus) {
      case 'completed':
        return allResponses.where((r) => r.status == 'completed').toList();
      case 'pending':
        return allResponses.where((r) => r.syncedAt == null).toList();
      case 'synced':
        return allResponses.where((r) => r.syncedAt != null).toList();
      default:
        return allResponses;
    }
  }

  // ==================== RESPONSE CARD ====================

  Widget _buildResponseCard(DynamicFormResponse response) {
    final template = _viewModel.getTemplateById(response.formTemplateId);
    final isSynced = response.syncedAt != null;

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
              _buildCardHeader(response, template, isSynced),
              SizedBox(height: 12),
              Divider(color: AppColors.border, height: 1),
              SizedBox(height: 12),
              _buildCardDetails(response, isSynced),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
      DynamicFormResponse response,
      dynamic template,
      bool isSynced,
      ) {
    return Row(
      children: [
        // Icono del estado del formulario
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
        // Título y badge
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
        // Ícono de sincronización
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isSynced ? AppColors.success : AppColors.warning)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isSynced ? Icons.cloud_done : Icons.cloud_upload,
            color: isSynced ? AppColors.success : AppColors.warning,
            size: 18,
          ),
        ),
        SizedBox(width: 8),
        Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildCardDetails(DynamicFormResponse response, bool isSynced) {
    return Column(
      children: [
        _buildInfoRow(
          Icons.calendar_today,
          'Creado: ${_dateFormat.format(response.createdAt)}',
          AppColors.textSecondary,
        ),

        if (response.completedAt != null) ...[
          SizedBox(height: 4),
          _buildInfoRow(
            Icons.check_circle,
            'Completado: ${_dateFormat.format(response.completedAt!)}',
            AppColors.success,
          ),
        ],

        // ✅ Mostrar estado de sincronización
        if (response.isSynced && response.syncedAt != null) ...[
          SizedBox(height: 4),
          _buildInfoRow(
            Icons.cloud_done,
            'Sincronizado: ${_dateFormat.format(response.syncedAt!)}',
            AppColors.success,
          ),
        ],

        // ⚠️ Mostrar si está pendiente de sync
        if (response.isCompleted && !response.isSynced) ...[
          SizedBox(height: 4),
          _buildInfoRow(
            Icons.cloud_upload,
            'Pendiente de sincronización',
            AppColors.warning,
          ),
        ],

        // ❌ Mostrar si hay error
        if (response.hasError && !response.isSynced) ...[
          SizedBox(height: 4),
          _buildInfoRow(
            Icons.error_outline,
            'Error: ${response.errorMessage}',
            AppColors.error,
          ),
        ],

        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.assignment, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 4),
            Text(
              '${response.answers.length} respuestas',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color == AppColors.success ? color : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 12, color: AppColors.error),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 10, color: AppColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final config = _getStatusConfig(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: config['color'], width: 1),
      ),
      child: Text(
        config['label'],
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: config['color'],
        ),
      ),
    );
  }

  // ==================== EMPTY & ERROR VIEWS ====================

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

  // ==================== HELPER METHODS ====================

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

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'completed':
        return {'label': 'COMPLETADO', 'color': AppColors.success};
      case 'draft':
        return {'label': 'BORRADOR', 'color': AppColors.warning};
      default:
        return {'label': status.toUpperCase(), 'color': AppColors.textSecondary};
    }
  }

  Color _getStatusColor(String status) {
    return _getStatusConfig(status)['color'];
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'draft':
        return Icons.edit_note;
      default:
        return Icons.help_outline;
    }
  }

  // ==================== NAVIGATION ====================

  void _navigateToFormList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFormTemplateListScreen(
          cliente: widget.cliente,
          viewModel: _viewModel,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _viewResponse(DynamicFormResponse response) {
    _viewModel.loadResponseForEditing(response);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFormFillScreen(
          viewModel: _viewModel,
          isReadOnly: response.status == 'completed',
        ),
      ),
    ).then((_) => _loadData());
  }

  // ==================== DOWNLOAD ====================

  Future<void> _downloadTemplates() async {
    print('🔴 DESCARGA INICIADA');

    // ✅ Obtener usuario actual (igual que cuando creas formularios)
    final usuario = await AuthService().getCurrentUser();
    final edfvendedorId = usuario?.edfVendedorId ?? '';

    print('🔍 edfVendedorId: $edfvendedorId');

    _showLoadingDialog();

    // PASO 1: Descargar templates
    print('📥 [1/2] Descargando templates...');
    final templatesSuccess = await _viewModel.downloadTemplatesFromServer();
    print('📋 Templates: $templatesSuccess');

    // PASO 2: Descargar respuestas
    print('📥 [2/2] Descargando respuestas...');
    bool responsesSuccess = false;

    if (edfvendedorId.isNotEmpty) {
      responsesSuccess = await _viewModel.downloadResponsesFromServer(edfvendedorId);
      print('📝 Responses: $responsesSuccess');
    } else {
      print('⚠️ Sin edfVendedorId - saltando descarga de respuestas');
    }

    if (!mounted) return;
    Navigator.pop(context);

    // Mostrar resultado
    final templatesCount = _viewModel.templates.length;
    final responsesCount = _viewModel.savedResponses.length;

    String message;
    Color backgroundColor;

    if (edfvendedorId.isEmpty) {
      message = templatesSuccess
          ? '✅ Formularios: $templatesCount\n⚠️ Respuestas no descargadas (sin vendedor)'
          : '❌ Error descargando formularios';
      backgroundColor = templatesSuccess ? AppColors.warning : AppColors.error;
    } else if (templatesSuccess && responsesSuccess) {
      message = '✅ Descarga completa:\n📋 $templatesCount formularios\n📝 $responsesCount respuestas';
      backgroundColor = AppColors.success;
    } else if (templatesSuccess && !responsesSuccess) {
      message = '⚠️ Formularios: OK ($templatesCount)\n❌ Respuestas: Error';
      backgroundColor = AppColors.warning;
    } else if (!templatesSuccess && responsesSuccess) {
      message = '❌ Formularios: Error\n⚠️ Respuestas: OK ($responsesCount)';
      backgroundColor = AppColors.warning;
    } else {
      message = '❌ Error en la descarga';
      backgroundColor = AppColors.error;
    }

    _showSnackBar(message, backgroundColor);

    if (templatesSuccess || responsesSuccess) {
      print('🔄 Recargando datos...');
      await _loadData();
    }

    print('🔴 DESCARGA FINALIZADA');
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24),
            margin: EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Descargando formularios...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ==================== DELETE ====================

  Future<void> _deleteResponse(DynamicFormResponse response) async {
    final confirm = await _showDeleteConfirmation();

    if (confirm == true) {
      final success = await _viewModel.deleteResponse(response.id);

      if (!mounted) return;

      _showSnackBar(
        success ? '✅ Respuesta eliminada' : '❌ Error al eliminar',
        success ? AppColors.success : AppColors.error,
      );

      if (success) await _loadData();
    }
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
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
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
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
  }
}