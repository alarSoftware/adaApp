import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import 'dynamic_form_template_repository.dart';
import 'dynamic_form_response_repository.dart';
import 'dynamic_form_sync_repository.dart';

/// Repository unificado que expone los repositorios especializados
/// Ya no delega métodos innecesariamente, solo proporciona acceso directo
class DynamicFormRepository {
  final Logger _logger = Logger();

  // Repositorios especializados (acceso público directo)
  final DynamicFormTemplateRepository templates = DynamicFormTemplateRepository();
  final DynamicFormResponseRepository responses = DynamicFormResponseRepository();
  final DynamicFormSyncRepository sync = DynamicFormSyncRepository();

  // ==================== MÉTODOS DE CONVENIENCIA ====================
  // Solo métodos que realmente combinan múltiples repositorios

  /// Elimina una respuesta y sus datos relacionados
  Future<bool> deleteResponseWithCleanup(String responseId) async {
    try {
      final images = await responses.getImagesForResponse(responseId);

      for (var image in images) {
        await responses.deleteImageFile(image);
      }

      return await responses.delete(responseId);
    } catch (e) {
      _logger.e('❌ Error eliminando respuesta con cleanup: $e');
      return false;
    }
  }

  /// Obtiene estadísticas completas del sistema
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final templateCount = await templates.count();
      final syncStats = await sync.getSyncStats();

      return {
        'templates': templateCount,
        ...syncStats,
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {
        'templates': 0,
        'pending': 0,
        'synced': 0,
        'errors': 0,
        'total': 0,
      };
    }
  }
}