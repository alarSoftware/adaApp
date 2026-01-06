import 'package:flutter/material.dart';
import 'package:ada_app/services/permissions_service.dart';
import 'package:ada_app/viewmodels/select_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';

class DebugPermissionsDialog extends StatefulWidget {
  final SelectScreenViewModel viewModel;

  const DebugPermissionsDialog({super.key, required this.viewModel});

  @override
  State<DebugPermissionsDialog> createState() => _DebugPermissionsDialogState();
}

class _DebugPermissionsDialogState extends State<DebugPermissionsDialog> {
  Map<String, bool> _currentPermissions = {};
  bool _isLoading = true;

  final List<String> _modules = [
    'VerClientes',
    'CrearOperacionComercial',
    'CrearCensoActivo',
    'VerFormularios',
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final perms = await PermissionsService.checkPermissions(_modules);
    if (mounted) {
      setState(() {
        _currentPermissions = perms;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePermission(String module, bool value) async {
    setState(() => _isLoading = true);
    await widget.viewModel.togglePermission(module, value);
    await _loadPermissions();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: AppColors.error),
          SizedBox(width: 8),
          Text('Debug Permisos'),
        ],
      ),
      content: _isLoading
          ? SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _modules.map((module) {
                  final isEnabled = _currentPermissions[module] ?? false;
                  return SwitchListTile(
                    title: Text(module),
                    subtitle: Text(
                      isEnabled ? 'Habilitado' : 'Deshabilitado',
                      style: TextStyle(
                        fontSize: 12,
                        color: isEnabled
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    value: isEnabled,
                    onChanged: (val) => _togglePermission(module, val),
                  );
                }).toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar'),
        ),
      ],
    );
  }
}
