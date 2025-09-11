import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/preview_screen_viewmodel.dart';

class PreviewScreen extends StatefulWidget {
  final Map<String, dynamic> datos;

  const PreviewScreen({
    super.key,
    required this.datos,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PreviewScreenViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = PreviewScreenViewModel();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Cliente cliente = widget.datos['cliente'];

    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: _buildBody(cliente),
        bottomNavigationBar: _buildBottomButtons(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Confirmar Registro'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      shadowColor: AppColors.shadowLight,
    );
  }

  Widget _buildBody(Cliente cliente) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClienteCard(cliente),
          const SizedBox(height: 16),
          _buildEquipoCard(),
          const SizedBox(height: 16),
          _buildUbicacionCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildClienteCard(Cliente cliente) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppColors.secondary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Información del Cliente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            _buildInfoRow('Nombre', cliente.nombre, Icons.account_circle),
            _buildInfoRow('Dirección', cliente.direccion, Icons.location_on),
            _buildInfoRow('Teléfono', cliente.telefono ?? 'No especificado', Icons.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipoCard() {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.devices,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Datos del Visicooler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            _buildInfoRow(
              'Código de Barras',
              widget.datos['codigo_barras'] ?? 'No especificado',
              Icons.qr_code,
            ),
            _buildInfoRow(
              'Modelo del Equipo',
              widget.datos['modelo'] ?? 'No especificado',
              Icons.devices,
            ),
            _buildInfoRow(
              'Logo',
              widget.datos['logo'] ?? 'No especificado',
              Icons.business,
            ),
            if (widget.datos['observaciones'] != null && widget.datos['observaciones'].toString().isNotEmpty)
              _buildInfoRow(
                'Observaciones',
                widget.datos['observaciones'].toString(),
                Icons.note_add,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUbicacionCard() {
    final latitud = widget.datos['latitud'];
    final longitud = widget.datos['longitud'];
    final fechaRegistro = widget.datos['fecha_registro'];

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Información de Registro',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            _buildInfoRow(
              'Latitud',
              latitud != null ? latitud.toStringAsFixed(6) : 'No disponible',
              Icons.explore,
            ),
            _buildInfoRow(
              'Longitud',
              longitud != null ? longitud.toStringAsFixed(6) : 'No disponible',
              Icons.explore_off,
            ),
            Consumer<PreviewScreenViewModel>(
              builder: (context, vm, child) {
                return _buildInfoRow(
                  'Fecha y Hora',
                  vm.formatearFecha(fechaRegistro?.toString()),
                  Icons.access_time,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'No especificado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Consumer<PreviewScreenViewModel>(
      builder: (context, vm, child) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostrar mensaje de estado si existe
                if (vm.statusMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: AppColors.info, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: vm.isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Volver a Editar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: vm.isLoading ? null : _confirmarRegistro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: vm.isLoading
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.onPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Registrando...'),
                          ],
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Confirmar Registro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmarRegistro() async {
    final resultado = await viewModel.confirmarRegistro(widget.datos);

    if (mounted) {
      if (resultado['success']) {
        _mostrarSnackBar(resultado['message'], AppColors.success);
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(true); // Solo este pop
      } else {
        await _mostrarDialogoErrorConfirmacion(resultado['error']);
      }
    }
  }
  Future<void> _mostrarDialogoErrorConfirmacion(String error) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error en Confirmación',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hubo un problema al procesar el registro:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Datos Protegidos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sus datos están guardados localmente y no se perderán. Se sincronizarán automáticamente cuando se resuelva el problema.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                Navigator.of(context).pop(false); // Solo regresar a FormsScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}