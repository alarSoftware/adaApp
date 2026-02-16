// services/image_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Toma una foto usando la cámara
  Future<File?> tomarFoto({
    int maxWidth = 1600,
    int maxHeight = 900,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? foto = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (foto != null) {
        return File(foto.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error tomando foto: $e');
      rethrow;
    }
  }

  /// Selecciona una imagen de la galería
  Future<File?> seleccionarImagen({
    int maxWidth = 1600,
    int maxHeight = 900,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (imagen != null) {
        return File(imagen.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      rethrow;
    }
  }

  /// Guarda una imagen temporal en el directorio de la aplicación
  Future<File> guardarImagenEnApp(File imagen, String codigoEquipo) async {
    try {
      // Crear directorio para imágenes de equipos si no existe
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imageDir = Directory(
        path.join(appDir.path, 'equipos_images'),
      );

      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      // Generar nombre único para la imagen
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String codigoLimpio = codigoEquipo.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String extension = path.extension(imagen.path);
      final String nombreArchivo =
          'equipo_${codigoLimpio}_$timestamp$extension';

      // Copiar imagen al directorio de la app
      final String rutaDestino = path.join(imageDir.path, nombreArchivo);
      final File archivoDestino = await imagen.copy(rutaDestino);

      debugPrint('Imagen guardada: $rutaDestino');
      return archivoDestino;
    } catch (e) {
      debugPrint('Error guardando imagen: $e');
      rethrow;
    }
  }

  /// Elimina un archivo de imagen
  Future<bool> eliminarImagen(File imagen) async {
    try {
      if (await imagen.exists()) {
        await imagen.delete();
        debugPrint('Imagen eliminada: ${imagen.path}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error eliminando imagen: $e');
      return false;
    }
  }

  /// Valida si un archivo es una imagen válida
  bool esImagenValida(File? imagen) {
    if (imagen == null) return false;

    final String extension = path.extension(imagen.path).toLowerCase();
    final List<String> extensionesPermitidas = [
      '.jpg',
      '.jpeg',
      '.png',
      '.bmp',
      '.gif',
    ];

    return extensionesPermitidas.contains(extension);
  }

  /// Obtiene el tamaño de un archivo de imagen en MB
  Future<double> obtenerTamanoImagen(File imagen) async {
    try {
      final int bytes = await imagen.length();
      return bytes / (1024 * 1024); // Convertir a MB
    } catch (e) {
      debugPrint('Error obteniendo tamaño de imagen: $e');
      return 0.0;
    }
  }
}
