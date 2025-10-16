import 'package:flutter/material.dart';
import 'package:ada_app/repositories/models_repository.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class ModelosScreen extends StatefulWidget {
  const ModelosScreen({super.key});

  @override
  State<ModelosScreen> createState() => _ModelosScreenState();
}

class _ModelosScreenState extends State<ModelosScreen> {
  List<Map<String, dynamic>> _modelos = [];
  List<Map<String, dynamic>> _modelosFiltrados = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  // Controlador para el campo de búsqueda
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarModelosLocales();

    // Listener para el campo de búsqueda
    _searchController.addListener(_filtrarModelos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarModelos() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _modelosFiltrados = List.from(_modelos);
      } else {
        _modelosFiltrados = _modelos.where((modelo) {
          final nombre = (modelo['nombre'] ?? '').toString().toLowerCase();
          final id = (modelo['id'] ?? '').toString().toLowerCase();
          return nombre.contains(query) || id.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _cargarModelosLocales() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final modeloRepo = ModeloRepository();
      final modelosLocales = await modeloRepo.obtenerTodos();

      if (mounted) {
        final modelosData = modelosLocales.map((modelo) => {
          'id': modelo.id,
          'nombre': modelo.nombre,
        }).toList();

        setState(() {
          _modelos = modelosData;
          _modelosFiltrados = List.from(modelosData);
          _isLoading = false;
        });
      }

      _logger.i('Modelos locales cargados: ${_modelos.length}');
    } catch (e) {
      _logger.e('Error cargando modelos locales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando modelos locales: $e';
        });
      }
    }
  }

  Future<void> _sincronizarModelos() async {
    if (!mounted) return;

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Iniciando sincronización de modelos desde el servidor...');

      // Usar EquipmentSyncService en lugar de ModeloRepository
      final resultado = await EquipmentSyncService.sincronizarModelos();

      if (!mounted) return;

      if (resultado.exito) {
        // Recargar los modelos locales después de sincronizar
        final modeloRepo = ModeloRepository();
        final modelosActualizados = await modeloRepo.obtenerTodos();

        final modelosData = modelosActualizados.map((modelo) => {
          'id': modelo.id,
          'nombre': modelo.nombre,
        }).toList();

        setState(() {
          _modelos = modelosData;
          _modelosFiltrados = List.from(modelosData);
          _isSyncing = false;
        });

        // Aplicar filtro si hay búsqueda activa
        if (_searchController.text.isNotEmpty) {
          _filtrarModelos();
        }

        final cantidadSincronizada = resultado.itemsSincronizados;
        _logger.i('Modelos sincronizados exitosamente: $cantidadSincronizada');

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cantidadSincronizada > 0
                  ? 'Se sincronizaron $cantidadSincronizada modelo${cantidadSincronizada != 1 ? 's' : ''} exitosamente'
                  : 'No hay modelos nuevos para sincronizar',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        final mensaje = resultado.mensaje;

        setState(() {
          _isSyncing = false;
          _errorMessage = mensaje;
        });

        _logger.e('Error sincronizando modelos: $mensaje');

        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error sincronizando modelos: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _errorMessage = 'Error sincronizando modelos: $e';
        });

        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar modelos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelos'),
        backgroundColor: Colors.grey[700],
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _sincronizarModelos,
            icon: _isSyncing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.sync),
            tooltip: 'Sincronizar modelos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda fija
          _buildSearchSection(),

          // Contenido principal
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar modelos por nombre o ID...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[500]),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[600]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.grey,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_modelos.isEmpty) {
      return _buildEmptyState();
    }

    return _buildModelosList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar modelos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cargarModelosLocales,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay modelos registrados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Presiona el botón de sincronizar para descargar modelos del servidor',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _sincronizarModelos,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
              icon: _isSyncing
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelosList() {
    // Mostrar mensaje si no hay resultados de búsqueda
    if (_modelosFiltrados.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No se encontraron modelos',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Intenta con otros términos de búsqueda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Banner de estado de sincronización
        if (_isSyncing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sincronizando modelos...',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Contador de resultados si hay búsqueda activa
        if (_searchController.text.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Text(
              '${_modelosFiltrados.length} resultado${_modelosFiltrados.length != 1 ? 's' : ''} encontrado${_modelosFiltrados.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Lista de modelos
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: _modelosFiltrados.length,
            itemBuilder: (context, index) {
              final modelo = _modelosFiltrados[index];
              return _buildModeloCard(modelo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeloCard(Map<String, dynamic> modelo) {
    final searchQuery = _searchController.text.toLowerCase();
    final nombreModelo = modelo['nombre'] ?? 'Sin nombre';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.devices,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(
                      nombreModelo,
                      searchQuery,
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildHighlightedText(
                      'ID: ${modelo['id']}',
                      searchQuery,
                      TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Modelo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final startIndex = lowerText.indexOf(query);
    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, startIndex),
            style: style,
          ),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: style.copyWith(
              backgroundColor: Colors.yellow[200],
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: text.substring(endIndex),
            style: style,
          ),
        ],
      ),
    );
  }
}