// ui/widgets/searchable_dropdown.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;
  final IconData? prefixIcon;
  final String? Function(T)? itemAsString;
  final Widget? Function(T)? itemBuilder;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.itemAsString,
    this.itemBuilder,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<DropdownItem<T>> _filteredItems = [];
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _updateDisplayText();
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateDisplayText();
    }
    if (oldWidget.items != widget.items) {
      _filteredItems = widget.items;
      _filterItems(_searchController.text);
    }
  }

  void _updateDisplayText() {
    if (widget.value != null) {
      final selectedItem = widget.items.firstWhere(
            (item) => item.value == widget.value,
        orElse: () => DropdownItem(value: widget.value as T, label: ''),
      );
      _searchController.text = selectedItem.label;
    } else {
      _searchController.clear();
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          return item.label.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
    _updateOverlay();
  }

  void _openDropdown() {
    if (!widget.enabled) return;

    setState(() {
      _isOpen = true;
    });

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _focusNode.requestFocus();
  }

  void _closeDropdown() {
    setState(() {
      _isOpen = false;
    });

    _overlayEntry?.remove();
    _overlayEntry = null;
    _focusNode.unfocus();
    _updateDisplayText(); // Restaurar el texto original si no se seleccionó nada
  }

  void _selectItem(DropdownItem<T> item) {
    _searchController.text = item.label;
    _closeDropdown();
    if (widget.onChanged != null) {
      widget.onChanged!(item.value);
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: _filteredItems.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se encontraron resultados',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = widget.value == item.value;

                  return InkWell(
                    onTap: () => _selectItem(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        border: index < _filteredItems.length - 1
                            ? Border(
                          bottom: BorderSide(
                            color: AppColors.border.withOpacity(0.5),
                            width: 0.5,
                          ),
                        )
                            : null,
                      ),
                      child: Row(
                        children: [
                          if (widget.itemBuilder != null) ...[
                            widget.itemBuilder!(item.value) ??
                                Text(item.label),
                          ] else ...[
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.primary,
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
        ),
      ),
    );
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _overlayEntry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
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
            initialValue: widget.value,
            validator: widget.validator,
            builder: (FormFieldState<T> field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _isOpen ? _closeDropdown : _openDropdown,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: field.hasError
                              ? AppColors.error
                              : _isOpen
                              ? AppColors.primary
                              : AppColors.border,
                          width: _isOpen ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: widget.enabled
                            ? Colors.white
                            : AppColors.background,
                      ),
                      child: TextFormField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        enabled: widget.enabled && _isOpen,
                        onChanged: _filterItems,
                        onTap: () {
                          if (!_isOpen) {
                            _openDropdown();
                          }
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
                            _isOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        readOnly: !_isOpen,
                      ),
                    ),
                  ),
                  if (field.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      field.errorText!,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class DropdownItem<T> {
  final T value;
  final String label;
  final Widget? leading;

  const DropdownItem({
    required this.value,
    required this.label,
    this.leading,
  });
}