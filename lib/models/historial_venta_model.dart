class VentaHistorialModel {
  final String id;
  final dynamic fechaVentaRaw;
  final double subtotal;
  final double descuento;
  final double total;
  final String tipoVenta;
  final Map<String, dynamic> cliente;
  final List<Map<String, dynamic>> productos;
  final Map<String, dynamic> origen;
  final bool ocultarEnHistorial;
  final String foto;
  final String fotoBase64;

  VentaHistorialModel({
    required this.id,
    required this.fechaVentaRaw,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.tipoVenta,
    required this.cliente,
    required this.productos,
    required this.origen,
    required this.ocultarEnHistorial,
    required this.foto,
    required this.fotoBase64,
  });

  factory VentaHistorialModel.fromMap(Map<String, dynamic> m) {
    return VentaHistorialModel(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      fechaVentaRaw: m['fechaVenta'],
      subtotal: _toDouble(m['subtotal']),
      descuento: _toDouble(m['descuento']),
      total: _toDouble(m['total']),
      tipoVenta: (m['tipoVenta'] ?? '').toString(),
      cliente: (m['cliente'] as Map?)?.cast<String, dynamic>() ?? {},
      productos:
          (m['productos'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          [],
      origen: (m['origen'] as Map?)?.cast<String, dynamic>() ?? {},
      ocultarEnHistorial: m['ocultarEnHistorial'] == true,
      foto: (m['foto'] ?? '').toString(),
      fotoBase64: (m['fotoBase64'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'fechaVenta': fechaVentaRaw,
      'subtotal': subtotal,
      'descuento': descuento,
      'total': total,
      'tipoVenta': tipoVenta,
      'cliente': cliente,
      'productos': productos,
      'origen': origen,
      'ocultarEnHistorial': ocultarEnHistorial,
      'foto': foto,
      'fotoBase64': fotoBase64,
    };
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  @override
  String toString() => 'VentaHistorialModel(id: $id, total: $total)';
}
