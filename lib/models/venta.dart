class Venta {
  final String id;
  final String cliente;
  final DateTime fecha;
  final List<VentaItem> items;
  final double subtotal;
  final double descuento;
  final double total;
  final double ganancia;
  final String metodoPago;
  final String? notas;
  final VentaEstado estado;

  const Venta({
    required this.id,
    required this.cliente,
    required this.fecha,
    required this.items,
    required this.subtotal,
    this.descuento = 0.0,
    required this.total,
    required this.ganancia,
    required this.metodoPago,
    this.notas,
    this.estado = VentaEstado.completada,
  });

  int get totalPrendas => items.fold(0, (sum, item) => sum + item.cantidad);

  Venta copyWith({
    String? id,
    String? cliente,
    DateTime? fecha,
    List<VentaItem>? items,
    double? subtotal,
    double? descuento,
    double? total,
    double? ganancia,
    String? metodoPago,
    String? notas,
    VentaEstado? estado,
  }) {
    return Venta(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      fecha: fecha ?? this.fecha,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      descuento: descuento ?? this.descuento,
      total: total ?? this.total,
      ganancia: ganancia ?? this.ganancia,
      metodoPago: metodoPago ?? this.metodoPago,
      notas: notas ?? this.notas,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'descuento': descuento,
      'total': total,
      'ganancia': ganancia,
      'metodoPago': metodoPago,
    };
  }

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] as String,
      cliente: (json['cliente'] as String?) ?? 'Cliente General',
      fecha: DateTime.parse(json['fecha'] as String),
      items: (json['items'] as List)
          .map((item) => VentaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      descuento: (json['descuento'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num).toDouble(),
      ganancia: (json['ganancia'] as num).toDouble(),
      metodoPago: (json['metodoPago'] as String?) ?? MetodoPago.efectivo.name,
      notas: json['notas'] as String?,
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
  final int cantidad;
  final double precioUnitario;
  final double costoUnitario;
  final double subtotal;
  final double ganancia;

  const VentaItem({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.costoUnitario,
    required this.subtotal,
    required this.ganancia,
  });

  VentaItem copyWith({
    String? productoId,
    String? nombre,
    int? cantidad,
    double? precioUnitario,
    double? costoUnitario,
    double? subtotal,
    double? ganancia,
  }) {
    return VentaItem(
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      subtotal: subtotal ?? this.subtotal,
      ganancia: ganancia ?? this.ganancia,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productoId': productoId,
      'nombre': nombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'costoUnitario': costoUnitario,
      'subtotal': subtotal,
      'ganancia': ganancia,
    };
  }

  factory VentaItem.fromJson(Map<String, dynamic> json) {
    return VentaItem(
      productoId: json['productoId'] as String,
      nombre: json['nombre'] as String,
      cantidad: json['cantidad'] as int,
      precioUnitario: (json['precioUnitario'] as num).toDouble(),
      costoUnitario: (json['costoUnitario'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      ganancia: (json['ganancia'] as num).toDouble(),
    );
  }
}

enum VentaEstado { pendiente, completada, cancelada, devuelta }

enum MetodoPago { efectivo, tarjeta, transferencia, mixto }
