import 'package:flutter/material.dart';

import 'package:gestion_inventario/ViewModel/ventas_viewmodel.dart';
import 'package:gestion_inventario/widgets/app_menu_card.dart';

class VentasView extends StatelessWidget {
  const VentasView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = VentasViewModel();

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
                children: viewModel.tiles.map((tile) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: AppMenuCard(
                      icon: tile['icon'] as IconData,
                      title: tile['title'] as String,
                      subtitle: tile['subtitle'] as String?,
                      gradient: tile['gradient'] as LinearGradient?,
                      expanded: tile['expanded'] as bool? ?? false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => tile['page'] as Widget),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
