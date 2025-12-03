import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/pending_data_viewmodel.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/ui/screens/preview_screen.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:intl/intl.dart';

class CensosPendientesDetailScreen extends StatefulWidget {
  final PendingDataViewModel viewModel;
  final PendingDataGroup group;

  const CensosPendientesDetailScreen({
    super.key,
    required this.viewModel,
    required this.group,
  });

  @override
  State<CensosPendientesDetailScreen> createState() =>
      _CensosPendientesDetailScreenState();
}

class _CensosPendientesDetailScreenState
    extends State<CensosPendientesDetailScreen> {
  bool _isLoading = true;

  List<Map<String, dynamic>> _censosFallidos = [];
  String? _error;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadCensosFallidos();
  }

  Future<void> _loadCensosFallidos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final censos = await widget.viewModel.getCensosFallidos();
      setState(() {
        _censosFallidos = censos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Future<void> _reintentarTodos() async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Reintentar Todos'),
  //       content: Text(
  //           '¿Desea reintentar el envío de todos los ${_censosFallidos.length} censos pendientes?'
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('Cancelar'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: const Text('Reintentar'),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   if (confirm != true) return;
  //
  //   setState(() => _isRetrying = true);
  //
  //   // final resultado = await widget.viewModel.reintentarTodosCensos();
  //
  //   setState(() => _isRetrying = false);
  //
  //   if (resultado['success'] == true) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(resultado['message'] ?? 'Censos sincronizados'),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //     _loadCensosFallidos();
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(resultado['error'] ?? 'Error en sincronización'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  Future<void> _navegarAPreviewHistorial(Map<String, dynamic> censo) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Obtener datos completos del censo para el preview
      final datosParaPreview = await _obtenerDatosCompletosDelCenso(
        censo['id'],
      );

      // Cerrar indicador de carga
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (datosParaPreview == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar los datos del censo'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 🔥 NAVEGACIÓN IGUAL QUE DESDE HISTORIAL (sin parámetro esHistorial)
      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(datos: datosParaPreview),
        ),
      );

      // Si se reintentó y tuvo éxito, recargar lista
      if (resultado == true) {
        await _loadCensosFallidos();
      }
    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      debugPrint('Error navegando al preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🆕 MÉTODO AUXILIAR - Obtener datos completos del censo (FORMATO CORRECTO PARA PREVIEW)
  Future<Map<String, dynamic>?> _obtenerDatosCompletosDelCenso(
    String censoId,
  ) async {
    try {
      final db = await _dbHelper.database;

      // Obtener censo con JOINs
      final censos = await db.rawQuery(
        '''
        SELECT 
          ca.*,
          eq.cod_barras,
          eq.numero_serie,
          eq.marca_id,
          eq.modelo_id,
          eq.logo_id,
          c.id as cliente_id,
          c.nombre as cliente_nombre,
          c.telefono as cliente_telefono,
          c.direccion as cliente_direccion,
          m.nombre as marca_nombre,
          mo.nombre as modelo_nombre,
          l.nombre as logo_nombre
        FROM censo_activo ca
        LEFT JOIN equipos eq ON ca.equipo_id = eq.id
        LEFT JOIN clientes c ON ca.cliente_id = c.id
        LEFT JOIN marcas m ON eq.marca_id = m.id
        LEFT JOIN modelos mo ON eq.modelo_id = mo.id
        LEFT JOIN logo l ON eq.logo_id = l.id
        WHERE ca.id = ?
      ''',
        [censoId],
      );

      if (censos.isEmpty) return null;

      final censo = censos.first;

      // ✅ Obtener cliente completo desde ClienteRepository
      final clienteRepository = ClienteRepository();
      final clienteId = censo['cliente_id'];

      if (clienteId == null) {
        throw Exception('Cliente ID no encontrado');
      }

      final cliente = await clienteRepository.obtenerPorId(
        clienteId is int ? clienteId : int.parse(clienteId.toString()),
      );

      if (cliente == null) {
        throw Exception('Cliente no encontrado en la base de datos');
      }

      // ✅ Obtener fotos del censo
      final censoActivoFotoRepo = CensoActivoFotoRepository();
      final fotos = await censoActivoFotoRepo.obtenerFotosPorCenso(censoId);

      String? imagenPath;
      String? imagenBase64;
      bool tieneImagen = false;
      int? imagenTamano;

      String? imagenPath2;
      String? imagenBase64_2;
      bool tieneImagen2 = false;
      int? imagenTamano2;

      // Primera foto
      if (fotos.isNotEmpty) {
        final primeraFoto = fotos.first;
        imagenPath = primeraFoto.imagenPath;
        imagenBase64 = primeraFoto.imagenBase64;
        tieneImagen = primeraFoto.tieneImagen;
        imagenTamano = primeraFoto.imagenTamano;
      }

      // Segunda foto
      if (fotos.length > 1) {
        final segundaFoto = fotos[1];
        imagenPath2 = segundaFoto.imagenPath;
        imagenBase64_2 = segundaFoto.imagenBase64;
        tieneImagen2 = segundaFoto.tieneImagen;
        imagenTamano2 = segundaFoto.imagenTamano;
      }

      // ✅ Construir estructura EXACTAMENTE como lo hace el historial
      final equipoCompleto = {
        'id': censo['equipo_id'],
        'cod_barras': censo['cod_barras']?.toString() ?? '',
        'numero_serie': censo['numero_serie']?.toString() ?? '',
        'modelo_nombre': censo['modelo_nombre']?.toString() ?? '',
        'logo_nombre': censo['logo_nombre']?.toString() ?? '',
        'marca_nombre': censo['marca_nombre']?.toString() ?? '',
      };

      // ✅ ESTRUCTURA IDÉNTICA A LA DEL HISTORIAL
      return {
        'id': censo['id'],
        'cliente': cliente, // ✅ Cliente completo desde el repository
        'equipo_completo': equipoCompleto,
        'latitud': censo['latitud'],
        'longitud': censo['longitud'],
        'fecha_registro': censo['fecha_creacion'],
        'timestamp_gps': censo['fecha_creacion'],

        'codigo_barras': censo['cod_barras']?.toString() ?? 'No especificado',
        'modelo': censo['modelo_nombre']?.toString() ?? 'No especificado',
        'logo': censo['logo_nombre']?.toString() ?? 'No especificado',
        'numero_serie': censo['numero_serie']?.toString() ?? 'No especificado',

        'observaciones': censo['observaciones'] ?? 'Sin observaciones',

        // ✅ Fotos obtenidas del repositorio
        'imagen_path': imagenPath,
        'imagen_base64': imagenBase64,
        'tiene_imagen': tieneImagen,
        'imagen_tamano': imagenTamano,

        'imagen_path2': imagenPath2,
        'imagen_base64_2': imagenBase64_2,
        'tiene_imagen2': tieneImagen2,
        'imagen_tamano2': imagenTamano2,

        // ✅ Flags para indicar que viene de censos pendientes
        'es_censo': true,
        'es_historial': true, // 🔑 MODO HISTORIAL
        'es_censo_pendiente': true, // 🆕 Flag especial
        // ✅ Datos de sincronización
        'sincronizado': (censo['sincronizado'] as int?) == 1,
        'estado_censo': censo['estado_censo'],
        'intentos_sync': censo['intentos_sync'],
        'error_mensaje': censo['error_mensaje'],
      };
    } catch (e, stackTrace) {
      debugPrint('Error obteniendo datos completos: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Censos Pendientes (${widget.group.count})'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_censosFallidos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCensosFallidos,
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _censosFallidos.isNotEmpty ? null : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando censos pendientes...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error cargando datos'),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCensosFallidos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_censosFallidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Todos los censos sincronizados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text('No hay censos pendientes'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCensosFallidos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _censosFallidos.length,
        itemBuilder: (context, index) {
          final censo = _censosFallidos[index];
          return _buildCensoCard(censo);
        },
      ),
    );
  }

  Widget _buildCensoCard(Map<String, dynamic> censo) {
    final equipoNombre =
        '${censo['marca_nombre'] ?? ''} ${censo['modelo_nombre'] ?? ''}'.trim();
    final codigoBarras = censo['cod_barras']?.toString() ?? 'Sin código';
    final clienteNombre = censo['cliente_nombre']?.toString() ?? 'Sin cliente';
    final fechaCreacion = censo['fecha_creacion'] != null
        ? DateTime.parse(censo['fecha_creacion'])
        : null;
    final intentos = censo['intentos_sync'] as int? ?? 0;
    final mensajeError = censo['error_mensaje']?.toString();
    final fotosCount = 0; // Temporal, puedes calcular esto si lo necesitas

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navegarAPreviewHistorial(censo), // 🆕 CLICKEABLE
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sync_problem,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipoNombre.isNotEmpty
                              ? equipoNombre
                              : 'Equipo sin datos',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          codigoBarras,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🆕 Indicador de que es clickeable
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Información del censo
              _buildInfoRow(Icons.person, 'Cliente', clienteNombre),
              _buildInfoRow(Icons.photo_camera, 'Fotos', '$fotosCount'),
              if (fechaCreacion != null)
                _buildInfoRow(
                  Icons.access_time,
                  'Fecha',
                  DateFormat('dd/MM/yyyy HH:mm').format(fechaCreacion),
                ),
              _buildInfoRow(
                Icons.sync_problem,
                'Intentos',
                '$intentos',
                valueColor: Colors.orange,
              ),

              // Mensaje de error
              if (mensajeError != null && mensajeError.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mensajeError,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 🆕 Hint de tap para ver más
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Toca para ver detalles completos',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildBottomBar() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Theme.of(context).scaffoldBackgroundColor,
  //       border: Border(
  //         top: BorderSide(color: Theme.of(context).dividerColor),
  //       ),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           offset: const Offset(0, -2),
  //           blurRadius: 4,
  //         ),
  //       ],
  //     ),
  //     child: SafeArea(
  //       child: SizedBox(
  //         width: double.infinity,
  //         child: ElevatedButton.icon(
  //           onPressed: _isRetrying ? null : _reintentarTodos,
  //           icon: _isRetrying
  //               ? const SizedBox(
  //             width: 16,
  //             height: 16,
  //             child: CircularProgressIndicator(
  //               strokeWidth: 2,
  //               color: Colors.white,
  //             ),
  //           )
  //               : const Icon(Icons.sync),
  //           label: Text(
  //             _isRetrying
  //                 ? 'Reintentando...'
  //                 : 'Reintentar Todos (${_censosFallidos.length})',
  //           ),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Theme.of(context).primaryColor,
  //             foregroundColor: Colors.white,
  //             padding: const EdgeInsets.symmetric(vertical: 16),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
