// ui/screens/forms_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/viewmodels/forms_screens_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'preview_screen.dart';

class FormsScreen extends StatefulWidget {
  final Cliente cliente;

  const FormsScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final _formKey = GlobalKey<FormState>();
  late FormsScreenViewModel _viewModel;
  late StreamSubscription<FormsUIEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = FormsScreenViewModel();
    _setupEventListener();
    _viewModel.initialize(widget.cliente);
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

      if (event is ShowSnackBarEvent) {
        _showSnackBar(event.message, event.color);
      } else if (event is ShowDialogEvent) {
        _showDialog(event.title, event.message, event.actions);
      } else if (event is NavigateToPreviewEvent) {
        _navigateToPreview(event.datos);
      } else if (event is NavigateBackEvent) {
        Navigator.of(context).pop(event.result);
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showDialog(String title, String message, List<DialogAction> actions) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.cardBackground,
          title: Row(
            children: [
              Icon(
                Icons.search_off,
                color: AppColors.textSecondary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              if (title == 'Equipo no encontrado') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Desea registrar un nuevo equipo?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('• Complete manualmente los datos del equipo',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text('• El código actual se mantendrá',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text('• Podrá corregir el código si es necesario',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: actions.map((action) {
            return action.isDefault
                ? ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                action.onPressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                foregroundColor: AppColors.buttonTextPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(action.text),
            )
                : TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                action.onPressed();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(action.text),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _navigateToPreview(Map<String, dynamic> datos) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(datos: datos),
      ),
    );
    _viewModel.onNavigationResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          return Text(_viewModel.titleText);
        },
      ),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      elevation: 2,
      shadowColor: AppColors.shadowLight,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: 16.0 + MediaQuery.of(context).padding.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeIndicator(),
            const SizedBox(height: 16),
            _buildFormulario(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeIndicator() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border.all(
              color: AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _viewModel.modeIcon,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viewModel.modeTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _viewModel.modeSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormulario() {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCodigoBarrasField(),
            const SizedBox(height: 16),
            _buildModeloField(),
            const SizedBox(height: 16),
            _buildLogoDropdown(),
            const SizedBox(height: 16),
            _buildSerieField(),
          ],
        ),
      ),
    );
  }

  Widget _buildCodigoBarrasField() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código de activo:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _viewModel.codigoBarrasController,
                    validator: _viewModel.validarCodigoBarras,
                    onChanged: _viewModel.onCodigoChanged,
                    onFieldSubmitted: _viewModel.onCodigoSubmitted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: _viewModel.codigoHint,
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _viewModel.limpiarFormulario,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.focus),
                      ),
                    ),
                  ),
                ),
                if (_viewModel.shouldShowCamera) ...[
                  const SizedBox(width: 12),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: _viewModel.isLoading || _viewModel.isScanning
                          ? null
                          : _viewModel.escanearCodigoBarras,
                      icon: _viewModel.isScanning
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.camera_alt,
                        color: AppColors.background,
                        size: 24,
                      ),
                      tooltip: 'Escanear código',
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeloField() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return _buildTextField(
          controller: _viewModel.modeloController,
          label: 'Modelo:',
          hint: _viewModel.modeloHint,
          icon: Icons.devices,
          validator: _viewModel.validarModelo,
          enabled: _viewModel.areFieldsEnabled,
          backgroundColor: _viewModel.fieldBackgroundColor,
        );
      },
    );
  }

  Widget _buildSerieField() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return _buildTextField(
          controller: _viewModel.numeroSerieController,
          label: 'Serie:',
          hint: _viewModel.serieHint,
          icon: Icons.confirmation_number,
          validator: _viewModel.validarNumeroSerie,
          enabled: _viewModel.areFieldsEnabled,
          backgroundColor: _viewModel.fieldBackgroundColor,
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    Color? backgroundColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            fillColor: backgroundColor,
            filled: backgroundColor != null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.focus),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoDropdown() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logo:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<int>(
                value: _viewModel.logos.any((logo) => logo['id'] == _viewModel.logoSeleccionado)
                    ? _viewModel.logoSeleccionado
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.branding_watermark),
                  fillColor: _viewModel.fieldBackgroundColor,
                  filled: _viewModel.fieldBackgroundColor != null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.focus),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                hint: Text(
                  _viewModel.logoHint,
                  overflow: TextOverflow.ellipsis,
                ),
                items: _viewModel.logos.map((logo) {
                  return DropdownMenuItem<int>(
                    value: logo['id'] is int ? logo['id'] : int.tryParse(logo['id'].toString()),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        logo['nombre'],
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _viewModel.areFieldsEnabled ? _viewModel.setLogoSeleccionado : null,
                validator: _viewModel.validarLogo,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.containerBackground.withValues(alpha: 0.78),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, child) {
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _viewModel.isLoading ? null : _viewModel.cancelar,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () => _viewModel.continuarAPreview(_formKey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonPrimary,
                      foregroundColor: AppColors.buttonTextPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: _viewModel.isLoading
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Procesando...'),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _viewModel.buttonIcon,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_viewModel.buttonText),
                      ],
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
}