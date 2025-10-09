import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_field.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// Widget que renderiza un campo dinámico según su tipo CON LÓGICA CONDICIONAL Y JERARQUÍA VISUAL
class DynamicFormFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String? errorText;
  final Map<String, dynamic> allValues;
  final Function(String fieldId, dynamic value)? onNestedFieldChanged; // ⭐ NUEVO callback

  const DynamicFormFieldWidget({
    Key? key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.allValues = const {},
    this.onNestedFieldChanged, // ⭐ NUEVO
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Verificar si este campo es condicional (tiene conditionalParentId)
    final isConditional = field.metadata?['conditionalParentId'] != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 16,
        left: isConditional ? 24 : 0, // ⭐ Indentar campos condicionales
      ),
      child: isConditional
          ? _buildConditionalFieldWithLine(context)
          : _buildFieldByType(context),
    );
  }

  /// ⭐ NUEVO: Renderiza campo condicional con línea visual
  Widget _buildConditionalFieldWithLine(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Línea vertical conectora
        Container(
          width: 3,
          height: 60,
          margin: EdgeInsets.only(right: 12, top: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Campo con badge "Condicional"
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge indicador
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward, size: 12, color: AppColors.info),
                    SizedBox(width: 4),
                    Text(
                      'Campo condicional',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // El campo en sí
              _buildFieldByType(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldByType(BuildContext context) {
    switch (field.type) {
      case 'titulo':
        return _buildHeader();
      case 'radio_button':
        return _buildRadioGroupWithNested(context);
      case 'checkbox':
        return _buildCheckboxGroupWithNested(context);
      case 'resp_abierta':
        return _buildTextField(maxLines: 3);
      case 'resp_abierta_larga':
        return _buildTextField(maxLines: 6);
      case 'image':
        return _buildImagePicker(context);
      default:
        return _buildTextField();
    }
  }

  /// Renderiza un título/encabezado
  Widget _buildHeader() {
    return Card(
      elevation: 0,
      color: AppColors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                field.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⭐ MEJORADO: Radio con campos anidados visualmente debajo de cada opción
  Widget _buildRadioGroupWithNested(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: errorText != null ? AppColors.error : AppColors.border,
          width: errorText != null ? 2 : 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Etiqueta de la pregunta
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (field.required)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '*',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),

            if (errorText != null) ...[
              SizedBox(height: 4),
              Text(
                errorText!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                ),
              ),
            ],

            SizedBox(height: 12),
            Divider(color: AppColors.border, height: 1),
            SizedBox(height: 8),

            // Opciones
            if (field.children.isEmpty)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'No hay opciones disponibles',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...field.children.where((c) => c.type == 'opt').map((option) {
                final isSelected = value == option.id;
                final hasNestedFields = option.children.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Opción radio
                    InkWell(
                      onTap: () => onChanged(option.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: EdgeInsets.only(bottom: hasNestedFields && isSelected ? 8 : 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ⭐ CAMPOS ANIDADOS debajo de la opción seleccionada
                    if (isSelected && hasNestedFields)
                      Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 12),
                        child: _buildNestedFields(context, option.children),
                      ),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  /// ⭐ NUEVO: Renderiza campos anidados con líneas visuales RECURSIVAS
  Widget _buildNestedFields(BuildContext context, List<DynamicFormField> nestedFields, {int depth = 0}) {
    return Column(
      children: nestedFields
          .where((f) => f.type != 'opt') // Excluir opciones
          .map((nestedField) {
        // Verificar si este campo tiene a su vez más campos anidados
        final hasSubChildren = nestedField.children.where((c) => c.type != 'opt').isNotEmpty;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo actual con línea conectora
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Línea conectora en L
                  Column(
                    children: [
                      Container(
                        width: 2,
                        height: 20,
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                      if (hasSubChildren)
                        Container(
                          width: 2,
                          height: 40,
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                    ],
                  ),
                  Container(
                    width: 16,
                    height: 2,
                    margin: EdgeInsets.only(top: 20),
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                  SizedBox(width: 8),
                  // Campo anidado
                  Expanded(
                    child: _buildNestedFieldCard(context, nestedField),
                  ),
                ],
              ),

              // ⭐ RECURSIÓN: Si este campo tiene hijos, renderizarlos con más indentación
              if (hasSubChildren)
                Padding(
                  padding: EdgeInsets.only(left: 18), // Indentación adicional
                  child: _buildNestedFields(context, nestedField.children, depth: depth + 1),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// ⭐ NUEVO: Card para campo anidado
  Widget _buildNestedFieldCard(BuildContext context, DynamicFormField nestedField) {
    // Crear un sub-widget para el campo anidado, SIN el wrapper de indentación
    switch (nestedField.type) {
      case 'image':
        return _buildImagePickerForNested(context, nestedField);
      case 'checkbox':
        return _buildCheckboxForNested(context, nestedField);
      case 'resp_abierta':
        return _buildTextFieldForNested(nestedField, maxLines: 3);
      case 'resp_abierta_larga':
        return _buildTextFieldForNested(nestedField, maxLines: 6);
      default:
        return _buildTextFieldForNested(nestedField);
    }
  }

  /// Helper para campos de texto anidados
  Widget _buildTextFieldForNested(DynamicFormField nestedField, {int maxLines = 3}) {
    final nestedValue = allValues[nestedField.id];

    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nestedField.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              initialValue: nestedValue?.toString(),
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: maxLines,
              onChanged: (newValue) {
                if (onNestedFieldChanged != null) {
                  onNestedFieldChanged!(nestedField.id, newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Helper para image picker anidado
  Widget _buildImagePickerForNested(BuildContext context, DynamicFormField nestedField) {
    final nestedValue = allValues[nestedField.id];

    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nestedField.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            if (nestedValue != null && nestedValue.toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(nestedValue.toString()),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: AppColors.neutral200,
                      child: Center(
                        child: Icon(Icons.broken_image, size: 40, color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 8),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _pickImageForNested(context, nestedField, ImageSource.camera);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(Icons.camera_alt, size: 18),
                    label: Text('Cámara', style: TextStyle(fontSize: 12)),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _pickImageForNested(context, nestedField, ImageSource.gallery);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: AppColors.primary),
                    ),
                    icon: Icon(Icons.photo_library, size: 18),
                    label: Text('Galería', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),

            // Botón para eliminar imagen
            if (nestedValue != null && nestedValue.toString().isNotEmpty) ...[
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    if (onNestedFieldChanged != null) {
                      onNestedFieldChanged!(nestedField.id, null);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: Icon(Icons.delete_outline, size: 18),
                  label: Text('Eliminar imagen', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Helper para checkbox anidado
  Widget _buildCheckboxForNested(BuildContext context, DynamicFormField nestedField) {
    final nestedValue = allValues[nestedField.id];
    List<String> selectedIds = [];

    if (nestedValue is List) {
      selectedIds = List<String>.from(nestedValue);
    } else if (nestedValue is String && nestedValue.isNotEmpty) {
      selectedIds = [nestedValue];
    }

    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nestedField.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            ...nestedField.children.where((c) => c.type == 'opt').map((option) {
              final isSelected = selectedIds.contains(option.id);
              final hasNestedFields = option.children.where((c) => c.type != 'opt').isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      List<String> newSelected = List<String>.from(selectedIds);
                      if (isSelected) {
                        newSelected.remove(option.id);
                      } else {
                        newSelected.add(option.id);
                      }

                      if (onNestedFieldChanged != null) {
                        onNestedFieldChanged!(nestedField.id, newSelected);
                      }
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ⭐ NUEVO: Mostrar campos anidados si esta opción está seleccionada
                  if (isSelected && hasNestedFields)
                    Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 12),
                      child: _buildNestedFields(context, option.children, depth: 1),
                    ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageForNested(BuildContext context, DynamicFormField nestedField, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && onNestedFieldChanged != null) {
        onNestedFieldChanged!(nestedField.id, image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// ⭐ MEJORADO: Checkbox con campos anidados
  Widget _buildCheckboxGroupWithNested(BuildContext context) {
    List<String> selectedIds = [];

    if (value is List) {
      selectedIds = List<String>.from(value);
    } else if (value is String && value.isNotEmpty) {
      selectedIds = [value];
    }

    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: errorText != null ? AppColors.error : AppColors.border,
          width: errorText != null ? 2 : 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (field.required)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '*',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),

            if (errorText != null) ...[
              SizedBox(height: 4),
              Text(
                errorText!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                ),
              ),
            ],

            SizedBox(height: 12),
            Divider(color: AppColors.border, height: 1),
            SizedBox(height: 8),

            if (field.children.isEmpty)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'No hay opciones disponibles',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...field.children.where((c) => c.type == 'opt').map((option) {
                final isSelected = selectedIds.contains(option.id);
                final hasNestedFields = option.children.where((c) => c.type != 'opt').isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        List<String> newSelected = List<String>.from(selectedIds);

                        if (isSelected) {
                          newSelected.remove(option.id);
                        } else {
                          newSelected.add(option.id);
                        }

                        onChanged(newSelected);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: EdgeInsets.only(bottom: hasNestedFields && isSelected ? 8 : 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ⭐ NUEVO: Campos anidados debajo de la opción seleccionada
                    if (isSelected && hasNestedFields)
                      Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 12),
                        child: _buildNestedFields(context, option.children),
                      ),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  /// Renderiza un campo de texto abierto
  Widget _buildTextField({int maxLines = 3}) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (field.required)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '*',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              initialValue: value?.toString(),
              decoration: InputDecoration(
                hintText: field.placeholder ?? 'Escribe tu respuesta aquí...',
                errorText: errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.error, width: 2),
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: maxLines,
              maxLength: field.maxLength,
              onChanged: (newValue) => onChanged(newValue),
            ),
          ],
        ),
      ),
    );
  }

  /// Renderiza un selector de imagen
  Widget _buildImagePicker(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: errorText != null ? AppColors.error : AppColors.border,
          width: errorText != null ? 2 : 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (field.required)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '*',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),

            if (errorText != null) ...[
              SizedBox(height: 4),
              Text(
                errorText!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                ),
              ),
            ],

            SizedBox(height: 12),

            // Mostrar imagen si existe
            if (value != null && value.toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(value.toString()),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: AppColors.neutral200,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12),
            ],

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(context, ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(Icons.camera_alt, size: 20),
                    label: Text('Cámara'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(context, ImageSource.gallery),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(Icons.photo_library, size: 20),
                    label: Text('Galería'),
                  ),
                ),
              ],
            ),

            // Botón para eliminar imagen
            if (value != null && value.toString().isNotEmpty) ...[
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => onChanged(null),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: Icon(Icons.delete_outline, size: 20),
                  label: Text('Eliminar imagen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Función para seleccionar imagen
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        onChanged(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}