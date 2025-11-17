import 'package:flutter/material.dart';
import 'package:gestion_inventario/screens/producto/agregar_producto.dart';
import 'package:gestion_inventario/screens/producto/buscar_producto.dart';
import 'package:gestion_inventario/view/agregar_producto_view.dart';
import 'package:gestion_inventario/view/buscar_producto_view.dart';

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
              _menuCard(
                context,
                icon: Icons.add_box,
                title: 'Registrar producto',
                subtitle: 'Agrega un nuevo producto al inventario.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AgregarProductoPage(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _menuCard(
                context,
                icon: Icons.list_alt,
                title: 'Lista de productos',
                subtitle: 'Consulta todos los productos registrados.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BuscarInventarioPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 36, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
