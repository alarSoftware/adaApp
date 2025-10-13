import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_field.dart';
import '../repositories/dynamic_form_repository.dart';
import '../repositories/dynamic_form_template_repository.dart';
import '../repositories/dynamic_form_response_repository.dart';
import '../repositories/dynamic_form_sync_repository.dart';

class DynamicFormViewModel extends ChangeNotifier {
  final Logger _logger = Logger();

  // ⭐ Repositorios especializados
  final DynamicFormTemplateRepository _templateRepo = DynamicFormTemplateRepository();
  final DynamicFormResponseRepository _responseRepo = DynamicFormResponseRepository();
  final DynamicFormSyncRepository _syncRepo = DynamicFormSyncRepository();

  // También mantener el repository principal para compatibilidad
  final DynamicFormRepository _repository = DynamicFormRepository();

  // Estado
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;

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

  // ==================== MÉTODOS PARA TEMPLATES ====================

  /// Cargar templates desde la base de datos local
  Future<void> loadTemplates() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _templates = await _repository.getAvailableTemplates();

      _logger.i('✅ Templates cargados: ${_templates.length}');
    } catch (e) {
      _errorMessage = 'Error cargando formularios: $e';
      _logger.e('❌ Error cargando templates: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Descargar templates desde el servidor
  Future<bool> downloadTemplatesFromServer() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _logger.i('📥 Descargando formularios desde servidor...');

      final success = await _repository.downloadTemplatesFromServer();

      if (success) {
        await loadTemplates();
        _logger.i('✅ Templates descargados: ${_templates.length} disponibles');
        return true;
      } else {
        _errorMessage = 'Error descargando formularios del servidor';
        _logger.e('❌ Error descargando templates');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _logger.e('❌ Error descargando templates: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== MÉTODOS PARA LLENAR FORMULARIOS ====================

  /// Iniciar un nuevo formulario o cargar uno existente
  void startNewForm(
      String templateId, {
        String? clienteId,
        String? equipoId,
        String? userId,
        DynamicFormResponse? existingResponse,
      }) {
    try {
      // Buscar el template
      _currentTemplate = _templates.firstWhere(
            (t) => t.id == templateId,
        orElse: () => throw Exception('Template no encontrado'),
      );

      if (existingResponse != null) {
        // CASO 1: Cargar formulario existente (editar/continuar)
        _currentResponse = existingResponse;
        _fieldValues = Map<String, dynamic>.from(existingResponse.answers);
        _logger.i('✅ Formulario cargado para editar: ${existingResponse.id}');
        _logger.i('📝 Valores cargados: ${_fieldValues.length} campos');
      } else {
        // CASO 2: Crear nuevo formulario
        final responseId = DateTime.now().millisecondsSinceEpoch.toString();

        _currentResponse = DynamicFormResponse(
          id: responseId,
          formTemplateId: templateId,
          answers: {},
          createdAt: DateTime.now(),
          status: 'draft',
          clienteId: clienteId,
          equipoId: equipoId,
          userId: userId,
        );

        _fieldValues.clear();
        _logger.i('✅ Formulario nuevo iniciado: ${_currentTemplate?.title} (ID: $responseId)');
      }

      // Limpiar errores en ambos casos
      _fieldErrors.clear();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error iniciando formulario: $e';
      _logger.e('❌ Error iniciando formulario: $e');
      notifyListeners();
    }
  }

  /// Obtener valor de un campo (usa ID en lugar de key)
  dynamic getFieldValue(String fieldId) {
    return _fieldValues[fieldId];
  }

  /// Actualizar valor de un campo (usa ID en lugar de key)
  void updateFieldValue(String fieldId, dynamic value) {
    // Si es un campo de tipo radio_button o checkbox, limpiar sus hijos
    final field = _findFieldById(fieldId);
    if (field != null && (field.type == 'radio_button' || field.type == 'checkbox')) {
      _clearChildrenValues(field, value);
    }

    _fieldValues[fieldId] = value;

    // Limpiar error si existe
    if (_fieldErrors.containsKey(fieldId)) {
      _fieldErrors.remove(fieldId);
    }

    // Actualizar en la respuesta actual
    if (_currentResponse != null) {
      _currentResponse = _currentResponse!.copyWith(
        answers: {..._fieldValues},
      );
    }

    _logger.d('📝 Campo actualizado: $fieldId = $value');
    notifyListeners();
  }

  /// Buscar un campo por ID en el template actual
  DynamicFormField? _findFieldById(String fieldId) {
    if (_currentTemplate == null) return null;

    for (var field in _currentTemplate!.fields) {
      if (field.id == fieldId) return field;

      // Buscar recursivamente en los hijos
      final found = _findFieldInChildren(field, fieldId);
      if (found != null) return found;
    }

    return null;
  }

  /// Buscar recursivamente en los hijos
  DynamicFormField? _findFieldInChildren(DynamicFormField parent, String fieldId) {
    for (var child in parent.children) {
      if (child.id == fieldId) return child;

      final found = _findFieldInChildren(child, fieldId);
      if (found != null) return found;
    }

    return null;
  }

  /// Limpiar valores de campos hijos cuando cambia la selección
  void _clearChildrenValues(DynamicFormField field, dynamic newValue) {
    if (field.type == 'radio_button') {
      // Para radio button: limpiar hijos de TODAS las opciones
      for (var option in field.children.where((c) => c.type == 'opt')) {
        _clearFieldAndDescendants(option);
      }
    } else if (field.type == 'checkbox') {
      // Para checkbox: limpiar hijos de opciones NO seleccionadas
      final selectedIds = newValue is List ? List<String>.from(newValue) : <String>[];

      for (var option in field.children.where((c) => c.type == 'opt')) {
        if (!selectedIds.contains(option.id)) {
          _clearFieldAndDescendants(option);
        }
      }
    }
  }

  /// Limpiar un campo y todos sus descendientes recursivamente
  void _clearFieldAndDescendants(DynamicFormField field) {
    // Limpiar el valor del campo actual (si no es opción)
    if (field.type != 'opt') {
      _fieldValues.remove(field.id);
      _fieldErrors.remove(field.id);
      _logger.d('🧹 Limpiando campo: ${field.id} (${field.label})');
    }

    // Limpiar recursivamente todos los hijos
    for (var child in field.children) {
      _clearFieldAndDescendants(child);
    }
  }

  /// Obtener error de un campo (usa ID en lugar de key)
  String? getFieldError(String fieldId) {
    return _fieldErrors[fieldId];
  }

  /// Obtener todos los campos que necesitan respuesta
  List<DynamicFormField> _getAllAnswerableFields() {
    if (_currentTemplate == null) return [];

    final List<DynamicFormField> answerableFields = [];

    for (final field in _currentTemplate!.fields) {
      if (field.type == 'titulo') continue;

      if (field.type == 'radio_button' ||
          field.type == 'checkbox' ||
          field.type == 'resp_abierta' ||
          field.type == 'resp_abierta_larga' ||
          field.type == 'image') {
        answerableFields.add(field);
      }
    }

    return answerableFields;
  }

  /// Validar todos los campos
  bool _validateAllFields() {
    if (_currentTemplate == null) return false;

    _fieldErrors.clear();
    bool isValid = true;

    final answerableFields = _getAllAnswerableFields();

    for (final field in answerableFields) {
      if (field.required) {
        final value = _fieldValues[field.id];

        if (value == null ||
            (value is String && value.trim().isEmpty) ||
            (value is List && value.isEmpty)) {
          _fieldErrors[field.id] = '${field.label} es obligatorio';
          isValid = false;
          _logger.w('⚠️ Campo obligatorio sin completar: ${field.label} (${field.id})');
        }
      }
    }

    if (!isValid) {
      _logger.w('⚠️ Validación fallida: ${_fieldErrors.length} errores');
    }

    return isValid;
  }

  /// Verificar si el formulario está completo
  bool isFormComplete() {
    if (_currentTemplate == null) return false;

    final answerableFields = _getAllAnswerableFields();

    for (final field in answerableFields) {
      if (field.required) {
        final value = _fieldValues[field.id];

        if (value == null ||
            (value is String && value.trim().isEmpty) ||
            (value is List && value.isEmpty)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Obtener progreso del formulario (0.0 a 1.0)
  double getFormProgress() {
    if (_currentTemplate == null) return 0.0;

    final answerableFields = _getAllAnswerableFields();
    final requiredFields = answerableFields.where((f) => f.required).toList();

    if (requiredFields.isEmpty) {
      return 1.0;
    }

    int filledRequired = 0;

    for (final field in requiredFields) {
      final value = _fieldValues[field.id];

      if (value != null &&
          ((value is String && value.trim().isNotEmpty) ||
              (value is List && value.isNotEmpty) ||
              (value is! String && value is! List))) {
        filledRequired++;
      }
    }

    return filledRequired / requiredFields.length;
  }

  /// Guardar progreso (borrador - NO convierte imágenes a Base64)
  Future<bool> saveProgress() async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('💾 Guardando progreso como borrador...');

      // Las imágenes se guardan solo como rutas locales
      final updatedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        status: 'draft', // ⚠️ Estado borrador
      );

      final success = await _responseRepo.save(updatedResponse);

      if (success) {
        _currentResponse = updatedResponse;
        _logger.i('✅ Progreso guardado (imágenes como rutas)');
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Error guardando progreso';
        _logger.e('❌ Error guardando progreso');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error guardando progreso: $e';
      _logger.e('❌ Error guardando progreso: $e');
      return false;
    }
  }

  /// Guardar como borrador (NO convierte imágenes a Base64)
  Future<bool> saveDraft() async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('💾 Guardando borrador...');

      // Las imágenes se guardan solo como rutas locales
      final draftResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        status: 'draft', // ⚠️ Estado borrador
      );

      final success = await _responseRepo.save(draftResponse);

      if (success) {
        _currentResponse = draftResponse;
        _logger.i('✅ Borrador guardado (imágenes como rutas)');
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Error guardando borrador';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error guardando borrador: $e';
      _logger.e('❌ Error guardando borrador: $e');
      return false;
    }
  }

  /// Guardar y completar formulario (SÍ convierte imágenes a Base64)
  Future<bool> saveAndComplete() async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('✔️ Intentando completar formulario...');

      // Validar campos requeridos
      if (!_validateAllFields()) {
        _errorMessage = 'Por favor completa todos los campos obligatorios';
        _logger.w('⚠️ Validación fallida al completar');
        notifyListeners();
        return false;
      }

      // Preparar response completada
      // ⚠️ AQUÍ las imágenes SÍ se convierten a Base64
      final completedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        completedAt: DateTime.now(),
        status: 'completed', // ⚠️ Estado completado - ACTIVA conversión Base64
      );

      // Guardar en BD (convierte imágenes a Base64 automáticamente)
      final saved = await _responseRepo.save(completedResponse);
      if (!saved) {
        _errorMessage = 'Error al guardar el formulario';
        notifyListeners();
        return false;
      }

      _logger.i('✅ Formulario completado (imágenes convertidas a Base64)');

      // Iniciar sincronización
      _isSyncing = true;
      notifyListeners();

      final synced = await _syncRepo.simulateSyncToServer(completedResponse.id);

      _isSyncing = false;

      if (synced) {
        _logger.i('✅ Formulario sincronizado exitosamente');
      } else {
        _logger.w('⚠️ Formulario guardado pero no sincronizado');
      }

      // Limpiar estado actual
      _currentTemplate = null;
      _currentResponse = null;
      _fieldValues.clear();
      _fieldErrors.clear();

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

  /// Obtener contadores de sincronización
  Future<Map<String, int>> getSyncCounters() async {
    try {
      final pending = await _repository.countPendingSync();
      final synced = await _repository.countSynced();

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

  /// Reintentar sincronización
  Future<bool> retrySyncResponse(String responseId) async {
    try {
      _logger.i('🔄 Reintentando sincronización: $responseId');

      _isSyncing = true;
      notifyListeners();

      final success = await _repository.simulateSyncToServer(responseId);

      _isSyncing = false;
      notifyListeners();

      if (success) {
        _logger.i('✅ Reintento exitoso');
        return true;
      } else {
        _logger.w('⚠️ Reintento fallido');
        _errorMessage = 'No se pudo sincronizar. Intenta más tarde.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error en reintento: $e');
      _errorMessage = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  /// Sincronizar respuestas pendientes
  Future<Map<String, int>> syncPendingResponses() async {
    try {
      _isSyncing = true;
      notifyListeners();

      final result = await _repository.syncAllPendingResponses();

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

  /// Cargar una respuesta existente para editarla
  void loadResponseForEditing(DynamicFormResponse response) {
    try {
      _currentTemplate = _templates.firstWhere(
            (t) => t.id == response.formTemplateId,
        orElse: () => throw Exception('Template no encontrado'),
      );

      _currentResponse = response;
      _fieldValues = Map<String, dynamic>.from(response.answers);
      _fieldErrors.clear();

      _logger.i('✅ Respuesta cargada para edición: ${response.id}');
      _logger.d('📝 ${_fieldValues.length} valores cargados');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error cargando respuesta: $e';
      _logger.e('❌ Error cargando respuesta: $e');
      notifyListeners();
    }
  }

  // ==================== MÉTODOS PARA RESPUESTAS GUARDADAS ====================

  /// Cargar respuestas guardadas CON su sync_status desde la BD
  Future<void> loadSavedResponsesWithSync({String? clienteId}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final allResponses = await _repository.getLocalResponses();
      final List<DynamicFormResponse> responsesWithSync = [];

      for (var response in allResponses) {
        final metadata = await _repository.getSyncMetadata(response.id);
        final responseWithSync = response.copyWith(metadata: metadata);
        responsesWithSync.add(responseWithSync);
      }

      if (clienteId != null && clienteId.isNotEmpty) {
        _savedResponses = responsesWithSync
            .where((response) => response.clienteId == clienteId)
            .toList();
      } else {
        _savedResponses = responsesWithSync;
      }
    } catch (e) {
      _errorMessage = 'Error cargando respuestas: $e';
      _logger.e('❌ Error cargando respuestas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener template por ID
  DynamicFormTemplate? getTemplateById(String templateId) {
    try {
      return _templates.firstWhere((t) => t.id == templateId);
    } catch (e) {
      return null;
    }
  }

  /// Eliminar una respuesta
  Future<bool> deleteResponse(String responseId) async {
    try {
      final success = await _repository.deleteResponse(responseId);

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

  // ==================== CLEANUP ====================

  @override
  void dispose() {
    _logger.d('Limpiando DynamicFormViewModel');
    super.dispose();
  }
}