class Venta {
  final String id;
  final DateTime fecha;
  final List<VentaItem> items;
  final double subtotal;
  final double descuento;
  final double total;
  //final String metodoPago;
  final VentaEstado estado;

  const Venta({
    required this.id,
    required this.fecha,
    required this.items,
    required this.subtotal,
    this.descuento = 0.0,
    required this.total,
    //required this.metodoPago,
    this.estado = VentaEstado.completada,
  });

  Venta copyWith({
    String? id,
    String? cliente,
    DateTime? fecha,
    List<VentaItem>? items,
    double? subtotal,
    double? descuento,
    double? total,
    //String? metodoPago,
    VentaEstado? estado,
  }) {
    return Venta(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      descuento: descuento ?? this.descuento,
      total: total ?? this.total,
      //metodoPago: metodoPago ?? this.metodoPago,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'descuento': descuento,
      'total': total,
    };
  }

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      items: (json['items'] as List)
          .map((item) => VentaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      descuento: (json['descuento'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num).toDouble(),
      //metodoPago: (json['metodoPago'] as String?) ?? MetodoPago.efectivo.name,
      estado: json['estado'] != null
          ? VentaEstado.values.firstWhere(
              (e) => e.name == json['estado'],
              orElse: () => VentaEstado.completada,
            )
          : VentaEstado.completada,
    );
  }
}

class VentaItem {
  final String productoId;
  final String nombre;
  final String? talla;
  final double precioUnitario;
  final double costoUnitario;
  final double subtotal;
  final double descuento; // descuento aplicado a este producto

  const VentaItem({
    required this.productoId,
    required this.nombre,
    this.talla,
    required this.precioUnitario,
    required this.costoUnitario,
    required this.subtotal,
    this.descuento = 0.0,
  });

  VentaItem copyWith({
    String? productoId,
    String? nombre,
    String? talla,
    double? precioUnitario,
    double? costoUnitario,
    double? subtotal,
    double? descuento,
  }) {
    return VentaItem(
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      talla: talla ?? this.talla,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      subtotal: subtotal ?? this.subtotal,
      descuento: descuento ?? this.descuento,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productoId': productoId,
      'nombre': nombre,
      if (talla != null) 'talla': talla,
      // Precio final de venta del producto
      'precioVenta': precioUnitario,
      // Descuento aplicado a este producto (si hubo)
      'descuento': descuento,
    };
  }

  factory VentaItem.fromJson(Map<String, dynamic> json) {
    // Soporta estructuras antiguas (precioUnitario/subtotal) y nuevas
    final rawPrecio = json['precioUnitario'] ?? json['precioVenta'] ?? 0;
    final doublePrecio = (rawPrecio is num)
        ? rawPrecio.toDouble()
        : double.tryParse('$rawPrecio') ?? 0.0;

    final rawCosto = json['costoUnitario'] ?? 0;
    final doubleCosto = (rawCosto is num)
        ? rawCosto.toDouble()
        : double.tryParse('$rawCosto') ?? 0.0;

    final rawSubtotal = json['subtotal'] ?? doublePrecio;
    final doubleSubtotal = (rawSubtotal is num)
        ? rawSubtotal.toDouble()
        : double.tryParse('$rawSubtotal') ?? doublePrecio;

    final rawDesc = json['descuento'] ?? 0;
    final doubleDesc = (rawDesc is num)
        ? rawDesc.toDouble()
        : double.tryParse('$rawDesc') ?? 0.0;

    return VentaItem(
      productoId: json['productoId'] as String,
      nombre: json['nombre'] as String,
      talla:
          (json['talla'] as String?) ?? (json['tallaSeleccionada'] as String?),
      precioUnitario: doublePrecio,
      costoUnitario: doubleCosto,
      subtotal: doubleSubtotal,
      descuento: doubleDesc,
    );
  }
}

enum VentaEstado { pendiente, completada, cancelada, devuelta }

enum MetodoPago { efectivo, tarjeta, transferencia, mixto }
