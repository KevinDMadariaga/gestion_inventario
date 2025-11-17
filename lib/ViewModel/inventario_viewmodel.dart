import 'package:gestion_inventario/models/product_model.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

class InventarioViewModel {
  InventarioViewModel();

  Future<void> ensureConnected() async {
    try {
      await MongoService().connect();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveProduct(ProductModel p) async {
    await ensureConnected();
    final data = p.toMap();
    await MongoService().saveProduct(data);
  }

  Future<List<dynamic>> getMarcas() async {
    await ensureConnected();
    return await MongoService().getMarcas();
  }

  Future<List<Map<String, dynamic>>> getData() async {
    await ensureConnected();
    final res = await MongoService().getData();
    return List<Map<String, dynamic>>.from(res);
  }
}
