import 'package:cliente_app/repositories/equipo_repository.dart';
import 'package:flutter/material.dart';
import '../models/equipos.dart';
import '../services/sync_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';

var logger = Logger();

class EquipoListScreen extends StatefulWidget {
  const EquipoListScreen({super.key});

  @override
  _EquipoListScreenState createState() => _EquipoListScreenState();
}

class _EquipoListScreenState extends State<EquipoListScreen> {
  List<Map<String, dynamic>> equipos = [];
  List<Map<String, dynamic>> equiposFiltrados = [];
  List<Map<String, dynamic>> equiposMostrados = [];
  TextEditingController searchController = TextEditingController();
  EquipoRepository equipoRepository = EquipoRepository();
  bool isLoading = true;

  static const int equiposPorPagina = 10;
  int paginaActual = 0;
  bool hayMasDatos = true;
  bool cargandoMas = false;

  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _filtrarEquipos();
    });
  }

  Future<void> _cargarEquipos() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      paginaActual = 0;
      equiposMostrados.clear();
    });

    try {
      final equiposDB = await equipoRepository.obtenerCompletos(soloActivos: true);

      if (!mounted) return;

      setState(() {
        equipos = equiposDB;
        equiposFiltrados = equiposDB;
        isLoading = false;
        hayMasDatos = equiposFiltrados.length > equiposPorPagina;
      });

      _cargarSiguientePagina();

    } catch (e) {
      logger.e('Error cargando equipos: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _mostrarError('Error cargando equipos: $e');
    }
  }

  Future<void> _refrescarDatos() async {
    try {
      final resultado = await SyncService.sincronizarEquipos();

      if (resultado.exito) {
        await _cargarEquipos();
        if (mounted) {
          _mostrarExito('Equipos actualizados: ${resultado.itemsSincronizados}');
        }
      } else {
        throw Exception(resultado.mensaje);
      }
    } catch (e) {
      logger.e('Error refrescando datos: $e');
      if (mounted) {
        _mostrarError('Error al actualizar: $e');
      }
    }
  }

  void _cargarSiguientePagina() {
    if (cargandoMas || !hayMasDatos) return;

    setState(() {
      cargandoMas = true;
    });

    final startIndex = paginaActual * equiposPorPagina;
    final endIndex = (startIndex + equiposPorPagina).clamp(0, equiposFiltrados.length);

    if (startIndex < equiposFiltrados.length) {
      final nuevosEquipos = equiposFiltrados.sublist(startIndex, endIndex);

      setState(() {
        equiposMostrados.addAll(nuevosEquipos);
        paginaActual++;
        hayMasDatos = endIndex < equiposFiltrados.length;
        cargandoMas = false;
      });
    } else {
      setState(() {
        hayMasDatos = false;
        cargandoMas = false;
      });
    }
  }

  void _filtrarEquipos() {
    if (!mounted) return;

    final query = searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        equiposFiltrados = List.from(equipos);
      } else {
        equiposFiltrados = equipos.where((equipo) {
          final codBarras = equipo['cod_barras']?.toString().toLowerCase() ?? '';
          final marcaNombre = equipo['marca_nombre']?.toString().toLowerCase() ?? '';
          final modelo = equipo['modelo']?.toString().toLowerCase() ?? '';
          final logoNombre = equipo['logo_nombre']?.toString().toLowerCase() ?? '';

          return codBarras.contains(query) ||
              marcaNombre.contains(query) ||
              modelo.contains(query) ||
              logoNombre.contains(query);
        }).toList();
      }

      paginaActual = 0;
      equiposMostrados.clear();
      hayMasDatos = equiposFiltrados.isNotEmpty;
    });

    _cargarSiguientePagina();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cargarSiguientePagina();
    }
  }

  Color _getColorByLogo(String? logoNombre) {
    if (logoNombre == null) return Colors.grey;

    final logo = logoNombre.toLowerCase();

    switch (logo) {
      case 'pepsi':
        return Colors.blue;
      case 'pulp':
        return Colors.orange;
      case 'paso de los toros':
        return Colors.green;
      case 'mirinda':
        return Colors.deepOrange;
      case '7up':
        return Colors.lightGreen;
      case 'gatorade':
        return Colors.blue[800]!;
      case 'red bull':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getIconByLogo(String? logoNombre) {
    if (logoNombre == null) return Icons.kitchen;

    final logo = logoNombre.toLowerCase();

    switch (logo) {
      case 'pepsi':
      case 'mirinda':
      case '7up':
      case 'paso de los toros':
        return Icons.local_drink;
      case 'gatorade':
      case 'red bull':
        return Icons.sports_bar;
      case 'aquafina':
      case 'puro sol':
        return Icons.water_drop;
      default:
        return Icons.kitchen;
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarDetallesEquipo(Map<String, dynamic> equipo) {
    final marcaNombre = equipo['marca_nombre'] ?? 'Sin marca';
    final modelo = equipo['modelo'] ?? 'Sin modelo';
    final nombreCompleto = '$marcaNombre $modelo';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetalleRow('Código', equipo['cod_barras'] ?? 'N/A'),
            _buildDetalleRow('Marca', marcaNombre),
            _buildDetalleRow('Modelo', modelo),
            _buildDetalleRow('Logo', equipo['logo_nombre'] ?? 'Sin logo'),
            if (equipo['numero_serie'] != null)
              _buildDetalleRow('Número de Serie', equipo['numero_serie']),
            _buildDetalleRow('Estado Local', (equipo['estado_local'] == 1) ? "Activo" : "Inactivo"),
            _buildDetalleRow('Estado Asignación', equipo['estado_asignacion'] ?? 'Disponible'),
            if (equipo['cliente_nombre'] != null)
              _buildDetalleRow('Asignado a', equipo['cliente_nombre']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Equipos (${equiposFiltrados.length}/${equipos.length})'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refrescarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar equipos',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por código, marca, modelo o logo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    _filtrarEquipos();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando equipos...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : equiposMostrados.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _refrescarDatos,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: equiposMostrados.length + (cargandoMas ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == equiposMostrados.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return _buildEquipoCard(equiposMostrados[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = searchController.text.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.devices,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No se encontraron equipos\ncon "${searchController.text}"'
                : 'No hay equipos disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refrescarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar equipos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    final marcaNombre = equipo['marca_nombre'] ?? 'Sin marca';
    final modelo = equipo['modelo'] ?? 'Sin modelo';
    final nombreCompleto = '$marcaNombre $modelo';
    final logoNombre = equipo['logo_nombre'];
    final estadoAsignacion = equipo['estado_asignacion'] ?? 'Disponible';
    final clienteNombre = equipo['cliente_nombre'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          backgroundColor: _getColorByLogo(logoNombre),
          child: Icon(
            _getIconByLogo(logoNombre),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          nombreCompleto,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Logo: ${logoNombre ?? 'Sin logo'}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              'Código: ${equipo['cod_barras'] ?? 'N/A'}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            if (equipo['numero_serie'] != null)
              Text(
                'Serie: ${equipo['numero_serie']}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: estadoAsignacion == 'Disponible' ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estadoAsignacion,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (clienteNombre != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    clienteNombre,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => _mostrarDetallesEquipo(equipo),
      ),
    );
  }
}