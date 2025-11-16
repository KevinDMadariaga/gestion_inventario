import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:gestion_inventario/models/historial_venta_model.dart';

class HistorialVentaViewModel extends ChangeNotifier {
  final DateFormat fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat fmtMon = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
  );

  Future<List<VentaHistorialModel>>? future;

  HistorialVentaViewModel() {
    future = cargar();
  }

  DateTime parseLocal(dynamic v) {
    try {
      final d = DateTime.parse('$v');
      return d.isUtc ? d.toLocal() : d;
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  bool inToday(DateTime d) {
    final now = DateTime.now();
    final ini = DateTime(now.year, now.month, now.day);
    final fin = ini.add(const Duration(days: 1));
    return !d.isBefore(ini) && d.isBefore(fin);
  }

  double asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  double precioItem(dynamic raw) {
    final v = (raw is Map)
        ? (raw['precioVendido'] ?? raw['precioVenta'] ?? 0)
        : 0;
    return (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  }

  Future<List<VentaHistorialModel>> cargar() async {
    final ventas = await MongoService().getVentas(); // trae todo (lista de Map)

    // Filtra SOLO ventas de HOY (hora local)
    final hoy = ventas.where((v) {
      final f = parseLocal(v['fechaVenta']);
      return inToday(f);
    }).toList();

    // Ocultar cierres de apartado y registros marcados para ocultar
    hoy.removeWhere((v) {
      final tipo = ('${v['tipoVenta'] ?? ''}').toLowerCase().trim();
      final ocultar = v['ocultarEnHistorial'] == true;
      return ocultar || (tipo == 'apartado_pagado');
    });

    // Ordena desc por fecha
    hoy.sort((a, b) {
      final da = parseLocal(a['fechaVenta']);
      final db = parseLocal(b['fechaVenta']);
      return db.compareTo(da);
    });

    return hoy
        .map((e) => VentaHistorialModel.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> refresh() async {
    final nuevo = await cargar();
    future = Future.value(nuevo);
    notifyListeners();
  }
}
