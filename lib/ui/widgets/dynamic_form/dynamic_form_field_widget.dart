import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/dynamic_form/dynamic_form_field.dart';

/// Widget que renderiza un campo dinámico según su tipo CON LÓGICA CONDICIONAL
class DynamicFormFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String? errorText;
  final Map<String, dynamic> allValues; // ← NUEVO: todos los valores del formulario

  const DynamicFormFieldWidget({
    Key? key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.allValues = const {}, // ← NUEVO
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: _buildFieldByType(),
    );
  }

  Widget _buildFieldByType() {
    switch (field.type) {
      case 'titulo':
        return _buildHeader();
      case 'radio_button':
        return _buildRadioGroupConditional(); // ← NUEVO MÉTODO
      case 'checkbox':
        return _buildCheckboxGroup();
      case 'resp_abierta':
        return _buildTextField(maxLines: 3);
      case 'resp_abierta_larga':
        return _buildTextField(maxLines: 6);
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

  /// ✨ NUEVO: Renderiza un grupo de radio buttons con lógica condicional
  Widget _buildRadioGroupConditional() {
    // Obtener opciones visibles según la lógica condicional
    final visibleOptions = _getVisibleOptions(field.children);

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

            // Renderizar opciones visibles de forma recursiva
            if (visibleOptions.isEmpty)
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
              ..._buildOptionsRecursive(visibleOptions, 0),
          ],
        ),
      ),
    );
  }

  /// ✨ NUEVO: Construye las opciones de forma recursiva con indentación
  List<Widget> _buildOptionsRecursive(List<DynamicFormField> options, int level) {
    List<Widget> widgets = [];

    for (final option in options) {
      final isSelected = value == option.id;

      // ⭐ NUEVO: Verificar si algún descendiente está seleccionado
      final hasSelectedDescendant = _hasSelectedDescendant(option, value);

      // Agregar la opción actual
      widgets.add(
        InkWell(
          onTap: () => onChanged(option.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: EdgeInsets.only(
              bottom: 8,
              left: level * 16.0, // ← Indentación por nivel
            ),
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
      );

      // ⭐ CAMBIO CRÍTICO: Mostrar hijos si esta opción o algún descendiente está seleccionado
      if ((isSelected || hasSelectedDescendant) && option.children.isNotEmpty) {
        final childOptions = option.children.where((c) => c.type == 'opt').toList();
        widgets.addAll(_buildOptionsRecursive(childOptions, level + 1));
      }
    }

    return widgets;
  }

  /// ⭐ NUEVO MÉTODO: Verifica si algún descendiente está seleccionado
  bool _hasSelectedDescendant(DynamicFormField option, dynamic selectedValue) {
    if (selectedValue == null) return false;

    for (final child in option.children) {
      if (child.id == selectedValue) return true;
      if (_hasSelectedDescendant(child, selectedValue)) return true;
    }

    return false;
  }

  /// ✨ NUEVO: Obtiene solo las opciones visibles (primer nivel)
  List<DynamicFormField> _getVisibleOptions(List<DynamicFormField> allOptions) {
    // Devolver todas las opciones directas (children del radio_button/checkbox)
    // que sean de tipo 'opt'
    return allOptions.where((opt) => opt.type == 'opt').toList();
  }

  /// Renderiza un grupo de checkboxes
  Widget _buildCheckboxGroup() {
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
              ...field.children.map((option) {
                final isSelected = selectedIds.contains(option.id);

                return InkWell(
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
}