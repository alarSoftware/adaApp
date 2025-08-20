import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/api_service.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class ClienteDetailScreen extends StatelessWidget {
  final Cliente cliente;

  const ClienteDetailScreen({
    Key? key,
    required this.cliente,
  }) : super(key: key);

  Future<void> _enviarCliente(BuildContext context) async {
    bool? confirmar = await _mostrarDialogoConfirmacion(context);
    if (confirmar != true) return;

    await _ejecutarEnvio(context);
  }

  Future<bool?> _mostrarDialogoConfirmacion(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.send, color: Colors.grey[700]),
              SizedBox(width: 8),
              Text('Enviar Cliente'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Enviar este cliente al servidor?'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👤 ${cliente.nombre}'),
                    Text('📧 ${cliente.email}'),
                    if (cliente.telefono?.isNotEmpty == true)
                      Text('📱 ${cliente.telefono}'),
                  ],
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
              child: Text('Enviar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ejecutarEnvio(BuildContext context) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.grey[700]),
                SizedBox(width: 16),
                Text('Enviando...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      final resultado = await ApiService.enviarCliente(cliente);

      // Cerrar el diálogo de carga
      Navigator.of(context).pop();

      if (resultado.exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('✅ Cliente enviado correctamente')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('❌ Error: ${resultado.mensaje}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _ejecutarEnvio(context),
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error inesperado: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      logger.e('Error enviando cliente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Cliente'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _enviarCliente(context),
            icon: Icon(Icons.send),
            tooltip: 'Enviar al servidor',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar y nombre principal
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    child: Text(
                      cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    cliente.nombre,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Información del cliente
            _buildInfoCard(
              icon: Icons.email,
              title: 'Email',
              content: cliente.email,
              color: Colors.red,
            ),

            if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
              _buildInfoCard(
                icon: Icons.phone,
                title: 'Teléfono',
                content: cliente.telefono!,
                color: Colors.green,
              ),

            if (cliente.direccion != null && cliente.direccion!.isNotEmpty)
              _buildInfoCard(
                icon: Icons.location_on,
                title: 'Dirección',
                content: cliente.direccion!,
                color: Colors.orange,
              ),

            if (cliente.id != null)
              _buildInfoCard(
                icon: Icons.tag,
                title: 'ID Local',
                content: cliente.id.toString(),
                color: Colors.purple,
              ),

            _buildInfoCard(
              icon: Icons.access_time,
              title: 'Fecha de creación',
              content: cliente.fechaCreacion.toString().substring(0, 19),
              color: Colors.grey,
            ),

            _buildInfoCard(
              icon: cliente.estaSincronizado ? Icons.cloud_done : Icons.cloud_off,
              title: 'Estado de sincronización',
              content: cliente.estaSincronizado ? 'Sincronizado' : 'No sincronizado',
              color: cliente.estaSincronizado ? Colors.green : Colors.orange,
            ),

            SizedBox(height: 32),

            // Botón principal para enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _enviarCliente(context),
                icon: Icon(Icons.cloud_upload),
                label: Text('Enviar al Servidor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Información del servidor
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[700], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Información del servidor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Servidor: http://192.168.1.186:3000\n• Endpoint: POST /clientes\n• Los datos se enviarán en formato JSON\n• Para sincronización masiva, usa el Panel Principal',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
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
