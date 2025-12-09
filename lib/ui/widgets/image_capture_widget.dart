// ui/widgets/image_capture_widget.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/image_service.dart'; // TU SERVICE EXISTENTE

class ImageCaptureWidget extends StatefulWidget {
  final Function(String imagePath, String base64Data)? onImageCaptured;
  final String? initialImagePath;

  const ImageCaptureWidget({
    super.key,
    this.onImageCaptured,
    this.initialImagePath,
  });

  @override
  State<ImageCaptureWidget> createState() => _ImageCaptureWidgetState();
}

class _ImageCaptureWidgetState extends State<ImageCaptureWidget> {
  final ImageService _imageService = ImageService(); // USAR TU SERVICE
  String? _currentImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.initialImagePath;
  }

  Future<void> _captureImage() async {
    try {
      setState(() => _isLoading = true);

      // USAR TU IMAGE SERVICE
      final File? image = await _imageService.tomarFoto();

      if (image != null) {
        // Validar imagen usando tu service
        if (!_imageService.esImagenValida(image)) {
          _showErrorDialog('El archivo no es una imagen valida');
          return;
        }

        // Verificar tamano usando tu service
        final double tamanoMB = await _imageService.obtenerTamanoImagen(image);
        if (tamanoMB > 10.0) {
          _showErrorDialog(
            'La imagen es demasiado grande (${tamanoMB.toStringAsFixed(1)}MB). Maximo 10MB.',
          );
          return;
        }

        // Mostrar preview para confirmacion
        final confirmed = await _showImagePreview(image.path);

        if (confirmed == true) {
          // Convertir a Base64 para envio al servidor
          final bytes = await image.readAsBytes();
          final base64Data = base64Encode(bytes);

          setState(() {
            _currentImagePath = image.path;
          });

          // Callback con la ruta local y datos Base64
          widget.onImageCaptured?.call(image.path, base64Data);
        }
      }
    } catch (e) {
      _showErrorDialog('Error al capturar imagen: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      setState(() => _isLoading = true);

      // USAR TU IMAGE SERVICE PARA GALERIA
      final File? image = await _imageService.seleccionarImagen();

      if (image != null) {
        // Validar imagen usando tu service
        if (!_imageService.esImagenValida(image)) {
          _showErrorDialog('El archivo no es una imagen valida');
          return;
        }

        // Verificar tamano usando tu service
        final double tamanoMB = await _imageService.obtenerTamanoImagen(image);
        if (tamanoMB > 10.0) {
          _showErrorDialog(
            'La imagen es demasiado grande (${tamanoMB.toStringAsFixed(1)}MB). Maximo 10MB.',
          );
          return;
        }

        // Mostrar preview para confirmacion
        final confirmed = await _showImagePreview(image.path);

        if (confirmed == true) {
          // Convertir a Base64 para envio al servidor
          final bytes = await image.readAsBytes();
          final base64Data = base64Encode(bytes);

          setState(() {
            _currentImagePath = image.path;
          });

          // Callback con la ruta local y datos Base64
          widget.onImageCaptured?.call(image.path, base64Data);
        }
      }
    } catch (e) {
      _showErrorDialog('Error al seleccionar imagen: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showImagePreview(String imagePath) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImagePreviewDialog(imagePath: imagePath),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Seleccionar Imagen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Opcion de camara
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Tomar Foto'),
                subtitle: const Text('Usar la camara del dispositivo'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage();
                },
              ),

              // Opcion de galeria
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: AppColors.secondary),
                ),
                title: const Text('Seleccionar de Galeria'),
                subtitle: const Text('Elegir imagen existente'),
                onTap: () {
                  Navigator.pop(context);
                  _selectFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentImagePath != null
          ? _buildImagePreview()
          : _buildCaptureButton(),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_currentImagePath!),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'Error cargando imagen',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.edit,
                onPressed: _showImageSourceDialog,
                backgroundColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.delete,
                onPressed: _removeImage,
                backgroundColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.add_a_photo,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Agregar Imagen',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Camara o Galeria',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _currentImagePath = null;
    });
    widget.onImageCaptured?.call('', '');
  }
}

class ImagePreviewDialog extends StatelessWidget {
  final String imagePath;

  const ImagePreviewDialog({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.preview, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Confirmar Imagen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Image Preview
            Container(
              constraints: const BoxConstraints(
                maxHeight: 400,
                maxWidth: double.infinity,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
