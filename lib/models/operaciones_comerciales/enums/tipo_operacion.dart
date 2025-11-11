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
        return 'NOTA_REPOSICION';
      case TipoOperacion.notaRetiro:
        return 'NOTA_RETIRO';
      case TipoOperacion.notaRetiroDiscontinuos:
        return 'NOTA_RETIRO_DISCONTINUOS';
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
      case 'NOTA_REPOSICION':
        return TipoOperacion.notaReposicion;
      case 'NOTA_RETIRO':
        return TipoOperacion.notaRetiro;
      case 'NOTA_RETIRO_DISCONTINUOS':
        return TipoOperacion.notaRetiroDiscontinuos;
      case 'VENTA_DIRECTA':
        return TipoOperacion.ventaDirecta;
      default:
        return TipoOperacion.pedidoVenta;
    }
  }
}