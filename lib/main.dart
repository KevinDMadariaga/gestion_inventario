import 'package:flutter/material.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:gestion_inventario/view/home_view.dart';

  void main() {
WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  Future<void> inicializarMongo() async {
    await MongoService().connect();
    print('Conexión exitosa a la base de datos MongoDB');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: inicializarMongo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error al conectar con MongoDB')),
            );
          }
          return HomeView();
        },
      ),
    );
  }


}
