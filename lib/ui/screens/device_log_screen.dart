import 'package:flutter/material.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';

class DeviceLogScreen extends StatefulWidget {
  final DeviceLogRepository repository;

  const DeviceLogScreen({Key? key, required this.repository}) : super(key: key);

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
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
      body: Column(
        children: [
          _buildDiagnosticHeader(),
          Expanded(
            child: _cargando
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
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticHeader() {
    return FutureBuilder<Map<String, dynamic>>(
      future: DeviceLogBackgroundExtension.obtenerEstado(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final estado = snapshot.data!;

        final ultimoLog = estado['ultimo_log'] != null
            ? _formatearFecha(estado['ultimo_log'])
            : 'Ninguno';

        return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Diagnóstico',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {});
                    },
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statusChip('Servicio (Process)', estado['activo']),
                  _statusChip('Actividad Reciente', estado['timer_activo']),
                  _statusChip('Sesión', estado['sesion_activa']),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statusChip('Horario', estado['en_horario']),
                  Expanded(
                    child: Text(
                      'Último: $ultimoLog',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ),
                ],
              ),
              if (estado['activo'] == false)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ El servicio background está DETENIDO.',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(String label, bool active) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
