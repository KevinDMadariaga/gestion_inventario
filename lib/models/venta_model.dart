class VentaLinea {
  final String productoId;
  final String nombre;
  final double precioVendido;
  final double precioVendidoNeto;
  final double precioCompra;
  final double gananciaLinea;
  final String fotoBase64;
  final String foto;
  final String? sku;
  final String? talla;
  final String? color;

  VentaLinea({
    required this.productoId,
    required this.nombre,
    required this.precioVendido,
    required this.precioVendidoNeto,
    required this.precioCompra,
    required this.gananciaLinea,
    required this.fotoBase64,
    required this.foto,
    this.sku,
    this.talla,
    this.color,
  });
}

class VentaModel {
  final String clienteNombre;
  final String clienteTelefono;
  final List<VentaLinea> productos;
  final double subtotal;
  final double descuento;
  final double total;
  final double gananciaTotal;
  final DateTime fechaVenta;

  VentaModel({
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.productos,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.gananciaTotal,
    required this.fechaVenta,
  });
}
