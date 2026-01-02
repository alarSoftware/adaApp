import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

/// Widget de autocompletado simple que usa Autocomplete de Flutter
/// Más robusto y sin los problemas de overlays manuales
class SimpleAutocompleteField<T> extends StatefulWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;
  final IconData? prefixIcon;

  const SimpleAutocompleteField({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
  });

  @override
  State<SimpleAutocompleteField<T>> createState() =>
      _SimpleAutocompleteFieldState<T>();
}

class _SimpleAutocompleteFieldState<T>
    extends State<SimpleAutocompleteField<T>> {
  final TextEditingController _controller = TextEditingController();
  T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
    _updateDisplayText();
  }

  @override
  void didUpdateWidget(SimpleAutocompleteField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _selectedValue = widget.value;
      _updateDisplayText();
    }
  }

  void _updateDisplayText() {
    if (_selectedValue != null) {
      try {
        final item = widget.items.firstWhere(
          (item) => item.value == _selectedValue,
          orElse: () => DropdownItem(value: _selectedValue as T, label: ''),
        );

        if (item.label.isNotEmpty) {
          _controller.text = item.label;
        } else {
          _controller.clear();
        }
      } catch (e) {
        _controller.clear();
      }
    } else {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        FormField<T>(
          initialValue: _selectedValue,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (FormFieldState<T> field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Autocomplete<DropdownItem<T>>(
                  displayStringForOption: (item) => item.label,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return widget.items;
                    }

                    return widget.items.where((item) {
                      return item.label.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (DropdownItem<T> selection) {
                    setState(() {
                      _selectedValue = selection.value;
                      _controller.text = selection.label;
                    });

                    field.didChange(selection.value);

                    if (widget.onChanged != null) {
                      widget.onChanged!(selection.value);
                    }
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        // Sincronizar el controlador interno con nuestro controlador
                        if (textEditingController.text != _controller.text) {
                          textEditingController.text = _controller.text;
                          textEditingController.selection =
                              TextSelection.collapsed(
                                offset: textEditingController.text.length,
                              );
                        }

                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          enabled: widget.enabled,
                          onChanged: (value) {
                            _controller.text = value;
                          },
                          decoration: InputDecoration(
                            hintText: widget.hint,
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            prefixIcon: widget.prefixIcon != null
                                ? Icon(
                                    widget.prefixIcon,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  )
                                : null,
                            suffixIcon: Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.textSecondary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: field.hasError
                                    ? AppColors.error
                                    : AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: field.hasError
                                    ? AppColors.error
                                    : AppColors.primary,
                                width: 2,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            fillColor: widget.enabled
                                ? Colors.white
                                : AppColors.background,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        );
                      },
                  optionsViewBuilder:
                      (
                        BuildContext context,
                        AutocompleteOnSelected<DropdownItem<T>> onSelected,
                        Iterable<DropdownItem<T>> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: options.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            color: AppColors.textSecondary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'No se encontraron resultados',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final option = options.elementAt(
                                              index,
                                            );
                                            final isSelected =
                                                option.value == _selectedValue;

                                            return InkWell(
                                              onTap: () => onSelected(option),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                            .withValues(
                                                              alpha: 0.1,
                                                            )
                                                      : Colors.transparent,
                                                  border:
                                                      index < options.length - 1
                                                      ? Border(
                                                          bottom: BorderSide(
                                                            color: AppColors
                                                                .border
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                            width: 0.5,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        option.label,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isSelected
                                                              ? AppColors
                                                                    .primary
                                                              : AppColors
                                                                    .textPrimary,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w500
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                    ),
                                                    if (isSelected) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.check_circle,
                                                        size: 18,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                            ),
                          ),
                        );
                      },
                ),
                if (field.hasError) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          field.errorText!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class DropdownItem<T> {
  final T value;
  final String label;
  final Widget? leading;

  const DropdownItem({required this.value, required this.label, this.leading});
}
