import 'package:flutter/material.dart';
import '../../repositories/logo_repository.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class LogosScreen extends StatefulWidget {
  const LogosScreen({super.key});

  @override
  State<LogosScreen> createState() => _LogosScreenState();
}

class _LogosScreenState extends State<LogosScreen> {
  List<Map<String, dynamic>> _logos = [];
  List<Map<String, dynamic>> _logosFiltrados = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  // Controlador para el campo de búsqueda
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarLogosLocales();

    // Listener para el campo de búsqueda
    _searchController.addListener(_filtrarLogos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarLogos() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _logosFiltrados = List.from(_logos);
      } else {
        _logosFiltrados = _logos.where((logo) {
          final nombre = (logo['nombre'] ?? '').toString().toLowerCase();
          final id = (logo['id'] ?? '').toString().toLowerCase();
          return nombre.contains(query) || id.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _cargarLogosLocales() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logoRepo = LogoRepository();
      final logosLocales = await logoRepo.obtenerTodos();

      if (mounted) {
        final logosData = logosLocales.map((logo) => {
          'id': logo.id,
          'nombre': logo.nombre,
        }).toList();

        setState(() {
          _logos = logosData;
          _logosFiltrados = List.from(logosData);
          _isLoading = false;
        });
      }

      _logger.i('Logos locales cargados: ${_logos.length}');
    } catch (e) {
      _logger.e('Error cargando logos locales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando logos locales: $e';
        });
      }
    }
  }

  Future<void> _sincronizarLogos() async {
    if (!mounted) return;

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final logoRepo = LogoRepository();

      // Aquí debes agregar tu lógica de descarga desde el servidor
      // Por ejemplo:
      // await logoRepo.sincronizarDesdeServidor();

      // Después de sincronizar, recargar los logos locales
      final logosActualizados = await logoRepo.obtenerTodos();

      if (mounted) {
        final logosData = logosActualizados.map((logo) => {
          'id': logo.id,
          'nombre': logo.nombre,
        }).toList();

        setState(() {
          _logos = logosData;
          _logosFiltrados = List.from(logosData);
          _isSyncing = false;
        });

        // Aplicar filtro si hay búsqueda activa
        if (_searchController.text.isNotEmpty) {
          _filtrarLogos();
        }
      }

      _logger.i('Logos sincronizados exitosamente: ${_logos.length}');

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logos sincronizados exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error sincronizando logos: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _errorMessage = 'Error sincronizando logos: $e';
        });

        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar logos'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logos'),
        backgroundColor: Colors.grey[700],
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _sincronizarLogos,
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
            tooltip: 'Sincronizar logos',
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
          hintText: 'Buscar logos por nombre o ID...',
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

    if (_logos.isEmpty) {
      return _buildEmptyState();
    }

    return _buildLogosList();
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
              'Error al cargar logos',
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
              onPressed: _cargarLogosLocales,
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
              Icons.style_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay logos registrados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Presiona el botón de sincronizar para descargar logos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _sincronizarLogos,
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

  Widget _buildLogosList() {
    // Mostrar mensaje si no hay resultados de búsqueda
    if (_logosFiltrados.isEmpty && _searchController.text.isNotEmpty) {
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
                'No se encontraron logos',
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
                  'Sincronizando logos...',
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
              '${_logosFiltrados.length} resultado${_logosFiltrados.length != 1 ? 's' : ''} encontrado${_logosFiltrados.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Grid de logos
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
            itemCount: _logosFiltrados.length,
            itemBuilder: (context, index) {
              final logo = _logosFiltrados[index];
              return _buildLogoCard(logo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogoCard(Map<String, dynamic> logo) {
    final searchQuery = _searchController.text.toLowerCase();
    final nombreLogo = logo['nombre'] ?? 'Sin nombre';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                  Icons.style,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              _buildHighlightedText(
                nombreLogo,
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
                  'ID: ${logo['id']}',
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