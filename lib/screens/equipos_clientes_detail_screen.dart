import 'package:flutter/material.dart';
import '../models/equipos_cliente.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class EquiposClientesDetailScreen extends StatelessWidget {
  final EquipoCliente equipoCliente;

  const EquiposClientesDetailScreen({
    Key? key,
    required this.equipoCliente,
  }) : super(key: key);

  Future<void> _verificarEquipo(BuildContext context) async {
    if (equipoCliente.equipoCodBarras?.isNotEmpty == true) {
      // TODO: Implementar navegación a pantalla de cámara para verificar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.white),
              SizedBox(width: 8),
              Text('Verificando equipo ${equipoCliente.equipoCodBarras}'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _mostrarError(context, 'No hay código de barras para verificar');
    }
  }

  Future<void> _reportarEstado(BuildContext context) async {
    // TODO: Implementar reporte de estado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.report, color: Colors.white),
            SizedBox(width: 8),
            Text('Reportando estado del equipo...'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cambiarCliente(BuildContext context) async {
    // TODO: Implementar cambio de cliente
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.white),
            SizedBox(width: 8),
            Text('Función de cambio de cliente...'),
          ],
        ),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _retirarEquipo(BuildContext context) async {
    bool? confirmar = await _mostrarDialogoConfirmacionRetiro(context);
    if (confirmar != true) return;

    // TODO: Implementar retiro de equipo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.remove_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Retirando equipo...'),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _mostrarDialogoConfirmacionRetiro(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Retirar Equipo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Estás seguro de que quieres retirar este equipo?'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getNombreCompletoEquipo()),
                    if (equipoCliente.equipoCodBarras?.isNotEmpty == true)
                      Text('Código: ${equipoCliente.equipoCodBarras}'),
                    Text('Cliente: ${equipoCliente.clienteNombreCompleto}'),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Esta acción marcará el equipo como retirado y ya no estará asignado a este cliente.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Retirar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatearFechaHora(DateTime fecha) {
    return '${_formatearFecha(fecha)} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  // Método para obtener el nombre completo del equipo
  String _getNombreCompletoEquipo() {
    final marca = equipoCliente.equipoMarca ?? 'Sin marca';
    final modelo = equipoCliente.equipoModelo ?? 'Sin modelo';
    return '$marca $modelo';
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: Verificar qué datos llegan
    logger.i('DEBUG - Marca: ${equipoCliente.equipoMarca}');
    logger.i('DEBUG - Modelo: ${equipoCliente.equipoModelo}');
    logger.i('DEBUG - Nombre completo: ${equipoCliente.equipoNombreCompleto}');

    return Scaffold(
        appBar: AppBar(
          title: Text('Detalle del Equipo'),
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () => _reportarEstado(context),
              icon: Icon(Icons.report),
              tooltip: 'Reportar estado',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 16.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECCIÓN: EQUIPO ASIGNADO
                _buildSectionHeader(
                  icon: Icons.kitchen,
                  title: 'EQUIPO ASIGNADO',
                  color: Colors.orange,
                ),
                SizedBox(height: 12),

                _buildInfoCard(
                  icon: Icons.kitchen,
                  title: 'Equipo',
                  content: _getNombreCompletoEquipo(),
                  color: Colors.orange,
                ),

                if (equipoCliente.equipoMarca != null && equipoCliente.equipoMarca!.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.business,
                    title: 'Marca',
                    content: equipoCliente.equipoMarca!,
                    color: Colors.indigo,
                  ),

                if (equipoCliente.equipoModelo != null && equipoCliente.equipoModelo!.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.category,
                    title: 'Modelo',
                    content: equipoCliente.equipoModelo!,
                    color: Colors.teal,
                  ),

                if (equipoCliente.equipoCodBarras != null && equipoCliente.equipoCodBarras!.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.qr_code,
                    title: 'Código de Barras',
                    content: equipoCliente.equipoCodBarras!,
                    color: Colors.purple,
                  ),

                _buildInfoCard(
                  icon: Icons.calendar_today,
                  title: 'Fecha de Asignación',
                  content: _formatearFechaHora(equipoCliente.fechaAsignacion),
                  color: Colors.teal,
                ),

                _buildInfoCard(
                  icon: Icons.access_time,
                  title: 'Tiempo Asignado',
                  content: '${equipoCliente.diasDesdeAsignacion} días',
                  color: Colors.indigo,
                ),

                if (equipoCliente.fechaRetiro != null)
                  _buildInfoCard(
                    icon: Icons.event_busy,
                    title: 'Fecha de Retiro',
                    content: _formatearFechaHora(equipoCliente.fechaRetiro!),
                    color: Colors.red,
                  ),

                _buildInfoCard(
                  icon: equipoCliente.asignacionActiva ? Icons.check_circle : Icons.cancel,
                  title: 'Estado',
                  content: equipoCliente.estadoTexto,
                  color: equipoCliente.colorEstado,
                ),

                SizedBox(height: 32),

                // BOTONES DE ACCIÓN
                if (equipoCliente.asignacionActiva) ...[
                  // Botón Verificar Este Equipo
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _verificarEquipo(context),
                      icon: Icon(Icons.camera_alt),
                      label: Text('Verificar Este Equipo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Botón Reportar Estado
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _reportarEstado(context),
                      icon: Icon(Icons.report),
                      label: Text('Reportar Estado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Botón Cambiar Cliente
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cambiarCliente(context),
                      icon: Icon(Icons.swap_horiz),
                      label: Text('Cambiar Cliente'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple[700],
                        side: BorderSide(color: Colors.purple[700]!),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Botón Retirar Equipo
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _retirarEquipo(context),
                      icon: Icon(Icons.remove_circle),
                      label: Text('Retirar Equipo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[700]!),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Si el equipo ya fue retirado
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, size: 40, color: Colors.red[600]),
                        SizedBox(height: 8),
                        Text(
                          'Equipo no activo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Este equipo ya no está asignado activamente a este cliente',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20),
              ],
            ),
          ),
        )
    );
    }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}