import 'package:flutter/material.dart';
import 'package:cliente_app/repositories/models_repository.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class ModelosScreen extends StatefulWidget {
  const ModelosScreen({super.key});

  @override
  State<ModelosScreen> createState() => _ModelosScreenState();
}

class _ModelosScreenState extends State<ModelosScreen> {
  List<Map<String, dynamic>> _modelos = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarModelosLocales();
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
        setState(() {
          _modelos = modelosLocales.map((modelo) => {
            'id': modelo.id,
            'nombre': modelo.nombre,
          }).toList();
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
      final modeloRepo = ModeloRepository();

      // Aquí debes agregar tu lógica de descarga desde el servidor
      // Por ejemplo:
      // await modeloRepo.sincronizarDesdeServidor();

      // Después de sincronizar, recargar los modelos locales
      final modelosActualizados = await modeloRepo.obtenerTodos();

      if (mounted) {
        setState(() {
          _modelos = modelosActualizados.map((modelo) => {
            'id': modelo.id,
            'nombre': modelo.nombre,
          }).toList();
          _isSyncing = false;
        });
      }

      _logger.i('Modelos sincronizados exitosamente: ${_modelos.length}');

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modelos sincronizados exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
          const SnackBar(
            content: Text('Error al sincronizar modelos'),
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
              Icons.smartphone_outlined,
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
              'Presiona el botón de sincronizar para descargar modelos',
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

        // Lista de modelos
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: _modelos.length,
            itemBuilder: (context, index) {
              final modelo = _modelos[index];
              return _buildModeloCard(modelo);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeloCard(Map<String, dynamic> modelo) {
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
                  Icons.smartphone,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelo['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${modelo['id']}',
                      style: TextStyle(
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
}