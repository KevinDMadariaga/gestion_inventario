import 'package:flutter/material.dart';
import 'package:gestion_inventario/screens/ventas/historial_venta.dart';
import 'package:gestion_inventario/screens/ventas/registrar_venta.dart';
import 'package:gestion_inventario/widgets/app_menu_card.dart';

class VentasMenuPage extends StatelessWidget {
  const VentasMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink[200],
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.sell, size: 24),
            SizedBox(width: 8),
            Text(
              'Ventas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppMenuCard(
                    icon: Icons.point_of_sale,
                    title: 'Crear venta',
                    subtitle:
                        'Registra una nueva venta con productos del inventario.',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    expanded: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrarVentaPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppMenuCard(
                    icon: Icons.receipt_long,
                    title: 'Historial de ventas',
                    subtitle: 'Consulta y detalla las ventas registradas.',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA78BFA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    expanded: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistorialVentasPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
