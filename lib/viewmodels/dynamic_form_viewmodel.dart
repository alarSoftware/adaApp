import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_field.dart';
import '../repositories/dynamic_form_repository.dart';

class DynamicFormViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final DynamicFormRepository _repository = DynamicFormRepository();

  // Estado
  bool _isLoading = false;
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
  String? get errorMessage => _errorMessage;
  List<DynamicFormTemplate> get templates => _templates;
  DynamicFormTemplate? get currentTemplate => _currentTemplate;
  List<DynamicFormResponse> get savedResponses => _savedResponses;
  DynamicFormResponse? get currentResponse => _currentResponse;
  String? _currentClienteId;

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

      final success = await _repository.downloadTemplatesFromServer();

      if (success) {
        // Recargar templates desde la BD local
        await loadTemplates();
        _logger.i('✅ Templates descargados exitosamente');
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
          status: 'pending', // ✅ CORREGIDO: ahora es 'pending' en lugar de 'draft'
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
    _fieldValues[fieldId] = value;

    // Limpiar error si existe
    if (_fieldErrors.containsKey(fieldId)) {
      _fieldErrors.remove(fieldId);
    }

    // Actualizar en la respuesta actual
    if (_currentResponse != null) {
      _currentResponse = _currentResponse!.copyWith(
        answers: {..._currentResponse!.answers, fieldId: value},
      );
    }

    _logger.d('📝 Campo actualizado: $fieldId = $value');
    notifyListeners();
  }

  /// Obtener error de un campo (usa ID en lugar de key)
  String? getFieldError(String fieldId) {
    return _fieldErrors[fieldId];
  }

  /// Obtener todos los campos que necesitan respuesta (incluyendo campos hijos para grupos)
  List<DynamicFormField> _getAllAnswerableFields() {
    if (_currentTemplate == null) return [];

    final List<DynamicFormField> answerableFields = [];

    for (final field in _currentTemplate!.fields) {
      // Los títulos no se responden
      if (field.type == 'titulo') continue;

      // Para radio_button y checkbox, agregar el campo con sus opciones
      if (field.type == 'radio_button' || field.type == 'checkbox') {
        answerableFields.add(field);
      }
      // Campos de texto (ambos tipos)
      else if (field.type == 'resp_abierta' || field.type == 'resp_abierta_larga') {
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

    // Verificar que todos los campos requeridos estén llenos
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
      return 1.0; // Si no hay campos requeridos, está completo
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

  /// Guardar progreso (mantiene como 'pending')
  Future<bool> saveProgress() async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('💾 Guardando progreso...');
      _logger.d('📊 Valores a guardar: $_fieldValues');

      // Actualizar respuestas manteniendo el estado 'pending'
      final updatedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        // No cambiamos el status, se mantiene 'pending'
      );

      final success = await _repository.saveResponse(updatedResponse);

      if (success) {
        _currentResponse = updatedResponse;
        _logger.i('✅ Progreso guardado exitosamente');
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Error guardando progreso';
        _logger.e('❌ Error guardando progreso en repositorio');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error guardando progreso: $e';
      _logger.e('❌ Error guardando progreso: $e');
      return false;
    }
  }

  /// Guardar y completar formulario
  Future<bool> saveAndComplete() async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      _logger.i('✔️ Intentando completar formulario...');

      // Validar campos
      if (!_validateAllFields()) {
        _errorMessage = 'Por favor completa todos los campos obligatorios';
        _logger.w('⚠️ Validación fallida al completar');
        notifyListeners();
        return false;
      }

      // Marcar como completado
      final completedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        completedAt: DateTime.now(),
        status: 'completed', // ✅ Ahora cambia a 'completed'
      );

      final success = await _repository.saveResponse(completedResponse);

      if (success) {
        _currentResponse = completedResponse;
        _logger.i('✅ Formulario completado exitosamente');

        // Limpiar formulario actual
        _currentTemplate = null;
        _currentResponse = null;
        _fieldValues.clear();
        _fieldErrors.clear();

        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Error completando formulario';
        _logger.e('❌ Error completando formulario en repositorio');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error completando formulario: $e';
      _logger.e('❌ Error completando formulario: $e');
      notifyListeners();
      return false;
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  /// Sincronizar respuestas pendientes
  Future<Map<String, int>> syncPendingResponses() async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _repository.syncAllPendingResponses();

      _logger.i('✅ Sincronización completada: ${result['success']} exitosas, ${result['failed']} fallidas');
      return result;
    } catch (e) {
      _logger.e('❌ Error sincronizando: $e');
      return {'success': 0, 'failed': 0};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar una respuesta existente para editarla
  void loadResponseForEditing(DynamicFormResponse response) {
    try {
      // Buscar el template correspondiente
      _currentTemplate = _templates.firstWhere(
            (t) => t.id == response.formTemplateId,
        orElse: () => throw Exception('Template no encontrado'),
      );

      // Cargar la respuesta
      _currentResponse = response;

      // Cargar los valores de los campos
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

  /// Cargar respuestas guardadas desde la BD
  Future<void> loadSavedResponses({String? clienteId}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentClienteId = clienteId; // Guardar cliente actual

      // Obtener todas las respuestas locales
      final allResponses = await _repository.getLocalResponses();

      // Filtrar por cliente si es necesario
      if (clienteId != null && clienteId.isNotEmpty) {
        _savedResponses = allResponses
            .where((response) => response.clienteId == clienteId)
            .toList();
        _logger.i('✅ Respuestas del cliente $clienteId: ${_savedResponses.length}');
      } else {
        _savedResponses = allResponses;
        _logger.i('✅ Todas las respuestas: ${_savedResponses.length}');
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
    _logger.d('🧹 Limpiando DynamicFormViewModel');
    super.dispose();
  }
}