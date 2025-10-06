// lib/screens/api_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _connectionStatus;
  bool? _connectionSuccess;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await ApiConfigService.getBaseUrl();
    setState(() {
      _urlController.text = url;
      _isLoading = false;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = null;
      _connectionSuccess = null;
    });

    final result = await BaseSyncService.testConnection();

    setState(() {
      _isTesting = false;
      _connectionStatus = result.mensaje;
      _connectionSuccess = result.exito;
    });

    _showMessage(
      result.mensaje,
      isError: !result.exito,
    );
  }

  Future<void> _saveUrl() async {
    final newUrl = _urlController.text.trim();

    if (newUrl.isEmpty) {
      _showMessage('Por favor ingresa una URL', isError: true);
      return;
    }

    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      _showMessage('La URL debe comenzar con http:// o https://', isError: true);
      return;
    }

    String cleanUrl = newUrl;
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    setState(() {
      _isSaving = true;
    });

    await ApiConfigService.setBaseUrl(cleanUrl);

    setState(() {
      _isSaving = false;
      _connectionStatus = null;
      _connectionSuccess = null;
    });

    _showMessage('URL guardada exitosamente');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración API')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Servidor'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.dns, size: 64, color: Colors.blue),
            const SizedBox(height: 24),

            const Text(
              'URL del Servidor adaControl',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'http://servidor:puerto/adaControl',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
                helperText: 'No incluyas "/" al final',
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
              minLines: 1,
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveUrl,
              icon: _isSaving
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: const Text('Guardar', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.wifi_find),
              label: const Text('Probar Conexión'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _urlController.text = ApiConfigService.defaultBaseUrl;
                  _connectionStatus = null;
                  _connectionSuccess = null;
                });
              },
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar por defecto'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            if (_connectionStatus != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _connectionSuccess == true
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _connectionSuccess == true
                            ? Icons.check_circle
                            : Icons.error,
                        color: _connectionSuccess == true
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connectionStatus!,
                          style: TextStyle(
                            fontSize: 14,
                            color: _connectionSuccess == true
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}