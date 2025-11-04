import 'package:flutter/material.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:intl/intl.dart';

class DeviceLogScreen extends StatefulWidget {
  final DeviceLogRepository repository;

  const DeviceLogScreen({
    Key? key,
    required this.repository,
  }) : super(key: key);

  @override
  State<DeviceLogScreen> createState() => _DeviceLogScreenState();
}

class _DeviceLogScreenState extends State<DeviceLogScreen> {
  List<DeviceLog> _logs = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarLogs();
  }

  Future<void> _cargarLogs() async {
    setState(() => _cargando = true);
    try {
      final logs = await widget.repository.obtenerTodos();
      setState(() => _logs = logs);
    } catch (e) {
      _mostrarError('Error al cargar registros: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
  }

  String _formatearFecha(String isoDate) {
    try {
      final fecha = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Dispositivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarLogs,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay registros aún',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Los datos se registran automáticamente',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: log.sincronizado == 1
                    ? Colors.green
                    : Colors.orange,
                child: Icon(
                  log.sincronizado == 1
                      ? Icons.cloud_done
                      : Icons.cloud_upload,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                log.modelo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('📍 ${log.latitudLongitud}'),
                  Text('🔋 ${log.bateria}%'),
                  Text(
                    '🕐 ${_formatearFecha(log.fechaRegistro)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}