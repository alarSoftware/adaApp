import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'dart:io';
import 'dart:convert';

class PreviewImageSection extends StatelessWidget {
  final String? imagePath;
  final String? imageBase64;
  final String titulo;
  final int numero;
  final bool esHistorial;

  const PreviewImageSection({
    super.key,
    required this.imagePath,
    required this.imageBase64,
    required this.titulo,
    required this.numero,
    this.esHistorial = false,
  });

  bool get tieneImagen =>
      (imagePath != null && imagePath!.isNotEmpty) ||
          (imageBase64 != null && imageBase64!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Divider(height: 20, color: AppColors.border),
            if (tieneImagen) ...[
              _buildImagePreview(context),
              const SizedBox(height: 8),
              _buildImageInfo(),
            ] else
              _buildNoImagePlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.camera_alt,
          color: numero == 1 ? AppColors.secondary : AppColors.primary,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (tieneImagen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  imagePath != null ? 'Archivo' : 'Base64',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return GestureDetector(
      onTap: () => _verImagenCompleta(context),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWidget(),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Ver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.file(
        File(imagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (imageBase64 != null && imageBase64!.isNotEmpty) {
            return _buildBase64Image();
          }
          return _buildErrorWidget();
        },
      );
    } else if (imageBase64 != null && imageBase64!.isNotEmpty) {
      return _buildBase64Image();
    } else {
      return _buildErrorWidget();
    }
  }

  Widget _buildBase64Image() {
    try {
      final bytes = base64Decode(imageBase64!);
      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
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
  }

  Widget _buildImageInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getImageInfo(),
              style: TextStyle(color: AppColors.primary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getImageInfo() {
    if (imagePath != null && imagePath!.isNotEmpty) {
      if (imageBase64 != null) {
        try {
          final bytes = base64Decode(imageBase64!);
          final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
          return 'Imagen desde archivo ($mb MB). Toca para ver completa.';
        } catch (e) {
          return 'Imagen desde archivo. Toca para ver completa.';
        }
      }
      return 'Imagen desde archivo. Toca para ver completa.';
    } else if (imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64!);
        final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        return 'Imagen desde base de datos ($mb MB). Toca para ver completa.';
      } catch (e) {
        return 'Imagen desde base de datos. Toca para ver completa.';
      }
    }
    return 'Sin información de imagen disponible.';
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        color: Colors.grey[50],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Sin imagen',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              esHistorial
                  ? 'No se capturó imagen en este registro'
                  : 'Use "Volver a Editar" para agregar una',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _verImagenCompleta(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageWidget(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}