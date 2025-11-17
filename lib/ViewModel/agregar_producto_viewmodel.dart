import 'package:gestion_inventario/models/product_model.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

class AgregarProductoViewModel {
  AgregarProductoViewModel();

  Future<void> ensureConnected() async {
    await MongoService().connect();
  }

  Future<void> saveProduct(ProductModel p) async {
    await ensureConnected();
    final data = p.toMap();
    await MongoService().saveProduct(data);
  }

  Future<List<String>> getMarcas() async {
    await ensureConnected();
    final res = await MongoService().getMarcas();
    final list = <String>[];
    for (final e in res) {
      if (e is String)
        list.add(e);
      else if (e is Map) {
        final n = (e['nombre'] ?? e['name'] ?? '').toString().trim();
        if (n.isNotEmpty) list.add(n);
      } else {
        final s = e?.toString() ?? '';
        if (s.isNotEmpty) list.add(s);
      }
    }
    // dedupe + sort
    final uniq = list.toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return uniq;
  }

  Future<void> addMarca(String nombre) async {
    await ensureConnected();
    await MongoService().addMarca(nombre);
  }
}
