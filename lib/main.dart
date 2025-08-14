import 'package:flutter/material.dart';
import 'models/cliente.dart';
import 'services/database_helper.dart';
import 'services/sync_service.dart';

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
    } catch (e) {
      print('Error al cargar clientes: $e');
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
          // Menú de opciones (solo opciones de visualización)
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'probar_conexion') {
                _probarConexion();
              } else if (value == 'recargar_local') {
                _cargarClientes();
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

// Nueva pantalla de detalle de cliente (solo lectura)
class ClienteDetailScreen extends StatelessWidget {
  final Cliente cliente;

  const ClienteDetailScreen({
    Key? key,
    required this.cliente,
  }) : super(key:key);



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Cliente'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
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
          ],
        ),
      ),
    );
  }

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