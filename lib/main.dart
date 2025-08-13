import 'package:flutter/material.dart';
import 'models/cliente.dart';
import 'services/database_helper.dart';

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
  TextEditingController searchController = TextEditingController();
  DatabaseHelper dbHelper = DatabaseHelper();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    searchController.addListener(_filtrarClientes);
  }

  Future<void> _cargarClientes() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Cliente> clientesDB = await dbHelper.obtenerTodosLosClientes();
      setState(() {
        clientes = clientesDB;
        clientesFiltrados = clientesDB;
        isLoading = false;
      });
    } catch (e) {
      print('Error al cargar clientes: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filtrarClientes() async {
    String query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        clientesFiltrados = clientes;
      });
    } else {
      try {
        List<Cliente> resultados = await dbHelper.buscarClientes(query);
        setState(() {
          clientesFiltrados = resultados;
        });
      } catch (e) {
        print('Error en búsqueda: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista de Clientes'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarClientes,
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
              ),
            ),
          ),
          // Lista de clientes
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : clientesFiltrados.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No se encontraron clientes',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: clientesFiltrados.length,
              itemBuilder: (context, index) {
                final cliente = clientesFiltrados[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(cliente.nombre[0]),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    title: Text(cliente.nombre),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cliente.email),
                        if (cliente.telefono != null)
                          Text(cliente.telefono!,
                              style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      // Navegar a detalle del cliente
                      final resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClienteFormScreen(cliente: cliente),
                        ),
                      );

                      // Si se modificó algo, recargar la lista
                      if (resultado == true) {
                        _cargarClientes();
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Agregar nuevo cliente
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClienteFormScreen(),
            ),
          );

          // Si se agregó un cliente, recargar la lista
          if (resultado == true) {
            _cargarClientes();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// Pantalla de formulario de cliente
class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;

  ClienteFormScreen({this.cliente});

  @override
  _ClienteFormScreenState createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  DatabaseHelper dbHelper = DatabaseHelper();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.cliente != null) {
      _nombreController.text = widget.cliente!.nombre;
      _emailController.text = widget.cliente!.email;
      _telefonoController.text = widget.cliente!.telefono ?? '';
      _direccionController.text = widget.cliente!.direccion ?? '';
    }
  }

  Future<void> _guardarCliente() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      try {
        Cliente cliente = Cliente(
          id: widget.cliente?.id,
          nombre: _nombreController.text.trim(),
          email: _emailController.text.trim(),
          telefono: _telefonoController.text.trim().isEmpty
              ? null
              : _telefonoController.text.trim(),
          direccion: _direccionController.text.trim().isEmpty
              ? null
              : _direccionController.text.trim(),
        );

        if (widget.cliente != null) {
          // Actualizar cliente existente
          await dbHelper.actualizarCliente(cliente);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Insertar nuevo cliente
          await dbHelper.insertarCliente(cliente);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente agregado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }

        Navigator.pop(context, true); // Retorna true para indicar que se guardó

      } catch (e) {
        print('Error al guardar cliente: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar cliente'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _enviarAEDP() async {
    if (_formKey.currentState!.validate()) {
      // Crear cliente temporal para generar JSON
      Cliente clienteTemp = Cliente(
        id: widget.cliente?.id ?? DateTime.now().millisecondsSinceEpoch,
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        direccion: _direccionController.text.trim().isEmpty
            ? null
            : _direccionController.text.trim(),
      );

      // Generar JSON
      Map<String, dynamic> json = clienteTemp.toJson();
      print('JSON para EDP: $json');

      // Aquí irá la lógica para enviar al EDP
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON generado (revisar consola)'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cliente != null ? 'Editar Cliente' : 'Nuevo Cliente'),
        backgroundColor: Colors.blue,
        actions: [
          if (widget.cliente != null)
            IconButton(
              icon: Icon(Icons.send),
              onPressed: isLoading ? null : _enviarAEDP,
              tooltip: 'Enviar JSON al EDP',
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre completo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el email';
                  }
                  if (!value.contains('@')) {
                    return 'Ingresa un email válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _telefonoController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _direccionController,
                decoration: InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _guardarCliente,
                      child: Text(widget.cliente != null ? 'Actualizar' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (widget.cliente != null) ...[
                    SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : _enviarAEDP,
                        child: Text('Enviar a EDP'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          side: BorderSide(color: Colors.orange),
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}