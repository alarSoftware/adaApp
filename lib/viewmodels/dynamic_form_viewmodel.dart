import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_field.dart';
import '../repositories/dynamic_form_template_repository.dart';
import '../repositories/dynamic_form_response_repository.dart';
import '../repositories/dynamic_form_sync_repository.dart';
import '../services/sync/dynamic_form_sync_service.dart';

class DynamicFormViewModel extends ChangeNotifier {
  final Uuid _uuid = Uuid();

  final DynamicFormTemplateRepository _templateRepo =
      DynamicFormTemplateRepository();
  final DynamicFormResponseRepository _responseRepo =
      DynamicFormResponseRepository();
  final DynamicFormSyncRepository _syncRepo = DynamicFormSyncRepository();

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  List<DynamicFormTemplate> _templates = [];

  DynamicFormTemplate? _currentTemplate;
  DynamicFormResponse? _currentResponse;
  Map<String, dynamic> _fieldValues = {};
  Map<String, String?> _fieldErrors = {};

  List<DynamicFormResponse> _savedResponses = [];

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  List<DynamicFormTemplate> get templates => _templates;
  DynamicFormTemplate? get currentTemplate => _currentTemplate;
  DynamicFormResponse? get currentResponse => _currentResponse;
  List<DynamicFormResponse> get savedResponses => _savedResponses;

  Future<void> loadTemplates() async {
    await _executeWithLoading(() async {
      _templates = await _templateRepo.getAll();
    });
  }

  Future<bool> downloadTemplatesFromServer() async {
    return await _executeWithLoading(() async {
      final success = await _templateRepo.downloadFromServer();

      if (success) {
        await loadTemplates();
        return true;
      }

      _errorMessage = 'Error descargando formularios del servidor';
      return false;
    }, defaultValue: false);
  }

  DynamicFormTemplate? getTemplateById(String templateId) {
    try {
      return _templates.firstWhere((t) => t.id == templateId);
    } catch (e) {
      AppLogger.e("DYNAMIC_FORM_VIEWMODEL: Error", e);
      return null;
    }
  }

  void startNewForm(
    String templateId, {
    String? contactoId,
    String? equipoId,
    String? userId,
    String? employeeId,
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
        _createNewResponse(templateId, contactoId, userId, employeeId);
      }

      _fieldErrors.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error iniciando formulario: $e';
      notifyListeners();
    }
  }

  void _loadExistingResponse(DynamicFormResponse response) {
    _currentResponse = response;
    _fieldValues = Map<String, dynamic>.from(response.answers);
  }

  void _createNewResponse(
    String templateId,
    String? contactoId,
    String? userId,
    String? employeeId,
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
      employeeId: employeeId,
    );

    _fieldValues.clear();
  }

  void loadResponseForEditing(DynamicFormResponse response) {
    try {
      _currentTemplate = _templates.firstWhere(
        (t) => t.id == response.formTemplateId,
        orElse: () => throw Exception('Template no encontrado'),
      );

      _loadExistingResponse(response);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error cargando respuesta: $e';
      notifyListeners();
    }
  }

  dynamic getFieldValue(String fieldId) => _fieldValues[fieldId];

  String? getFieldError(String fieldId) => _fieldErrors[fieldId];

  void updateFieldValue(String fieldId, dynamic value) {
    final field = _currentTemplate?.getFieldById(fieldId);

    if (field != null &&
        (field.type == 'radio_button' || field.type == 'checkbox')) {
      _clearChildrenValues(field, value);
    }

    _fieldValues[fieldId] = value;
    _fieldErrors.remove(fieldId);

    if (_currentResponse != null) {
      _currentResponse = _currentResponse!.copyWith(answers: {..._fieldValues});
    }

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
    final selectedIds = newValue is List
        ? List<String>.from(newValue)
        : <String>[];

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
    }

    for (var child in field.children) {
      _clearFieldAndDescendants(child);
    }
  }

  Future<bool> saveImageForField(String fieldId, String imagePath) async {
    try {
      if (_currentResponse == null) {
        _errorMessage = 'No hay formulario activo';
        return false;
      }

      final imageId = await _responseRepo.saveImageImmediately(
        responseId: _currentResponse!.id,
        fieldId: fieldId,
        imagePath: imagePath,
      );

      if (imageId != null) {
        updateFieldValue(fieldId, imagePath);
        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = 'Error guardando imagen: $e';
      return false;
    }
  }

  Future<bool> deleteImageForField(String fieldId) async {
    try {
      if (_currentResponse == null) {
        return false;
      }

      final details = await _responseRepo.getDetails(_currentResponse!.id);
      final detail = details
          .where((d) => d.dynamicFormDetailId == fieldId)
          .firstOrNull;

      if (detail != null) {
        final images = await _responseRepo.getImagesForDetail(detail.id);
        for (var image in images) {
          await _responseRepo.deleteImageFile(image);
        }
      }

      updateFieldValue(fieldId, null);
      return true;
    } catch (e) {
      AppLogger.e("DYNAMIC_FORM_VIEWMODEL: Error", e);
      return false;
    }
  }

  bool _validateAllFields() {
    if (_currentTemplate == null) return false;

    _fieldErrors.clear();
    bool isValid = true;

    // Construir mapa de parent_id → parent para poder verificar visibilidad
    final parentMap = _buildParentMap(_currentTemplate!.fields);

    final answerableFields = _currentTemplate!.answerableFields;

    for (final field in answerableFields) {
      // Si el campo está dentro de una opción no seleccionada, ignorarlo
      if (!_isFieldActive(field, parentMap)) continue;

      final value = _fieldValues[field.id];

      // Validación: campo obligatorio vacío
      if (field.required && _isFieldEmpty(value)) {
        _fieldErrors[field.id] = '${field.label} es obligatorio';
        isValid = false;
        continue;
      }

      // Validación: campo numérico activo (visible) → obligatorio + rango
      if (field.type == 'numerico') {
        if (!_isFieldEmpty(value)) {
          final parsed = double.tryParse(value.toString());
          if (parsed == null) {
            _fieldErrors[field.id] = '${field.label} debe ser un número válido';
            isValid = false;
          } else if (field.minValue != null && parsed < field.minValue!) {
            _fieldErrors[field.id] =
                'El valor mínimo para ${field.label} es ${_formatFieldNumber(field.minValue!)}';
            isValid = false;
          } else if (field.maxValue != null && parsed > field.maxValue!) {
            _fieldErrors[field.id] =
                'El valor máximo para ${field.label} es ${_formatFieldNumber(field.maxValue!)}';
            isValid = false;
          }
        }
      }
    }

    return isValid;
  }

  /// Verifica si un campo está activo (visible) según las selecciones actuales.
  /// Un campo dentro de un `opt` solo es activo si ese `opt` está seleccionado.
  bool _isFieldActive(
    DynamicFormField field,
    Map<String, DynamicFormField> parentMap,
  ) {
    String? currentId = field.parentId;

    while (currentId != null) {
      final parent = parentMap[currentId];
      if (parent == null) break;

      if (parent.type == 'opt') {
        // Encontrar el radio_button/checkbox que contiene este opt
        final grandParent = parent.parentId != null
            ? parentMap[parent.parentId!]
            : null;

        if (grandParent == null) break;

        final selectedValue = _fieldValues[grandParent.id];

        if (grandParent.type == 'radio_button') {
          // Activo solo si este opt es el seleccionado
          if (selectedValue?.toString() != parent.id) return false;
        } else if (grandParent.type == 'checkbox') {
          // Activo solo si este opt está en la lista seleccionada
          final selected = selectedValue is List
              ? selectedValue.map((e) => e.toString()).toList()
              : (selectedValue != null
                    ? [selectedValue.toString()]
                    : <String>[]);
          if (!selected.contains(parent.id)) return false;
        }
      }

      currentId = parent.parentId;
    }

    return true;
  }

  /// Construye un mapa field.id → DynamicFormField para toda la jerarquía.
  Map<String, DynamicFormField> _buildParentMap(List<DynamicFormField> fields) {
    final map = <String, DynamicFormField>{};

    void traverse(DynamicFormField field) {
      map[field.id] = field;
      for (final child in field.children) {
        traverse(child);
      }
    }

    for (final field in fields) {
      traverse(field);
    }

    return map;
  }

  String _formatFieldNumber(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  bool isFormComplete() {
    if (_currentTemplate == null) return false;

    return _currentTemplate!.requiredFields.every(
      (field) => !_isFieldEmpty(_fieldValues[field.id]),
    );
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

  Future<bool> saveProgress() async {
    return await _saveWithStatus(
      'draft',
      'Guardando progreso como borrador...',
    );
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

      if (!_validateAllFields()) {
        _errorMessage = 'Por favor completa todos los campos obligatorios';
        notifyListeners();
        return false;
      }

      final now = DateTime.now();
      final completedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        completedAt: now,
        status: 'completed',
      );

      final saved = await _responseRepo.save(completedResponse);
      if (!saved) {
        _errorMessage = 'Error al guardar el formulario';
        notifyListeners();
        return false;
      }

      unawaited(_syncResponse(completedResponse.id));

      _clearCurrentForm();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error completando formulario: $e';
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

      final updatedResponse = _currentResponse!.copyWith(
        answers: Map<String, dynamic>.from(_fieldValues),
        status: status,
      );

      final success = await _responseRepo.save(updatedResponse);

      if (success) {
        _currentResponse = updatedResponse;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Error guardando';
      return false;
    } catch (e) {
      _errorMessage = 'Error guardando: $e';
      return false;
    }
  }

  void _clearCurrentForm() {
    _currentTemplate = null;
    _currentResponse = null;
    _fieldValues.clear();
    _fieldErrors.clear();
    _errorMessage = null;
  }

  /// Descarta el formulario actual sin guardar nada.
  /// Si hay un borrador en la BD (status=draft), lo elimina.
  Future<void> discardForm() async {
    final responseToDelete = _currentResponse;
    _clearCurrentForm();
    notifyListeners();

    // Limpiar DB solo si era un borrador que nunca fue completado/sincronizado
    if (responseToDelete != null && responseToDelete.status == 'draft') {
      try {
        // Verificar que existe en DB antes de intentar borrarlo
        final exists = await _responseRepo.getById(responseToDelete.id);
        if (exists != null) {
          await _responseRepo.delete(responseToDelete.id);
        }
      } catch (_) {
        // Si falla el borrado de DB, no es crítico — el borrador queda huérfano
        // pero el estado en memoria ya fue limpiado
      }
    }
  }

  Future<void> _syncResponse(String responseId) async {
    _isSyncing = true;
    notifyListeners();

    try {
      await _syncRepo.syncTo(responseId);
    } catch (e) {
      _errorMessage = 'Error de sincronización: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<Map<String, int>> syncPendingResponses() async {
    try {
      _isSyncing = true;
      notifyListeners();

      final result = await _syncRepo.syncAllPending();

      return result;
    } catch (e) {
      _errorMessage = 'Error sincronizando pendientes: $e';
      return {'success': 0, 'failed': 0};
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> retrySyncResponse(String responseId) async {
    try {
      _isSyncing = true;
      notifyListeners();

      final success = await _syncRepo.retrySyncResponse(responseId);

      _isSyncing = false;
      notifyListeners();

      if (success) {
        return true;
      }

      _errorMessage = 'No se pudo sincronizar. Intenta más tarde.';
      notifyListeners();
      return false;
    } catch (e) {
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

      return {'pending': pending, 'synced': synced, 'total': pending + synced};
    } catch (e) {
      AppLogger.e("DYNAMIC_FORM_VIEWMODEL: Error", e);
      return {'pending': 0, 'synced': 0, 'total': 0};
    }
  }

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
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = 'Error eliminando respuesta: $e';
      return false;
    }
  }

  Future<bool> downloadResponsesFromServer(String employeeId) async {
    return await _executeWithLoading(() async {
      final resultado =
          await DynamicFormSyncService.obtenerRespuestasPorVendedor(employeeId);

      if (resultado.exito) {
        await loadSavedResponsesWithSync();
        return true;
      }

      _errorMessage = 'Error descargando respuestas del servidor';
      return false;
    }, defaultValue: false);
  }

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
      if (defaultValue != null) return defaultValue;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
