import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_template.dart';
import 'package:ada_app/ui/screens/dynamic_form/dynamic_form_fill_screen.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/widgets/dynamic_form/dynamic_form_loading_dialog.dart';
import 'package:ada_app/services/api/auth_service.dart';

/// Pantalla que muestra la lista de formularios dinámicos disponibles (templates)
class DynamicFormTemplateListScreen extends StatefulWidget {
  final Cliente? cliente;
  final DynamicFormViewModel viewModel;

  const DynamicFormTemplateListScreen({
    super.key,
    this.cliente,
    required this.viewModel,
  });

  @override
  State<DynamicFormTemplateListScreen> createState() =>
      _DynamicFormTemplateListScreenState();
}

class _DynamicFormTemplateListScreenState
    extends State<DynamicFormTemplateListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seleccionar Formulario',
          style: TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.onPrimary),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await widget.viewModel.downloadTemplatesFromServer();
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Formularios actualizados'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            tooltip: 'Actualizar formularios',
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
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, child) {
            if (widget.viewModel.isLoading) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            if (widget.viewModel.errorMessage != null) {
              return _buildErrorView();
            }

            if (widget.viewModel.templates.isEmpty) {
              return _buildEmptyView();
            }

            return _buildFormList();
          },
        ),
      ),
    );
  }

  Widget _buildFormList() {
    return RefreshIndicator(
      onRefresh: () async {
        await widget.viewModel.downloadTemplatesFromServer();
      },
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: widget.viewModel.templates.length,
        itemBuilder: (context, index) {
          final template = widget.viewModel.templates[index];
          return _buildFormCard(template);
        },
      ),
    );
  }

  Widget _buildFormCard(DynamicFormTemplate template) {
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
        onTap: () => _startNewForm(template),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        template.category,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getCategoryColor(template.category),
                      ),
                    ),
                    child: Icon(
                      _getCategoryIcon(template.category),
                      color: _getCategoryColor(template.category),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (template.category != null) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                template.category,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getCategoryColor(template.category),
                              ),
                            ),
                            child: Text(
                              template.category!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getCategoryColor(template.category),
                              ),
                            ),
                          ),
                        ],
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
              Text(
                template.description,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              SizedBox(height: 12),
              Divider(color: AppColors.border, height: 1),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.assignment,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${template.fieldCount} campos',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.star, size: 16, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text(
                    '${template.requiredFieldCount} obligatorios',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'v${template.version}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_download_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay formularios',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Es necesario descargar los formularios del servidor para comenzar.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.viewModel.downloadTemplatesFromServer();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Descargar Ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
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
            Icon(Icons.error_outline, size: 80, color: AppColors.error),
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
              widget.viewModel.errorMessage ?? 'Error desconocido',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await widget.viewModel.loadTemplates();
              },
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

  void _startNewForm(DynamicFormTemplate template) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ModernLoadingDialog(
        title: 'Iniciando formulario...',
      ),
    );

    // ✅ Obtener usuario actual
    final usuario = await AuthService().getCurrentUser();
    if (!mounted) return;

    // ✅ Iniciar formulario con todos los datos
    widget.viewModel.startNewForm(
      template.id,
      contactoId: widget.cliente?.id?.toString(),
      userId: usuario?.id?.toString(),
      employeeId: usuario?.employeeId,
    );

    // ✅ Guardar inmediatamente en la BD como borrador
    final saved = await widget.viewModel.saveDraft();
    if (!mounted) return;

    // Cerrar loading
    Navigator.pop(context);

    if (saved) {
      // Navegar a la pantalla de llenado
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DynamicFormFillScreen(viewModel: widget.viewModel),
        ),
      );
    } else {
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al crear el formulario'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'censo':
        return AppColors.info;
      case 'mantenimiento':
        return AppColors.warning;
      case 'incidencia':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'censo':
        return Icons.assignment_outlined;
      case 'mantenimiento':
        return Icons.build_outlined;
      case 'incidencia':
        return Icons.report_problem_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
