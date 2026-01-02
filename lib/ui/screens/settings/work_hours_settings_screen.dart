import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class WorkHoursSettingsScreen extends StatefulWidget {
  const WorkHoursSettingsScreen({super.key});

  @override
  State<WorkHoursSettingsScreen> createState() =>
      _WorkHoursSettingsScreenState();
}

class _WorkHoursSettingsScreenState extends State<WorkHoursSettingsScreen> {
  int _startHour = 9;
  int _endHour = 17;
  int _intervalMinutes = 5; // Default
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    // 1. Cargar la configuración persistida actualizada
    await DeviceLogBackgroundExtension.cargarConfiguracionHorario();

    // 2. Leer las variables estáticas actualizadas
    setState(() {
      _startHour = BackgroundLogConfig.horaInicio;
      _endHour = BackgroundLogConfig.horaFin;
      _intervalMinutes = BackgroundLogConfig.intervalo.inMinutes < 1
          ? 1
          : BackgroundLogConfig.intervalo.inMinutes;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_startHour >= _endHour) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('La hora de inicio debe ser menor a la hora de fin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await DeviceLogBackgroundExtension.guardarConfiguracionHorario(
        _startHour,
        _endHour,
        intervaloMinutos: _intervalMinutes,
      );

      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke("updateConfig");
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Configuración guardada correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración de Horario'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Horario de Monitoreo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Define en qué horario la aplicación debe registrar la ubicación y estado del dispositivo.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHourSelector(
                              'Hora Inicio',
                              _startHour,
                              (val) => setState(() => _startHour = val!),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildHourSelector(
                              'Hora Fin',
                              _endHour,
                              (val) => setState(() => _endHour = val!),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      Text(
                        'Intervalo entre registros: $_intervalMinutes min',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Slider(
                        value: _intervalMinutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '$_intervalMinutes min',
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          setState(() {
                            _intervalMinutes = value.round();
                          });
                        },
                      ),
                      Text(
                        'Frecuencia con la que se guardará la ubicación.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHourSelector(
    String label,
    int value,
    ValueChanged<int?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              items: List.generate(24, (index) {
                return DropdownMenuItem(
                  value: index,
                  child: Text(
                    '${index.toString().padLeft(2, '0')}:00',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
