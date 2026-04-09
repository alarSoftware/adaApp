import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:android_id/android_id.dart';
class TechnicalInfoScreen extends StatefulWidget {
  const TechnicalInfoScreen({super.key});

  @override
  State<TechnicalInfoScreen> createState() => _TechnicalInfoScreenState();
}

class _TechnicalInfoScreenState extends State<TechnicalInfoScreen> {
  Map<String, String> _info = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      Platform.isAndroid ? const AndroidId().getId() : DeviceInfoHelper.obtenerIdUnicoDispositivo(),
      DeviceInfoHelper.obtenerModeloDispositivo(),
      DeviceInfoHelper.obtenerNivelBateria(),
      PackageInfo.fromPlatform(),
    ]);

    final packageInfo = results[3] as PackageInfo;

    setState(() {
      _info = {
        'ID de Dispositivo (Android ID)': results[0]?.toString() ?? 'No disponible',
        'Modelo': results[1].toString(),
        'Nivel de Batería': '${results[2]}%',
        'Versión de App': packageInfo.version,
      };
      _isLoading = false;
    });
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información Técnica'),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                ..._info.entries.map((e) => _buildInfoCard(e.key, e.value)),
                const SizedBox(height: 24),
                const Text(
                  'Esta información es útil para soporte técnico y depuración de errores.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.developer_mode, size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const Text(
          'Detalles del Dispositivo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
          onPressed: () => _copyToClipboard(label, value),
        ),
      ),
    );
  }
}
