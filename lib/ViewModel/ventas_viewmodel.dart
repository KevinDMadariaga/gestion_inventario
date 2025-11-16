import 'package:flutter/material.dart';

import 'package:gestion_inventario/view/historial_venta_view.dart';
import 'package:gestion_inventario/view/registrar_venta_view.dart';

/// ViewModel para la vista de Ventas. Expone las opciones del menú de ventas.
class VentasViewModel {
  VentasViewModel();

  final List<Map<String, dynamic>> _tiles = [
    {
      'title': 'Crear venta',
      'subtitle': 'Registra una nueva venta con productos del inventario.',
      'icon': Icons.point_of_sale,
      'gradient': const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'expanded': true,
      'page': const RegistrarVentaView(),
    },
    {
      'title': 'Historial de ventas',
      'subtitle': 'Consulta y detalla las ventas registradas.',
      'icon': Icons.receipt_long,
      'gradient': const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'expanded': true,
      'page': const HistorialVentasView(),
    },
  ];

  List<Map<String, dynamic>> get tiles => List.unmodifiable(_tiles);
}
