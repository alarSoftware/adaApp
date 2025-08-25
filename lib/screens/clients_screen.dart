import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';
import 'cliente_detail_screen.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});
  @override
  _ClienteListScreenState createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  List<Cliente> clientesMostrados = [];
  TextEditingController searchController = TextEditingController();
  final ClienteRepository repo = ClienteRepository();
  bool isLoading = true;

  // Configuración de paginación
  static const int clientesPorPagina = 10;
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
      final clienteRepo = ClienteRepository(); // instancia del repositorio
      List<Cliente> clientesDB = await clienteRepo.buscar(''); // trae todos los clientes activos
      setState(() {
        clientes = clientesDB;
        clientesFiltrados = clientesDB;
        isLoading = false;
      });

      _cargarSiguientePagina();
    } catch (e, stackTrace) {
      logger.e('Error al cargar clientes', error: e, stackTrace: stackTrace);
      setState(() {
        isLoading = false;
      });
      _mostrarError('Error al cargar clientes: $e');
    }
  }

  void _cargarSiguientePagina() {
    if (!hayMasDatos || cargandoMas) return;

    setState(() {
      cargandoMas = true;
    });

    Future.delayed(Duration(milliseconds: 150), () {
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

  void _filtrarClientes() async {
    String query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        clientesFiltrados = clientes;
        paginaActual = 0;
        clientesMostrados.clear();
        hayMasDatos = true;
      });
      _cargarSiguientePagina();
    } else {
      try {
        final clienteRepo = ClienteRepository();
        List<Cliente> resultados = await clienteRepo.buscar(query);
        setState(() {
          clientesFiltrados = resultados;
          paginaActual = 0;
          clientesMostrados.clear();
          hayMasDatos = true;
        });
        _cargarSiguientePagina();
      } catch (e) {
        logger.e('Error en búsqueda: $e');
      }

    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $mensaje'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista de Clientes (${clientesMostrados.length})'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _cargarClientes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[50],
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nombre, email o teléfono...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    _cargarClientes();
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
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
                  CircularProgressIndicator(color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando clientes...',
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
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    searchController.text.isEmpty
                        ? 'No hay clientes'
                        : 'No se encontraron clientes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    searchController.text.isEmpty
                        ? 'No hay clientes registrados en el sistema'
                        : 'con "${searchController.text}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!cargandoMas &&
                    hayMasDatos &&
                    scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _cargarSiguientePagina();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _cargarClientes,
                color: Colors.grey[700],
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: clientesMostrados.length + (hayMasDatos ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == clientesMostrados.length) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.grey[700]),
                        ),
                      );
                    }

                    final cliente = clientesMostrados[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          child: Text(
                            cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          cliente.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cliente.email,
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    cliente.telefono!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
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
    );
  }


  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

