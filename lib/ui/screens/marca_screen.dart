import 'package:flutter/material.dart';
import '../../repositories/marca_repository.dart';
import '../../services/sync/equipment_sync_service.dart';



class MarcaScreen extends StatefulWidget {
  const MarcaScreen({super.key});

  @override
  State<MarcaScreen> createState() => _MarcaScreenState();
}

class _MarcaScreenState extends State<MarcaScreen> {
  List<Map<String, dynamic>> _marcas = [];
  List<Map<String, dynamic>> _marcasFiltradas = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  // Controlador para el campo de búsqueda
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarMarcasLocales();

    // Listener para el campo de búsqueda
    _searchController.addListener(_filtrarMarca);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarMarca() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _marcasFiltradas = List.from(_marcas);
      } else {
        _marcasFiltradas = _marcas.where((marca) {
          final nombre = (marca['nombre'] ?? '').toString().toLowerCase();
          final id = (marca['id'] ?? '').toString().toLowerCase();
          return nombre.contains(query) || id.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _cargarMarcasLocales() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final marcaRepo = MarcaRepository();
      final marcasLocales = await marcaRepo.obtenerTodos();

      if (mounted) {
        final marcasData = marcasLocales.map((marca) => {
          'id': marca.id,
          'nombre': marca.nombre,
        }).toList();

        setState(() {
          _marcas = marcasData;
          _marcasFiltradas = List.from(marcasData);
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando marcas locales: $e';
        });
      }
    }
  }

  Future<void> _sincronizarMarcas() async {
    if (!mounted) return;

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      // Usar EquipmentSyncService en lugar de MarcaRepository
      final resultado = await EquipmentSyncService.sincronizarMarcas();

      if (!mounted) return;

      if (resultado.exito) {
        // Recargar marcas locales después de la sincronización
        final marcaRepo = MarcaRepository();
        final marcasActualizadas = await marcaRepo.obtenerTodos();

        final marcasData = marcasActualizadas.map((marca) => {
          'id': marca.id,
          'nombre': marca.nombre,
        }).toList();

        setState(() {
          _marcas = marcasData;
          _marcasFiltradas = List.from(marcasData);
          _isSyncing = false;
        });

        // Aplicar filtro si hay búsqueda activa
        if (_searchController.text.isNotEmpty) {
          _filtrarMarca();
        }

        final cantidadSincronizada = resultado.itemsSincronizados;

        // Mostrar mensaje de éxito con la cantidad
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cantidadSincronizada > 0
                  ? 'Se sincronizaron $cantidadSincronizada marca${cantidadSincronizada != 1 ? 's' : ''} exitosamente'
                  : 'No hay marcas nuevas para sincronizar',
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


        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _errorMessage = 'Error sincronizando marcas: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar marcas: ${e.toString()}'),
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
        title: const Text('Marcas'),
        backgroundColor: Colors.grey[700],
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _sincronizarMarcas,
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
            tooltip: 'Sincronizar marcas',
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
          hintText: 'Buscar marcas por nombre o ID...',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando marcas...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _cargarMarcasLocales,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                ),
                icon: Icon(Icons.refresh),
                label: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_marcas.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMarcasList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay marcas registradas',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Presiona el botón de sincronizar para descargar marcas',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _sincronizarMarcas,
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

  Widget _buildMarcasList() {
    // Mostrar mensaje si no hay resultados de búsqueda
    if (_marcasFiltradas.isEmpty && _searchController.text.isNotEmpty) {
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
                'No se encontraron marcas',
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
                  'Sincronizando marcas...',
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
              '${_marcasFiltradas.length} resultado${_marcasFiltradas.length != 1 ? 's' : ''} encontrado${_marcasFiltradas.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Grid de marcas
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: _marcasFiltradas.length,
            itemBuilder: (context, index) {
              final marca = _marcasFiltradas[index];
              return _buildMarcaCard(marca);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarcaCard(Map<String, dynamic> marca) {
    final searchQuery = _searchController.text.toLowerCase();
    final nombreMarca = marca['nombre'] ?? 'Sin nombre';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.label,
                color: Colors.white,
                size: 18,
              ),
            ),
            _buildHighlightedText(
              nombreMarca,
              searchQuery,
              const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildHighlightedText(
                'ID: ${marca['id']}',
                searchQuery,
                TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
      String text,
      String query,
      TextStyle style, {
        TextAlign? textAlign,
        int? maxLines,
        TextOverflow? overflow,
      }) {
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final lowerText = text.toLowerCase();
    final startIndex = lowerText.indexOf(query);
    final endIndex = startIndex + query.length;

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
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