class ProductModel {
  String? nombre;
  String? talla;
  String? categoria;
  String? marca;
  double? precioCompra;
  double? precioVenta;
  double? precioDescuento;
  DateTime? fechaRegistro;
  String? foto;
  String? fotoBase64;
  String? fotoMime;
  String? estado;

  ProductModel({
    this.nombre,
    this.talla,
    this.categoria,
    this.marca,
    this.precioCompra,
    this.precioVenta,
    this.precioDescuento,
    DateTime? fechaRegistro,
    this.foto,
    this.fotoBase64,
    this.fotoMime,
    this.estado,
  }) : fechaRegistro = fechaRegistro ?? DateTime.now();

  factory ProductModel.fromMap(Map<String, dynamic> m) {
    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim().replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(s);
    }

    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return ProductModel(
      nombre: (m['nombre'] ?? m['name'])?.toString(),
      talla: (m['talla'] ?? '')?.toString(),
      categoria: (m['categoria'] ?? '')?.toString(),
      marca: (m['marca'] ?? '')?.toString(),
      precioCompra: _toDouble(m['precioCompra']),
      precioVenta: _toDouble(m['precioVenta']),
      precioDescuento: _toDouble(m['precioDescuento']),
      fechaRegistro: _toDate(m['fechaRegistro']),
      foto: (m['foto'] ?? '')?.toString(),
      fotoBase64: (m['fotoBase64'] ?? '')?.toString(),
      fotoMime: (m['fotoMime'] ?? '')?.toString(),
      estado: (m['estado'] ?? 'disponible')?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre ?? '',
      'talla': talla ?? '',
      'categoria': categoria ?? '',
      'marca': marca ?? '',
      'precioCompra': precioCompra ?? 0,
      'precioVenta': precioVenta ?? 0,
      'precioDescuento': precioDescuento ?? 0,
      'fechaRegistro':
          fechaRegistro?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'foto': foto ?? '',
      'fotoBase64': fotoBase64 ?? '',
      'fotoMime': fotoMime ?? 'image/jpeg',
      'estado': estado ?? 'disponible',
    };
  }
}
