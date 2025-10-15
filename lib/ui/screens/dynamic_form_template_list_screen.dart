import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_template.dart';
import 'package:ada_app/ui/screens/dynamic_form_fill_screen.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/services/auth_service.dart'; // ← AGREGAR IMPORT

/// Pantalla que muestra la lista de formularios dinámicos disponibles (templates)
class DynamicFormTemplateListScreen extends StatefulWidget {
  final Cliente cliente;
  final DynamicFormViewModel viewModel;

  const DynamicFormTemplateListScreen({
    super.key,
    required this.cliente,
    required this.viewModel,
  });

  @override
  State<DynamicFormTemplateListScreen> createState() => _DynamicFormTemplateListScreenState();
}

class _DynamicFormTemplateListScreenState extends State<DynamicFormTemplateListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seleccionar Formulario', style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.onPrimary),
            onPressed: () async {
              await widget.viewModel.downloadTemplatesFromServer();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Formularios actualizados'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
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
                      color: _getCategoryColor(template.category).withOpacity(0.1),
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
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(template.category).withOpacity(0.1),
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
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 12),
              Divider(color: AppColors.border, height: 1),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.assignment, size: 16, color: AppColors.textSecondary),
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No hay formularios disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Descarga formularios desde el servidor',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await widget.viewModel.downloadTemplatesFromServer();
              },
              icon: Icon(Icons.cloud_download),
              label: Text('Descargar Formularios'),
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
              widget.viewModel.errorMessage ?? 'Error desconocido',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );

    // ✅ Obtener usuario actual
    final usuario = await AuthService().getCurrentUser();

    // ✅ Iniciar formulario con todos los datos
    widget.viewModel.startNewForm(
      template.id,
      contactoId: widget.cliente.id.toString(),
      userId: usuario?.id?.toString(),
      edfVendedorId: usuario?.edfVendedorId,
    );

    // ✅ Guardar inmediatamente en la BD como borrador
    final saved = await widget.viewModel.saveDraft();

    // Cerrar loading
    if (mounted) {
      Navigator.pop(context);
    }

    if (saved) {
      // Navegar a la pantalla de llenado
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DynamicFormFillScreen(viewModel: widget.viewModel),
          ),
        ).then((_) {
          // Cuando regresa de llenar el formulario, cierra esta pantalla también
          Navigator.pop(context);
        });
      }
    } else {
      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al crear el formulario'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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