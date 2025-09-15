import 'package:gestion_inventario/models/venta_record.dart';
import 'package:gestion_inventario/models/apartado_record.dart';
import 'package:gestion_inventario/utils/id_utils.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

enum RangoResumen { semana, mes, anio }
enum CategoriaChart { todos, ventas, abonos, cambios, apartados }

class ResumenController {
  final List<VentaRecord> ventas = [];
  final List<ApartadoRecord> apartados = [];
  final Map<String, Map<String, dynamic>> prodById = {};

  Future<void> cargarDatos() async {
    final ventasDb = await MongoService().getVentas();
    final apartadosDb = await MongoService().getApartados();
    final productos = await MongoService().getData();

    // indexar productos por id
    prodById.clear();
    for (final p in productos) {
      final id = IdUtils.hexFromAnyId(p['_id']);
      if (id.isNotEmpty) prodById[id] = p;
    }

    ventas.clear();
    for (final v in ventasDb) {
      try {
        final fv = DateTime.parse('${v['fechaVenta']}').toLocal();
        final tipo = (v['tipoVenta'] ?? '').toString().trim().toLowerCase();

        final total = (v['total'] is num)
            ? (v['total'] as num).toDouble()
            : double.tryParse('${v['total']}') ?? 0.0;

        final items = (v['productos'] ?? []) as List;
        final prendas = items.length;

        double g = 0.0;
        final esAbono = (tipo == 'abono_apartado');

        for (final raw in items) {
          final p = (raw as Map).cast<String, dynamic>();
          final pv = double.tryParse('${p['precioVendidoNeto'] ?? p['precioVenta'] ?? 0}') ?? 0.0;
          final costo = double.tryParse('${p['precioCompra'] ?? 0}') ?? 0.0;
          if (!esAbono) g += (pv - costo);
        }

        final id = IdUtils.hexFromAnyId(v['_id']);
        final cliente = ((v['cliente'] ?? {}) as Map)['nombre']?.toString() ?? '—';

        ventas.add(VentaRecord(
          id: id,
          cliente: cliente,
          fecha: fv,
          total: total,
          ganancia: g,
          prendas: prendas,
          tipo: esAbono
              ? VentaTipo.abono
              : (tipo == 'cambio' ? VentaTipo.cambio : VentaTipo.venta),
        ));
      } catch (_) {}
    }

    apartados.clear();
    for (final a in apartadosDb) {
      try {
        final fa = DateTime.parse('${a['fechaApartado']}').toLocal();
        final valor = double.tryParse('${a['valorTotal'] ?? 0}') ?? 0.0;
        final id = IdUtils.hexFromAnyId(a['_id']);
        final cliente = ((a['cliente'] ?? {}) as Map)['nombre']?.toString() ?? '—';
        apartados.add(ApartadoRecord(id: id, cliente: cliente, fecha: fa, valorTotal: valor));
      } catch (_) {}
    }
  }
}
