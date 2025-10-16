import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import 'dynamic_form_template_repository.dart';
import 'dynamic_form_response_repository.dart';
import 'dynamic_form_sync_repository.dart';

/// Repository principal que delega a los repositorios especializados
/// Mantiene compatibilidad con el código existente
class DynamicFormRepository {
  final Logger _logger = Logger();

  // Repositorios especializados
  final DynamicFormTemplateRepository _templateRepo = DynamicFormTemplateRepository();
  final DynamicFormResponseRepository _responseRepo = DynamicFormResponseRepository();
  final DynamicFormSyncRepository _syncRepo = DynamicFormSyncRepository();

  // ==================== MÉTODOS DELEGADOS PARA TEMPLATES ====================

  Future<List<DynamicFormTemplate>> getAvailableTemplates() async {
    return await _templateRepo.getAll();
  }

  Future<bool> downloadTemplatesFromServer() async {
    return await _templateRepo.downloadFromServer();
  }

  Future<int> guardarFormulariosDesdeServidor(List<Map<String, dynamic>> formulariosServidor) async {
    return await _templateRepo.saveTemplatesFromServer(formulariosServidor);
  }

  Future<List<DynamicFormTemplate>> obtenerTodos() async {
    return await _templateRepo.getAll();
  }

  Future<DynamicFormTemplate?> obtenerPorId(String id) async {
    return await _templateRepo.getById(id);
  }

  Future<DynamicFormTemplate?> getTemplateById(String id) async {
    return await _templateRepo.getById(id);
  }

  Future<List<DynamicFormTemplate>> obtenerPorEstado(String estado) async {
    return await _templateRepo.getByStatus(estado);
  }

  Future<int> guardarTodosLosDetallesDesdeServidor(List<Map<String, dynamic>> detallesServidor) async {
    return await _templateRepo.saveDetailsFromServer(detallesServidor);
  }

  Future<int> guardarDetallesDesdeServidor(List<Map<String, dynamic>> detallesServidor, String formId) async {
    return await _templateRepo.saveDetailsFromServer(detallesServidor);
  }

  Future<bool> eliminar(String id) async {
    return await _templateRepo.delete(id);
  }

  Future<int> contarFormularios() async {
    return await _templateRepo.count();
  }

  // ==================== MÉTODOS DELEGADOS PARA RESPUESTAS ====================

  Future<bool> saveResponse(DynamicFormResponse response) async {
    return await _responseRepo.save(response);
  }

  Future<List<DynamicFormResponse>> getLocalResponses() async {
    return await _responseRepo.getAll();
  }

  Future<DynamicFormResponse?> getResponseById(String id) async {
    return await _responseRepo.getById(id);
  }

  Future<List<DynamicFormResponse>> getPendingResponses() async {
    return await _responseRepo.getByStatus('pending');
  }

  Future<bool> deleteResponse(String responseId) async {
    return await _responseRepo.delete(responseId);
  }

  Future<Map<String, dynamic>> getSyncMetadata(String responseId) async {
    return await _responseRepo.getSyncMetadata(responseId);
  }

  // ==================== MÉTODOS DELEGADOS PARA SINCRONIZACIÓN ====================

  /// Sincronizar una respuesta específica al servidor
  Future<bool> syncResponse(DynamicFormResponse response) async {
    return await _syncRepo.syncToServer(response.id);
  }

  /// Sincronizar todas las respuestas pendientes
  Future<Map<String, int>> syncAllPendingResponses() async {
    return await _syncRepo.syncAllPending();
  }

  /// Marcar respuesta como sincronizada
  Future<bool> markResponseAsSynced(String responseId) async {
    return await _syncRepo.markAsSynced(responseId);
  }

  /// Marcar detalles de respuesta como sincronizados
  Future<bool> markResponseDetailsAsSynced(String responseId) async {
    return await _syncRepo.markDetailsAsSynced(responseId);
  }

  /// Registrar intento fallido de sincronización
  Future<bool> markSyncAttemptFailed(String responseId, String errorMessage) async {
    return await _syncRepo.markSyncAttemptFailed(responseId, errorMessage);
  }

  /// Obtener respuestas pendientes de sincronización
  Future<List<DynamicFormResponse>> getPendingSync() async {
    return await _responseRepo.getPendingSync();
  }

  /// Contar respuestas pendientes de sincronización
  Future<int> countPendingSync() async {
    return await _responseRepo.countPendingSync();
  }

  /// Contar respuestas sincronizadas
  Future<int> countSynced() async {
    return await _responseRepo.countSynced();
  }

  /// Reintentar sincronización de una respuesta
  Future<bool> retrySyncResponse(String responseId) async {
    return await _syncRepo.retrySyncResponse(responseId);
  }

  /// Sincronizar respuesta al servidor (método principal)
  Future<bool> syncToServer(String responseId) async {
    return await _syncRepo.syncToServer(responseId);
  }

  /// Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _syncRepo.getSyncStats();
  }

  /// Verificar si hay respuestas pendientes de sincronización
  Future<bool> hasPendingSync() async {
    return await _syncRepo.hasPendingSync();
  }

  Future<int> guardarRespuestasDesdeServidor(List<Map<String, dynamic>> respuestasServidor) async {
    return await _responseRepo.saveResponsesFromServer(respuestasServidor);
  }

  /// Guardar detalles de respuestas desde el servidor
  Future<int> guardarDetallesRespuestasDesdeServidor(List<Map<String, dynamic>> detallesServidor) async {
    return await _responseRepo.saveResponseDetailsFromServer(detallesServidor);
  }

  // ==================== ACCESO DIRECTO A REPOSITORIOS ====================

  DynamicFormTemplateRepository get templates => _templateRepo;
  DynamicFormResponseRepository get responses => _responseRepo;
  DynamicFormSyncRepository get sync => _syncRepo;
}