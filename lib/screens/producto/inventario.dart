import 'package:flutter/material.dart';
import 'package:gestion_inventario/screens/producto/agregar_producto.dart';
import 'package:gestion_inventario/screens/producto/buscar_producto.dart';
import 'package:gestion_inventario/widgets/app_menu_card.dart';


class InventarioMenuPage extends StatelessWidget {
  const InventarioMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink[200],
        foregroundColor: Colors.white,
        title: const Text(
          'Inventario',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppMenuCard(
                icon: Icons.add_box,
                title: 'Registrar producto',
                subtitle: 'Agrega un nuevo producto al inventario.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF4ADE80)], // verde
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                expanded: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgregarProductoPage()),
                ),
              ),
              const SizedBox(height: 16),
              AppMenuCard(
                icon: Icons.list_alt,
                title: 'Lista de productos',
                subtitle: 'Consulta todos los productos registrados.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)], // azul
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                expanded: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BuscarInventarioPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
