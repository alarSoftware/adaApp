// ui/screens/select_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/screens/equipos_screen.dart';
import 'package:ada_app/ui/screens/modelos_screen.dart';
import 'package:ada_app/ui/screens/logo_screen.dart';
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

  // DIÁLOGOS - EXACTAMENTE IGUALES A LOS ORIGINALES
  Future<bool?> _mostrarDialogoSincronizacion() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sync, color: Colors.grey[700]),
              SizedBox(width: 8),
              Text('Sincronizar Datos'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Esta acción descargará todos los datos del servidor:'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• 👥 Clientes del servidor'),
                    Text('• 🔧 Equipos y refrigeradores'),
                    Text('• 📊 Estados y asignaciones'),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text('Los datos locales serán actualizados.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Sincronizar Todo'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 8),
              Text('Borrar Base de Datos', style: TextStyle(fontSize: 20)),
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
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text('Esta acción borrará TODOS los datos locales:'),
              SizedBox(height: 8),
              Text('• Todos los clientes'),
              Text('• Todos los equipos'),
              Text('• Configuraciones locales'),
              Text('• Datos de sincronización'),
              SizedBox(height: 16),
              Text('¿Estás seguro?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Sí, Borrar Todo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // MENSAJES - EXACTAMENTE IGUALES
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $mensaje'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $mensaje'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // WIDGETS - EXACTAMENTE IGUALES
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
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
          color = Colors.red;
          text = 'Sin Internet';
        } else if (!status.hasApiConnection) {
          icon = Icons.cloud_off;
          color = Colors.orange;
          text = 'API Desconectada';
        } else {
          icon = Icons.cloud_done;
          color = Colors.green;
          text = 'Conectado';
        }

        return Container(
          margin: EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 4),
              Text(text, style: TextStyle(fontSize: 12)),
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
        title: const Text('Panel Principal'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.sync),
                tooltip: _viewModel.isSyncing ? 'Sincronizando...' : 'Sincronizar datos',
              );
            },
          ),

          // Estado de conexión
          _buildConnectionStatus(),

          // Menu de opciones - SIN test API
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
                        Icon(Icons.wifi_find, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Probar Conexión'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'borrar_bd',
                    enabled: !_viewModel.isSyncing,
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Borrar Base de Datos'),
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
              Colors.grey.shade50,
              Colors.white,
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
                            color: Colors.grey[700],
                            routeName: '/clienteLista',
                          ),
                          _buildMenuButton(
                            context,
                            label: 'Equipos',
                            icon: Icons.devices,
                            color: Colors.grey[600],
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
                            color: Colors.grey[600],
                            page: const ModelosScreen(),
                          ),
                          _buildMenuButton(
                            context,
                            label: 'Logos',
                            icon: Icons.newspaper,
                            color: Colors.grey[600],
                            page: const LogosScreen(),
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              icon: Icon(Icons.logout, color: Colors.grey[600]),
              label: Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}