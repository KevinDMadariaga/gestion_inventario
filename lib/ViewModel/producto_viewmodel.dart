import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

class ProductoViewModel extends ChangeNotifier {
  String? nombre;
  String? talla;
  String? marca;
  double? precioCompra;
  double? precioVenta;
  double? precioMinimo;
  String? fotoBase64;
  String? fotoPath;
  DateTime fechaRegistro = DateTime.now();
  bool _guardando = false;

  bool get guardando => _guardando;

  void setNombre(String value) {
    nombre = value.trim();
    notifyListeners();
  }

  void setTalla(String value) {
    talla = value.trim();
    notifyListeners();
  }

  void setMarca(String value) {
    marca = value.trim();
    notifyListeners();
  }

  void setPrecioCompra(double value) {
    precioCompra = value;
    notifyListeners();
  }

  void setPrecioVenta(double value) {
    precioVenta = value;
    notifyListeners();
  }

  void setPrecioMinimo(double value) {
    precioMinimo = value;
    notifyListeners();
  }

  void setFoto(String? base64, String? path) {
    fotoBase64 = base64;
    fotoPath = path;
    notifyListeners();
  }

  void limpiarFormulario() {
    nombre = null;
    talla = null;
    marca = null;
    precioCompra = null;
    precioVenta = null;
    precioMinimo = null;
    fotoBase64 = null;
    fotoPath = null;
    fechaRegistro = DateTime.now();
    notifyListeners();
  }

  Future<bool> guardarProducto() async {
    if (nombre == null || nombre!.isEmpty) {
      throw Exception('El nombre del producto es obligatorio');
    }
    if (precioCompra == null || precioCompra! <= 0) {
      throw Exception('El precio de compra es obligatorio y debe ser mayor a 0');
    }
    if (precioVenta == null || precioVenta! <= 0) {
      throw Exception('El precio de venta es obligatorio y debe ser mayor a 0');
    }
    if (precioMinimo == null || precioMinimo! <= 0) {
      throw Exception('El precio mínimo es obligatorio y debe ser mayor a 0');
    }

    _guardando = true;
    notifyListeners();

    try {
      final producto = {
        'nombre': nombre!.trim(),
        'talla': talla?.trim() ?? '',
        'marca': marca?.trim() ?? '',
        'precioCompra': precioCompra!,
        'precioVenta': precioVenta!,
        'precioMinimo': precioMinimo!,
        'fechaRegistro': fechaRegistro.toIso8601String(),
        'foto': fotoPath ?? '',
        'fotoBase64': fotoBase64 ?? '',
        'fotoMime': 'image/jpeg',
        'estado': 'disponible',
        'cantidad': 0,
      };

      // Log para verificar que la foto se está guardando
      debugPrint('Guardando producto con foto: ${fotoBase64 != null ? 'Sí (${(fotoBase64?.length ?? 0) ~/ 1024} KB)' : 'No'}');
      debugPrint('Ruta de foto: $fotoPath');
      
      await MongoService().saveProduct(producto);
      
      limpiarFormulario();
      _guardando = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      _guardando = false;
      notifyListeners();
      rethrow;
    }
  }
}
