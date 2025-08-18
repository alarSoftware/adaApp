import 'package:flutter/material.dart';
import 'models/cliente.dart';
import 'services/database_helper.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cliente App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ClienteListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Pantalla principal - Lista de clientes
class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});
  @override
  _ClienteListScreenState createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  List<Cliente> clientesMostrados = []; // Nueva lista para paginación
  TextEditingController searchController = TextEditingController();
  DatabaseHelper dbHelper = DatabaseHelper();
  bool isLoading = true;
  bool isSyncing = false;

  // Configuración de paginación
  static const int clientesPorPagina = 5;
  int paginaActual = 0;
  bool hayMasDatos = true;
  bool cargandoMas = false;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    searchController.addListener(_filtrarClientes);
  }

  Future<void> _cargarClientes() async {
    setState(() {
      isLoading = true;
      paginaActual = 0;
      clientesMostrados.clear();
    });

    try {
      List<Cliente> clientesDB = await dbHelper.obtenerTodosLosClientes();
      setState(() {
        clientes = clientesDB;
        clientesFiltrados = clientesDB;
        isLoading = false;
      });

      // Cargar primera página
      _cargarSiguientePagina();
    } catch (e, stackTrace) {
      logger.e('Error al cargar clientes', error: e, stackTrace: stackTrace);
      setState(() {
        isLoading = false;
      });
    }
  }

  // Nueva función para cargar páginas
  void _cargarSiguientePagina() {
    if (!hayMasDatos || cargandoMas) return;

    setState(() {
      cargandoMas = true;
    });

    // Simular delay para mejor UX
    Future.delayed(Duration(milliseconds: 300), () {
      int inicio = paginaActual * clientesPorPagina;
      int fin = inicio + clientesPorPagina;

      if (inicio < clientesFiltrados.length) {
        List<Cliente> nuevosClientes = clientesFiltrados
            .skip(inicio)
            .take(clientesPorPagina)
            .toList();

        setState(() {
          clientesMostrados.addAll(nuevosClientes);
          paginaActual++;
          hayMasDatos = fin < clientesFiltrados.length;
          cargandoMas = false;
        });
      } else {
        setState(() {
          hayMasDatos = false;
          cargandoMas = false;
        });
      }
    });
  }

  // Método de sincronización con la API
  Future<void> _sincronizarConAPI() async {
    setState(() {
      isSyncing = true;
    });

    try {
      // Probar conexión primero
      final conexion = await SyncService.probarConexion();
      if (!conexion.exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sin conexión al servidor: ${conexion.mensaje}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Mostrar diálogo de confirmación
      bool? confirmar = await _mostrarDialogoSincronizacion();
      if (confirmar != true) return;

      // Sincronizar datos
      final resultado = await SyncService.sincronizarConAPI();

      if (resultado.exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sincronización exitosa: ${resultado.clientesSincronizados} clientes descargados'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Recargar datos locales después de la sincronización
        await _cargarClientes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en sincronización: ${resultado.mensaje}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  // Diálogo de confirmación para sincronización
  Future<bool?> _mostrarDialogoSincronizacion() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sync, color: Colors.blue),
              SizedBox(width: 8),
              Text('Sincronizar'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Esta acción:'),
              SizedBox(height: 8),
              Text('• Descargará todos los clientes del servidor'),
              Text('• Reemplazará los datos locales actuales'),
              Text('• Puede tomar algunos segundos'),
              SizedBox(height: 16),
              Text('¿Estás seguro de continuar?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Sincronizar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        );
      },
    );
  }

  // NUEVO: Método para borrar la base de datos local
  Future<void> _borrarBaseDeDatos() async {
    // Mostrar diálogo de confirmación
    bool? confirmar = await _mostrarDialogoBorrarBD();
    if (confirmar != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Borrar todos los datos de la base de datos
      await dbHelper.borrarTodosLosClientes();

      // Limpiar las listas en memoria
      setState(() {
        clientes.clear();
        clientesFiltrados.clear();
        clientesMostrados.clear();
        paginaActual = 0;
        hayMasDatos = true;
        isLoading = false;
      });

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('🗑️ Base de datos borrada correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al borrar la base de datos: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // NUEVO: Diálogo de confirmación para borrar la BD
  Future<bool?> _mostrarDialogoBorrarBD() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 2.5),
              Text('Borrar Base de Datos',
              style: TextStyle(
                fontSize: 20
              ),),
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
              Text('Esta acción:'),
              SizedBox(height: 8),
              Text('• Borrará TODOS los clientes de la base de datos local'),
              Text('• NO se puede deshacer'),
              Text('• Los datos del servidor NO se verán afectados'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'Clientes actuales: ${clientes.length}\nTodos serán eliminados permanentemente.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[700],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                '¿Estás completamente seguro?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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

  void _filtrarClientes() async {
    String query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        clientesFiltrados = clientes;
        // Resetear paginación
        paginaActual = 0;
        clientesMostrados.clear();
        hayMasDatos = true;
      });
      _cargarSiguientePagina();
    } else {
      try {
        List<Cliente> resultados = await dbHelper.buscarClientes(query);
        setState(() {
          clientesFiltrados = resultados;
          // Resetear paginación para búsqueda
          paginaActual = 0;
          clientesMostrados.clear();
          hayMasDatos = true;
        });
        _cargarSiguientePagina();
      } catch (e) {
        print('Error en búsqueda: $e');
      }
    }
  }

  Future<void> _probarConexion() async {
    setState(() {
      isLoading = true;
    });

    try {
      ApiResponse response = await SyncService.probarConexion();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.mensaje),
          backgroundColor: response.exito ? Colors.green : Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clientes (${clientesMostrados.length}/${clientesFiltrados.length})'),
        backgroundColor: Colors.blue,
        actions: [
          // BOTÓN DE SINCRONIZACIÓN
          IconButton(
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
            onPressed: isSyncing ? null : _sincronizarConAPI,
            tooltip: 'Sincronizar con servidor',
          ),
          // Menú de opciones (ACTUALIZADO con opción de borrar BD)
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'probar_conexion') {
                _probarConexion();
              } else if (value == 'recargar_local') {
                _cargarClientes();
              } else if (value == 'borrar_bd') {
                _borrarBaseDeDatos();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'recargar_local',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Recargar datos locales'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'probar_conexion',
                child: Row(
                  children: [
                    Icon(Icons.wifi_find, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Probar conexión'),
                  ],
                ),
              ),
              PopupMenuDivider(), // SEPARADOR
              PopupMenuItem<String>(
                value: 'borrar_bd',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Borrar base de datos', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    _cargarClientes();
                  },
                  icon: Icon(Icons.clear),
                )
                    : null,
              ),
            ),
          ),
          // Lista de clientes
          Expanded(
            child: isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    isSyncing ? 'Sincronizando con servidor...' : 'Cargando...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : clientesMostrados.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    searchController.text.isEmpty
                        ? 'No hay clientes\nPresiona el botón de sincronizar (↻) para descargar datos del servidor'
                        : 'No se encontraron clientes con "${searchController.text}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  if (searchController.text.isEmpty) ...[
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isSyncing ? null : _sincronizarConAPI,
                      icon: Icon(Icons.sync),
                      label: Text('Sincronizar ahora'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                  ],
                ],
              ),
            )
                : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // Cargar más datos cuando se acerque al final
                if (!cargandoMas &&
                    hayMasDatos &&
                    scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _cargarSiguientePagina();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _cargarClientes,
                child: ListView.builder(
                  itemCount: clientesMostrados.length + (hayMasDatos ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Mostrar indicador de carga al final
                    if (index == clientesMostrados.length) {
                      return Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final cliente = clientesMostrados[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: CircleAvatar(
                          radius: 20,
                          child: Text(
                            cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 16),
                          ),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        title: Text(
                          cliente.nombre,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cliente.email,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(fontSize: 14),
                              ),
                              if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    cliente.telefono!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClienteDetailScreen(cliente: cliente),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      // Removido el FloatingActionButton para agregar clientes
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// Nueva pantalla de detalle de cliente (solo lectura) - CON ENVÍO POST
class ClienteDetailScreen extends StatelessWidget {
  final Cliente cliente;

  const ClienteDetailScreen({
    Key? key,
    required this.cliente,
  }) : super(key: key);

  // Método para enviar todos los datos del cliente al servidor
  void _enviarTodosLosDatos(BuildContext context) async {
    // Mostrar diálogo de confirmación con preview de los datos
    bool? confirmar = await _mostrarDialogoConfirmacion(context);
    if (confirmar != true) return;

    // Ejecutar el envío
    await _ejecutarEnvio(context);
  }

  // Diálogo de confirmación antes del envío
  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) async {
    String datosCompletos = '''
Datos del Cliente:
━━━━━━━━━━━━━━━━
Nombre: ${cliente.nombre}
Email: ${cliente.email}
${cliente.telefono?.isNotEmpty == true ? 'Teléfono: ${cliente.telefono}\n' : ''}${cliente.direccion?.isNotEmpty == true ? 'Dirección: ${cliente.direccion}\n' : ''}${cliente.id != null ? 'ID: ${cliente.id}' : ''}
    '''.trim();

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.send, color: Colors.blue),
              SizedBox(width: 8),
              Text('Enviar datos'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se enviarán los siguientes datos al servidor:'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  datosCompletos,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '• Endpoint: POST /clientes\n• Servidor: 192.168.1.185:3000',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Enviar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        );
      },
    );
  }

  // Método que ejecuta el envío real al servidor Node.js
  Future<void> _ejecutarEnvio(BuildContext context) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Enviando datos...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Usar el servicio de sincronización para enviar el cliente
      final resultado = await SyncService.enviarClienteAAPI(cliente);

      // Cerrar el diálogo de carga
      Navigator.of(context).pop();

      if (resultado.exito) {
        // Envío exitoso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('✅ Datos enviados correctamente al servidor'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Ver detalles',
              textColor: Colors.white,
              onPressed: () => _mostrarDetallesEnvio(context, resultado),
            ),
          ),
        );
      } else {
        // Error en el envío
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('❌ Error: ${resultado.mensaje}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _ejecutarEnvio(context),
            ),
          ),
        );
      }

    } catch (e) {
      // Cerrar el diálogo de carga si está abierto
      Navigator.of(context).pop();

      // Mostrar error inesperado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error inesperado: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Mostrar detalles del envío exitoso
  void _mostrarDetallesEnvio(BuildContext context, ApiResponse resultado) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Detalles del envío'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Estado: Enviado correctamente'),
              SizedBox(height: 8),
              Text('📤 Cliente: ${cliente.nombre}'),
              Text('📧 Email: ${cliente.email}'),
              if (cliente.id != null) Text('🆔 ID: ${cliente.id}'),
              SizedBox(height: 12),
              Text('🕒 Enviado: ${DateTime.now().toString().substring(0, 19)}'),
              if (resultado.datos != null) ...[
                SizedBox(height: 8),
                Text('📋 Respuesta del servidor:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    resultado.datos.toString(),
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Cliente'),
        backgroundColor: Colors.blue,
        actions: [
          // Botón rápido de envío en el AppBar
          IconButton(
            onPressed: () => _enviarTodosLosDatos(context),
            icon: Icon(Icons.send),
            tooltip: 'Enviar datos al servidor',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar y nombre principal
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    child: Text(
                      cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 32),
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      cliente.nombre,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Información del cliente en cards
            _buildInfoCard(
              icon: Icons.email,
              title: 'Email',
              content: cliente.email,
              color: Colors.red,
            ),

            if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
              _buildInfoCard(
                icon: Icons.phone,
                title: 'Teléfono',
                content: cliente.telefono!,
                color: Colors.green,
              ),

            if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
              _buildInfoCard(
                icon: Icons.location_on,
                title: 'Dirección',
                content: cliente.direccion!,
                color: Colors.orange,
              ),

            if (cliente.id != null)
              _buildInfoCard(
                icon: Icons.tag,
                title: 'ID',
                content: cliente.id.toString(),
                color: Colors.grey,
              ),

            // Información técnica
            _buildInfoCard(
              icon: Icons.access_time,
              title: 'Fecha de creación',
              content: cliente.fechaCreacion.toString().substring(0, 19),
              color: Colors.purple,
            ),

            // Espacio adicional
            SizedBox(height: 32),

            // Botón principal para enviar todos los datos
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _enviarTodosLosDatos(context),
                icon: Icon(Icons.send),
                label: Text('Enviar al servidor Node.js'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Información sobre el servidor
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Información del servidor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Servidor: http://192.168.1.185:3000\n• Endpoint: POST /clientes\n• Los datos se enviarán en formato JSON',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Espacio adicional al final para mejor UX
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Método para construir las cards de información
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}