import 'package:flutter/material.dart';

import 'package:gestion_inventario/ViewModel/home_viewmodel.dart';
import 'package:gestion_inventario/widgets/app_menu_card.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = HomeViewModel();

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
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 200, // altura fija de cada tile
                        ),
                    itemCount: viewModel.tiles.length,
                    itemBuilder: (context, index) {
                      final tile = viewModel.tiles[index];
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: AppMenuCard(
                          icon: tile.icon,
                          title: tile.title,
                          color: tile.color,
                          iconSize: 64,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => tile.page),
                          ),
                        ),
                      );
                    },
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
