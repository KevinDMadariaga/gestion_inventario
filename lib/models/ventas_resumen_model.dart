enum RangoResumen { semana, mes, anio }

enum CategoriaChart { todos, ventas, abonos, cambios, apartados }

enum VentaTipo { venta, abono, cambio }

class VentaRecord {
  final String id;
  final String cliente;
  final DateTime fecha;
  final double total;
  final double ganancia;
  final int prendas;
  final VentaTipo tipo;

  VentaRecord({
    required this.id,
    required this.cliente,
    required this.fecha,
    required this.total,
    required this.ganancia,
    required this.prendas,
    required this.tipo,
  });
}

class ApartadoRecord {
  final String id;
  final String cliente;
  final DateTime fecha;
  final double valorTotal;

  ApartadoRecord({
    required this.id,
    required this.cliente,
    required this.fecha,
    required this.valorTotal,
  });
}
