import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class Producto {
  final String id;
  final String nombre;
  final List<String> tallas;
  final String marca;
  final double precioCompra;
  final double precioVenta;
  final double precioMinimo;
  final DateTime fechaRegistro;
  final String foto;
  final String fotoBase64;
  final String fotoMime;
  final String estado;

  const Producto({
    required this.id,
    required this.nombre,
    required this.tallas,
    required this.marca,
    required this.precioCompra,
    required this.precioVenta,
    required this.precioMinimo,
    required this.fechaRegistro,
    required this.foto,
    required this.fotoBase64,
    required this.fotoMime,
    required this.estado,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    final dynamic idRaw = json['_id'];
    final String idStr = idRaw is ObjectId
        ? idRaw.toHexString()
        : idRaw?.toString() ?? '';

    // Normalizamos tallas a una sola lista, soportando tanto
    // el esquema nuevo (tallas: [...]) como el viejo (talla: '6, 8, 10').
    final List<String> tallas = <String>[];
    final dynamic tallasRaw = json['tallas'];
    if (tallasRaw is List) {
      for (final t in tallasRaw) {
        final s = t.toString().trim();
        if (s.isNotEmpty) tallas.add(s);
      }
    } else {
      final String tallaTextoLegacy = (json['talla'] ?? '').toString();
      if (tallaTextoLegacy.isNotEmpty) {
        for (final t in tallaTextoLegacy.split(',')) {
          final s = t.trim();
          if (s.isNotEmpty) tallas.add(s);
        }
      }
    }

    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    DateTime _asDate(dynamic v) {
      if (v is DateTime) return v;
      try {
        return DateTime.parse('$v');
      } catch (_) {
        return DateTime.now();
      }
    }

    return Producto(
      id: idStr,
      nombre: (json['nombre'] ?? '').toString(),
      tallas: tallas,
      marca: (json['marca'] ?? '').toString(),
      precioCompra: _asDouble(json['precioCompra']),
      precioVenta: _asDouble(json['precioVenta']),
      precioMinimo: _asDouble(json['precioMinimo']),
      fechaRegistro: _asDate(json['fechaRegistro']),
      foto: (json['foto'] ?? '').toString(),
      fotoBase64: (json['fotoBase64'] ?? '').toString(),
      fotoMime: (json['fotoMime'] ?? '').toString(),
      estado: (json['estado'] ?? 'disponible').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'tallas': tallas,
      'marca': marca,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'precioMinimo': precioMinimo,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'foto': foto,
      'fotoBase64': fotoBase64,
      'fotoMime': fotoMime,
      'estado': estado,
    };

    // Si viene un id (por ejemplo al editar), lo propagamos al _id de Mongo
    if (id.isNotEmpty) {
      try {
        map['_id'] = ObjectId.fromHexString(id);
      } catch (_) {
        // Si no es un ObjectId válido, lo guardamos como String plano
        map['_id'] = id;
      }
    }

    return map;
  }
}
