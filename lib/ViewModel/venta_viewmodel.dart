import 'package:flutter/material.dart';
import 'package:gestion_inventario/models/venta.dart';
import 'package:gestion_inventario/utils/id_utils.dart';

/// ViewModel para la gestión de ventas.
/// Maneja la lógica de negocio para crear, modificar y gestionar ventas.
class VentaViewModel extends ChangeNotifier {
  // Lista de items en el carrito actual
  final List<VentaItem> _itemsCarrito = [];
  
  // Información del cliente
  String _cliente = 'Cliente General';
  
  // Método de pago seleccionado
  MetodoPago _metodoPago = MetodoPago.efectivo;
  
  // Descuento aplicado
  double _descuento = 0.0;
  
  // Notas adicionales
  String _notas = '';

  // Getters
  List<VentaItem> get itemsCarrito => List.unmodifiable(_itemsCarrito);
  String get cliente => _cliente;
  MetodoPago get metodoPago => _metodoPago;
  double get descuento => _descuento;
  String get notas => _notas;
  
  int get totalPrendas => _itemsCarrito.fold(0, (sum, item) => sum + item.cantidad);
  
  double get subtotal => _itemsCarrito.fold(
    0.0,
    (sum, item) => sum + item.subtotal,
  );
  
  double get total => subtotal - _descuento;
  
  double get gananciaTotal => _itemsCarrito.fold(
    0.0,
    (sum, item) => sum + item.ganancia,
  );

  bool get carritoVacio => _itemsCarrito.isEmpty;

  // Setters
  void setCliente(String nombre) {
    _cliente = nombre;
    notifyListeners();
  }

  void setMetodoPago(MetodoPago metodo) {
    _metodoPago = metodo;
    notifyListeners();
  }

  void setDescuento(double valor) {
    _descuento = valor.clamp(0.0, subtotal);
    notifyListeners();
  }

  void setNotas(String texto) {
    _notas = texto;
    notifyListeners();
  }

  // Métodos para gestionar el carrito
  void agregarItem({
    required String productoId,
    required String nombre,
    required int cantidad,
    required double precioUnitario,
    required double costoUnitario,
  }) {
    // Verificar si el producto ya está en el carrito
    final index = _itemsCarrito.indexWhere((item) => item.productoId == productoId);
    
    if (index >= 0) {
      // Actualizar cantidad del item existente
      final itemExistente = _itemsCarrito[index];
      final nuevaCantidad = itemExistente.cantidad + cantidad;
      final nuevoSubtotal = precioUnitario * nuevaCantidad;
      final nuevaGanancia = (precioUnitario - costoUnitario) * nuevaCantidad;
      
      _itemsCarrito[index] = itemExistente.copyWith(
        cantidad: nuevaCantidad,
        subtotal: nuevoSubtotal,
        ganancia: nuevaGanancia,
      );
    } else {
      // Agregar nuevo item
      final subtotal = precioUnitario * cantidad;
      final ganancia = (precioUnitario - costoUnitario) * cantidad;
      
      _itemsCarrito.add(VentaItem(
        productoId: productoId,
        nombre: nombre,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        costoUnitario: costoUnitario,
        subtotal: subtotal,
        ganancia: ganancia,
      ));
    }
    
    notifyListeners();
  }

  void actualizarCantidadItem(int index, int nuevaCantidad) {
    if (index < 0 || index >= _itemsCarrito.length) return;
    
    if (nuevaCantidad <= 0) {
      eliminarItem(index);
      return;
    }
    
    final item = _itemsCarrito[index];
    final nuevoSubtotal = item.precioUnitario * nuevaCantidad;
    final nuevaGanancia = (item.precioUnitario - item.costoUnitario) * nuevaCantidad;
    
    _itemsCarrito[index] = item.copyWith(
      cantidad: nuevaCantidad,
      subtotal: nuevoSubtotal,
      ganancia: nuevaGanancia,
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
    _cliente = 'Cliente General';
    _metodoPago = MetodoPago.efectivo;
    _descuento = 0.0;
    _notas = '';
    notifyListeners();
  }

  // Crear venta
  Venta crearVenta() {
    if (_itemsCarrito.isEmpty) {
      throw Exception('No se puede crear una venta sin items');
    }

    return Venta(
      id: IdUtils.generarId(),
      cliente: _cliente,
      fecha: DateTime.now(),
      items: List.from(_itemsCarrito),
      subtotal: subtotal,
      descuento: _descuento,
      total: total,
      ganancia: gananciaTotal,
      metodoPago: _metodoPago.name,
      notas: _notas.isEmpty ? null : _notas,
      estado: VentaEstado.completada,
    );
  }

  // Guardar venta (aquí se integraría con el servicio de base de datos)
  Future<bool> guardarVenta() async {
    try {
      final venta = crearVenta();
      
      // TODO: Integrar con MongoService para guardar la venta
      // await MongoService.instance.guardarVenta(venta);
      
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
    _cliente = venta.cliente;
    _metodoPago = MetodoPago.values.firstWhere(
      (m) => m.name == venta.metodoPago,
      orElse: () => MetodoPago.efectivo,
    );
    _descuento = venta.descuento;
    _notas = venta.notas ?? '';
    notifyListeners();
  }
}
