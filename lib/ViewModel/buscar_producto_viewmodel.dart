import 'package:gestion_inventario/services/mongo_service.dart';

class BuscarProductoViewModel {
  BuscarProductoViewModel();

  Future<void> ensureConnected() async {
    await MongoService().connect();
  }

  /// Busca productos por texto; si q está vacío devuelve todo
  Future<List<Map<String, dynamic>>> search(String q) async {
    await ensureConnected();
    final term = q.trim().toLowerCase();
    if (term.isEmpty) {
      final res = await MongoService().getData();
      return List<Map<String, dynamic>>.from(res);
    }

    try {
      final res = await MongoService().getProductosByNombre(term);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      final todos = await MongoService().getData();
      return List<Map<String, dynamic>>.from(
        todos.where((p) {
          final n = (p['nombre'] ?? '').toString().toLowerCase();
          return n.contains(term);
        }),
      );
    }
  }

  /// Filtra la lista por estado: 'todos'|'disponible'|'apartado'|'vendido'|'prestado'
  List<Map<String, dynamic>> aplicarFiltroEstado(
    List<Map<String, dynamic>> lista,
    String estadoFiltro,
  ) {
    if (estadoFiltro == 'todos') return lista;

    return lista.where((p) {
      final estado = (p['estado'] ?? 'disponible')
          .toString()
          .toLowerCase()
          .trim();
      switch (estadoFiltro) {
        case 'vendido':
          return estado == 'vendido';
        case 'apartado':
          return estado == 'apartado' || estado == 'aparto';
        case 'disponible':
          return estado != 'vendido' &&
              estado != 'apartado' &&
              estado != 'aparto';
        case 'prestado':
          return estado == 'prestado';
        default:
          return true;
      }
    }).toList();
  }
}
