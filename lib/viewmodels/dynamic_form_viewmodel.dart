import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_field.dart';
import '../repositories/dynamic_form_template_repository.dart';
import '../repositories/dynamic_form_response_repository.dart';
import '../repositories/dynamic_form_sync_repository.dart';
import '../services/sync/dynamic_form_sync_service.dart';

class DynamicFormViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final Uuid _uuid = Uuid();

  // Repositorios
  final DynamicFormTemplateRepository _templateRepo = DynamicFormTemplateRepository();
  final DynamicFormResponseRepository _responseRepo = DynamicFormResponseRepository();
  final DynamicFormSyncRepository _syncRepo = DynamicFormSyncRepository();

  // Estado
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  // Templates
  List<DynamicFormTemplate> _templates = [];

  // Formulario actual
  DynamicFormTemplate? _currentTemplate;
  DynamicFormResponse? _currentResponse;
  Map<String, dynamic> _fieldValues = {};
  Map<String, String?> _fieldErrors = {};

  // Respuestas guardadas
  List<DynamicFormResponse> _savedResponses = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  List<DynamicFormTemplate> get templates => _templates;
  DynamicFormTemplate? get currentTemplate => _currentTemplate;
  DynamicFormResponse? get currentResponse => _currentResponse;
  List<DynamicFormResponse> get savedResponses => _savedResponses;

  // ==================== TEMPLATES ====================

  Future<void> loadTemplates() async {
    await _executeWithLoading(() async {
      _templates = await _templateRepo.getAll();
      _logger.i('✅ Templates cargados: ${_templates.length}');
    });
  }

  Future<bool> downloadTemplatesFromServer() async {
    return await _executeWithLoading(() async {
      _logger.i('📥 Descargando formularios desde servidor...');

      final success = await _templateRepo.downloadFromServer();

      if (success) {
        await loadTemplates();
        _logger.i('✅ Templates descargados: ${_templates.length} disponibles');
        return true;
      }

      _errorMessage = 'Error descargando formularios del servidor';
      _logger.e('❌ Error descargando templates');
      return false;
    }, defaultValue: false);
  }

  DynamicFormTemplate? getTemplateById(String templateId) {
    try {
      return _templates.firstWhere((t) => t.id == templateId);
    } catch (e) {
      return null;
    }
  }

  // ==================== FORM LIFECYCLE ====================

  void startNewForm(
      String templateId, {
        String? contactoId,
        String? equipoId,
        String? userId,
        String? edfVendedorId,
        DynamicFormResponse? existingResponse,
      }) {
    try {
      _currentTemplate = _templates.firstWhere(
            (t) => t.id == templateId,
        orElse: () => throw Exception('Template no encontrado'),
      );

      if (existingResponse != null) {
        _loadExistingResponse(existingResponse);
      } else {
        _createNewResponse(templateId, contactoId, userId, edfVendedorId);
      }

      _fieldErrors.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error iniciando formulario: $e';
      _logger.e('❌ Error iniciando formulario: $e');
      notifyListeners();
    }
  }

  void _loadExistingResponse(DynamicFormResponse response) {
    _currentResponse = response;
    _fieldValues = Map<String, dynamic>.from(response.answers);

    _logger.i('✅ Formulario cargado para editar: ${response.id}');
    _logger.i('📝 Valores cargados: ${_fieldValues.length} campos');

    // ✨ NUEVO: Log detallado de los valores cargados
    _logger.i('📋 Contenido de campos:');
    _fieldValues.forEach((key, value) {
      if (value is String && (value.contains('.jpg') || value.contains('.png') || value.contains('.jpeg'))) {
        _logger.i('  📸 $key: $value (posible imagen)');
      } else {
        _logger.i('  📝 $key: $value');
      }
    });
  }

  void _createNewResponse(
      String templateId,
      String? contactoId,
      String? userId,
      String? edfVendedorId,
      ) {
    final responseId = _uuid.v4();

    _currentResponse = DynamicFormResponse(
      id: responseId,
      formTemplateId: templateId,
      answers: {},
      createdAt: DateTime.now(),
      status: 'draft',
      contactoId: contactoId,
      userId: userId,
      edfVendedorId: edfVendedorId,
    );

    _fieldValues.clear();
    _logger.i('✅ Formulario nuevo iniciado: ${_currentTemplate?.title} (UUID: $responseId)');
  }

  void loadResponseForEditing(DynamicFormResponse response) {
    try {
      _currentTemplate = _templates.firstWhere(
            (t) => t.id == response.formTemplateId,
        orElse: () => throw Exception('Template no encontrado'),
      );

      _loadExistingResponse(response);
      _logger.i('✅ Respuesta cargada para edición: ${response.id}');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error cargando respuesta: $e';
      _logger.e('❌ Error cargando respuesta: $e');
      notifyListeners();
    }
  }

  // ==================== FIELD MANAGEMENT ====================

  dynamic getFieldValue(String fieldId) => _fieldValues[fieldId];

  String? getFieldError(String fieldId) => _fieldErrors[fieldId];

  void updateFieldValue(String fieldId, dynamic value) {
    final field = _currentTemplate?.getFieldById(fieldId);

    if (field != null && (field.type == 'radio_button' || field.type == 'checkbox')) {
      _clearChildrenValues(field, value);
    }

    _fieldValues[fieldId] = value;
    _fieldErrors.remove(fieldId);

    if (_currentResponse != null) {
      _currentResponse = _currentResponse!.copyWith(answers: {..._fieldValues});
    }

    _logger.d('📝 Campo actualizado: $fieldId = $value');
    notifyListeners();
  }

  void _clearChildrenValues(DynamicFormField field, dynamic newValue) {
    if (field.type == 'radio_button') {
      _clearAllOptions(field);
    } else if (field.type == 'checkbox') {
      _clearUnselectedOptions(field, newValue);
    }
  }

  void _clearAllOptions(DynamicFormField field) {
    for (var option in field.children.where((c) => c.type == 'opt')) {
      _clearFieldAndDescendants(option);
    }
  }

  void _clearUnselectedOptions(DynamicFormField field, dynamic newValue) {
    final selectedIds = newValue is List ? List<String>.from(newValue) : <String>[];

    for (var option in field.children.where((c) => c.type == 'opt')) {
      if (!selectedIds.contains(option.id)) {
        _clearFieldAndDescendants(option);
      }
    }
  }

  void _clearFieldAndDescendants(DynamicFormField field) {
    if (field.type != 'opt') {
      _fieldValues.remove(field.id);
      _fieldErrors.remove(field.id);
      _logger.d('🧹 Limpiando campo: ${field.id} (${field.label})');
    }

    for (var child in field.children) {
      _clearFieldAndDescendants(child);
    }
  }

  // ==================== MANEJO DE IMÁGENES ====================

  /// Guarda una imagen inmediatamente cuando el usuario la selecciona
  Future<bool> saveImageForField(String fieldId, String imagePath) async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      // 1. Guardar imagen en dynamic_form_response_image
      final imageId = await _responseRepo.saveImageImmediately(
        responseId: _currentResponse!.id,
        fieldId: fieldId,
        imagePath: imagePath,
      );

      if (imageId != null) {
        updateFieldValue(fieldId, imagePath);

        _logger.i('✅ Imagen y detalle guardados exitosamente');
        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = 'Error guardando imagen: $e';
      _logger.e('❌ Error en saveImageForField: $e');
      return false;
    }
  }

  /// Elimina una imagen de un campo
  Future<bool> deleteImageForField(String fieldId) async {
    try {
      if (_currentResponse == null) {
        _logger.e('❌ No hay formulario activo para eliminar imagen');
        return false;
      }

      _logger.i('🗑️ Eliminando imagen del campo: $fieldId');

      // Buscar el detalle asociado
      final details = await _responseRepo.getDetails(_currentResponse!.id);
      final detail = details.where((d) => d.dynamicFormDetailId == fieldId).firstOrNull;

      if (detail != null) {
        // Obtener y eliminar imágenes
        final images = await _responseRepo.getImagesForDetail(detail.id);
        for (var image in images) {
          await _responseRepo.deleteImageFile(image);
        }
      }

      // Limpiar el valor del campo
      updateFieldValue(fieldId, null);
      _logger.i('✅ Imagen eliminada');
      return true;
    } catch (e) {
      _logger.e('❌ Error eliminando imagen: $e');
      return false;
    }
  }

  // ==================== VALIDATION ====================

  bool _validateAllFields() {
    if (_currentTemplate == null) return false;

    _fieldErrors.clear();
    bool isValid = true;

    final answerableFields = _currentTemplate!.answerableFields;

    for (final field in answerableFields) {
      if (field.required && _isFieldEmpty(_fieldValues[field.id])) {
        _fieldErrors[field.id] = '${field.label} es obligatorio';
        isValid = false;
        _logger.w('⚠️ Campo obligatorio sin completar: ${field.label} (${field.id})');
      }
    }

    if (!isValid) {
      _logger.w('⚠️ Validación fallida: ${_fieldErrors.length} errores');
    }

    return isValid;
  }

  bool isFormComplete() {
    if (_currentTemplate == null) return false;

    return _currentTemplate!.requiredFields
        .every((field) => !_isFieldEmpty(_fieldValues[field.id]));
  }

  double getFormProgress() {
    if (_currentTemplate == null) return 0.0;

    final requiredFields = _currentTemplate!.requiredFields;
    if (requiredFields.isEmpty) return 1.0;

    final filledCount = requiredFields
        .where((field) => !_isFieldEmpty(_fieldValues[field.id]))
        .length;

    return filledCount / requiredFields.length;
  }

  bool _isFieldEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }

  // ==================== SAVING ====================

  Future<bool> saveProgress() async {
    return await _saveWithStatus('draft', 'Guardando progreso como borrador...');
  }

  Future<bool> saveDraft() async {
    return await _saveWithStatus('draft', 'Guardando borrador...');
  }

  Future<bool> saveAndComplete() async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('✔️ Intentando completar formulario...');

      if (!_validateAllFields()) {
        _errorMessage = 'Por favor completa todos los campos obligatorios';
        _logger.w('⚠️ Validación fallida al completar');
        notifyListeners();
        return false;
      }

      final completedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        completedAt: DateTime.now(),
        status: 'completed',
      );

      final saved = await _responseRepo.save(completedResponse);
      if (!saved) {
        _errorMessage = 'Error al guardar el formulario';
        notifyListeners();
        return false;
      }

      _logger.i('✅ Formulario completado (imágenes ya guardadas en BD)');

      // Sincronizar
      await _syncResponse(completedResponse.id);

      _clearCurrentForm();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error completando formulario: $e';
      _logger.e('❌ Error en saveAndComplete: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _saveWithStatus(String status, String logMessage) async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('💾 $logMessage');

      final updatedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        status: status,
      );

      final success = await _responseRepo.save(updatedResponse);

      if (success) {
        _currentResponse = updatedResponse;
        _logger.i('✅ Guardado exitoso');
        notifyListeners();
        return true;
      }

      _errorMessage = 'Error guardando';
      _logger.e('❌ Error guardando');
      return false;
    } catch (e) {
      _errorMessage = 'Error guardando: $e';
      _logger.e('❌ Error guardando: $e');
      return false;
    }
  }

  void _clearCurrentForm() {
    _currentTemplate = null;
    _currentResponse = null;
    _fieldValues.clear();
    _fieldErrors.clear();
  }

  // ==================== SYNC ====================

  Future<void> _syncResponse(String responseId) async {
    _isSyncing = true;
    notifyListeners();

    final synced = await _syncRepo.syncToServer(responseId);

    _isSyncing = false;

    if (synced) {
      _logger.i('✅ Formulario sincronizado exitosamente');
    } else {
      _logger.w('⚠️ Formulario guardado pero no sincronizado');
    }
  }

  Future<Map<String, int>> syncPendingResponses() async {
    try {
      _isSyncing = true;
      notifyListeners();

      final result = await _syncRepo.syncAllPending();
      _logger.i('✅ Sincronización completada: ${result['success']} exitosas, ${result['failed']} fallidas');

      return result;
    } catch (e) {
      _logger.e('❌ Error sincronizando: $e');
      return {'success': 0, 'failed': 0};
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> retrySyncResponse(String responseId) async {
    try {
      _logger.i('🔄 Reintentando sincronización: $responseId');

      _isSyncing = true;
      notifyListeners();

      final success = await _syncRepo.retrySyncResponse(responseId);

      _isSyncing = false;
      notifyListeners();

      if (success) {
        _logger.i('✅ Reintento exitoso');
        return true;
      }

      _logger.w('⚠️ Reintento fallido');
      _errorMessage = 'No se pudo sincronizar. Intenta más tarde.';
      notifyListeners();
      return false;
    } catch (e) {
      _logger.e('❌ Error en reintento: $e');
      _errorMessage = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, int>> getSyncCounters() async {
    try {
      final pending = await _responseRepo.countPendingSync();
      final synced = await _responseRepo.countSynced();

      return {
        'pending': pending,
        'synced': synced,
        'total': pending + synced,
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo contadores: $e');
      return {'pending': 0, 'synced': 0, 'total': 0};
    }
  }

  // ==================== RESPONSES ====================

  Future<void> loadSavedResponsesWithSync({String? clienteId}) async {
    await _executeWithLoading(() async {
      final allResponses = await _responseRepo.getAll();

      _savedResponses = clienteId != null && clienteId.isNotEmpty
          ? allResponses.where((r) => r.contactoId == clienteId).toList()
          : allResponses;
    });
  }

  Future<bool> deleteResponse(String responseId) async {
    try {
      final success = await _responseRepo.delete(responseId);

      if (success) {
        _savedResponses.removeWhere((r) => r.id == responseId);
        _logger.i('✅ Respuesta eliminada: $responseId');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = 'Error eliminando respuesta: $e';
      _logger.e('❌ Error eliminando respuesta: $e');
      return false;
    }
  }

  Future<bool> downloadResponsesFromServer(String edfvendedorId) async {
    return await _executeWithLoading(() async {
      _logger.i('📥 Descargando respuestas desde servidor...');

      final resultado = await DynamicFormSyncService.obtenerRespuestasPorVendedor(edfvendedorId);

      if (resultado.exito) {
        await loadSavedResponsesWithSync();
        _logger.i('✅ Respuestas descargadas: ${resultado.itemsSincronizados}');
        return true;
      }

      _errorMessage = 'Error descargando respuestas del servidor';
      _logger.e('❌ Error descargando respuestas');
      return false;
    }, defaultValue: false);
  }

  // ==================== HELPERS ====================

  Future<T> _executeWithLoading<T>(
      Future<T> Function() action, {
        T? defaultValue,
      }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      return await action();
    } catch (e) {
      _errorMessage = 'Error: $e';
      _logger.e('❌ Error: $e');
      if (defaultValue != null) return defaultValue;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _logger.d('Limpiando DynamicFormViewModel');
    super.dispose();
  }
}