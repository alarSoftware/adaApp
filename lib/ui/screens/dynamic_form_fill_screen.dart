import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/ui/widgets/dynamic_form/dynamic_form_field_widget.dart';
import 'package:intl/intl.dart';

/// Pantalla para llenar un formulario dinámico
class DynamicFormFillScreen extends StatefulWidget {
  final DynamicFormViewModel viewModel;

  const DynamicFormFillScreen({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  @override
  State<DynamicFormFillScreen> createState() => _DynamicFormFillScreenState();
}

class _DynamicFormFillScreenState extends State<DynamicFormFillScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await _showExitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.viewModel.currentTemplate?.title ?? 'Formulario',
            style: TextStyle(color: AppColors.onPrimary),
          ),
          backgroundColor: AppColors.appBarBackground,
          foregroundColor: AppColors.appBarForeground,
          actions: [
            IconButton(
              icon: Icon(Icons.save_outlined, color: AppColors.onPrimary),
              onPressed: _saveDraft,
              tooltip: 'Guardar borrador',
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, child) {
            final template = widget.viewModel.currentTemplate;

            if (template == null) {
              return Center(
                child: Text(
                  'No se pudo cargar el formulario',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            // ⭐ CAMBIO CRÍTICO: Obtener solo campos visibles según respuestas actuales
            final currentAnswers = widget.viewModel.currentResponse?.answers ?? {};
            final visibleFields = template.getVisibleFields(currentAnswers);

            return Column(
              children: [
                // Barra de progreso
                _buildProgressBar(),

                // Formulario
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.containerBackground, AppColors.background],
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Descripción del formulario
                          _buildFormHeader(template),

                          SizedBox(height: 24),

                          // ⭐ CAMBIO CRÍTICO: Usar visibleFields en lugar de template.fields
                          ...visibleFields.map((field) {
                            return DynamicFormFieldWidget(
                              key: ValueKey('${field.id}_${currentAnswers[field.id]}'), // ⭐ Key para forzar rebuild
                              field: field,
                              value: widget.viewModel.getFieldValue(field.id),
                              onChanged: (value) {
                                widget.viewModel.updateFieldValue(field.id, value);
                              },
                              errorText: widget.viewModel.getFieldError(field.id),
                              allValues: currentAnswers,
                              onNestedFieldChanged: (fieldId, value) {
                                // ⭐ NUEVO: Callback para campos anidados
                                widget.viewModel.updateFieldValue(fieldId, value);
                              },
                            );
                          }).toList(),

                          SizedBox(height: 80), // Espacio para el botón flotante
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = widget.viewModel.getFormProgress();
    final percentage = (progress * 100).toInt();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso del formulario',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral200,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader(template) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Información',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              template.description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.assignment, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Text(
                  '${template.fieldCount} campos',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                SizedBox(width: 12),
                Icon(Icons.star, size: 14, color: AppColors.warning),
                SizedBox(width: 4),
                Text(
                  '${template.requiredFieldCount} obligatorios',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    final success = await widget.viewModel.saveDraft();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Borrador guardado'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar borrador'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveAndComplete() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success),
            SizedBox(width: 8),
            Text('Completar formulario', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          '¿Estás seguro de completar este formulario? Se guardará y quedará listo para sincronizar.',
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
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text('Completar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Guardar y completar
    final success = await widget.viewModel.saveAndComplete();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Formulario completado exitosamente'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      // Volver a la pantalla anterior
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${widget.viewModel.errorMessage ?? "Error al completar formulario"}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _showExitConfirmation() async {
    final progress = widget.viewModel.getFormProgress();

    // Si no hay progreso, permitir salir sin confirmación
    if (progress == 0) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('¿Salir sin guardar?', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Tienes cambios sin guardar. ¿Deseas guardar un borrador antes de salir?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Salir sin guardar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.viewModel.saveDraft();
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text('Guardar borrador'),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }
}