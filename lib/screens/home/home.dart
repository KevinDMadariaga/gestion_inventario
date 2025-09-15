import 'package:flutter/material.dart';

import 'package:gestion_inventario/screens/apartados/apartado.dart';
import 'package:gestion_inventario/screens/cambios/cambio_producto_venta_page.dart';
import 'package:gestion_inventario/screens/prestamo/producto_prestado.dart';
import 'package:gestion_inventario/screens/producto/inventario.dart';
import 'package:gestion_inventario/screens/ventas/ventas_menu_page.dart';
import 'package:gestion_inventario/widgets/app_menu_card.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      {
        "title": "Punto de venta",
        "icon": Icons.point_of_sale,
        "color": const Color(0xFF0EA5E9),
        "page": const VentasMenuPage(),
      },
      {
        "title": "Gestionar apartados",
        "icon": Icons.bookmark_add_outlined,
        "color": const Color(0xFFF59E0B),
        "page": const ApartadosMenuPage(),
      },
      {
        "title": "Productos y stock",
        "icon": Icons.inventory_2_rounded,
        "color": const Color(0xFF6366F1),
        "page": InventarioMenuPage(),
      },
      {
        "title": "Producto prestado",
        "icon": Icons.assignment_return_outlined,
        "color": const Color(0xFF22C55E),
        "page": const GestionPrestamosPage(),
      },
      {
        "title": "Cambiar producto en venta",
        "icon": Icons.swap_horiz,
        "color": const Color(0xFF8B5CF6),
        "page": const CambiosVentaPage(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink[200],
        title: const Text(
          'Gestión de Ventas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF4F5F7),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Elige una opción',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: tiles
                      .map(
                        (tile) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: AppMenuCard(
                              icon: tile["icon"] as IconData,
                              title: tile["title"] as String,
                              color: tile["color"] as Color,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => tile["page"] as Widget,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
