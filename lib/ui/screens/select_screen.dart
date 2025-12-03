import 'package:ada_app/ui/screens/pending_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/ui/widgets/battery_optimization_dialog.dart';
import 'package:ada_app/ui/widgets/app_connection_indicator.dart';
import 'package:ada_app/ui/screens/equipos_screen.dart';
import 'package:ada_app/ui/screens/modelos_screen.dart';
import 'package:ada_app/ui/screens/logo_screen.dart';
import 'package:ada_app/ui/screens/marca_screen.dart';
import 'package:ada_app/viewmodels/select_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/login/sync_progress_widget.dart';
import 'package:ada_app/services/database_validation_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/ui/screens/productos_screen.dart';
import 'dart:async';

class SelectScreen extends StatefulWidget {
  const SelectScreen({super.key});

  @override
  State<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> {
  late SelectScreenViewModel _viewModel;
  late StreamSubscription<UIEvent> _eventSubscription;

  // 🆕 NUEVO: Estado para datos pendientes
  int _pendingDataCount = 0;
  Timer? _pendingDataTimer;

  // ✅ NUEVO: Variable para evitar múltiples verificaciones de batería
  bool _batteryOptimizationChecked = false;

  @override
  void initState() {
    super.initState();
    _viewModel = SelectScreenViewModel();
    _setupEventListener();
    _startPendingDataMonitoring(); // 🆕 NUEVO

    // ✅ NUEVO: Verificar optimización de batería cuando se carga la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBatteryOptimizationOnFirstLoad();
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _pendingDataTimer?.cancel(); // 🆕 NUEVO
    _viewModel.dispose();
    super.dispose();
  }

  // 🆕 NUEVO: Monitoreo de datos pendientes
  void _startPendingDataMonitoring() {
    // _pendingDataTimer = Timer.periodic(
    //   Duration(minutes: 2),
    //       (_) => _checkPendingData(),
    // );
    _checkPendingData();
  }

  // 🆕 NUEVO: Verificar datos pendientes
  // 🆕 NUEVO: Verificar datos pendientes (CORREGIDO)
  Future<void> _checkPendingData() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 🔥 CONTAR SOLO CENSOS ACTIVOS NO SINCRONIZADOS
      final censosPendientes = await db.query(
        'censo_activo',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );

      final cantidadCensos = censosPendientes.length;

      // 🔥 CONTAR OTROS DATOS PENDIENTES (excluyendo tablas relacionadas con censos)
      final validationService = DatabaseValidationService(db);
      final summary = await validationService.getPendingSyncSummary();
      final pendingByTable =
          summary['pending_by_table'] as List<dynamic>? ?? [];

      // Tablas que se excluyen del conteo (ya están incluidas en censos)
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

      // Total: censos + otros datos
      final totalPendientes = cantidadCensos + otrosDatos;

      if (mounted) {
        setState(() {
          _pendingDataCount = totalPendientes;
        });
      }

      debugPrint(
        '📊 Datos pendientes: $totalPendientes (Censos: $cantidadCensos, Otros: $otrosDatos)',
      );
    } catch (e) {
      debugPrint('❌ Error verificando datos pendientes: $e');
      // Silently ignore errors for background check
    }
  }

  // ✅ NUEVO: Verificar optimización de batería en el primer acceso
  Future<void> _checkBatteryOptimizationOnFirstLoad() async {
    // Evitar múltiples verificaciones
    if (_batteryOptimizationChecked) return;
    _batteryOptimizationChecked = true;

    try {
      debugPrint('🔋 INICIANDO verificación de batería en SelectScreen...');
      await BatteryOptimizationDialog.checkAndRequestBatteryOptimization(
        context,
      );
      debugPrint('🔋 ✅ COMPLETADO verificación de batería en SelectScreen');
    } catch (e) {
      debugPrint(
        '🔋 ❌ ERROR verificando optimización de batería en SelectScreen: $e',
      );
    }
  }

  // ✅ NUEVO: Método para manejar logout correctamente
  Future<void> _handleLogout() async {
    try {
      // Mostrar indicador de carga
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

      // Hacer logout
      await AuthService().logout();

      // Cerrar diálogo de carga
      if (mounted) Navigator.of(context).pop();

      // Navegar a login y limpiar stack completo
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false, // Elimina TODAS las pantallas anteriores
        );
      }
    } catch (e) {
      // Cerrar diálogo si está abierto
      if (mounted) Navigator.of(context).pop();

      _mostrarError('Error al cerrar sesión: $e');
    }
  }

  // 🆕 NUEVO: Botón de campanita con badge
  Widget _buildPendingDataButton() {
    return Stack(
      children: [
        IconButton(
          onPressed: () async {
            // Navegar a la pantalla de datos pendientes
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PendingDataScreen()),
            );
            // Refrescar contador después de volver
            // _checkPendingData();
          },
          icon: Icon(Icons.notifications, color: AppColors.onPrimary),
          tooltip: 'Datos pendientes de envío',
        ),
        // Badge con contador
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
        // 🆕 NUEVO: Refrescar contador después de sync exitoso
        // _checkPendingData();
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
        // 🆕 NUEVO: Refrescar contador después de sync
        // _checkPendingData();
      } else if (event is SyncErrorEvent) {
        // 🆕 NUEVO: Mostrar diálogo de error de sincronización
        _mostrarDialogoErrorSync(event);
      }
    });
  }

  // 🆕 NUEVO: Diálogo para mostrar errores de sincronización
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
                  '❌ Error de Sincronización',
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
                // Mensaje principal
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

                // Detalles técnicos si existen
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

                // Recomendaciones
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
                _viewModel.requestSync(); // Reintentar sincronización
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

  // 🆕 NUEVO: Widget helper para recomendaciones
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
                  '⚠️ No se puede eliminar',
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
            // NUEVO: Botón para ir a datos pendientes
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PendingDataScreen()),
                );
                // _checkPendingData();
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

  Widget _buildMenuCard({
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    String? routeName,
    Widget? page,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            onTap ??
            () {
              if (routeName != null) {
                Navigator.pushNamed(context, routeName);
              } else if (page != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => page),
                );
              }
            },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: color, size: 28),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
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
          // Botón de sincronización
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
          // 🆕 NUEVO: Botón de campanita para datos pendientes
          _buildPendingDataButton(),
          // Indicador de conexión
          _buildConnectionStatus(),
          // Menú de opciones
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
                    value: 'borrar_bd',
                    enabled:
                        !_viewModel.isSyncing &&
                        !_viewModel.isTestingConnection,
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
                  // Header con nombre de usuario
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                      elevation: 2,
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
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
                                  Text(
                                    'Hola, ${_viewModel.userDisplayName}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Lista de opciones
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildMenuCard(
                          label: 'Clientes',
                          description: 'Lista de clientes',
                          icon: Icons.people,
                          color: AppColors.primary,
                          routeName: '/clienteLista',
                        ),
                        SizedBox(height: 12),
                        _buildMenuCard(
                          label: 'Equipos',
                          description: 'Lista de equipos de frío',
                          icon: Icons.kitchen,
                          color: AppColors.primary,
                          page: const EquipoListScreen(),
                        ),
                        SizedBox(height: 12),
                        _buildMenuCard(
                          label: 'Modelos',
                          description: 'Catálogo de modelos de equipos',
                          icon: Icons.branding_watermark,
                          color: AppColors.primary,
                          page: const ModelosScreen(),
                        ),
                        SizedBox(height: 12),
                        _buildMenuCard(
                          label: 'Logos',
                          description: 'Lista de los logos de la empresa',
                          icon: Icons.newspaper,
                          color: AppColors.primary,
                          page: const LogosScreen(),
                        ),
                        SizedBox(height: 12),
                        _buildMenuCard(
                          label: 'Marcas',
                          description: 'Lista de las Marcas',
                          icon: Icons.domain,
                          color: AppColors.primary,
                          page: const MarcaScreen(),
                        ),
                        _buildMenuCard(
                          label: 'Productos',
                          description: 'Catálogo completo de productos',
                          icon: Icons.inventory_2,
                          color: AppColors.primary,
                          page: const ProductosScreen(),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // ✅ BOTÓN DE CERRAR SESIÓN CORREGIDO
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton.icon(
                      onPressed: _handleLogout, // ✅ Usar el método correcto
                      icon: Icon(Icons.logout, color: AppColors.textSecondary),
                      label: Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Overlay de sincronización mejorado con progreso
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
