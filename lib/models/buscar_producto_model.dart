import 'product_model.dart';

class BuscarProductoModel {
  final ProductModel product;
  final Map<String, dynamic> raw;

  BuscarProductoModel(this.raw) : product = ProductModel.fromMap(raw);

  String get nombre => product.nombre ?? '';
  double get precioVenta => product.precioVenta ?? 0;
  double get precioDescuento => product.precioDescuento ?? 0;
  String get estado => product.estado ?? 'disponible';
  String get foto => product.foto ?? '';
}
