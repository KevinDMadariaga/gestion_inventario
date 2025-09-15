import 'package:flutter/material.dart';
import 'package:gestion_inventario/screens/apartados/historial_apartado.dart';
import 'package:gestion_inventario/screens/apartados/registrar_apartado.dart';

import 'package:gestion_inventario/widgets/app_menu_card.dart';

class ApartadosMenuPage extends StatelessWidget {
  const ApartadosMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink[200],
        foregroundColor: Colors.white,
        title: const Text(
          'Apartados',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppMenuCard(
                icon: Icons.bookmark_add_outlined,
                title: 'Registrar apartado',
                subtitle: 'Crea un nuevo apartado de producto.',
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)], // naranja
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                expanded: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CrearApartadoPage()),
                ),
              ),
              const SizedBox(height: 16),
              AppMenuCard(
                icon: Icons.bookmarks,
                title: 'Lista de apartados',
                subtitle: 'Consulta todos los apartados activos.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA78BFA)], // morado
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                expanded: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistorialApartadosPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
