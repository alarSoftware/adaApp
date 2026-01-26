import 'package:permission_handler/permission_handler.dart'; // Add import

import 'package:ada_app/ui/screens/menu_principal/pending_data_screen.dart';
import 'package:ada_app/services/permissions_service.dart';
// import 'package:ada_app/ui/screens/dynamic_form/dynamic_form_template_list_screen.dart';
import 'package:ada_app/ui/screens/dynamic_form/dynamic_form_responses_screen.dart';
// import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';

import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/ui/widgets/battery_optimization_dialog.dart';
// import 'package:ada_app/ui/widgets/debug_permissions_dialog.dart';
import 'package:ada_app/ui/widgets/app_connection_indicator.dart';
import 'package:ada_app/ui/screens/menu_principal/equipos_screen.dart';
import 'package:ada_app/ui/screens/menu_principal/modelos_screen.dart';
import 'package:ada_app/ui/screens/menu_principal/logo_screen.dart';
import 'package:ada_app/ui/screens/menu_principal/marca_screen.dart';
import 'package:ada_app/viewmodels/select_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/login/sync_progress_widget.dart';
import 'package:ada_app/services/data/database_validation_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/ui/screens/menu_principal/productos_screen.dart';
import 'package:ada_app/ui/screens/menu_principal/about_screen.dart';
import 'package:ada_app/config/app_config.dart';
import 'package:ada_app/ui/screens/error_log_screen.dart';
import 'package:ada_app/ui/screens/settings/data_usage_screen.dart';

import 'package:ada_app/services/device/location_service.dart';

import 'package:ada_app/services/navigation/navigation_guard_service.dart';
import 'package:ada_app/services/navigation/route_constants.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operaciones_comerciales_history_screen.dart';
import 'package:ada_app/ui/screens/settings/system_options_screen.dart';

import 'dart:async';

class SelectScreen extends StatefulWidget {
  const SelectScreen({super.key});

  @override
  State<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen>
    with WidgetsBindingObserver {
  late SelectScreenViewModel _viewModel;
  late StreamSubscription<UIEvent> _eventSubscription;

  int _pendingDataCount = 0;

  Timer? _pendingDataTimer;

  bool _batteryOptimizationChecked = false;

  @override
  void initState() {
    super.initState();
    _viewModel = SelectScreenViewModel();
    _setupEventListener();
    _startPendingDataMonitoring();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBatteryOptimizationOnFirstLoad();
      _checkLocationPermissions();
      _checkNotificationPermissions();
      _checkAutoRedirect();
    });
  }

  Future<void> _checkAutoRedirect() async {
    final permissions = await PermissionsService.checkPermissions([
      'VerClientes',
      'VerFormularios',
    ]);
    final canViewClients = permissions['VerClientes'] ?? false;
    final canViewForms = permissions['VerFormularios'] ?? false;

    if (canViewForms && !canViewClients) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DynamicFormResponsesScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription.cancel();
    _pendingDataTimer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _startPendingDataMonitoring() {
    _checkPendingData();

    _pendingDataTimer?.cancel();
    _pendingDataTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkPendingData();
    });
  }

  Future<void> _checkPendingData() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final censosPendientes = await db.query(
        'censo_activo',
        where: 'estado_censo IN (?, ?)',
        whereArgs: ['creado', 'error'],
      );

      final cantidadCensos = censosPendientes.length;

      final validationService = DatabaseValidationService(db);
      final summary = await validationService.getPendingSyncSummary();
      final pendingByTable =
          summary['pending_by_table'] as List<dynamic>? ?? [];

      final tablasExcluidas = {
        'censo_activo',
        'equipos_pendientes',
        'censo_activo_foto',
      };

      int otrosDatos = 0;
      for (var item in pendingByTable) {
        final tableName = item['table'] as String;
        if (!tablasExcluidas.contains(tableName)) {
          otrosDatos += item['count'] as int;
        }
      }

      final totalPendientes = cantidadCensos + otrosDatos;

      if (mounted && _pendingDataCount != totalPendientes) {
        setState(() {
          _pendingDataCount = totalPendientes;
        });
      }
    } catch (e) {
      debugPrint('Error checking pending data: $e');
    }
  }

  Future<void> _checkBatteryOptimizationOnFirstLoad() async {
    if (_batteryOptimizationChecked) return;
    _batteryOptimizationChecked = true;

    try {
      await BatteryOptimizationDialog.checkAndRequestBatteryOptimization(
        context,
      );
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
    }
  }

  Future<void> _checkLocationPermissions() async {
    try {
      // Solicitar permisos de ubicación si no están otorgados
      await LocationService().ensurePermissions();
    } catch (e) {
      if (mounted) {
        _mostrarError(
          'Se requieren permisos de ubicación para el funcionamiento correcto.',
        );
      }
    }

    // 🕵️‍♂️ NUEVO: Verificar ubicación simulada
    await _checkFakeGps();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermissions();
    }
  }

  Future<void> _checkNotificationPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
    }
  }

  Future<void> _checkFakeGps() async {
    try {
      final isMocked = await LocationService().checkForMockLocation();
      if (isMocked) {
        if (mounted) {
          _mostrarDialogoFakeLocation();
        }
      }
    } catch (e) {
      debugPrint('Error checking fake GPS: $e');
    }
  }

  Future<void> _mostrarDialogoFakeLocation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // NO SE PUEDE CERRAR TOCANDO AFUERA
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // NO SE PUEDE CERRAR CON BACK BUTTON
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                Icon(Icons.location_off, color: AppColors.error, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ubicación Simulada Detectada',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Se ha detectado el uso de una aplicación para simular la ubicación (Fake GPS).',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Por motivos de seguridad y control, no es posible utilizar la aplicación con ubicaciones falsas.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 16),
                Text(
                  'Por favor, desactiva cualquier aplicación de ubicación falsa y vuelve a intentar.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Reintentar verificación
                  await _checkFakeGps();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Reintentar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            color: AppColors.surface,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Cerrando sesión...',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await AuthService().logout();

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      _mostrarError('Error al cerrar sesión: $e');
    }
  }

  Widget _buildPendingDataButton() {
    return Stack(
      children: [
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PendingDataScreen()),
            );
          },
          icon: Icon(Icons.notifications, color: AppColors.onPrimary),
          tooltip: 'Datos pendientes de envío',
        ),
        if (_pendingDataCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _pendingDataCount > 99 ? '99+' : _pendingDataCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
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
      } else if (event is RequiredSyncEvent) {
        _handleRequiredSync(event);
      } else if (event is RedirectToLoginEvent) {
        _redirectToLogin();
      } else if (event is RequestDeleteConfirmationEvent) {
        _handleDeleteConfirmation();
      } else if (event is RequestDeleteWithValidationEvent) {
        _handleDeleteValidationFailed(event.validationResult);
      } else if (event is SyncCompletedEvent) {
        _mostrarExito(event.result.message);
      } else if (event is SyncErrorEvent) {
        _mostrarDialogoErrorSync(event);
      }
    });
  }

  Future<void> _mostrarDialogoErrorSync(SyncErrorEvent event) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error de Sincronización',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.message,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (event.details != null && event.details!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Detalles técnicos:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      event.details!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 16),

                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.info,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Recomendaciones:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _buildRecommendation('Verifica tu conexión a internet'),
                      _buildRecommendation(
                        'Intenta nuevamente en unos momentos',
                      ),
                      _buildRecommendation(
                        'Si el problema persiste, contacta a soporte',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cerrar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _viewModel.requestSync();
              },
              icon: Icon(Icons.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              label: Text('Reintentar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecommendation(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(color: AppColors.info, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteValidationFailed(
    DatabaseValidationResult validation,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No se puede eliminar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hay datos pendientes de sincronizar:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: validation.pendingItems.map((item) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.displayName}: ${item.count} registro(s)',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Por favor, sincroniza estos datos antes de eliminar la base de datos.',
                          style: TextStyle(color: AppColors.info, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Entendido',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PendingDataScreen()),
                );
              },
              child: Text(
                'Ver Detalles',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _viewModel.requestSync();
              },
              icon: Icon(Icons.sync),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: AppColors.onPrimary,
              ),
              label: Text('Sincronizar Ahora'),
            ),
          ],
        );
      },
    );
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
                      '• Clientes',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '• Equipos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '• Formularios',
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
                style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
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
              Text(
                '• Todos los clientes',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '• Todos los equipos',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '• Configuraciones locales',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '• Datos de sincronización',
                style: TextStyle(color: AppColors.textSecondary),
              ),
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

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
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
        content: Text(mensaje),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMenuCard({
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    String? routeName,
    Widget? page,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : Colors.grey;
    final contentOpacity = enabled ? 1.0 : 0.6;

    return Card(
      elevation: enabled ? 2 : 0,
      color: enabled ? AppColors.surface : Colors.grey[100],
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: enabled ? AppColors.border : Colors.grey[300]!,
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? (onTap ??
                  () {
                    if (routeName != null) {
                      Navigator.pushNamed(context, routeName);
                    } else if (page != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => page),
                      );
                    }
                  })
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No tienes permiso para acceder a este módulo',
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.grey[700],
                  ),
                );
              },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Opacity(
            opacity: contentOpacity,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: enabled ? AppColors.textPrimary : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: enabled
                              ? AppColors.textSecondary
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  )
                else
                  Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync, size: 48, color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Sincronizando Datos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                SyncProgressWidget(
                  progress: _viewModel.syncProgress,
                  currentStep: _viewModel.syncCurrentStep,
                  completedSteps: _viewModel.syncCompletedSteps,
                ),
                SizedBox(height: 16),
                Text(
                  'Por favor no cierres la aplicación',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final status = _viewModel.connectionStatus;
        return AppConnectionIndicator(
          hasInternet: status.hasInternet,
          hasApiConnection: status.hasApiConnection,
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: BoxDecoration(color: AppColors.primary),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, child) {
                if (_viewModel.isLoadingUser) {
                  return Text(
                    'Cargando...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _viewModel.userDisplayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Panel de Control',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(width: 12),
                        _buildConnectionStatus(),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.kitchen,
                  label: 'Equipos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EquipoListScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.widgets,
                  label: 'Modelos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ModelosScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.local_offer,
                  label: 'Logos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LogosScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.domain,
                  label: 'Marcas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MarcaScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.inventory_2,
                  label: 'Productos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductosScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.history_edu,
                  label: 'Historial Operaciones',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const OperacionesComercialesHistoryScreen(),
                      ),
                    );
                  },
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    'Sistema',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  icon: Icons.bug_report,
                  label: 'Log de Errores',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ErrorLogScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.data_usage,
                  label: 'Consumo de Datos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DataUsageScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  label: 'Opciones de Sistema',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SystemOptionsScreen(),
                      ),
                    );
                  },
                ),

                _buildDrawerItem(
                  icon: Icons.logout,
                  label: 'Cerrar Sesión',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                ),

                Divider(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Versión ${AppConfig.currentAppVersion}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
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
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.onPrimary,
                          ),
                        ),
                      )
                    : Icon(Icons.sync, color: AppColors.onPrimary),
                tooltip: _viewModel.isSyncing
                    ? 'Sincronizando...'
                    : 'Sincronizar datos',
              );
            },
          ),

          _buildPendingDataButton(),
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return PopupMenuButton<String>(
                onSelected: (String value) {
                  switch (value) {
                    case 'probar_conexion':
                      _viewModel.testConnection();
                      break;

                    case 'acerca_de':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AboutScreen()),
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'probar_conexion',
                    enabled:
                        !_viewModel.isTestingConnection &&
                        !_viewModel.isSyncing,
                    child: Row(
                      children: [
                        _viewModel.isTestingConnection
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.success,
                                  ),
                                ),
                              )
                            : Icon(Icons.wifi_find, color: AppColors.success),
                        SizedBox(width: 8),
                        Text(
                          _viewModel.isTestingConnection
                              ? 'Probando...'
                              : 'Probar Conexión',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuItem<String>(
                    value: 'acerca_de',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Acerca de',
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
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.containerBackground, AppColors.background],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ListenableBuilder(
                            listenable: _viewModel,
                            builder: (context, child) {
                              return Row(
                                children: [
                                  if (_viewModel.isLoadingUser) ...[
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Cargando usuario...',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ] else
                                    Expanded(
                                      child: Text(
                                        'Hola, ${_viewModel.userDisplayName}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<Map<String, bool>>(
                      future: _checkNavigationPermissions(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final permissions = snapshot.data ?? {};
                        final canViewClients =
                            permissions[RouteConstants.serverClientes] ?? false;
                        final canViewForms =
                            permissions[RouteConstants.serverFormularios] ??
                            false;

                        // Auto-redirect logic handling could be done here or in initState.
                        // Doing it here risks rebuild loops if not careful.
                        // Better to just render the buttons here.

                        if (!canViewClients && !canViewForms) {
                          return Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.lock_person,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No tienes módulos asignados.",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            if (canViewClients)
                              _buildMenuCard(
                                label: 'Clientes',
                                description: 'Lista de clientes y operaciones',
                                icon: Icons.people,
                                color: AppColors.primary,
                                routeName: '/clienteLista',
                              ),

                            if (canViewClients && canViewForms)
                              SizedBox(height: 16),

                            if (canViewForms)
                              _buildMenuCard(
                                label: 'Formularios Dinámicos',
                                description: 'Completar y enviar formularios',
                                icon: Icons.assignment,
                                color: AppColors.secondary,
                                routeName: '/dynamicForms',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DynamicFormResponsesScreen(),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              if (!_viewModel.isSyncing) return const SizedBox.shrink();
              return _buildSyncOverlay();
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, bool>> _checkNavigationPermissions() async {
    final guard = NavigationGuardService();
    // Desde el Menú (/menu) hacia...
    final canViewClients = await guard.canNavigate(
      currentScreen: RouteConstants.serverMenu,
      targetScreen: RouteConstants.serverClientes,
    );
    final canViewForms = await guard.canNavigate(
      currentScreen: RouteConstants.serverMenu,
      targetScreen: RouteConstants.serverFormularios,
    );

    return {
      RouteConstants.serverClientes: canViewClients,
      RouteConstants.serverFormularios: canViewForms,
    };
  }

  Future<void> _handleRequiredSync(RequiredSyncEvent event) async {
    await _mostrarDialogoSincronizacionObligatoria(event);
  }

  void _redirectToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _mostrarDialogoSincronizacionObligatoria(
    RequiredSyncEvent event,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.sync_problem, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sincronización Requerida',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.validationResult.razon,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _viewModel.cancelAndLogout();
              },
              child: Text(
                'Login',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _viewModel.executeMandatorySync();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Sincronizar'),
            ),
          ],
        );
      },
    );
  }
}
