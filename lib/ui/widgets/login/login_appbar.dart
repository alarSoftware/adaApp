import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';

class LoginAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(LoginScreenViewModel) onSync;
  final VoidCallback onDeleteUsers;

  const LoginAppBar({
    super.key,
    required this.onSync,
    required this.onDeleteUsers,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        Consumer<LoginScreenViewModel>(
          builder: (context, viewModel, child) {
            return PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 24),
              tooltip: 'Más opciones',
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: AppColors.cardBackground,
              elevation: 8,
              shadowColor: AppColors.shadowLight,
              onSelected: (String value) {
                switch (value) {
                  case 'sync':
                    if (!viewModel.isSyncingUsers) {
                      onSync(viewModel);
                    }
                    break;
                  case 'delete_users':
                    onDeleteUsers();
                    break;
                  case 'api_settings':
                    Navigator.of(context).pushNamed('/api-settings');
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'sync',
                  enabled: !viewModel.isSyncingUsers,
                  child: Row(
                    children: [
                      viewModel.isSyncingUsers
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textSecondary,
                          ),
                        ),
                      )
                          : Icon(Icons.sync, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Sincronizar usuarios',
                        style: TextStyle(
                          color: viewModel.isSyncingUsers
                              ? AppColors.textSecondary.withOpacity(0.5)
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'delete_users',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Eliminar usuarios',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'api_settings',
                  child: Row(
                    children: [
                      Icon(Icons.dns, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Configurar servidor',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}