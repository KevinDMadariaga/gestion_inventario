enum VentaTipo { venta, abono, cambio }

class VentaRecord {
  final String id;
  final String cliente;
  final DateTime fecha;
  final double total;
  final double ganancia;
  final int prendas;
  final VentaTipo tipo;

  const VentaRecord({
    required this.id,
    required this.cliente,
    required this.fecha,
    required this.total,
    required this.ganancia,
    required this.prendas,
    required this.tipo,
  });
}
