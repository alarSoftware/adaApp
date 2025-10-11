import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/ui/widgets/dynamic_form/dynamic_form_field_widget.dart';

/// Pantalla para llenar un formulario dinámico
class DynamicFormFillScreen extends StatefulWidget {
  final DynamicFormViewModel viewModel;
  final bool isReadOnly;

  const DynamicFormFillScreen({
    super.key,
    required this.viewModel,
    this.isReadOnly = false,
  });

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
        if (widget.isReadOnly) return true; // Si es readonly, salir sin preguntar
        return await _showExitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.viewModel.currentTemplate?.title ?? 'Formulario',
                style: TextStyle(color: AppColors.onPrimary, fontSize: 18),
              ),
              // ✅ MOSTRAR "Solo lectura" si está en readonly
              if (widget.isReadOnly)
                Text(
                  'Solo lectura',
                  style: TextStyle(
                    color: AppColors.onPrimary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          backgroundColor: AppColors.appBarBackground,
          foregroundColor: AppColors.appBarForeground,
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

            final currentAnswers = widget.viewModel.currentResponse?.answers ?? {};
            final visibleFields = template.getVisibleFields(currentAnswers);

            return Column(
              children: [
                // Barra de progreso (solo si NO es readonly)
                if (!widget.isReadOnly) _buildProgressBar(),

                // ✅ BANNER DE SOLO LECTURA
                if (widget.isReadOnly)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: AppColors.info.withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.info, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este formulario está completado y no se puede modificar',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          // Usar visibleFields en lugar de template.fields
                          ...visibleFields.map((field) {
                            return DynamicFormFieldWidget(
                              key: ValueKey('${field.id}_${currentAnswers[field.id]}'),
                              field: field,
                              value: widget.viewModel.getFieldValue(field.id),
                              onChanged: widget.isReadOnly // ✅ Si es readonly, no hacer nada
                                  ? (_) {}
                                  : (value) {
                                widget.viewModel.updateFieldValue(field.id, value);
                              },
                              errorText: widget.viewModel.getFieldError(field.id),
                              allValues: currentAnswers,
                              isReadOnly: widget.isReadOnly, // ✅ NUEVO parámetro
                              onNestedFieldChanged: widget.isReadOnly
                                  ? (_, __) {}
                                  : (fieldId, value) {
                                widget.viewModel.updateFieldValue(fieldId, value);
                              },
                            );
                          }),

                          SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botón de completar (fijo en la parte inferior)
                if (!widget.isReadOnly)
                  _buildCompleteButton()
                else
                  _buildCloseButton()
              ],
            );
          },
        ),
      ),
    );
  }
  Widget _buildCloseButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: Text('Cerrar'),
          ),
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

  Widget _buildCompleteButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _completeForm,
            icon: Icon(Icons.check_circle),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: Text('Confirmar formulario'),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProgress() async {
    final success = await widget.viewModel.saveProgress();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Progreso guardado'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar progreso'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeForm() async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Completar formulario?',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'Una vez completado, el formulario será marcado como terminado. ¿Deseas continuar?',
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
              foregroundColor: Colors.white,
            ),
            child: Text('Completar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Intentar completar el formulario
    final success = await widget.viewModel.saveAndComplete();

    if (!mounted) return;

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
      // Mostrar error específico
      final errorMessage = widget.viewModel.errorMessage ??
          'Error al completar formulario';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
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
            Expanded(
              child: Text(
                '¿Salir sin guardar?',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'Tienes cambios sin guardar. ¿Deseas guardar el progreso antes de salir?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Salir sin guardar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.viewModel.saveProgress();
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text('Guardar progreso'),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }
}