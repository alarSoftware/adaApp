import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/ui/widgets/dynamic_form/dynamic_form_field_widget.dart';

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
        if (widget.isReadOnly) return true;
        return await _showExitConfirmation();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, child) => _buildBody(),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        widget.viewModel.currentTemplate?.title ?? 'Formulario',
        style: TextStyle(color: AppColors.onPrimary, fontSize: 18),
      ),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
    );
  }

  Widget _buildBody() {
    final template = widget.viewModel.currentTemplate;

    if (template == null) {
      return Center(
        child: Text(
          'No se pudo cargar el formulario',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        if (!widget.isReadOnly) _buildProgressBar(),
        if (widget.isReadOnly) _buildReadOnlyBanner(),
        Expanded(child: _buildFormContent(template)),
        widget.isReadOnly ? _buildCloseButton() : _buildCompleteButton(),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = widget.viewModel.getFormProgress();
    final percentage = (progress * 100).toInt();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
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

  Widget _buildReadOnlyBanner() {
    return Container(
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
    );
  }

  Widget _buildFormContent(template) {
    final currentAnswers = widget.viewModel.currentResponse?.answers ?? {};

    return Container(
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
            ...template.fields.map((field) {
              return DynamicFormFieldWidget(
                key: ValueKey('${field.id}_${currentAnswers[field.id]}'),
                field: field,
                value: widget.viewModel.getFieldValue(field.id),
                onChanged: widget.isReadOnly
                    ? (_) {}
                    : (value) => widget.viewModel.updateFieldValue(field.id, value),
                errorText: widget.viewModel.getFieldError(field.id),
                allValues: currentAnswers,
                isReadOnly: widget.isReadOnly,
                onNestedFieldChanged: widget.isReadOnly
                    ? (_, __) {}
                    : (fieldId, value) => widget.viewModel.updateFieldValue(fieldId, value),
              );
            }),
            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
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

  Widget _buildCloseButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
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

  Future<void> _completeForm() async {
    final confirm = await _showConfirmDialog(
      title: '¿Completar formulario?',
      content: 'Una vez completado, el formulario será marcado como terminado. ¿Deseas continuar?',
      confirmText: 'Completar',
      confirmColor: AppColors.success,
    );

    if (confirm != true) return;

    final success = await widget.viewModel.saveAndComplete();

    if (!mounted) return;

    if (success) {
      _showSnackBar(
        message: '✅ Formulario completado exitosamente',
        backgroundColor: AppColors.success,
      );
      Navigator.pop(context);
    } else {
      final errorMessage = widget.viewModel.errorMessage ?? 'Error al completar formulario';
      _showSnackBar(
        message: '❌ $errorMessage',
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 3),
      );
    }
  }

  Future<bool> _showExitConfirmation() async {
    final progress = widget.viewModel.getFormProgress();

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

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: confirmColor),
            SizedBox(width: 8),
            Expanded(
              child: Text(title, style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
        content: Text(content, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
}