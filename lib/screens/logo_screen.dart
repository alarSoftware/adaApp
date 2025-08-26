import 'package:flutter/material.dart';
import '../repositories/logo_repository.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class LogosScreen extends StatefulWidget {
  const LogosScreen({super.key});

  @override
  State<LogosScreen> createState() => _LogosScreenState();
}

class _LogosScreenState extends State<LogosScreen> {
  List<Map<String, dynamic>> _logos = [];
  bool _isLoading = false; // Cambiado a false inicialmente
  bool _isSyncing = false; // Nuevo estado para sincronización
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Solo cargar logos que ya existen localmente, SIN descargar nuevos
    _cargarLogosLocales();
  }

  // Nueva función para cargar solo logos locales existentes
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
        setState(() {
          _logos = logosLocales.map((logo) => {
            'id': logo.id,
            'nombre': logo.nombre,
          }).toList();
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

  // Nueva función para sincronizar (descargar desde servidor)
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
        setState(() {
          _logos = logosActualizados.map((logo) => {
            'id': logo.id,
            'nombre': logo.nombre,
          }).toList();
          _isSyncing = false;
        });
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
          // Botón de sincronizar en el AppBar
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
      body: SafeArea(
        child: _buildContent(),
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

        // Lista de logos
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
            itemCount: _logos.length,
            itemBuilder: (context, index) {
              final logo = _logos[index];
              return _buildLogoCard(logo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogoCard(Map<String, dynamic> logo) {
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
              Text(
                logo['nombre'] ?? 'Sin nombre',
                style: const TextStyle(
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
                child: Text(
                  'ID: ${logo['id']}',
                  style: TextStyle(
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
}