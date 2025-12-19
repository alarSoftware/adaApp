// database_sync.dart
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class DatabaseSync {
  // ================================================================
  // SINCRONIZACIÓN SIMPLIFICADA CON TEMPLATE METHOD PATTERN
  // ================================================================

  Future<void> sincronizarClientes(
    Database db,
    List<dynamic> clientesAPI,
  ) async {
    await _sincronizarEntidades<dynamic>(
      db: db,
      tabla: 'clientes',
      datos: clientesAPI,
      nombreEntidad: 'Clientes',
      mapearEntidad: _mapearCliente,
      validarEntidad: _validarCliente,
      limpiarTabla: true,
    );
  }

  Future<void> sincronizarUsuarios(
    Database db,
    List<Map<String, dynamic>> usuariosMapas,
  ) async {
    await _sincronizarEntidades<Map<String, dynamic>>(
      db: db,
      tabla: 'Users',
      datos: usuariosMapas,
      nombreEntidad: 'Usuarios',
      mapearEntidad: _mapearUsuario,
      validarEntidad: _validarUsuario,
      limpiarTabla: true,
      usarReplace: true,
    );
  }

  Future<void> sincronizarMarcas(Database db, List<dynamic> marcasAPI) async {
    await _sincronizarEntidades<dynamic>(
      db: db,
      tabla: 'marcas',
      datos: marcasAPI,
      nombreEntidad: 'Marcas',
      mapearEntidad: _mapearMarca,
      validarEntidad: _validarEntidadBasica,
      limpiarTabla: false,
      usarReplace: true,
    );
  }

  Future<void> sincronizarModelos(Database db, List<dynamic> modelosAPI) async {
    await _sincronizarEntidades<dynamic>(
      db: db,
      tabla: 'modelos',
      datos: modelosAPI,
      nombreEntidad: 'Modelos',
      mapearEntidad: _mapearModelo,
      validarEntidad: _validarEntidadBasica,
      limpiarTabla: false,
      usarReplace: true,
    );
  }

  Future<void> sincronizarLogos(Database db, List<dynamic> logosAPI) async {
    await _sincronizarEntidades<dynamic>(
      db: db,
      tabla: 'logo',
      datos: logosAPI,
      nombreEntidad: 'Logos',
      mapearEntidad: _mapearLogo,
      validarEntidad: _validarEntidadBasica,
      limpiarTabla: false,
      usarReplace: true,
    );
  }

  Future<void> sincronizarUsuarioCliente(
    Database db,
    List<dynamic> usuarioClienteAPI,
  ) async {
    await _sincronizarEntidades<dynamic>(
      db: db,
      tabla: 'usuario_cliente',
      datos: usuarioClienteAPI,
      nombreEntidad: 'Usuario-Cliente',
      mapearEntidad: _mapearUsuarioCliente,
      validarEntidad: _validarEntidadBasica,
      limpiarTabla: true,
    );
  }

  // ================================================================
  // TEMPLATE METHOD GENÉRICO PARA SINCRONIZACIÓN
  // ================================================================

  Future<void> _sincronizarEntidades<T>({
    required Database db,
    required String tabla,
    required List<T> datos,
    required String nombreEntidad,
    required Map<String, dynamic>? Function(T) mapearEntidad,
    required bool Function(T) validarEntidad,
    bool limpiarTabla = false,
    bool usarReplace = false,
  }) async {
    logger.i('=== SINCRONIZANDO $nombreEntidad ===');
    logger.i('$nombreEntidad recibidos: ${datos.length}');

    await db.transaction((txn) async {
      if (limpiarTabla) {
        await txn.delete(tabla);
        logger.i('$nombreEntidad existentes eliminados');
      }

      int sincronizados = 0;
      int omitidos = 0;

      for (int i = 0; i < datos.length; i++) {
        final entidad = datos[i];

        if (!validarEntidad(entidad)) {
          logger.w('$nombreEntidad ${i + 1} omitido por validación');
          omitidos++;
          continue;
        }

        try {
          final mapa = mapearEntidad(entidad);
          if (mapa == null) {
            logger.w('$nombreEntidad ${i + 1} omitido - mapeo falló');
            omitidos++;
            continue;
          }

          if (usarReplace) {
            await txn.insert(
              tabla,
              mapa,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            await txn.insert(tabla, mapa);
          }

          sincronizados++;
        } catch (e) {
          logger.e(
            'Error insertando ${nombreEntidad.toLowerCase()} ${i + 1}: $e',
          );
          omitidos++;
        }
      }

      logger.i(
        '$nombreEntidad: $sincronizados sincronizados, $omitidos omitidos',
      );
    });

    logger.i('=== SINCRONIZACIÓN DE $nombreEntidad COMPLETADA ===');
  }

  // ================================================================
  // FUNCIONES DE MAPEO ESPECÍFICAS
  // ================================================================

  Map<String, dynamic>? _mapearCliente(dynamic clienteData) {
    if (clienteData['nombre'] == null ||
        clienteData['nombre'].toString().trim().isEmpty) {
      return null;
    }

    return {
      'id': clienteData['id'],
      'nombre': clienteData['nombre'].toString().trim(),
      'telefono': clienteData['telefono']?.toString().trim() ?? '',
      'direccion': clienteData['direccion']?.toString().trim() ?? '',
      'ruc_ci': clienteData['ruc_ci']?.toString().trim() ?? '',
      'propietario': clienteData['propietario']?.toString().trim() ?? '',
    };
  }

  Map<String, dynamic>? _mapearUsuario(Map<String, dynamic> usuarioMapa) {
    // Validar campos críticos
    final camposCriticos = ['code', 'username', 'password', 'fullname'];
    for (final campo in camposCriticos) {
      if (usuarioMapa[campo] == null) {
        logger.e('Campo requerido null: $campo');
        return null;
      }
    }

    return {
      'id': usuarioMapa['id'],
      'employee_id': usuarioMapa['employee_id'],
      'edf_vendedor_nombre': usuarioMapa['edfVendedorNombre']
          ?.toString(), // Corrected key
      'code': usuarioMapa['code'],
      'username': usuarioMapa['username'],
      'password': usuarioMapa['password'],
      'fullname': usuarioMapa['fullname'],
    };
  }

  Map<String, dynamic>? _mapearMarca(dynamic marcaData) {
    if (marcaData['marca'] == null) return null;

    return {'id': marcaData['id'], 'nombre': marcaData['marca']};
  }

  Map<String, dynamic>? _mapearModelo(dynamic modeloData) {
    if (modeloData['nombre'] == null ||
        modeloData['nombre'].toString().trim().isEmpty) {
      return null;
    }

    return {
      'id': modeloData['id'],
      'nombre': modeloData['nombre'].toString().trim(),
    };
  }

  Map<String, dynamic>? _mapearLogo(dynamic logoData) {
    if (logoData['logo'] == null) return null;

    return {'id': logoData['id'], 'nombre': logoData['logo']};
  }

  Map<String, dynamic>? _mapearUsuarioCliente(dynamic data) {
    if (data['usuario_id'] == null || data['cliente_id'] == null) return null;

    return {
      'id': data['id'],
      'usuario_id': data['usuario_id'],
      'cliente_id': data['cliente_id'],
    };
  }

  // ================================================================
  // FUNCIONES DE VALIDACIÓN
  // ================================================================

  bool _validarCliente(dynamic cliente) {
    return cliente != null && cliente['nombre'] != null;
  }

  bool _validarUsuario(Map<String, dynamic> usuario) {
    return usuario['code'] != null &&
        usuario['username'] != null &&
        usuario['password'] != null &&
        usuario['fullname'] != null;
  }

  bool _validarEntidadBasica(dynamic entidad) {
    return entidad != null && entidad['id'] != null;
  }
}
