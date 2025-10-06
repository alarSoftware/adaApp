// lib/ui/screens/sync_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SyncPanelScreen extends StatefulWidget {
  const SyncPanelScreen({super.key});

  @override
  State<SyncPanelScreen> createState() => _SyncPanelScreenState();
}

class _SyncPanelScreenState extends State<SyncPanelScreen> {
  final EstadoEquipoRepository _estadoRepo = EstadoEquipoRepository();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();

  bool _isLoading = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _registrosPendientes = [];
  List<Map<String, dynamic>> _registrosError = [];
  int _totalPendientes = 0;
  int _totalErrores = 0;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener registros con estado "creado" (pendientes)
      final pendientes = await _estadoRepo.obtenerCreados();

      // Obtener registros con estado "error"
      final errores = await _estadoRepo.obtenerConError();

      setState(() {
        _registrosPendientes = pendientes.map((estado) => {
          'id': estado.id,
          'equipo_id': estado.equipoId,
          'cliente_id': estado.clienteId,
          'fecha_revision': estado.fechaRevision,
          'observaciones': estado.observaciones,
          'estado': 'pendiente',
        }).toList();

        _registrosError = errores.map((estado) => {
          'id': estado.id,
          'equipo_id': estado.equipoId,
          'cliente_id': estado.clienteId,
          'fecha_revision': estado.fechaRevision,
          'observaciones': estado.observaciones,
          'estado': 'error',
        }).toList();

        _totalPendientes = _registrosPendientes.length;
        _totalErrores = _registrosError.length;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error cargando estadísticas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarTodos() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final usuario = await _authService.getCurrentUser();
      final usuarioId = usuario?.id ?? 1;
      final edfVendedorId = usuario?.edfVendedorId;

      int exitosos = 0;
      int fallidos = 0;

      // Sincronizar pendientes
      for (final registro in _registrosPendientes) {
        final resultado = await _enviarRegistro(registro, usuarioId, edfVendedorId);
        if (resultado) {
          exitosos++;
        } else {
          fallidos++;
        }
      }

      // Sincronizar errores
      for (final registro in _registrosError) {
        final resultado = await _enviarRegistro(registro, usuarioId, edfVendedorId);
        if (resultado) {
          exitosos++;
        } else {
          fallidos++;
        }
      }

      _mostrarMensaje(
        'Sincronización completada: $exitosos exitosos, $fallidos fallidos',
        exitosos > 0,
      );

      await _cargarEstadisticas();
    } catch (e) {
      _logger.e('Error en sincronización masiva: $e');
      _mostrarMensaje('Error en sincronización: $e', false);
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<bool> _enviarRegistro(
      Map<String, dynamic> registro,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final now = DateTime.now().toLocal();
      final timestampId = now.millisecondsSinceEpoch;

      final datosParaApi = {
        'id': timestampId.toString(),
        'edfVendedorSucursalId': edfVendedorId ?? '',
        'edfEquipoId': registro['equipo_id']?.toString() ?? '',
        'usuarioId': usuarioId,
        'edfClienteId': registro['cliente_id'] ?? 0,
        'fecha_revision': registro['fecha_revision']?.toString() ?? now.toIso8601String(),
        'latitud': 0.0,
        'longitud': 0.0,
        'enLocal': true,
        'fechaDeRevision': registro['fecha_revision']?.toString() ?? now.toIso8601String(),
        'estadoCenso': 'pendiente',
        'observaciones': registro['observaciones'] ?? 'Sincronización automática',
        'cliente_id': registro['cliente_id'] ?? 0,
        'usuario_id': usuarioId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/censoActivo/insertCensoActivo'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datosParaApi),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        dynamic servidorId = timestampId;
        try {
          final responseBody = json.decode(response.body);
          servidorId = responseBody['estado']?['id'] ??
              responseBody['id'] ??
              responseBody['insertId'] ??
              servidorId;
        } catch (e) {
          _logger.w('No se pudo parsear respuesta: $e');
        }

        await _estadoRepo.marcarComoMigrado(
          registro['id'],
          servidorId: servidorId,
        );

        _logger.i('Registro ${registro['id']} sincronizado exitosamente');
        return true;
      } else {
        await _estadoRepo.marcarComoError(
          registro['id'],
          'Error del servidor: ${response.statusCode}',
        );
        _logger.w('Error sincronizando ${registro['id']}: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Excepción sincronizando registro ${registro['id']}: $e');
      await _estadoRepo.marcarComoError(
        registro['id'],
        'Excepción: $e',
      );
      return false;
    }
  }

  Future<void> _reintentarRegistro(Map<String, dynamic> registro) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final usuario = await _authService.getCurrentUser();
      final usuarioId = usuario?.id ?? 1;
      final edfVendedorId = usuario?.edfVendedorId;

      final resultado = await _enviarRegistro(registro, usuarioId, edfVendedorId);

      _mostrarMensaje(
        resultado
            ? 'Registro sincronizado correctamente'
            : 'Error al sincronizar registro',
        resultado,
      );

      await _cargarEstadisticas();
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _mostrarMensaje(String mensaje, bool exito) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: exito ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Sincronización'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _cargarEstadisticas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _cargarEstadisticas,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildResumenCard(),
                const SizedBox(height: 16),
                _buildBotonSincronizar(),
                const SizedBox(height: 24),
                if (_totalPendientes > 0) ...[
                  _buildSeccionHeader('Registros Pendientes', _totalPendientes, AppColors.warning),
                  const SizedBox(height: 8),
                  ..._registrosPendientes.map((r) => _buildRegistroCard(r)),
                  const SizedBox(height: 16),
                ],
                if (_totalErrores > 0) ...[
                  _buildSeccionHeader('Registros con Error', _totalErrores, AppColors.error),
                  const SizedBox(height: 8),
                  ..._registrosError.map((r) => _buildRegistroCard(r)),
                ],
                if (_totalPendientes == 0 && _totalErrores == 0) ...[
                  _buildEmptyState(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumenCard() {
    final total = _totalPendientes + _totalErrores;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              total > 0 ? Icons.cloud_upload : Icons.cloud_done,
              size: 48,
              color: total > 0 ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              total > 0
                  ? '$total registro${total == 1 ? '' : 's'} sin sincronizar'
                  : 'Todo sincronizado',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildEstadoChip('Pendientes', _totalPendientes, AppColors.warning),
                  const SizedBox(width: 12),
                  _buildEstadoChip('Errores', _totalErrores, AppColors.error),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBotonSincronizar() {
    final total = _totalPendientes + _totalErrores;
    if (total == 0) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: _isSyncing ? null : _sincronizarTodos,
      icon: _isSyncing
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : const Icon(Icons.cloud_upload),
      label: Text(
        _isSyncing ? 'Sincronizando...' : 'Sincronizar Todo',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildSeccionHeader(String titulo, int count, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 8),
        Text(
          '$titulo ($count)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistroCard(Map<String, dynamic> registro) {
    final esError = registro['estado'] == 'error';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          esError ? Icons.error : Icons.schedule,
          color: esError ? AppColors.error : AppColors.warning,
        ),
        title: Text('Equipo: ${registro['equipo_id'] ?? 'N/A'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente ID: ${registro['cliente_id'] ?? 'N/A'}'),
            if (registro['observaciones'] != null)
              Text(
                'Obs: ${registro['observaciones']}',
                style: const TextStyle(fontSize: 12),
              ),
            if (esError && registro['mensaje_error'] != null)
              Text(
                'Error: ${registro['mensaje_error']}',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
          ],
        ),
        trailing: esError
            ? IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isSyncing ? null : () => _reintentarRegistro(registro),
          tooltip: 'Reintentar',
        )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.cloud_done, size: 80, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'Todos los registros están sincronizados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}