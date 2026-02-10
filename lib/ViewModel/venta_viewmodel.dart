import 'package:flutter/material.dart';
import 'package:gestion_inventario/models/venta.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:gestion_inventario/utils/id_utils.dart';

/// ViewModel para la gestión de ventas.
/// Maneja la lógica de negocio para crear, modificar y gestionar ventas.
class VentaViewModel extends ChangeNotifier {
  // Lista de items en el carrito actual
  final List<VentaItem> _itemsCarrito = [];

  // Getters
  List<VentaItem> get itemsCarrito => List.unmodifiable(_itemsCarrito);
  int get totalPrendas => _itemsCarrito.length;

  double get subtotal =>
      _itemsCarrito.fold(0.0, (sum, item) => sum + item.subtotal);

  double get total => subtotal;

  bool get carritoVacio => _itemsCarrito.isEmpty;

  // Métodos para gestionar el carrito
  void agregarItem({
    required String productoId,
    required String nombre,
    required double precioUnitario,
    required double costoUnitario,
    String? talla,
    double descuentoProducto = 0.0,
  }) {
    // Cada llamada representa un producto vendido (1 unidad) con su talla
    final subtotal = precioUnitario; // 1 unidad por ítem

    _itemsCarrito.add(
      VentaItem(
        productoId: productoId,
        nombre: nombre,
        talla: talla,
        precioUnitario: precioUnitario,
        costoUnitario: costoUnitario,
        subtotal: subtotal,
        descuento: descuentoProducto,
      ),
    );

    notifyListeners();
  }

  void eliminarItem(int index) {
    if (index >= 0 && index < _itemsCarrito.length) {
      _itemsCarrito.removeAt(index);
      notifyListeners();
    }
  }

  void limpiarCarrito() {
    _itemsCarrito.clear();
    notifyListeners();
  }

  // Crear venta
  Venta crearVenta() {
    if (_itemsCarrito.isEmpty) {
      throw Exception('No se puede crear una venta sin items');
    }

    return Venta(
      id: IdUtils.generarId(),
      fecha: DateTime.now(),
      items: List.from(_itemsCarrito),
      subtotal: subtotal,
      total: total,
      estado: VentaEstado.completada,
    );
  }

  // Guardar venta (las tallas vendidas se actualizan desde la vista)
  Future<bool> guardarVenta() async {
    try {
      final venta = crearVenta();
      // Guardar la venta en la base de datos
      await MongoService().saveVenta(venta.toJson());

      limpiarCarrito();
      return true;
    } catch (e) {
      debugPrint('Error al guardar venta: $e');
      return false;
    }
  }

  // Cargar una venta existente para edición
  void cargarVenta(Venta venta) {
    _itemsCarrito.clear();
    _itemsCarrito.addAll(venta.items);
    notifyListeners();
  }
}
