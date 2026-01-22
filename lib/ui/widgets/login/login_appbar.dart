import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:showcaseview/showcaseview.dart';

class LoginAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSync;
  final GlobalKey syncKey;

  const LoginAppBar({super.key, required this.onSync, required this.syncKey});

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
            return Showcase(
              key: syncKey,
              title: 'Sincronizar Usuarios',
              description:
                  'Primero debes descargar los usuarios del servidor para poder ingresar.',
              targetPadding: const EdgeInsets.all(8),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
                tooltip: 'Más opciones',
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppColors.cardBackground,
                elevation: 8,
                shadowColor: AppColors.shadowLight,
                onSelected: (String value) {
                  switch (value) {
                    case 'sync':
                      if (!viewModel.isSyncing) {
                        // ✅ CAMBIO: isSyncing en lugar de isSyncingUsers
                        onSync(); // ✅ CAMBIO: Sin parámetro
                      }
                      break;

                    case 'api_settings':
                      Navigator.of(context).pushNamed('/api-settings');
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'sync',
                    enabled: !viewModel.isSyncing, // ✅ CAMBIO: isSyncing
                    child: Row(
                      children: [
                        viewModel
                                .isSyncing // ✅ CAMBIO: isSyncing
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
                            : Icon(
                                Icons.sync,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                        const SizedBox(width: 12),
                        Text(
                          'Sincronizar usuarios',
                          style: TextStyle(
                            color:
                                viewModel
                                    .isSyncing // ✅ CAMBIO: isSyncing
                                ? AppColors.textSecondary.withValues(alpha: 0.5)
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
                    value: 'api_settings',
                    child: Row(
                      children: [
                        Icon(
                          Icons.dns,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
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
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
