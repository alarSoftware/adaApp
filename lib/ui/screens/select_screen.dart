// ui/screens/select_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/screens/equipos_screen.dart';
import 'package:ada_app/ui/screens/modelos_screen.dart';
import 'package:ada_app/ui/screens/logo_screen.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/select_screen_viewmodel.dart';
import 'dart:async';

class SelectScreen extends StatefulWidget {
  const SelectScreen({super.key});

  @override
  _SelectScreenState createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> {
  late SelectScreenViewModel _viewModel;
  late StreamSubscription<UIEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = SelectScreenViewModel();
    _setupEventListener();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription = _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowErrorEvent) {
        _mostrarError(event.message);
      } else if (event is ShowSuccessEvent) {
        _mostrarExito(event.message);
      } else if (event is RequestSyncConfirmationEvent) {
        _handleSyncConfirmation();
      } else if (event is RequestDeleteConfirmationEvent) {
        _handleDeleteConfirmation();
      } else if (event is SyncCompletedEvent) {
        _mostrarExito(event.result.message);
      }
    });
  }

  Future<void> _handleSyncConfirmation() async {
    final confirmar = await _mostrarDialogoSincronizacion();
    if (confirmar == true) {
      _viewModel.executeSync();
    }
  }

  Future<void> _handleDeleteConfirmation() async {
    final confirmar = await _mostrarDialogoBorrarBD();
    if (confirmar == true) {
      _viewModel.executeDeleteDatabase();
    }
  }

  // DIÁLOGOS - Actualizados con sistema de colores
  Future<bool?> _mostrarDialogoSincronizacion() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.sync, color: AppColors.neutral700),
              SizedBox(width: 8),
              Text(
                'Sincronizar Datos',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción descargará todos los datos del servidor:',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Clientes del servidor',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '• Equipos y refrigeradores',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '• Estados y asignaciones',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Los datos locales serán actualizados.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Sincronizar Todo'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _mostrarDialogoBorrarBD() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'Borrar Base de Datos',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡ATENCIÓN!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Esta acción borrará TODOS los datos locales:',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              SizedBox(height: 8),
              Text('• Todos los clientes', style: TextStyle(color: AppColors.textSecondary)),
              Text('• Todos los equipos', style: TextStyle(color: AppColors.textSecondary)),
              Text('• Configuraciones locales', style: TextStyle(color: AppColors.textSecondary)),
              Text('• Datos de sincronización', style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text(
                '¿Estás seguro?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Sí, Borrar Todo'),
            ),
          ],
        );
      },
    );
  }

  // MENSAJES - Actualizados con sistema de colores
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $mensaje'),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $mensaje'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required Color? color,
        String? routeName,
        Widget? page,
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap ?? () {
        if (routeName != null) {
          Navigator.pushNamed(context, routeName);
        } else if (page != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color ?? AppColors.primary),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final status = _viewModel.connectionStatus;
        IconData icon;
        Color color;
        String text;

        if (!status.hasInternet) {
          icon = Icons.wifi_off;
          color = AppColors.error;
          text = 'Sin Internet';
        } else if (!status.hasApiConnection) {
          icon = Icons.cloud_off;
          color = AppColors.warning;
          text = 'API Desconectada';
        } else {
          icon = Icons.cloud_done;
          color = AppColors.success;
          text = 'Conectado';
        }

        return Container(
          margin: EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.appBarForeground,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panel Principal',
          style: TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          // Botón de sync - usa ViewModel
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return IconButton(
                onPressed: _viewModel.isSyncing ? null : _viewModel.requestSync,
                icon: _viewModel.isSyncing
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                  ),
                )
                    : Icon(Icons.sync, color: AppColors.onPrimary),
                tooltip: _viewModel.isSyncing ? 'Sincronizando...' : 'Sincronizar datos',
              );
            },
          ),

          // Estado de conexión
          _buildConnectionStatus(),

          // Menu de opciones
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return PopupMenuButton<String>(
                onSelected: (String value) {
                  switch (value) {
                    case 'probar_conexion':
                      _viewModel.testConnection();
                      break;
                    case 'borrar_bd':
                      _viewModel.requestDeleteDatabase();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'probar_conexion',
                    enabled: !_viewModel.isSyncing,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_find, color: AppColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Probar Conexión',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'borrar_bd',
                    enabled: !_viewModel.isSyncing,
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: AppColors.error),
                        SizedBox(width: 8),
                        Text(
                          'Borrar Base de Datos',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.containerBackground,
              AppColors.background,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMenuButton(
                            context,
                            label: 'Clientes',
                            icon: Icons.people,
                            color: AppColors.primary,
                            routeName: '/clienteLista',
                          ),
                          _buildMenuButton(
                            context,
                            label: 'Equipos',
                            icon: Icons.devices,
                            color: AppColors.primary,
                            page: const EquipoListScreen(),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMenuButton(
                            context,
                            label: 'Modelos',
                            icon: Icons.branding_watermark,
                            color: AppColors.primary,
                            page: const ModelosScreen(),
                          ),
                          _buildMenuButton(
                            context,
                            label: 'Logos',
                            icon: Icons.newspaper,
                            color: AppColors.primary,
                            page: const LogosScreen(),
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
            SafeArea(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: Icon(Icons.logout, color: AppColors.textSecondary),
                label: Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
            )

          ],
        ),
      ),
    );
  }
}