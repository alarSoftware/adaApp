enum TipoOperacion {
  pedidoVenta,
  notaReposicion,
  notaRetiro,
  notaRetiroDiscontinuos,
  ventaDirecta,
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
      case TipoOperacion.ventaDirecta:
        return 'VENTA_DIRECTA';
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
      case TipoOperacion.ventaDirecta:
        return 'Venta Directa';
    }
  }

  // ✅ NUEVO: Getter para saber si el tipo de operación necesita fecha de retiro
  bool get necesitaFechaRetiro {
    return this == TipoOperacion.notaRetiro ||
        this == TipoOperacion.notaRetiroDiscontinuos;
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
      case 'VENTA_DIRECTA':
        return TipoOperacion.ventaDirecta;
      default:
        return TipoOperacion.pedidoVenta;
    }
  }
}