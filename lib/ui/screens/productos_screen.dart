import 'package:flutter/material.dart';
import 'package:ada_app/repositories/producto_repository.dart';
import 'package:ada_app/services/sync/producto_sync_service.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  // Controlador para el campo de búsqueda
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarProductosLocales();

    // Listener para el campo de búsqueda
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = List.from(_productos);
      } else {
        _productosFiltrados = _productos.where((producto) {
          final nombre = (producto['nombre'] ?? '').toString().toLowerCase();
          final codigo = (producto['codigo'] ?? '').toString().toLowerCase();
          final codigoBarras = (producto['codigo_barras'] ?? '').toString().toLowerCase();
          final id = (producto['id'] ?? '').toString().toLowerCase();
          return nombre.contains(query) ||
              codigo.contains(query) ||
              codigoBarras.contains(query) ||
              id.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _cargarProductosLocales() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productoRepo = ProductoRepositoryImpl();
      final productosLocales = await productoRepo.obtenerProductosDisponibles();

      if (mounted) {
        final productosData = productosLocales.map((producto) => {
          'id': producto.id,
          'codigo': producto.codigo,
          'codigo_barras': producto.codigoBarras,
          'nombre': producto.nombre,
          'categoria': producto.categoria,
        }).toList();

        setState(() {
          _productos = productosData;
          _productosFiltrados = List.from(productosData);
          _isLoading = false;
        });
      }

      _logger.i('Productos locales cargados: ${_productos.length}');
    } catch (e) {
      _logger.e('Error cargando productos locales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando productos locales: $e';
        });
      }
    }
  }

  Future<void> _sincronizarProductos() async {
    if (!mounted) return;

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Iniciando sincronización de productos desde el servidor...');

      // Usar ProductoSyncService
      final resultado = await ProductoSyncService.obtenerProductos();

      if (!mounted) return;

      if (resultado.exito) {
        // Recargar productos locales después de la sincronización
        final productoRepo = ProductoRepositoryImpl();
        final productosActualizados = await productoRepo.obtenerProductosDisponibles();

        final productosData = productosActualizados.map((producto) => {
          'id': producto.id,
          'codigo': producto.codigo,
          'codigo_barras': producto.codigoBarras,
          'nombre': producto.nombre,
          'categoria': producto.categoria,
        }).toList();

        setState(() {
          _productos = productosData;
          _productosFiltrados = List.from(productosData);
          _isSyncing = false;
        });

        // Aplicar filtro si hay búsqueda activa
        if (_searchController.text.isNotEmpty) {
          _filtrarProductos();
        }

        final cantidadSincronizada = resultado.itemsSincronizados;
        _logger.i('Productos sincronizados exitosamente: $cantidadSincronizada');

        // Mostrar mensaje de éxito con la cantidad
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cantidadSincronizada > 0
                  ? 'Se sincronizaron $cantidadSincronizada producto${cantidadSincronizada != 1 ? 's' : ''} exitosamente'
                  : 'No hay productos nuevos para sincronizar',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Error en la sincronización
        final mensaje = resultado.mensaje;

        setState(() {
          _isSyncing = false;
          _errorMessage = mensaje;
        });

        _logger.e('Error sincronizando productos: $mensaje');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error sincronizando productos: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _errorMessage = 'Error sincronizando productos: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar productos: ${e.toString()}'),
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
        title: const Text('Productos'),
        backgroundColor: Colors.grey[700],
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _sincronizarProductos,
            icon: _isSyncing
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(Icons.sync),
            tooltip: 'Sincronizar productos',
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
          hintText: 'Buscar por nombre, código, código de barras o ID...',
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

    if (_productos.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductosList();
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
              'Error al cargar productos',
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
              onPressed: _cargarProductosLocales,
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
              Icons.inventory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay productos registrados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Presiona el botón de sincronizar para descargar productos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _sincronizarProductos,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
              icon: _isSyncing
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Icon(Icons.sync),
              label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductosList() {
    // Mostrar mensaje si no hay resultados de búsqueda
    if (_productosFiltrados.isEmpty && _searchController.text.isNotEmpty) {
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
                'No se encontraron productos',
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
            padding: EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Sincronizando productos...',
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
              '${_productosFiltrados.length} resultado${_productosFiltrados.length != 1 ? 's' : ''} encontrado${_productosFiltrados.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Lista de productos
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: _productosFiltrados.length,
            itemBuilder: (context, index) {
              final producto = _productosFiltrados[index];
              return _buildProductoCard(producto);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    final searchQuery = _searchController.text.toLowerCase();
    final nombre = producto['nombre'] ?? 'Sin nombre';
    final codigo = producto['codigo'];
    final codigoBarras = producto['codigo_barras'];
    final categoria = producto['categoria'] ?? 'Sin categoría';

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
                  Icons.inventory,
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
                      nombre,
                      searchQuery,
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (codigo != null && codigo.isNotEmpty) ...[
                          _buildHighlightedText(
                            'Código: $codigo',
                            searchQuery,
                            TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _buildHighlightedText(
                          'ID: ${producto['id']}',
                          searchQuery,
                          TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    if (codigoBarras != null && codigoBarras.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildHighlightedText(
                        'Código de barras: $codigoBarras',
                        searchQuery,
                        TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  categoria,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
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