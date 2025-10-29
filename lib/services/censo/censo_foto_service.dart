// lib/services/censo/censo_foto_service.dart

import 'package:logger/logger.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/models/censo_activo_foto.dart'; // ← Agregar import

class CensoFotoService {
  final Logger _logger = Logger();
  final CensoActivoFotoRepository _fotoRepository;

  CensoFotoService({CensoActivoFotoRepository? fotoRepository})
      : _fotoRepository = fotoRepository ?? CensoActivoFotoRepository();

  /// Guarda las fotos asociadas a un censo
  Future<Map<String, String?>> guardarFotosDelCenso(
      String censoActivoId,
      Map<String, dynamic> datos,
      ) async {
    try {
      _logger.i('📸 Guardando fotos para censo: $censoActivoId');

      String? imagenId1;
      String? imagenId2;

      // Guardar primera imagen
      final tieneImagen = datos['tiene_imagen'] ?? false;
      if (tieneImagen && datos['imagen_base64'] != null) {
        imagenId1 = await _guardarFoto(
          censoActivoId: censoActivoId,
          imagenPath: datos['imagen_path'],
          imagenBase64: datos['imagen_base64'],
          imagenTamano: datos['imagen_tamano'],
          orden: 1,
        );
      }

      // Guardar segunda imagen
      final tieneImagen2 = datos['tiene_imagen2'] ?? false;
      if (tieneImagen2 && datos['imagen_base64_2'] != null) {
        imagenId2 = await _guardarFoto(
          censoActivoId: censoActivoId,
          imagenPath: datos['imagen_path2'],
          imagenBase64: datos['imagen_base64_2'],
          imagenTamano: datos['imagen_tamano2'],
          orden: 2,
        );
      }

      _logger.i('✅ Fotos guardadas - ID1: $imagenId1, ID2: $imagenId2');

      return {
        'imagen_id_1': imagenId1,
        'imagen_id_2': imagenId2,
      };
    } catch (e) {
      _logger.e('❌ Error en guardarFotosDelCenso: $e');
      return {
        'imagen_id_1': null,
        'imagen_id_2': null,
      };
    }
  }

  /// Obtiene las fotos de un censo
  Future<List<CensoActivoFoto>> obtenerFotos(String censoActivoId) async {
    try {
      return await _fotoRepository.obtenerFotosPorCenso(censoActivoId);
    } catch (e) {
      _logger.e('❌ Error obteniendo fotos: $e');
      return [];
    }
  }

  /// Marca las fotos como sincronizadas
  Future<void> marcarFotosComoSincronizadas(List<CensoActivoFoto> fotos) async {
    try {
      for (final foto in fotos) {
        if (foto.id != null) {
          await _fotoRepository.marcarComoSincronizada(foto.id!);
        }
      }
      _logger.i('✅ ${fotos.length} fotos marcadas como sincronizadas');
    } catch (e) {
      _logger.e('❌ Error marcando fotos: $e');
    }
  }

  // Método privado para guardar una foto individual
  Future<String?> _guardarFoto({
    required String censoActivoId,
    String? imagenPath,
    String? imagenBase64,
    int? imagenTamano,
    required int orden,
  }) async {
    try {
      final foto = await _fotoRepository.guardarFoto(
        censoActivoId: censoActivoId,
        imagenPath: imagenPath,
        imagenBase64: imagenBase64,
        imagenTamano: imagenTamano,
        orden: orden,
      );
      _logger.i('✅ Foto $orden guardada: ${foto.id}');
      return foto.id; // ← Retornar el ID del objeto
    } catch (e) {
      _logger.e('❌ Error guardando foto $orden: $e');
      return null;
    }
  }
}