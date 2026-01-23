import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/pending_data_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_upload_service.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/dynamic_form_viewmodel.dart';
import 'package:ada_app/ui/screens/dynamic_form/dynamic_form_fill_screen.dart';
import 'package:ada_app/repositories/dynamic_form_response_repository.dart';

class DynamicFormsPendientesDetailScreen extends StatefulWidget {
  final PendingDataViewModel viewModel;
  final PendingDataGroup group;

  const DynamicFormsPendientesDetailScreen({
    super.key,
    required this.viewModel,
    required this.group,
  });

  @override
  State<DynamicFormsPendientesDetailScreen> createState() =>
      _DynamicFormsPendientesDetailScreenState();
}

class _DynamicFormsPendientesDetailScreenState
    extends State<DynamicFormsPendientesDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _formsFallidos = [];
  String? _error;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _loadFormsFallidos();
  }

  Future<void> _loadFormsFallidos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final forms = await widget.viewModel.getFormulariosFallidos();
      setState(() {
        _formsFallidos = forms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmarEliminacion(Map<String, dynamic> form) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Respuesta'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta respuesta con error? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _eliminarForm(form['id'].toString());
    }
  }

  Future<void> _eliminarForm(String responseId) async {
    setState(() => _isLoading = true);
    try {
      await widget.viewModel.deleteDynamicFormResponse(responseId);
      await _loadFormsFallidos(); // Recargar lista

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respuesta eliminada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reintentarEnvio(Map<String, dynamic> form) async {
    setState(() => _isRetrying = true);

    try {
      final responseId = form['id'].toString();
      final uploadService = DynamicFormUploadService();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reintentando envío...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Usamos el servicio de upload que mapea correctamente los datos (snake_case -> camelCase)
      final result = await uploadService.enviarRespuestaAlServidor(
        responseId,
        guardarLog: true,
        userId: form['usuario_id']?.toString(),
      );

      if (result['exito'] == true || result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Enviado correctamente!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadFormsFallidos(); // Recargar lista
      } else {
        if (mounted) {
          final errorMessage =
              result['mensaje'] ??
              result['message'] ??
              result['error'] ??
              'Error desconocido';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al enviar: $errorMessage'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excepción al reintentar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  Future<void> _navigateToPreview(Map<String, dynamic> form) async {
    // 1. Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final responseId = form['id'].toString();

      // 2. Obtener respuesta completa
      final repo = DynamicFormResponseRepository();
      final response = await repo.getById(responseId);

      if (response == null) {
        throw Exception('No se encontró el formulario');
      }

      // 3. Inicializar ViewModel para preview
      final vm = DynamicFormViewModel();
      await vm.loadTemplates(); // Cargar templates para tener metadatos
      vm.loadResponseForEditing(response);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      // 4. Navegar a DynamicFormFillScreen en modo lectura
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DynamicFormFillScreen(
            viewModel: vm,
            isReadOnly: true,
            onRetry: () {
              Navigator.pop(context); // Cerrar preview
              _reintentarEnvio(form); // Reintentar desde lista
            },
            onDelete: () {
              Navigator.pop(context); // Cerrar preview
              _confirmarEliminacion(form); // Eliminar desde lista
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error abriendo preview: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Formularios Pendientes (${widget.group.count})'),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
          if (_formsFallidos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFormsFallidos,
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _formsFallidos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando formularios pendientes...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorContainer,
            ),
            const SizedBox(height: 16),
            Text('Error cargando datos'),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFormsFallidos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar carga'),
            ),
          ],
        ),
      );
    }

    if (_formsFallidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.successLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Todos los formularios sincronizados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text('No hay formularios pendientes'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadFormsFallidos,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _formsFallidos.length,
            itemBuilder: (context, index) {
              final form = _formsFallidos[index];
              return _buildFormCard(form);
            },
          ),
        ),
        if (_isRetrying)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildFormCard(Map<String, dynamic> form) {
    final formNombre =
        form['formulario_nombre']?.toString() ?? 'Formulario sin nombre';
    final fechaCreacion = form['fecha_creacion'] != null
        ? DateTime.parse(form['fecha_creacion'])
        : null;
    final clienteNombre = form['cliente_nombre']?.toString() ?? 'Sin cliente';
    final usuarioNombre =
        form['usuario_nombre']?.toString() ?? 'Usuario desconocido';
    final mensajeError = form['error_mensaje']?.toString();
    final intentos = form['intentos_envio'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToPreview(form),
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
                      color: AppColors.errorContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_late,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${form['id']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icono flecha indicando navegación
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Información
              _buildInfoRow(Icons.person, 'Cliente', clienteNombre),
              _buildInfoRow(Icons.badge, 'Usuario', usuarioNombre),
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
                valueColor: AppColors.warning,
              ),

              // Mensaje de error
              if (mensajeError != null && mensajeError.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mensajeError,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Hint de tap
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Toca para ver detalles y reintentar',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
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
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
