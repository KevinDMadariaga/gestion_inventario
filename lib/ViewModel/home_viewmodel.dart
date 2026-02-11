import 'package:flutter/material.dart';

import 'package:gestion_inventario/models/home_tile_data.dart';
import 'package:gestion_inventario/screens/apartados/apartado.dart';
import 'package:gestion_inventario/screens/cambios/cambio_producto_venta_page.dart';
import 'package:gestion_inventario/screens/prestamo/producto_prestado.dart';
import 'package:gestion_inventario/screens/producto/inventario.dart';
import 'package:gestion_inventario/screens/settings/configuracion_page.dart';
import 'package:gestion_inventario/view/inicio_venta.dart';

/// ViewModel para la vista Home.
/// Expone la lista de tiles y cualquier lógica relacionada con la vista.
class HomeViewModel {
  HomeViewModel();

  final List<HomeTileData> _tiles = [
    HomeTileData(
      title: 'Punto de venta',
      icon: Icons.point_of_sale,
      color: const Color(0xFF0EA5E9),
      page: const InicioVenta(),
    ),
    HomeTileData(
      title: 'Gestionar apartados',
      icon: Icons.bookmark_add_outlined,
      color: const Color(0xFFF59E0B),
      page: const ApartadosMenuPage(),
    ),
    HomeTileData(
      title: 'Productos y stock',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF6366F1),
      page: InventarioMenuPage(),
    ),
    HomeTileData(
      title: 'Producto prestado',
      icon: Icons.assignment_return_outlined,
      color: const Color(0xFF22C55E),
      page: const GestionPrestamosPage(),
    ),
    HomeTileData(
      title: 'Cambiar producto en venta',
      icon: Icons.swap_horiz,
      color: const Color(0xFF8B5CF6),
      page: const CambiosVentaPage(),
    ),
    HomeTileData(
      title: 'Configuración',
      icon: Icons.settings,
      color: const Color(0xFF9CA3AF),
      page: const ConfiguracionPage(),
    ),
  ];

  List<HomeTileData> get tiles => List.unmodifiable(_tiles);
}
