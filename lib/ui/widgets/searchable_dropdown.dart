// ui/screens/forms_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:ada_app/ui/widgets/simple_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/viewmodels/forms_screens_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/app_notification.dart';
import 'package:ada_app/ui/widgets/inline_notification.dart';
import '../screens/preview_screen.dart';

class FormsScreen extends StatefulWidget {
  final Cliente cliente;

  const FormsScreen({super.key, required this.cliente});

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final _formKey = GlobalKey<FormState>();
  late FormsScreenViewModel _viewModel;
  late StreamSubscription<FormsUIEvent> _eventSubscription;
  late FocusNode _codigoBarrasFocusNode;

  // ✅ NUEVA: Bandera para evitar búsquedas durante acciones específicas
  bool _ejecutandoAccion = false;

  // ✅ Variables para notificaciones inline
  String? _inlineNotificationMessage;
  InlineNotificationType? _inlineNotificationType;
  bool _isInlineNotificationVisible = false;

  @override
  void initState() {
    super.initState();
    _viewModel = FormsScreenViewModel();
    _setupEventListener();
    _viewModel.initialize(widget.cliente);
    // Inicializar FocusNode para el campo de código
    _codigoBarrasFocusNode = FocusNode();
    _codigoBarrasFocusNode.addListener(_onCodigoBarrasFocusChanged);
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _codigoBarrasFocusNode.removeListener(_onCodigoBarrasFocusChanged);
    _codigoBarrasFocusNode.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // ✅ MODIFICADO: Método que detecta cuando el campo pierde el foco
  void _onCodigoBarrasFocusChanged() {
    if (!_codigoBarrasFocusNode.hasFocus) {
      // ✅ Solo buscar si NO estamos ejecutando una acción (Continuar/Cancelar)
      if (!_ejecutandoAccion) {
        _viewModel.buscarEquipoSiHuboCambios();
      }
    }
  }

  // ✅ MODIFICADO: Ahora usa notificaciones inline para mensajes de equipo con colores específicos
  void _setupEventListener() {
    _eventSubscription = _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowSnackBarEvent) {
        // ✅ Detectar si es un mensaje relacionado con búsqueda de equipo
        final mensajesInline = [
          'Equipo encontrado',
          'pendiente',
          'No se encontró',
          'encontrado',
        ];

        bool esInline = mensajesInline.any(
          (msg) => event.message.toLowerCase().contains(msg.toLowerCase()),
        );

        if (esInline) {
          // ✅ NUEVO: Determinar color según el contenido exacto del mensaje
          Color color;
          final message = event.message;

          // 🟢 Verde: "¡Equipo encontrado!" (mensaje corto, equipo YA asignado)
          if (message.contains('¡Equipo encontrado!') ||
              (message.contains('Equipo encontrado') &&
                  !message.contains('pero no asignado'))) {
            color = AppColors.success;
          }
          // 🟠 Amarillo/Naranja: "Equipo encontrado pero no asignado..." (mensaje largo, pendiente)
          else if (message.contains('pero no asignado') ||
              message.contains('pendiente') ||
              message.contains('se censara como pendiente')) {
            color = AppColors.warning;
          }
          // 🔴 Rojo: No encontrado
          else if (message.toLowerCase().contains('no se encontró') ||
              message.toLowerCase().contains('no encontrado')) {
            color = AppColors.error;
          }
          // Por defecto usar el color original
          else {
            color = event.color;
          }

          // Usar notificación inline con el color correcto
          _showInlineNotification(event.message, color);
        } else {
          // Usar SnackBar normal para otros mensajes
          _showSnackBar(event.message, event.color);
        }
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
    // ✅ Determinar tipo de notificación según el color
    NotificationType type;
    if (color == AppColors.success) {
      type = NotificationType.success;
    } else if (color == AppColors.error) {
      type = NotificationType.error;
    } else if (color == AppColors.warning) {
      type = NotificationType.warning;
    } else {
      type = NotificationType.info;
    }

    // ✅ Mostrar notificación moderna
    AppNotification.show(context, message: message, type: type);
  }

  // ✅ NUEVO: Método para mostrar notificación inline
  void _showInlineNotification(String message, Color color) {
    // Determinar tipo de notificación según el color
    InlineNotificationType type;
    if (color == AppColors.success) {
      type = InlineNotificationType.success;
    } else if (color == AppColors.error) {
      type = InlineNotificationType.error;
    } else if (color == AppColors.warning) {
      type = InlineNotificationType.warning;
    } else {
      type = InlineNotificationType.info;
    }

    setState(() {
      _inlineNotificationMessage = message;
      _inlineNotificationType = type;
      _isInlineNotificationVisible = true;
    });

    // Auto-ocultar después de 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isInlineNotificationVisible = false;
        });
      }
    });
  }

  // ✅ NUEVO: Método para ocultar notificación inline
  void _dismissInlineNotification() {
    setState(() {
      _isInlineNotificationVisible = false;
    });
  }

  Future<void> _showDialog(
    String title,
    String message,
    List<DialogAction> actions,
  ) async {
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          action.onPressed();
                        },
                        icon: Icon(_getButtonIcon(action.text), size: 16),
                        label: Text(action.text),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
              );
            }),
          ],
        );
      },
    );
  }

  Color _getIconBackgroundColor(String title) {
    if (title.contains('Advertencia') || title.contains('Atención')) {
      return AppColors.warning.withValues(alpha: 0.1);
    } else if (title.contains('Error') || title.contains('Problema')) {
      return AppColors.error;
    } else if (title.contains('Éxito') || title.contains('Completado')) {
      return AppColors.success;
    }
    return AppColors.info.withValues(alpha: 0.1);
  }

  Color _getIconColor(String title) {
    if (title.contains('Advertencia') || title.contains('Atención')) {
      return AppColors.warning;
    } else if (title.contains('Error') || title.contains('Problema')) {
      return AppColors.error;
    } else if (title.contains('Éxito') || title.contains('Completado')) {
      return AppColors.success;
    }
    return AppColors.info;
  }

  IconData _getIconForTitle(String title) {
    if (title.contains('Advertencia') || title.contains('Atención')) {
      return Icons.warning_amber_rounded;
    } else if (title.contains('Error') || title.contains('Problema')) {
      return Icons.error_outline;
    } else if (title.contains('Éxito') || title.contains('Completado')) {
      return Icons.check_circle_outline;
    } else if (title.contains('Equipo Encontrado')) {
      return Icons.qr_code_scanner;
    }
    return Icons.info_outline;
  }

  String _getSubtitle(String title) {
    if (title.contains('Equipo Encontrado')) {
      return 'Datos recuperados del sistema';
    } else if (title.contains('Equipo no encontrado')) {
      return 'Complete los datos manualmente';
    }
    return '';
  }

  bool _shouldShowAdditionalInfo(String title) {
    return title.contains('Equipo no encontrado') ||
        title.contains('Error') ||
        title.contains('Advertencia');
  }

  String _getAdditionalInfo(String title) {
    if (title.contains('Equipo no encontrado')) {
      return 'Recuerde verificar que el código sea correcto y que el equipo esté registrado en el sistema.';
    } else if (title.contains('Error')) {
      return 'Si el problema persiste, contacte con el administrador del sistema.';
    } else if (title.contains('Advertencia')) {
      return 'Por favor, revise la información antes de continuar.';
    }
    return '';
  }

  IconData _getButtonIcon(String text) {
    if (text.contains('Continuar') || text.contains('Aceptar')) {
      return Icons.check;
    } else if (text.contains('Cancelar')) {
      return Icons.close;
    } else if (text.contains('Reintentar')) {
      return Icons.refresh;
    }
    return Icons.arrow_forward;
  }

  void _navigateToPreview(Map<String, dynamic> datos) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PreviewScreen(datos: datos)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // ✅ Evita que se cierre automáticamente
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // ✅ Mostrar diálogo de confirmación
        final shouldExit = await _showCancelConfirmation();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return Text(_viewModel.titleText);
            },
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _viewModel.limpiarFormulario,
              tooltip: 'Limpiar formulario',
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          _buildCodigoBarrasField(),
                          const SizedBox(height: 16),
                          _buildMarcaDropdown(),
                          const SizedBox(height: 16),
                          _buildModeloDropdown(),
                          const SizedBox(height: 16),
                          _buildSerieField(),
                          const SizedBox(height: 16),
                          _buildLogoDropdown(),
                          const SizedBox(height: 16),
                          _buildImagenField(),
                          const SizedBox(height: 16),
                          _buildObservacionesField(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ MODIFICADO: Ahora incluye la notificación inline debajo del campo
  Widget _buildCodigoBarrasField() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código de barras:',
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
                    focusNode: _codigoBarrasFocusNode,
                    validator: _viewModel.validarCodigoBarras,
                    onChanged: _viewModel.onCodigoChanged,
                    onFieldSubmitted: _viewModel.onCodigoSubmitted,
                    enabled: !_viewModel.isLoading,
                    decoration: InputDecoration(
                      hintText: _viewModel.codigoHint,
                      prefixIcon: const Icon(Icons.barcode_reader),
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
                    width: 56,
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

            // ✅ NUEVA: Notificación inline debajo del campo de código
            if (_isInlineNotificationVisible &&
                _inlineNotificationMessage != null &&
                _inlineNotificationType != null)
              InlineNotification(
                message: _inlineNotificationMessage!,
                type: _inlineNotificationType!,
                visible: _isInlineNotificationVisible,
                onDismiss: _dismissInlineNotification,
              ),
          ],
        );
      },
    );
  }

  // ✅ ACTUALIZADO: Ahora usa SimpleAutocompleteField
  Widget _buildMarcaDropdown() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        // Convertir la lista de marcas a DropdownItems
        final marcaItems = _viewModel.marcas.map((marca) {
          final marcaId = marca['id'] is int
              ? marca['id']
              : int.tryParse(marca['id'].toString());

          return DropdownItem<int>(
            value: marcaId!,
            label: '${marca['nombre']}'.trim(),
          );
        }).toList();

        return SimpleAutocompleteField<int>(
          label: 'Marca:',
          hint: _viewModel.marcaHint,
          value: _viewModel.marcaSeleccionada,
          items: marcaItems,
          prefixIcon: Icons.business,
          enabled: _viewModel.areFieldsEnabled,
          onChanged: (value) {
            _viewModel.setMarcaSeleccionada(value);
            Future.microtask(() {
              _formKey.currentState?.validate();
            });
          },
          validator: (value) => _viewModel.validarMarca(value),
        );
      },
    );
  }

  Widget _buildModeloDropdown() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        // Convertir la lista de modelos a DropdownItems
        final modeloItems = _viewModel.modelos.map((modelo) {
          final modeloId = modelo['id'] is int
              ? modelo['id']
              : int.tryParse(modelo['id'].toString());

          return DropdownItem<int>(
            value: modeloId!,
            label: '${modelo['nombre']}'.trim(),
          );
        }).toList();

        return SimpleAutocompleteField<int>(
          label: 'Modelo:',
          hint: _viewModel.modeloHint,
          value: _viewModel.modeloSeleccionado,
          items: modeloItems,
          prefixIcon: Icons.devices,
          enabled: _viewModel.areFieldsEnabled,
          onChanged: (value) {
            _viewModel.setModeloSeleccionado(value);
            Future.microtask(() {
              _formKey.currentState?.validate();
            });
          },
          validator: (value) => _viewModel.validarModelo(value),
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
    FocusNode? focusNode,
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
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            fillColor: backgroundColor,
            filled: backgroundColor != null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        // Convertir la lista de logos a DropdownItems
        final logoItems = _viewModel.logos.map((logo) {
          final logoId = logo['id'] is int
              ? logo['id']
              : int.tryParse(logo['id'].toString());

          return DropdownItem<int>(
            value: logoId!,
            label: '${logo['nombre']}'.trim(),
          );
        }).toList();

        return SimpleAutocompleteField<int>(
          label: 'Logo:',
          hint: _viewModel.logoHint,
          value: _viewModel.logoSeleccionado,
          items: logoItems,
          prefixIcon: Icons.branding_watermark,
          enabled: _viewModel.areFieldsEnabled,
          onChanged: (value) {
            _viewModel.setLogoSeleccionado(value);
            Future.microtask(() {
              _formKey.currentState?.validate();
            });
          },
          validator: (value) => _viewModel.validarLogo(value),
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
        if (imagen != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  imagen,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: onEliminar,
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: onTomar,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tomar foto',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
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
                  onPressed: _viewModel.isLoading ? null : _handleCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _viewModel.isLoading ? null : _handleContinuar,
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
                            Icon(_viewModel.buttonIcon, size: 20),
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

  // ✅ NUEVO: Método para manejar el botón Continuar
  Future<void> _handleContinuar() async {
    // ✅ Activar bandera para evitar búsqueda automática
    setState(() {
      _ejecutandoAccion = true;
    });

    // ✅ Verificar cambios manualmente ANTES de continuar
    await _viewModel.buscarEquipoSiHuboCambios();

    // ✅ Continuar con el flujo normal
    _viewModel.continuarAPreview(_formKey);

    // ✅ Desactivar bandera después de un pequeño delay
    // (para evitar que se dispare la búsqueda durante la navegación)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _ejecutandoAccion = false;
        });
      }
    });
  }

  // ✅ MODIFICADO: Método para manejar el botón Cancelar
  Future<void> _handleCancel() async {
    // ✅ Activar bandera para evitar búsqueda automática
    setState(() {
      _ejecutandoAccion = true;
    });

    final shouldExit = await _showCancelConfirmation();
    if (shouldExit) {
      _viewModel.cancelar();
      // No hace falta desactivar la bandera porque salimos de la pantalla
    } else {
      // ✅ Si decide continuar, desactivar bandera
      setState(() {
        _ejecutandoAccion = false;
      });
    }
  }

  // ✅ NUEVO: Diálogo de confirmación simple
  Future<bool> _showCancelConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Cancelar censo?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro que quieres cancelar el censo? Se perderán los datos ingresados.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Continuar censo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}
