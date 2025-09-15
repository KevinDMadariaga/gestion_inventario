import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

class RegistrarController {
  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final buscarCtrl = TextEditingController();
  final descuentoCtrl = TextEditingController();
  final pagaCtrl = TextEditingController();

  final formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> seleccionados = [];
  List<Map<String, dynamic>> resultados = [];

  Timer? debounce;
  bool guardando = false;

  double asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  double get subtotal =>
      seleccionados.fold(0.0, (acc, p) => acc + asDouble(p['precioVenta']));

  double get descuento {
    final txt = descuentoCtrl.text.trim().replaceAll(',', '.');
    final d = double.tryParse(txt) ?? 0.0;
    if (d < 0) return 0;
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
    if (sub <= 0) return 0;
    final desc = descuento;
    double totalGan = 0;
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

  Future<void> buscarProductos(String q) async {
    if (q.isEmpty) {
      resultados = [];
      return;
    }
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
    // disponibles y no duplicados
    r = r.where((e) {
      final estado =
          (e['estado'] ?? 'disponible').toString().toLowerCase().trim();
      return estado == 'disponible';
    }).toList();
    final selIds = seleccionados.map((e) => '${e['_id']}').toSet();
    r = r.where((e) => !selIds.contains('${e['_id']}')).toList();
    resultados = r;
  }

  void agregarProducto(Map<String, dynamic> p) {
    seleccionados.add(p);
    resultados.removeWhere((e) => '${e['_id']}' == '${p['_id']}');
  }

  void eliminarProducto(Map<String, dynamic> p) {
    seleccionados.remove(p);
  }

  void limpiarFormulario() {
    formKey.currentState?.reset();
    nombreCtrl.clear();
    telefonoCtrl.clear();
    buscarCtrl.clear();
    descuentoCtrl.clear();
    pagaCtrl.clear();
    resultados.clear();
    seleccionados.clear();
  }

  Future<void> guardarVenta(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;
    if (seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    guardando = true;

    try {
      final venta = {
        'cliente': {
          'nombre': nombreCtrl.text.trim(),
          'telefono': telefonoCtrl.text.trim(),
        },
        'productos': seleccionados,
        'subtotal': subtotal,
        'descuento': descuento,
        'total': total,
        'gananciaTotal': gananciaEstimada,
        'fechaVenta': DateTime.now().toIso8601String(),
      };

      await MongoService().saveVenta(venta);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Venta registrada')),
      );
      limpiarFormulario();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      guardando = false;
    }
  }

  void dispose() {
    nombreCtrl.dispose();
    telefonoCtrl.dispose();
    buscarCtrl.dispose();
    descuentoCtrl.dispose();
    pagaCtrl.dispose();
    debounce?.cancel();
  }
}
