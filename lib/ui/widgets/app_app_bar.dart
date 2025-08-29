import 'package:flutter/material.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.grey[800],
      foregroundColor: Colors.white,
      elevation: 2,
      leading: leading ??
          (showBackButton && Navigator.canPop(context)
              ? IconButton(
            onPressed: onBackPressed ?? () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          )
              : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}