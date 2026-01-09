import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_field.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class DynamicFormFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String? errorText;
  final Map<String, dynamic> allValues;
  final Function(String fieldId, dynamic value)? onNestedFieldChanged;
  final int depth;
  final bool isReadOnly;

  final Future<bool> Function(String fieldId, String imagePath)?
  onImageSelected;
  final Future<bool> Function(String fieldId)? onImageDeleted;

  const DynamicFormFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.allValues = const {},
    this.onNestedFieldChanged,
    this.depth = 0,
    this.isReadOnly = false,
    this.onImageSelected,
    this.onImageDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final isConditional = field.metadata?['conditionalParentId'] != null;
    final content = _buildFieldByType(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 16, left: isConditional ? 24 : 0),
      child: isConditional ? _buildWithConditionalBadge(content) : content,
    );
  }

  Widget _buildFieldByType(BuildContext context) {
    return switch (field.type) {
      'titulo' => _buildHeader(),
      'radio_button' => _buildSelectionGroup(context, isMultiple: false),
      'checkbox' => _buildSelectionGroup(context, isMultiple: true),
      'resp_abierta' => _buildTextField(maxLines: 3),
      'resp_abierta_larga' => _buildTextField(maxLines: 6),
      'image' => _buildImagePicker(context),
      _ => _buildTextField(),
    };
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      color: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
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

  Widget _buildSelectionGroup(
    BuildContext context, {
    required bool isMultiple,
  }) {
    final selectedIds = _parseSelectedIds(value);
    final options = field.children.where((c) => c.type == 'opt').toList();

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(),
          if (errorText != null) _buildErrorText(),
          SizedBox(height: 12),
          Divider(color: AppColors.border, height: 1),
          SizedBox(height: 8),
          if (options.isEmpty)
            _buildEmptyMessage()
          else
            ...options.map(
              (opt) =>
                  _buildOptionWithNested(context, opt, selectedIds, isMultiple),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionWithNested(
    BuildContext context,
    DynamicFormField option,
    List<String> selectedIds,
    bool isMultiple,
  ) {
    final isSelected = selectedIds.contains(option.id);
    final hasNested = option.children.any((c) => c.type != 'opt');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOptionItem(
          option: option,
          isSelected: isSelected,
          isRadio: !isMultiple,
          onTap: isReadOnly
              ? null
              : () => _handleSelection(option.id, isMultiple, selectedIds),
        ),
        if (isSelected && hasNested)
          _buildNestedFields(context, option.children),
      ],
    );
  }

  Widget _buildOptionItem({
    required DynamicFormField option,
    required bool isSelected,
    required VoidCallback? onTap,
    required bool isRadio,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: isReadOnly ? 0.6 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
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
                isRadio
                    ? (isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank),
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
              if (isReadOnly)
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNestedFields(
    BuildContext context,
    List<DynamicFormField> nestedFields, {
    int depth = 0,
  }) {
    final fields = nestedFields.where((f) => f.type != 'opt').toList();
    if (fields.isEmpty) return SizedBox.shrink();

    return Column(
      children: fields.map((f) {
        final hasSubChildren = f.children.any((c) => c.type != 'opt');
        return Padding(
          padding: EdgeInsets.only(bottom: depth >= 2 ? 12.0 : 8.0, top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNestedLineIndicator(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNestedFieldCard(context, f, depth),
                    if (hasSubChildren)
                      Padding(
                        padding: EdgeInsets.only(left: 10, top: 8),
                        child: _buildNestedFields(
                          context,
                          f.children,
                          depth: depth + 1,
                        ),
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

  Widget _buildNestedLineIndicator() {
    return SizedBox(
      width: 16,
      child: Column(
        children: [
          Container(
            width: 2,
            height: 14,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          Row(
            children: [
              Container(
                width: 2,
                height: 2,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNestedFieldCard(
    BuildContext context,
    DynamicFormField nestedField,
    int depth,
  ) {
    return Card(
      elevation: 0.5,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(depth >= 2 ? 14.0 : 12.0),
        child: _buildNestedFieldContent(context, nestedField),
      ),
    );
  }

  Widget _buildNestedFieldContent(
    BuildContext context,
    DynamicFormField field,
  ) {
    return switch (field.type) {
      'image' => _buildNestedImagePicker(context, field),
      'checkbox' => _buildNestedSelectionField(context, field, isRadio: false),
      'radio_button' => _buildNestedSelectionField(
        context,
        field,
        isRadio: true,
      ),
      'resp_abierta' => _buildNestedTextField(field, maxLines: 2),
      'resp_abierta_larga' => _buildNestedTextField(field, maxLines: 4),
      _ => _buildNestedTextField(field),
    };
  }

  Widget _buildNestedSelectionField(
    BuildContext context,
    DynamicFormField field, {
    required bool isRadio,
  }) {
    final nestedValue = allValues[field.id];
    final selectedIds = isRadio
        ? (nestedValue != null ? [nestedValue.toString()] : <String>[])
        : _parseSelectedIds(nestedValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        ...field.children.where((c) => c.type == 'opt').map((opt) {
          final isSelected = isRadio
              ? selectedIds.firstOrNull == opt.id
              : selectedIds.contains(opt.id);
          final hasNested = opt.children.any((c) => c.type != 'opt');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNestedOption(
                opt,
                isSelected,
                isRadio,
                isReadOnly
                    ? null
                    : () {
                        if (onNestedFieldChanged == null) return;
                        if (isRadio) {
                          onNestedFieldChanged!(field.id, opt.id);
                        } else {
                          final newIds = List<String>.from(selectedIds);
                          isSelected
                              ? newIds.remove(opt.id)
                              : newIds.add(opt.id);
                          onNestedFieldChanged!(field.id, newIds);
                        }
                      },
              ),
              if (isSelected && hasNested)
                _buildNestedFields(context, opt.children, depth: 1),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildNestedOption(
    DynamicFormField opt,
    bool isSelected,
    bool isRadio,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: isReadOnly ? 0.6 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isRadio
                    ? (isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank),
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (isReadOnly)
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNestedTextField(DynamicFormField field, {int maxLines = 2}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          initialValue: allValues[field.id]?.toString(),
          enabled: !isReadOnly,
          decoration: InputDecoration(
            hintText: isReadOnly ? '' : 'Escribe...',
            hintStyle: TextStyle(fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            isDense: true,
            filled: true,
            fillColor: isReadOnly ? AppColors.neutral200 : AppColors.background,
            suffixIcon: isReadOnly ? Icon(Icons.lock_outline, size: 16) : null,
          ),
          style: TextStyle(fontSize: 12),
          maxLines: maxLines,
          onChanged: isReadOnly
              ? null
              : (v) => onNestedFieldChanged?.call(field.id, v),
        ),
      ],
    );
  }

  Widget _buildNestedImagePicker(BuildContext context, DynamicFormField field) {
    final imagePath = allValues[field.id]?.toString();
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera, color: AppColors.primary, size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                field.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isReadOnly)
              Icon(
                Icons.lock_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
          ],
        ),
        SizedBox(height: 8),
        if (hasImage) ...[
          _buildImagePreview(imagePath, height: 100),
          SizedBox(height: 6),
        ] else if (isReadOnly) ...[
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sin imagen',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
        ],
        if (!isReadOnly) ...[
          _buildImageButtons(context, isNested: true, fieldId: field.id),
          if (hasImage)
            _buildDeleteButton(
              fieldId: field.id,
              onLocalDelete: () => onNestedFieldChanged?.call(field.id, null),
              isCompact: true,
            ),
        ],
      ],
    );
  }

  Widget _buildTextField({int maxLines = 3}) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(),
          SizedBox(height: 8),
          TextFormField(
            initialValue: value?.toString(),
            enabled: !isReadOnly,
            decoration: InputDecoration(
              hintText: isReadOnly
                  ? ''
                  : (field.placeholder ?? 'Escribe tu respuesta aquí...'),
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              filled: true,
              fillColor: isReadOnly
                  ? AppColors.neutral200
                  : AppColors.background,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: isReadOnly
                  ? Icon(Icons.lock_outline, size: 20)
                  : null,
            ),
            maxLines: maxLines,
            maxLength: isReadOnly ? null : field.maxLength,
            onChanged: isReadOnly ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    final hasImage = value != null && value.toString().isNotEmpty;

    return _buildCardContainer(
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
              if (field.required && !isReadOnly) _buildRequiredBadge(),
              if (isReadOnly)
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          if (errorText != null) _buildErrorText(),
          SizedBox(height: 12),
          if (hasImage) ...[
            _buildImagePreview(value.toString(), height: 200),
            SizedBox(height: 12),
          ] else if (isReadOnly) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: AppColors.textSecondary,
                      size: 48,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sin imagen',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
          ],
          if (!isReadOnly) ...[
            _buildImageButtons(context),
            if (hasImage)
              _buildDeleteButton(
                fieldId: field.id,
                onLocalDelete: () => onChanged(null),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview(String path, {double height = 200}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: AppColors.neutral200,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: height > 100 ? 48 : 28,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageButtons(
    BuildContext context, {
    bool isNested = false,
    String? fieldId,
  }) {
    final buttonPadding = isNested
        ? EdgeInsets.symmetric(vertical: 6)
        : EdgeInsets.symmetric(vertical: 12);
    final iconSize = isNested ? 14.0 : 20.0;
    final fontSize = isNested ? 10.0 : 14.0;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(
              context,
              ImageSource.camera,
              isNested: isNested,
              fieldId: fieldId,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: buttonPadding,
            ),
            icon: Icon(Icons.camera_alt, size: iconSize),
            label: Text('Cámara', style: TextStyle(fontSize: fontSize)),
          ),
        ),
        SizedBox(width: isNested ? 6 : 8),
        Expanded(
          child: isNested
              ? OutlinedButton.icon(
                  onPressed: () => _pickImage(
                    context,
                    ImageSource.gallery,
                    isNested: true,
                    fieldId: fieldId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: buttonPadding,
                    side: BorderSide(color: AppColors.primary),
                  ),
                  icon: Icon(Icons.photo_library, size: iconSize),
                  label: Text('Galería', style: TextStyle(fontSize: fontSize)),
                )
              : ElevatedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    padding: buttonPadding,
                  ),
                  icon: Icon(Icons.photo_library, size: iconSize),
                  label: Text('Galería', style: TextStyle(fontSize: fontSize)),
                ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton({
    required String fieldId,
    required VoidCallback onLocalDelete,
    bool isCompact = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          // Si hay callback de eliminación de imagen, usarlo
          if (onImageDeleted != null) {
            final success = await onImageDeleted!(fieldId);
            if (success) {
              onLocalDelete();
            }
          } else {
            // Fallback: solo limpiar el valor local
            onLocalDelete();
          }
        },
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
        ),
        icon: Icon(Icons.delete_outline, size: isCompact ? 14 : 20),
        label: Text(
          'Eliminar',
          style: TextStyle(fontSize: isCompact ? 10 : 14),
        ),
      ),
    );
  }

  Future<void> _pickImage(
    BuildContext context,
    ImageSource source, {
    bool isNested = false,
    String? fieldId,
  }) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      // Mostrar indicador de carga
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Guardando imagen...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.info,
          ),
        );
      }

      // GUARDAR IMAGEN EN LA BD
      final targetFieldId = isNested && fieldId != null ? fieldId : field.id;

      if (onImageSelected != null) {
        final success = await onImageSelected!(targetFieldId, image.path);

        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Imagen guardada'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 1),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error guardando imagen'),
                backgroundColor: AppColors.error,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Fallback: solo actualizar el valor (comportamiento anterior)
        if (isNested && fieldId != null) {
          onNestedFieldChanged?.call(fieldId, image.path);
        } else {
          onChanged(image.path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildCardContainer({required Widget child}) {
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
      child: Padding(padding: EdgeInsets.all(12), child: child),
    );
  }

  Widget _buildFieldHeader() {
    return Row(
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
        if (field.required && !isReadOnly) _buildRequiredBadge(),
        if (isReadOnly)
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.lock_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildRequiredBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
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
    );
  }

  Widget _buildErrorText() {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text(
        errorText!,
        style: TextStyle(fontSize: 11, color: AppColors.error),
      ),
    );
  }

  Widget _buildEmptyMessage() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        'No hay opciones disponibles',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildWithConditionalBadge(Widget child) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 60,
          margin: EdgeInsets.only(right: 12, top: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
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
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
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
              child,
            ],
          ),
        ),
      ],
    );
  }

  List<String> _parseSelectedIds(dynamic value) {
    if (value == null) return [];

    // Si ya es una lista
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    // Si es un string que podría ser JSON
    if (value is String && value.isNotEmpty) {
      // Intentar parsear como JSON array
      if (value.startsWith('[')) {
        try {
          final decoded = jsonDecode(value) as List;
          return decoded.map((e) => e.toString()).toList();
        } catch (e) {
          // Si falla, tratarlo como string simple
          return [value];
        }
      }
      return [value];
    }

    // Si es un número u otro tipo
    if (value is int || value is double) {
      return [value.toString()];
    }

    return [];
  }

  void _handleSelection(
    String optionId,
    bool isMultiple,
    List<String> current,
  ) {
    if (isMultiple) {
      final newSelected = List<String>.from(current);
      newSelected.contains(optionId)
          ? newSelected.remove(optionId)
          : newSelected.add(optionId);
      onChanged(newSelected);
    } else {
      onChanged(optionId);
    }
  }
}
