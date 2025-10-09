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
  final Function(String fieldId, dynamic value)? onNestedFieldChanged;

  const DynamicFormFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.allValues = const {},
    this.onNestedFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isConditional = field.metadata?['conditionalParentId'] != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 16,
        left: isConditional ? 24 : 0,
      ),
      child: isConditional
          ? _buildConditionalFieldWithLine(context)
          : _buildFieldByType(context),
    );
  }

  Widget _buildConditionalFieldWithLine(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 60,
          margin: EdgeInsets.only(right: 12, top: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                style: TextStyle(fontSize: 11, color: AppColors.error),
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
                final isSelected = value == option.id;
                final hasNestedFields = option.children.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => onChanged(option.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
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
                    if (isSelected && hasNestedFields)
                      _buildNestedFields(context, option.children),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  ///DISEÑO COMPACTO CON LÍNEAS EN "L"
  Widget _buildNestedFields(BuildContext context, List<DynamicFormField> nestedFields, {int depth = 0}) {
    // Límite de profundidad visual con líneas (niveles 0-1 con líneas)
    final showLines = depth < 2;
    final leftPadding = depth == 0 ? 8.0 : 6.0; // Padding muy compacto

    return Column(
      children: nestedFields
          .where((f) => f.type != 'opt')
          .map((nestedField) {
        final hasSubChildren = nestedField.children.where((c) => c.type != 'opt').isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(bottom: 6, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Línea en "L" compacta
              if (showLines)
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      // Línea vertical corta
                      SizedBox(
                        width: 2,
                        height: 10,
                      ),
                      // Línea horizontal
                      Row(
                        children: [
                          SizedBox(
                            width: 2,
                            height: 2,
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Campo anidado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNestedFieldCard(context, nestedField, depth),

                    // Recursión con más profundidad
                    if (hasSubChildren)
                      Padding(
                        padding: EdgeInsets.only(left: leftPadding, top: 4),
                        child: _buildNestedFields(context, nestedField.children, depth: depth + 1),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  ///Card compacta para campos anidados
  Widget _buildNestedFieldCard(BuildContext context, DynamicFormField nestedField, int depth) {
    return Card(
      elevation: 0.5,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: _buildNestedFieldContent(context, nestedField),
      ),
    );
  }

  Widget _buildNestedFieldContent(BuildContext context, DynamicFormField nestedField) {
    switch (nestedField.type) {
      case 'image':
        return _buildImagePickerContent(context, nestedField);
      case 'checkbox':
        return _buildCheckboxContent(context, nestedField);
      case 'resp_abierta':
        return _buildTextFieldContent(nestedField, maxLines: 2);
      case 'resp_abierta_larga':
        return _buildTextFieldContent(nestedField, maxLines: 4);
      default:
        return _buildTextFieldContent(nestedField);
    }
  }

  Widget _buildTextFieldContent(DynamicFormField nestedField, {int maxLines = 2}) {
    final nestedValue = allValues[nestedField.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nestedField.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          initialValue: nestedValue?.toString(),
          decoration: InputDecoration(
            hintText: 'Escribe...',
            hintStyle: TextStyle(fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            isDense: true,
            filled: true,
            fillColor: AppColors.background,
          ),
          style: TextStyle(fontSize: 12),
          maxLines: maxLines,
          onChanged: (newValue) {
            if (onNestedFieldChanged != null) {
              onNestedFieldChanged!(nestedField.id, newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCheckboxContent(BuildContext context, DynamicFormField nestedField) {
    final nestedValue = allValues[nestedField.id];
    List<String> selectedIds = [];

    if (nestedValue is List) {
      selectedIds = List<String>.from(nestedValue);
    } else if (nestedValue is String && nestedValue.isNotEmpty) {
      selectedIds = [nestedValue];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nestedField.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
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
                  margin: EdgeInsets.only(bottom: 6),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
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
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSelected && hasNestedFields)
                _buildNestedFields(context, option.children, depth: 1),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildImagePickerContent(BuildContext context, DynamicFormField nestedField) {
    final nestedValue = allValues[nestedField.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera, color: AppColors.primary, size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                nestedField.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (nestedValue != null && nestedValue.toString().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(nestedValue.toString()),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  color: AppColors.neutral200,
                  child: Center(
                    child: Icon(Icons.broken_image, size: 28, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 6),
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
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
                icon: Icon(Icons.camera_alt, size: 14),
                label: Text('Cámara', style: TextStyle(fontSize: 10)),
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _pickImageForNested(context, nestedField, ImageSource.gallery);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 6),
                  side: BorderSide(color: AppColors.primary),
                ),
                icon: Icon(Icons.photo_library, size: 14),
                label: Text('Galería', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
        if (nestedValue != null && nestedValue.toString().isNotEmpty) ...[
          SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              if (onNestedFieldChanged != null) {
                onNestedFieldChanged!(nestedField.id, null);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: EdgeInsets.symmetric(vertical: 4),
            ),
            icon: Icon(Icons.delete_outline, size: 14),
            label: Text('Eliminar', style: TextStyle(fontSize: 10)),
          ),
        ],
      ],
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
              Text(errorText!, style: TextStyle(fontSize: 11, color: AppColors.error)),
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
                        margin: EdgeInsets.only(bottom: 8),
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
                    if (isSelected && hasNestedFields)
                      _buildNestedFields(context, option.children),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

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
              Text(errorText!, style: TextStyle(fontSize: 11, color: AppColors.error)),
            ],
            SizedBox(height: 12),
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