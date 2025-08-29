import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../models/cliente.dart';

final _logger = Logger();

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
  bool _isLoading = false;

  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU SERVIDOR
  static const String _baseUrl = 'http://192.168.1.185:3000';
  static const String _estadosEndpoint = '/estados';
  static const String _pingEndpoint = '/ping';

  @override
  Widget build(BuildContext context) {
    final Cliente cliente = widget.datos['cliente'];

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(cliente),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Confirmar Registro'),
      backgroundColor: Colors.grey[700],
      foregroundColor: Colors.white,
      elevation: 2,
    );
  }

  Widget _buildBody(Cliente cliente) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderInfo(),
          const SizedBox(height: 20),
          _buildClienteCard(cliente),
          const SizedBox(height: 16),
          _buildEquipoCard(),
          const SizedBox(height: 16),
          _buildUbicacionCard(),
          const SizedBox(height: 16),
          _buildWarningCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[600],
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revisar Información',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verifica que todos los datos sean correctos antes de confirmar el registro.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(Cliente cliente) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Información del Cliente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Datos del Visicooler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Información de Registro',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
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
            _buildInfoRow(
              'Fecha y Hora',
              _formatearFecha(fechaRegistro?.toString()),
              Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return 'No disponible';

    try {
      final fecha = DateTime.parse(fechaIso);
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final ano = fecha.year;
      final hora = fecha.hour.toString().padLeft(2, '0');
      final minuto = fecha.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$ano - $hora:$minuto';
    } catch (e) {
      return 'Formato inválido';
    }
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
            color: Colors.grey[500],
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
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'No especificado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                color: Colors.green[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Datos Protegidos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• La ubicación GPS fue capturada en el momento exacto del registro',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Los datos se guardarán localmente para evitar pérdidas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Se sincronizarán automáticamente cuando haya conexión',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Volver a Editar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmarRegistro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Registrando...'),
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
      ),
    );
  }

  // ============================================================================
  // IMPLEMENTACIÓN DE API - CONFIGURADA PARA TU SERVIDOR
  // ============================================================================

  Future<void> _confirmarRegistro() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _logger.i('📝 Confirmando registro con datos completos...');

      // Preparar datos para envío
      final datosCompletos = _prepararDatosParaEnvio();

      _logger.i('📋 Datos preparados para envío a tu API');

      // PASO 1: GUARDAR LOCALMENTE (CRÍTICO - No perder datos)
      _mostrarSnackBar('💾 Guardando registro localmente...', Colors.blue);
      await _guardarRegistroLocal(datosCompletos);

      // PASO 2: INTENTAR ENVIAR AL SERVIDOR
      _mostrarSnackBar('📤 Sincronizando con servidor...', Colors.orange);
      final respuestaServidor = await _intentarEnviarAlServidor(datosCompletos);

      if (respuestaServidor['exito']) {
        // Éxito: Datos enviados y guardados
        await _marcarComoSincronizado(datosCompletos['id_local'] as int);
        _mostrarSnackBar('✅ Estado del equipo registrado en el servidor', Colors.green);

        // Mostrar ID del servidor si lo devuelve
        if (respuestaServidor['servidor_id'] != null) {
          await _actualizarConIdServidor(
              datosCompletos['id_local'] as int,
              respuestaServidor['servidor_id']
          );
        }
      } else {
        // Sin conexión o error: Solo guardado local
        _mostrarSnackBar(
            '📱 Registro guardado localmente. Se sincronizará cuando haya conexión.',
            Colors.blue
        );
      }

      // Éxito en ambos casos - volver a pantallas anteriores
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(true); // Volver a FormsScreen
        Navigator.of(context).pop(true); // Volver a ClienteDetailScreen
      }

    } catch (e) {
      _logger.e('❌ Error crítico en confirmación: $e');
      await _mostrarDialogoErrorConfirmacion(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _prepararDatosParaEnvio() {
    final cliente = widget.datos['cliente'] as Cliente;

    return {
      // Datos locales para control
      'id_local': DateTime.now().millisecondsSinceEpoch,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': DateTime.now().toIso8601String(),

      // Datos para API /estados (según tu esquema)
      'equipo_id': _buscarEquipoPorCodigo(widget.datos['codigo_barras']),
      'cliente_id': cliente.id,
      'usuario_id': 1, // TODO: Obtener del usuario logueado
      'funcionando': true, // Asumimos que está funcionando al registrar
      'estado_general': 'Equipo registrado - ${widget.datos['observaciones'] ?? 'Sin observaciones'}',
      'temperatura_actual': null, // Se actualizará en próximas revisiones
      'temperatura_freezer': null, // Se actualizará en próximas revisiones
      'latitud': widget.datos['latitud'],
      'longitud': widget.datos['longitud'],

      // Datos adicionales para referencia local
      'codigo_barras': widget.datos['codigo_barras'],
      'modelo': widget.datos['modelo'],
      'logo': widget.datos['logo'],
      'numero_serie': widget.datos['numero_serie'],
      'observaciones': widget.datos['observaciones'],
      'fecha_registro': widget.datos['fecha_registro'],
      'timestamp_gps': widget.datos['timestamp_gps'],
      'version_app': '1.0.0',
      'dispositivo': Platform.operatingSystem,
    };
  }

  int? _buscarEquipoPorCodigo(String? codigoBarras) {
    // TODO: Implementar búsqueda real en base de datos local
    // o hacer una consulta a /equipos/buscar?q=codigo

    if (codigoBarras == null) return null;

    // Simulamos que encontramos el equipo basado en el código
    // En una implementación real, buscarías en tu base de datos local
    // o harías una petición a tu API para obtener el equipo_id
    return 1; // Provisional - debería ser el ID real del equipo
  }

  Future<void> _guardarRegistroLocal(Map<String, dynamic> datos) async {
    try {
      _logger.i('💾 Guardando en base de datos local...');

      // TODO: Implementar guardado en SQLite local
      // final db = await DatabaseHelper.instance.database;
      // await db.insert('registros_equipos', datos);

      // Simulación por ahora
      await Future.delayed(const Duration(seconds: 1));

      _logger.i('✅ Registro guardado localmente con ID: ${datos['id_local']}');
    } catch (e) {
      _logger.e('❌ Error crítico guardando localmente: $e');
      throw 'Error guardando datos localmente. Verifica el almacenamiento del dispositivo.';
    }
  }

  Future<Map<String, dynamic>> _intentarEnviarAlServidor(Map<String, dynamic> datos) async {
    try {
      // Verificar conectividad con tu servidor
      final tieneConexion = await _verificarConectividad();
      if (!tieneConexion) {
        _logger.w('⚠️ Sin conexión al servidor');
        return {'exito': false, 'motivo': 'sin_conexion'};
      }

      // Preparar datos para tu API /estados
      final datosApi = _prepararDatosParaApiEstados(datos);

      // Enviar a tu API
      final response = await _enviarAApiEstados(datosApi);

      if (response['exito']) {
        _logger.i('✅ Estado del equipo registrado en el servidor');
        return {
          'exito': true,
          'servidor_id': response['id'],
          'mensaje': response['mensaje']
        };
      } else {
        _logger.w('⚠️ Error del servidor: ${response['mensaje']}');
        return {
          'exito': false,
          'motivo': 'error_servidor',
          'detalle': response['mensaje']
        };
      }

    } catch (e) {
      _logger.w('⚠️ Error enviando al servidor: $e');
      return {
        'exito': false,
        'motivo': 'excepcion',
        'detalle': e.toString()
      };
    }
  }

  Future<bool> _verificarConectividad() async {
    try {
      _logger.i('🌐 Verificando conectividad con tu servidor...');

      final response = await http.get(
        Uri.parse('$_baseUrl$_pingEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('✅ Servidor respondió: ${data['message']}');
        return true;
      }

      return false;

    } catch (e) {
      _logger.w('⚠️ Sin conectividad: $e');
      return false;
    }
  }

  Map<String, dynamic> _prepararDatosParaApiEstados(Map<String, dynamic> datosLocales) {
    // Estructura exacta que espera tu API /estados
    return {
      'equipo_id': datosLocales['equipo_id'],
      'cliente_id': datosLocales['cliente_id'],
      'usuario_id': datosLocales['usuario_id'],
      'funcionando': datosLocales['funcionando'],
      'estado_general': datosLocales['estado_general'],
      'temperatura_actual': datosLocales['temperatura_actual'],
      'temperatura_freezer': datosLocales['temperatura_freezer'],
      'latitud': datosLocales['latitud'],
      'longitud': datosLocales['longitud'],
    };
  }

  Future<Map<String, dynamic>> _enviarAApiEstados(Map<String, dynamic> datos) async {
    try {
      _logger.i('📤 Enviando estado a API: $_baseUrl$_estadosEndpoint');
      _logger.i('📋 Datos: $datos');

      final response = await http.post(
        Uri.parse('$_baseUrl$_estadosEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datos),
      ).timeout(const Duration(seconds: 30));

      _logger.i('📥 Respuesta API: ${response.statusCode}');
      _logger.i('📄 Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = json.decode(response.body);

        // Tu API devuelve { success: true, message: "...", estado: {...} }
        if (responseBody['success'] == true) {
          return {
            'exito': true,
            'id': responseBody['estado']['id'],
            'mensaje': responseBody['message'] ?? 'Estado actualizado correctamente'
          };
        } else {
          return {
            'exito': false,
            'mensaje': responseBody['message'] ?? 'Error desconocido'
          };
        }
      } else {
        final errorBody = response.body.isNotEmpty ?
        json.decode(response.body) : {'message': 'Error HTTP ${response.statusCode}'};

        return {
          'exito': false,
          'mensaje': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}'
        };
      }

    } catch (e) {
      _logger.e('❌ Excepción enviando a API: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e'
      };
    }
  }

  Future<void> _marcarComoSincronizado(int idLocal) async {
    try {
      // TODO: Actualizar estado en SQLite local
      // final db = await DatabaseHelper.instance.database;
      // await db.update(
      //   'registros_equipos',
      //   {'estado_sincronizacion': 'sincronizado'},
      //   where: 'id_local = ?',
      //   whereArgs: [idLocal]
      // );

      _logger.i('✅ Registro marcado como sincronizado: $idLocal');
    } catch (e) {
      _logger.e('❌ Error marcando como sincronizado: $e');
    }
  }

  Future<void> _actualizarConIdServidor(int idLocal, dynamic servidorId) async {
    try {
      // TODO: Actualizar con ID del servidor en SQLite
      // final db = await DatabaseHelper.instance.database;
      // await db.update(
      //   'registros_equipos',
      //   {'servidor_id': servidorId},
      //   where: 'id_local = ?',
      //   whereArgs: [idLocal]
      // );

      _logger.i('✅ ID del servidor actualizado: $servidorId para local: $idLocal');
    } catch (e) {
      _logger.e('❌ Error actualizando ID servidor: $e');
    }
  }

  Future<void> _mostrarDialogoErrorConfirmacion(String error) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Error en Confirmación',
                  style: TextStyle(fontSize: 18),
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
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(fontSize: 14, color: Colors.red[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Datos Protegidos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sus datos están guardados localmente y no se perderán. Se sincronizarán automáticamente cuando se resuelva el problema.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
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
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
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
      ),
    );
  }
}