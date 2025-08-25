import 'package:cliente_app/repositories/cliente_repository.dart';
import 'package:cliente_app/repositories/equipo_repository.dart';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import 'package:logger/logger.dart';
import 'equipos_screen.dart';

var logger = Logger();

class SelectScreen extends StatefulWidget {
  const SelectScreen({super.key});

  @override
  _SelectScreenState createState() => _SelectScreenState();
}

class _SelectScreenState extends State<SelectScreen> {
  bool isSyncing = false;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _verificarConexion();
  }

  Future<void> _verificarConexion() async {
    try {
      final conexion = await SyncService.probarConexion();
      setState(() {
        isConnected = conexion.exito;
      });
    } catch (e) {
      logger.e('Error verificando conexión: $e');
    }
  }

  Future<void> _sincronizarConAPI() async {
    if (isSyncing) return;

    setState(() {
      isSyncing = true;
    });

    try {
      final conexion = await SyncService.probarConexion();
      if (!conexion.exito) {
        _mostrarError('Sin conexión al servidor: ${conexion.mensaje}');
        return;
      }

      bool? confirmar = await _mostrarDialogoSincronizacion();
      if (confirmar != true) return;

      // Usar el método unificado
      final resultado = await SyncService.sincronizarTodosLosDatos();

      if (resultado.exito) {
        String mensaje = 'Sincronización completada';
        if (resultado.clientesSincronizados > 0 || resultado.equiposSincronizados > 0) {
          mensaje += '\n• Clientes: ${resultado.clientesSincronizados}';
          mensaje += '\n• Equipos: ${resultado.equiposSincronizados}';
        }
        _mostrarExito(mensaje);
        await _verificarConexion(); // Actualizar estado de conexión
      } else {
        _mostrarError('Error en sincronización: ${resultado.mensaje}');
      }
    } catch (e) {
      _mostrarError('Error inesperado: $e');
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> _testAPI() async {
    setState(() {
      isSyncing = true;
    });

    try {
      logger.i('🔍 INICIANDO TEST DE CLIENTES...');

      final resultado = await ApiService.obtenerTodosLosClientes();

      logger.i('🔍 RESULTADO:');
      logger.i('Éxito: ${resultado.exito}');
      logger.i('Total clientes: ${resultado.clientes.length}');
      logger.i('Mensaje: ${resultado.mensaje}');

      for (int i = 0; i < resultado.clientes.length && i < 5; i++) {
        logger.i('Cliente ${i + 1}: ${resultado.clientes[i].nombre}');
      }

      _mostrarExito('Test completado: ${resultado.clientes.length} clientes recibidos');
    } catch (e) {
      logger.e('❌ Error en test: $e');
      _mostrarError('Error en test: $e');
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

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

  Future<void> _probarConexion() async {
    setState(() {
      isSyncing = true;
    });

    try {
      final response = await SyncService.probarConexion();

      if (response.exito) {
        _mostrarExito(response.mensaje);
        setState(() {
          isConnected = true;
        });
      } else {
        _mostrarError(response.mensaje);
        setState(() {
          isConnected = false;
        });
      }
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> _borrarBaseDeDatos() async {
    bool? confirmar = await _mostrarDialogoBorrarBD();
    if (confirmar != true) return;

    setState(() {
      isSyncing = true;
    });

    try {
      final clienteRepo = ClienteRepository();
      final equipoRepo = EquipoRepository();

      // Usar el nuevo método que borra todo
      await clienteRepo.limpiarYSincronizar([]); // lista vacía borra todo
      await equipoRepo.limpiarYSincronizar([]);

      _mostrarExito('Base de datos completa borrada correctamente\\n• Clientes eliminados\\n• Equipos eliminados\\n• Todos los datos borrados');

    } catch (e) {
      _mostrarError('Error al borrar la base de datos: $e');
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
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
              Text('Borrar Base de Datos',
                style: TextStyle(fontSize: 20),),
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

  // MÉTODO MOVIDO FUERA DEL BUILD - AQUÍ ES DONDE DEBE ESTAR
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
            Icon(
              icon,
              size: 40,
              color: color,
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        actions: [
          // Botón de sync pequeño
          IconButton(
            onPressed: isSyncing ? null : _sincronizarConAPI,
            icon: isSyncing
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(Icons.sync),
            tooltip: isSyncing ? 'Sincronizando...' : 'Sincronizar datos',
          ),

          // Indicador de conexión
          Container(
            margin: EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  isConnected ? 'Conectado' : 'Desconectado',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          // Menú de 3 puntos
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'probar_conexion':
                  _probarConexion();
                  break;
                case 'test_api':
                  _testAPI();
                  break;
                case 'borrar_bd':
                  _borrarBaseDeDatos();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'probar_conexion',
                enabled: !isSyncing,
                child: Row(
                  children: [
                    Icon(Icons.wifi_find, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Probar Conexión'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'test_api',
                enabled: !isSyncing,
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Test API Clientes'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'borrar_bd',
                enabled: !isSyncing,
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Borrar Base de Datos'),
                  ],
                ),
              ),
            ],
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

                  // Botones de navegación principales
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
                            label: 'Marcas',
                            icon: Icons.branding_watermark,
                            color: Colors.grey[600],
                            onTap: () {
                              // TODO: Navegar a pantalla de marcas
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Pantalla de marcas próximamente')),
                              );
                            },
                          ),
                          _buildMenuButton(
                            context,
                            label: 'Logos',
                            icon: Icons.newspaper,
                            color: Colors.grey[600],
                            onTap: () {
                              // TODO: Navegar a pantalla de logos
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Pantalla de logos próximamente')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  )

                ],
              ),
            ),

            // Botón de logout
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