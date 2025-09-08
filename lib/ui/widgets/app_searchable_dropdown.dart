// widgets/app_searchable_dropdown.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class DropdownItem<T> {
  final T value;
  final String text;
  final Widget? icon;

  DropdownItem({
    required this.value,
    required this.text,
    this.icon,
  });
}

class SearchableDropdown<T> extends StatefulWidget {
  final List<DropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final String? Function(T?)? validator;
  final bool enabled;
  final Color? fillColor;

  const SearchableDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
    this.fillColor,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<DropdownItem<T>> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _updateDisplayText();

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isOpen) {
        _removeOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _updateDisplayText();
    }
    if (oldWidget.items != widget.items) {
      _filteredItems = widget.items;
      _updateOverlay();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _updateDisplayText() {
    if (widget.value != null) {
      try {
        final selectedItem = widget.items.firstWhere(
              (item) => item.value == widget.value,
        );
        _searchController.text = selectedItem.text;
      } catch (e) {
        _searchController.clear();
      }
    } else {
      _searchController.clear();
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => item.text.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    _updateOverlay();
  }

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }

    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.surface,
            shadowColor: AppColors.shadowMedium,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _filteredItems.isEmpty
                  ? _buildEmptyState()
                  : _buildItemsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = item.value == widget.value;

        return InkWell(
          onTap: () {
            _selectItem(item);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
            ),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  item.icon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: AppColors.primary,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectItem(DropdownItem<T> item) {
    _searchController.text = item.text;
    widget.onChanged?.call(item.value);
    _removeOverlay();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Esto permite que el tap se propague al TextFormField
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.labelText != null) ...[
            Text(
              widget.labelText!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          CompositedTransformTarget(
            link: _layerLink,
            child: TextFormField(
              controller: _searchController,
              focusNode: _focusNode,
              enabled: widget.enabled,
              onChanged: _filterItems,
              onTap: () {
                if (!_isOpen) {
                  _showOverlay();
                }
              },
              validator: widget.validator != null
                  ? (String? value) {
                // Convertir la validación del valor T al texto mostrado
                if (value == null || value.isEmpty) {
                  return widget.validator!(null);
                }
                // Buscar el item que coincida con el texto
                final matchingItem = widget.items.cast<DropdownItem<T>?>().firstWhere(
                      (item) => item?.text == value,
                  orElse: () => null,
                );
                return widget.validator!(matchingItem?.value);
              }
                  : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty && widget.enabled)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          widget.onChanged?.call(null);
                          _filterItems('');
                        },
                        color: AppColors.textSecondary,
                      ),
                    Icon(
                      _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                fillColor: widget.fillColor,
                filled: widget.fillColor != null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.focus),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}