// ui/screens/forms_screen.dart
import 'dart:io';

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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.dialogBackground,
          elevation: 8,
          titlePadding: const EdgeInsets.all(20),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(title),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getIconForTitle(title),
                  color: _getIconColor(title),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dialogTitleText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_getSubtitle(title).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _getSubtitle(title),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.dialogContentText,
                    ),
                  ),

                  if (_shouldShowAdditionalInfo(title)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.infoContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getAdditionalInfo(title),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          actions: [
            ...actions.reversed.map((action) {
              final bool isPrimary = action.isDefault;

              return Container(
                margin: const EdgeInsets.only(left: 6),
                child: isPrimary
                    ? ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    action.onPressed();
                  },
                  icon: Icon(_getButtonIcon(action.text), size: 16),
                  label: Text(action.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                    foregroundColor: AppColors.buttonTextPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                )
                    : OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    action.onPressed();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  child: Text(action.text),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'equipo no encontrado':
        return Icons.search_off_outlined;
      case 'error':
        return Icons.error_outline;
      case 'confirmación':
        return Icons.check_circle_outline;
      case 'advertencia':
        return Icons.warning_amber_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(String title) {
    switch (title.toLowerCase()) {
      case 'equipo no encontrado':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      case 'confirmación':
        return AppColors.success;
      case 'advertencia':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  Color _getIconBackgroundColor(String title) {
    return _getIconColor(title).withValues(alpha: 0.1);
  }

  String _getSubtitle(String title) {
    switch (title.toLowerCase()) {
      case 'equipo no encontrado':
        return 'Sistema de Inventario';
      case 'error':
        return 'Se requiere atención';
      case 'confirmación':
        return 'Operación completada';
      default:
        return '';
    }
  }

  bool _shouldShowAdditionalInfo(String title) {
    return ['equipo no encontrado', 'error'].contains(title.toLowerCase());
  }

  String _getAdditionalInfo(String title) {
    switch (title.toLowerCase()) {
      case 'equipo no encontrado':
        return 'Contacte al administrador si el problema persiste.';
      case 'error':
        return 'Verifique su conexión e intente nuevamente.';
      default:
        return '';
    }
  }

  IconData _getButtonIcon(String buttonText) {
    switch (buttonText.toLowerCase()) {
      case 'corregir código':
      case 'corregir':
      case 'editar código':
        return Icons.edit;
      case 'registrar':
      case 'crear':
      case 'agregar':
      case 'registrar nuevo':
      case 'registrar nuevo equipo':
        return Icons.add_circle_outline;
      case 'reintentar':
        return Icons.refresh;
      case 'continuar':
        return Icons.arrow_forward;
      case 'guardar':
        return Icons.save;
      case 'cancelar':
        return Icons.close;
      case 'aceptar':
      case 'ok':
        return Icons.check;
      default:
        return Icons.check;
    }
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
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Stack(
          children: [
            Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: _buildAppBar(),
              body: SafeArea(
                child: Column(
                  children: [
                    // Contenido scrolleable
                    Expanded(
                      child: _buildBody(),
                    ),
                    // Botones AQUÍ - esto es lo que faltaba agregar
                    _buildBottomButtons(),
                  ],
                ),
              ),
              // NO pongas bottomNavigationBar aquí
            ),

            // Overlay de bloqueo cuando está procesando
            if (_viewModel.isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Procesando...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Por favor espere',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
      padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 16,),
            _buildImagenField(),
            const SizedBox(height: 16,),
            _buildObservacionesField(),
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
                value: _viewModel.logos.isNotEmpty &&
                    _viewModel.logoSeleccionado != null &&
                    _viewModel.logos.any((logo) => logo['id'] == _viewModel.logoSeleccionado)
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
                  final logoId = logo['id'] is int ? logo['id'] : int.tryParse(logo['id'].toString());
                  return DropdownMenuItem<int>(
                    value: logoId,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        '${logo['nombre']} (ID: $logoId)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _viewModel.areFieldsEnabled
                    ? (value) {
                  print('Dropdown onChanged: $value');
                  _viewModel.setLogoSeleccionado(value);
                }
                    : null,
                validator: (value) {
                  final result = _viewModel.validarLogo(value);
                  print('Dropdown validation: $value -> $result');
                  return result;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagenField() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imágenes del equipo:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            _buildSingleImageField(
              imagen: _viewModel.imagenSeleccionada,
              titulo: 'Foto',
              onTomar: () => _viewModel.tomarFoto(esPrimeraFoto: true),
              onEliminar: () => _viewModel.eliminarImagen(esPrimeraFoto: true),
            ),

            const SizedBox(height: 16),

            _buildSingleImageField(
              imagen: _viewModel.imagenSeleccionada2,
              titulo: 'Foto',
              onTomar: () => _viewModel.tomarFoto(esPrimeraFoto: false),
              onEliminar: () => _viewModel.eliminarImagen(esPrimeraFoto: false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleImageField({
    required File? imagen,
    required String titulo,
    required VoidCallback onTomar,
    required VoidCallback onEliminar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        if (imagen != null) ...[
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                imagen,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onTomar,
            icon: Icon(imagen != null ? Icons.camera_alt : Icons.add_a_photo),
            label: Text(imagen != null ? 'Cambiar $titulo' : 'Tomar $titulo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
            ),
          ),
        ),

        if (imagen != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text('Eliminar $titulo'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildObservacionesField() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return _buildTextField(
          controller: _viewModel.observacionesController,
          label: _viewModel.observacionesLabel,
          hint: _viewModel.observacionesHint,
          icon: Icons.comment_outlined,
          maxLines: 3,
          enabled: _viewModel.observacionesEnabled,
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16,  // ← Simplificado, el SafeArea ya maneja el padding inferior
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
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
    );
  }
}