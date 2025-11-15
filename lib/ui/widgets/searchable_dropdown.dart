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
  final double maxHeight;

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
    this.maxHeight = 200,
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

    // ✅ PRIMERO: Actualizar la lista de items filtrados
    if (oldWidget.items != widget.items) {
      _filteredItems = widget.items;

      // Si el overlay está abierto, actualizar el filtro
      if (_isOpen) {
        _filterItems(_searchController.text);
      }
    }

    // ✅ SEGUNDO: Actualizar el texto mostrado solo si el valor cambió
    // y si el dropdown NO está abierto (para no interferir con la búsqueda)
    if (oldWidget.value != widget.value && !_isOpen) {
      _updateDisplayText();
    }
  }

  void _updateDisplayText() {
    // ✅ Verificar que el valor existe en la lista de items
    if (widget.value != null) {
      try {
        final selectedItem = widget.items.firstWhere(
              (item) => item.value == widget.value,
          orElse: () => DropdownItem(value: widget.value as T, label: ''),
        );

        // Solo actualizar si encontramos un label válido
        if (selectedItem.label.isNotEmpty) {
          _searchController.text = selectedItem.label;
        } else {
          _searchController.clear();
        }
      } catch (e) {
        // Si hay algún error, limpiar el campo
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
        _filteredItems = widget.items.where((item) {
          return item.label.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
    _updateOverlay();
  }

  void _openDropdown() {
    if (!widget.enabled || _isOpen) return;

    // ✅ Cerrar cualquier overlay previo antes de abrir uno nuevo
    _closeDropdown();

    setState(() {
      _isOpen = true;
    });

    // ✅ Usar addPostFrameCallback para asegurar que el widget está montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOpen) {
        _overlayEntry = _createOverlayEntry();
        Overlay.of(context).insert(_overlayEntry!);
        _focusNode.requestFocus();
      }
    });
  }

  void _closeDropdown() {
    if (!_isOpen) return;

    setState(() {
      _isOpen = false;
    });

    // ✅ Remover el overlay de forma segura
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;

    _focusNode.unfocus();

    // Restaurar el texto original si no se seleccionó nada
    if (!_focusNode.hasFocus) {
      _updateDisplayText();
    }
  }

  void _selectItem(DropdownItem<T> item) {
    _searchController.text = item.label;
    _closeDropdown();

    // ✅ Llamar a onChanged después de cerrar el dropdown
    if (widget.onChanged != null && widget.value != item.value) {
      // Usar addPostFrameCallback para evitar llamadas durante el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onChanged!(item.value);
        }
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    // Obtener el tamaño de la pantalla
    final screenHeight = MediaQuery.of(context).size.height;

    // Calcular si hay espacio suficiente abajo
    final spaceBelow = screenHeight - (offset.dy + size.height);
    final spaceAbove = offset.dy;
    final showAbove = spaceBelow < widget.maxHeight && spaceAbove > spaceBelow;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        // CLAVE: Este GestureDetector captura TODOS los toques fuera del dropdown
        behavior: HitTestBehavior.translucent,
        onTap: _closeDropdown,
        child: Stack(
          children: [
            // Fondo transparente que cubre toda la pantalla
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // El dropdown en sí
            Positioned(
              left: offset.dx,
              top: showAbove
                  ? offset.dy - widget.maxHeight - 5
                  : offset.dy + size.height + 5,
              width: size.width,
              child: GestureDetector(
                // Prevenir que los toques en el dropdown lo cierren
                onTap: () {},
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: widget.maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildDropdownContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownContent() {
    if (_filteredItems.isEmpty) {
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
            Expanded(
              child: Text(
                'No se encontraron resultados',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
                  widget.itemBuilder!(item.value) ?? Text(item.label),
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
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateOverlay() {
    if (_overlayEntry != null && mounted) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _closeDropdown();
    _searchController.dispose();
    _focusNode.dispose();
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
        CompositedTransformTarget(
          link: _layerLink,
          child: FormField<T>(
            // ✅ REMOVIDO: Ya no usar ValueKey que causa reconstrucciones
            initialValue: widget.value,
            validator: widget.validator,
            // ✅ NUEVO: Forzar revalidación cuando cambia el valor
            autovalidateMode: AutovalidateMode.onUserInteraction,
            builder: (FormFieldState<T> field) {
              // ✅ Actualizar el valor del field cuando cambia externamente
              if (field.value != widget.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    field.didChange(widget.value);
                  }
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _isOpen ? null : _openDropdown,
                    child: AbsorbPointer(
                      absorbing: !_isOpen,
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
                          enabled: widget.enabled,
                          onChanged: _filterItems,
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
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isOpen &&
                                    _searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterItems('');
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                Icon(
                                  _isOpen
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                              ],
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
        ),
      ],
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