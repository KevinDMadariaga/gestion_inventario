import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

/// ViewModel para la pantalla de Registrar Venta.
/// Expone controllers, listas y lógica utilizada por la vista.
class RegistrarVentaViewModel extends ChangeNotifier {
  RegistrarVentaViewModel();

  // Controllers públicos (la vista puede accederlos)
  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final buscarCtrl = TextEditingController();
  final descuentoCtrl = TextEditingController();
  final pagaCtrl = TextEditingController();

  // FormKey (la vista lo mantiene, pero lo dejamos público por si acaso)
  final formKey = GlobalKey<FormState>();

  // Resultados y seleccionados
  List<Map<String, dynamic>> resultados = [];
  final List<Map<String, dynamic>> seleccionados = [];

  // Debounce
  Timer? _debounce;

  // Estado
  bool guardando = false;

  void init() {
    // Conectar servicio opcionalmente
    try {
      MongoService().connect();
    } catch (_) {}
    buscarCtrl.addListener(_onBuscarChanged);
  }

  void disposeViewModel() {
    buscarCtrl.removeListener(_onBuscarChanged);
    _debounce?.cancel();
    nombreCtrl.dispose();
    telefonoCtrl.dispose();
    buscarCtrl.dispose();
    descuentoCtrl.dispose();
    pagaCtrl.dispose();
    super.dispose();
  }

  void _onBuscarChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await buscarProductos(buscarCtrl.text.trim());
    });
  }

  Future<void> buscarProductos(String q) async {
    if (q.isEmpty) {
      resultados = [];
      notifyListeners();
      return;
    }
    try {
      List<Map<String, dynamic>> r = [];
      try {
        r = await MongoService().getProductosByNombre(q);
      } catch (_) {
        final all = await MongoService().getData();
        r = all.where((p) {
          final n = (p['nombre'] ?? '').toString().toLowerCase();
          return n.contains(q.toLowerCase());
        }).toList();
      }

      r = r.where((e) {
        final estado = (e['estado'] ?? 'disponible')
            .toString()
            .toLowerCase()
            .trim();
        return estado == 'disponible';
      }).toList();

      final selIds = seleccionados.map((e) => '${e['_id']}').toSet();
      r = r.where((e) => !selIds.contains('${e['_id']}')).toList();

      resultados = r;
      notifyListeners();
    } catch (e) {
      // propagate error to UI via throw or set an error field (we keep simple)
      rethrow;
    }
  }

  void agregarProducto(Map<String, dynamic> p) {
    final isSold = (p['estado'] ?? '').toString().toLowerCase() == 'vendido';
    if (isSold) return;
    seleccionados.add(p);
    resultados.removeWhere((e) => '${e['_id']}' == '${p['_id']}');
    buscarCtrl.clear();
    resultados.clear();
    notifyListeners();
  }

  void eliminarProducto(Map<String, dynamic> p) {
    seleccionados.remove(p);
    notifyListeners();
  }

  double asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  double get subtotal {
    return seleccionados.fold<double>(0.0, (acc, p) {
      final v = asDouble(p['precioVenta']);
      return acc + v;
    });
  }

  double get descuento {
    final txt = descuentoCtrl.text.trim().replaceAll(',', '.');
    final d = double.tryParse(txt) ?? 0.0;
    if (d < 0) return 0.0;
    if (d > subtotal) return subtotal;
    return d;
  }

  double get total => (subtotal - descuento).clamp(0.0, double.infinity);

  double get pagaCon {
    final t = pagaCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t) ?? 0.0;
  }

  double get vueltos => (pagaCon - total).clamp(0.0, double.infinity);

  double get gananciaEstimada {
    final sub = subtotal;
    if (sub <= 0) return 0.0;
    final desc = descuento;
    double totalGan = 0.0;

    for (final p in seleccionados) {
      final pv = asDouble(p['precioVenta']);
      final propor = pv / sub;
      final descLinea = desc * propor;
      final vendidoNeto = pv - descLinea;
      final costo = asDouble(p['precioCompra']);
      totalGan += (vendidoNeto - costo);
    }
    return totalGan;
  }

  String _oidHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final m = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    return m != null ? m.group(1)! : s;
  }

  Future<void> guardarVenta() async {
    if (guardando) return;
    if (seleccionados.isEmpty) throw Exception('Agrega al menos un producto');

    guardando = true;
    notifyListeners();

    try {
      // Asegura que la conexión a MongoDB esté establecida antes de intentar guardar.
      try {
        await MongoService().connect();
      } catch (e) {
        // Si no se puede conectar, propaga un error claro para la UI.
        throw Exception('No se pudo conectar a la base de datos: $e');
      }

      final double sub = subtotal;
      final double desc = descuento;
      final double tot = (sub - desc).clamp(0.0, double.infinity);

      final List<Map<String, dynamic>> productosLinea = [];
      double gananciaTotal = 0.0;

      for (final p in seleccionados) {
        final pv = asDouble(p['precioVenta']);
        final propor = sub <= 0 ? 0.0 : (pv / sub);
        final descLinea = desc * propor;
        final vendidoNeto = pv - descLinea;

        final costo = asDouble(p['precioCompra']);
        final gananciaLinea = vendidoNeto - costo;
        gananciaTotal += gananciaLinea;

        String? fotoBase64 = (p['fotoBase64'] ?? '') as String?;
        if ((fotoBase64 == null || fotoBase64.isEmpty)) {
          final f = (p['foto'] ?? '') as String;
          if (f.isNotEmpty && !(f.startsWith('http') || f.startsWith('/'))) {
            try {
              base64Decode(f);
              fotoBase64 = f;
            } catch (_) {}
          }
        }

        productosLinea.add({
          'productoId': '${p['_id']}',
          'nombre': p['nombre'],
          'precioVendido': pv,
          'precioVendidoNeto': vendidoNeto,
          'precioCompra': costo,
          'gananciaLinea': gananciaLinea,
          'fotoBase64': fotoBase64 ?? '',
          'foto': p['foto'] ?? '',
          'sku': p['sku'],
          'talla': p['talla'],
          'color': p['color'],
        });
      }

      final venta = {
        'cliente': {
          'nombre': nombreCtrl.text.trim(),
          'telefono': telefonoCtrl.text.trim(),
        },
        'productos': productosLinea,
        'subtotal': sub,
        'descuento': desc,
        'total': tot,
        'gananciaTotal': gananciaTotal,
        'fechaVenta': DateTime.now().toIso8601String(),
      };

      await MongoService().saveVenta(venta);

      final idsVendidos = seleccionados
          .map((p) => _oidHex(p['_id']))
          .where((s) => s.isNotEmpty)
          .toList();

      if (idsVendidos.isNotEmpty) {
        try {
          await MongoService().marcarProductosVendidos(idsVendidos);
        } catch (e) {
          // Log y no interrumpir el flujo; dejamos que la UI conozca el problema si es necesario
          // pero no revertimos la venta ya guardada.
          rethrow;
        }
      }

      limpiarFormulario();
    } finally {
      guardando = false;
      notifyListeners();
    }
  }

  void limpiarFormulario() {
    formKey.currentState?.reset();
    nombreCtrl.clear();
    telefonoCtrl.clear();
    buscarCtrl.clear();
    descuentoCtrl.clear();
    resultados.clear();
    seleccionados.clear();
    pagaCtrl.clear();
    notifyListeners();
  }
}
