import 'package:cliente_app/repositories/equipo_repository.dart';
import 'package:flutter/material.dart';
import '../models/equipos.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class EquipoListScreen extends StatefulWidget {
  const EquipoListScreen({super.key});

  @override
  _EquipoListScreenState createState() => _EquipoListScreenState();
}

class _EquipoListScreenState extends State<EquipoListScreen> {
  List<Equipo> equipos = [];
  List<Equipo> equiposFiltrados = [];
  List<Equipo> equiposMostrados = [];
  TextEditingController searchController = TextEditingController();
  EquipoRepository equipoRepository = EquipoRepository();
  bool isLoading = true;

  // Configuración de paginación
  static const int equiposPorPagina = 10;
  int paginaActual = 0;
  bool hayMasDatos = true;
  bool cargandoMas = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
    searchController.addListener(_filtrarEquipos);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarEquipos() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      paginaActual = 0;
      equiposMostrados.clear();
    });

    try {
      final equiposDB = await equipoRepository.buscar('');

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

  Future<void> _sincronizarConAPI() async {
    try {
      logger.i('🔄 Sincronizando equipos con API...');

      final response = await ApiService.obtenerTodosLosEquipos();
      logger.i('📊 Respuesta API: ${response.toString()}');

      if (response.exito && response.equipos.isNotEmpty) {
        await equipoRepository.limpiarYSincronizar(response.equipos);
        logger.i('✅ ${response.equipos.length} equipos sincronizados');
      } else {
        logger.w('⚠️ No se pudieron obtener equipos de la API: ${response.mensaje}');
        throw Exception(response.mensaje);
      }
    } catch (e) {
      logger.e('❌ Error sincronizando con API: $e');
      rethrow;
    }
  }

  Future<void> _refrescarDatos() async {
    try {
      await _sincronizarConAPI();
      await _cargarEquipos();

      if (mounted) {
        _mostrarExito('Datos actualizados correctamente');
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

    final nuevosEquipos = equiposFiltrados.sublist(startIndex, endIndex);

    setState(() {
      equiposMostrados.addAll(nuevosEquipos);
      paginaActual++;
      hayMasDatos = endIndex < equiposFiltrados.length;
      cargandoMas = false;
    });
  }

  void _filtrarEquipos() {
    final query = searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        equiposFiltrados = List.from(equipos);
      } else {
        equiposFiltrados = equipos.where((equipo) {
          return equipo.codBarras.toLowerCase().contains(query) ||
              equipo.marca.toLowerCase().contains(query) ||
              equipo.modelo.toLowerCase().contains(query) ||
              equipo.tipoEquipo.toLowerCase().contains(query);
        }).toList();
      }

      // Reiniciar paginación
      paginaActual = 0;
      equiposMostrados.clear();
      hayMasDatos = equiposFiltrados.length > equiposPorPagina;
    });

    _cargarSiguientePagina();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _cargarSiguientePagina();
    }
  }

  Color _getColorByTipo(String tipoEquipo) {
    final tipo = tipoEquipo.toLowerCase();

    switch (tipo) {
      case 'heladera':
      case 'refrigerador':
      case 'refrigerador no frost':
      case 'refrigerador side by side':
      case 'refrigerador convencional':
      case 'refrigerador inverter':
      case 'refrigerador inteligente':
      case 'refrigerador door-in-door':
      case 'french door':
        return Colors.blue;
      case 'freezer':
      case 'congelador':
      case 'freezer vertical':
      case 'freezer horizontal':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconByTipo(String tipoEquipo) {
    final tipo = tipoEquipo.toLowerCase();

    switch (tipo) {
      case 'heladera':
      case 'refrigerador':
      case 'refrigerador no frost':
      case 'refrigerador side by side':
      case 'refrigerador convencional':
      case 'refrigerador inverter':
      case 'refrigerador inteligente':
      case 'refrigerador door-in-door':
      case 'french door':
        return Icons.kitchen;
      case 'freezer':
      case 'congelador':
      case 'freezer vertical':
      case 'freezer horizontal':
        return Icons.ac_unit;
      default:
        return Icons.devices;
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

  void _mostrarDetallesEquipo(Equipo equipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          equipo.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código: ${equipo.codBarras}'),
            const SizedBox(height: 8),
            Text('Marca: ${equipo.marca}'),
            const SizedBox(height: 8),
            Text('Modelo: ${equipo.modelo}'),
            const SizedBox(height: 8),
            Text('Tipo: ${equipo.tipoEquipo}'),
            const SizedBox(height: 8),
            Text('Estado: ${equipo.estaActivo ? "Activo" : "Inactivo"}'),
            const SizedBox(height: 8),
            Text('Sincronizado: ${equipo.estaSincronizado ? "Sí" : "No"}'),
            const SizedBox(height: 8),
            Text('Fecha creación: ${equipo.fechaCreacion.day}/${equipo.fechaCreacion.month}/${equipo.fechaCreacion.year}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Equipos (${equipos.length})'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        actions: [

        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por código, marca, modelo o tipo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
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

          // Lista de equipos
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEquipoCard(Equipo equipo) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          backgroundColor: _getColorByTipo(equipo.tipoEquipo),
          child: Icon(
            _getIconByTipo(equipo.tipoEquipo),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          equipo.nombreCompleto,
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
              'Tipo: ${equipo.tipoEquipo}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              'Código: ${equipo.codBarras}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              equipo.estaSincronizado ? Icons.cloud_done : Icons.cloud_off,
              color: equipo.estaSincronizado ? Colors.green : Colors.orange,
              size: 16,
            ),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        onTap: () => _mostrarDetallesEquipo(equipo),
      ),
    );
  }
}