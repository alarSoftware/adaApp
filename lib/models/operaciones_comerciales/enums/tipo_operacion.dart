import 'package:ada_app/utils/unidad_medida_helper.dart';

enum TipoOperacion {
  pedidoVenta,
  notaReposicion,
  notaRetiro,
  notaRetiroDiscontinuos,
}

extension TipoOperacionExtension on TipoOperacion {
  String get valor {
    switch (this) {
      case TipoOperacion.pedidoVenta:
        return 'PEDIDO_VENTA';
      case TipoOperacion.notaReposicion:
        return 'REPOSICION';
      case TipoOperacion.notaRetiro:
        return 'NOTA_DE_RETIRO';
      case TipoOperacion.notaRetiroDiscontinuos:
        return 'NDR_DISCONTINUO';
    }
  }

  String get displayName {
    switch (this) {
      case TipoOperacion.pedidoVenta:
        return 'Pedido de Venta';
      case TipoOperacion.notaReposicion:
        return 'Nota de Reposición';
      case TipoOperacion.notaRetiro:
        return 'Nota de Retiro';
      case TipoOperacion.notaRetiroDiscontinuos:
        return 'Nota de Retiro Discontinuos';
    }
  }

  bool get necesitaFechaRetiro {
    return this == TipoOperacion.notaRetiro ||
        this == TipoOperacion.notaRetiroDiscontinuos ||
        this == TipoOperacion.notaReposicion;
  }

  bool get esNotaRetiro {
    return this == TipoOperacion.notaRetiro ||
        this == TipoOperacion.notaRetiroDiscontinuos;
  }

  bool get esNotaReposicion {
    return this == TipoOperacion.notaReposicion;
  }

  bool get requiereReemplazo {
    return this == TipoOperacion.notaRetiroDiscontinuos;
  }

  /// Valida si la unidad de medida es correcta para este tipo de operación
  /// Retorna null si es válido, o un mensaje de error si no lo es
  /// Valida si la unidad de medida es correcta para este tipo de operación
  /// Retorna null si es válido, o un mensaje de error si no lo es
  String? validarUnidadMedida(String unidadMedida) {
    // REGLA 1: Las notas de retiro SOLO pueden ser en unidades simples
    if (esNotaRetiro && !UnidadMedidaHelper.esUnidadSimple(unidadMedida)) {
      return 'Las notas de retiro solo pueden ser en unidades simples (Units)';
    }

    // REGLA 2: Las notas de reposición DEBEN ser en packs/cajas (no unidades simples)
    if (esNotaReposicion && !UnidadMedidaHelper.esPack(unidadMedida)) {
      return 'Las notas de reposición deben ser en packs/cajas (X 6, X 12, X 24, etc.)';
    }

    return null; // válido
  }

  static TipoOperacion fromString(String? tipo) {
    if (tipo == null) return TipoOperacion.pedidoVenta;

    switch (tipo.toUpperCase()) {
      case 'PEDIDO_VENTA':
        return TipoOperacion.pedidoVenta;
      case 'REPOSICION':
        return TipoOperacion.notaReposicion;
      case 'NOTA_DE_RETIRO':
        return TipoOperacion.notaRetiro;
      case 'NDR_DISCONTINUO':
        return TipoOperacion.notaRetiroDiscontinuos;
      default:
        return TipoOperacion.pedidoVenta;
    }
  }
}
