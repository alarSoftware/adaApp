import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;

  const AppSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[50],
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            onPressed: () {
              controller.clear();
              onClear?.call();
            },
            icon: const Icon(Icons.clear, color: Colors.grey),
          )
              : null,
        ),
      ),
    );
  }
}