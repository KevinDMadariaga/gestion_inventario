import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:gestion_inventario/models/ventas_resumen_model.dart';

class VentasResumenViewModel extends ChangeNotifier {
  final NumberFormat fmtMon = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 0,
  );

  bool cargando = true;

  // Datos normalizados
  List<VentaRecord> ventasRecords = [];
  List<ApartadoRecord> apartadosRecords = [];
  List<String> labels = [];
  Map<String, Map<String, dynamic>> prodById = {};

  // Estado UI
  RangoResumen rango = RangoResumen.semana;
  CategoriaChart cat = CategoriaChart.todos;
  bool modoTorta = false;
  int highlightIndex = 0;

  // Series
  List<double> serieVentasMonto = [];
  List<double> serieAbonosMonto = [];
  List<double> serieCambiosMonto = [];
  List<double> serieApartadosMonto = [];

  List<int> serieVentasCount = [];
  List<int> serieAbonosCount = [];
  List<int> serieCambiosCount = [];
  List<int> serieApartadosCount = [];

  VentasResumenViewModel() {
    cargar();
  }

  // ---------- Utiles locales ----------
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfWeek(DateTime d) =>
      _startOfDay(d).subtract(Duration(days: d.weekday - 1));
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  // (no _startOfYear needed)

  String _hexFromAnyId(dynamic raw) {
    if (raw == null) return '';
    try {
      final s = raw.toString();
      final mHex = RegExp(r'^[0-9a-fA-F]{24}\$').firstMatch(s);
      if (mHex != null) return mHex.group(0)!;
    } catch (_) {}
    final s = raw.toString();
    final m = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
    return m?.group(1) ?? '';
  }

  // ---------- Carga ----------
  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    try {
      final ventas = await MongoService().getVentas();
      final apartados = await MongoService().getApartados();
      final productos = await MongoService().getData();

      prodById = {};
      for (final p in productos) {
        final id = _hexFromAnyId(p['_id']);
        if (id.isNotEmpty) prodById[id] = p;
      }

      ventasRecords = [];
      for (final v in ventas) {
        final fStr = '${v['fechaVenta'] ?? ''}';
        DateTime fv;
        try {
          fv = DateTime.parse(fStr).toLocal();
        } catch (_) {
          continue;
        }
        final tipo = '${v['tipoVenta'] ?? ''}'.toLowerCase().trim();
        // origen no usado en el cálculo actual
        final totalRaw = v['total'] ?? 0;
        final total = (totalRaw is num)
            ? totalRaw.toDouble()
            : double.tryParse('$totalRaw') ?? 0.0;
        final items = (v['productos'] ?? []) as List;

        final prendas = items.length;

        double g = 0.0;
        final esAbono = (tipo == 'abono_apartado');

        for (final raw in items) {
          final p = (raw as Map).cast<String, dynamic>();

          final pvAny =
              p['precioVendidoNeto'] ??
              p['precioVendido'] ??
              p['precioVenta'] ??
              0;
          final double pv = (pvAny is num)
              ? pvAny.toDouble()
              : double.tryParse('$pvAny') ?? 0.0;

          double pc = 0.0;
          final pcRaw = p['precioCompra'];
          if (pcRaw != null) {
            pc = (pcRaw is num)
                ? pcRaw.toDouble()
                : double.tryParse('$pcRaw') ?? 0.0;
          } else {
            final idProd = _hexFromAnyId(
              p['productoId'] ?? p['_id'] ?? p['id'],
            );
            final prod = (idProd.isNotEmpty) ? prodById[idProd] : null;
            if (prod != null) {
              final cRaw = prod['precioCompra'];
              pc = (cRaw is num)
                  ? cRaw.toDouble()
                  : double.tryParse('$cRaw') ?? 0.0;
            }
          }

          final ganItem = pv - pc;
          if (!esAbono) g += ganItem;
        }

        VentaTipo vtipo;
        if (esAbono)
          vtipo = VentaTipo.abono;
        else if (tipo == 'cambio')
          vtipo = VentaTipo.cambio;
        else
          vtipo = VentaTipo.venta;

        final id = _hexFromAnyId(v['_id']);
        final cliente =
            ((v['cliente'] ?? {}) as Map)['nombre']?.toString() ?? '—';

        ventasRecords.add(
          VentaRecord(
            id: id,
            cliente: cliente,
            fecha: fv,
            total: total,
            ganancia: g,
            prendas: prendas,
            tipo: vtipo,
          ),
        );
      }

      apartadosRecords = [];
      for (final a in apartados) {
        final fStr = '${a['fechaApartado'] ?? ''}';
        DateTime fa;
        try {
          fa = DateTime.parse(fStr).toLocal();
        } catch (_) {
          continue;
        }
        final valor = (a['valorTotal'] is num)
            ? (a['valorTotal'] as num).toDouble()
            : double.tryParse('${a['valorTotal']}') ?? 0.0;
        final id = _hexFromAnyId(a['_id']);
        final cliente =
            ((a['cliente'] ?? {}) as Map)['nombre']?.toString() ?? '—';
        apartadosRecords.add(
          ApartadoRecord(
            id: id,
            cliente: cliente,
            fecha: fa,
            valorTotal: valor,
          ),
        );
      }

      _aplicarRango(rango);
      cargando = false;
      notifyListeners();
    } catch (e) {
      cargando = false;
      notifyListeners();
      rethrow;
    }
  }

  // ---------- Agregación por rango/buckets ----------
  void _aplicarRango(RangoResumen r) {
    final ahora = DateTime.now().toLocal();
    late DateTime ini, fin;
    late int buckets;
    List<String> lbls = [];
    int highlight = -1;

    DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _weekStart(DateTime d) =>
        _d0(d).subtract(Duration(days: d.weekday - 1));

    int bucketIndexSemana(DateTime d, DateTime start) =>
        _d0(d.toLocal()).difference(start).inDays;
    int bucketIndexMes(DateTime d, DateTime start) =>
        _d0(d.toLocal()).difference(start).inDays ~/ 7;
    int bucketIndexAnio(DateTime d) => d.toLocal().month - 1;

    if (r == RangoResumen.semana) {
      ini = _weekStart(ahora);
      fin = ini.add(const Duration(days: 7));
      buckets = 7;
      for (int i = 0; i < 7; i++) {
        final d = ini.add(Duration(days: i));
        lbls.add('${_diaCortoES(d)} ${d.day}');
      }
      final hoy0 = _d0(ahora);
      for (int i = 0; i < 7; i++) {
        if (_d0(ini.add(Duration(days: i))) == hoy0) {
          highlight = i;
          break;
        }
      }
    } else if (r == RangoResumen.mes) {
      ini = DateTime(ahora.year, ahora.month, 1);
      fin = DateTime(ahora.year, ahora.month + 1, 1);
      buckets = 6;
      lbls = List.generate(buckets, (i) => 'Sem${i + 1}');
      final base = _weekStart(ini);
      highlight = ((ahora.difference(base).inDays) ~/ 7).clamp(0, buckets - 1);
    } else {
      ini = DateTime(ahora.year, 1, 1);
      fin = DateTime(ahora.year + 1, 1, 1);
      buckets = 12;
      const m = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      lbls = List<String>.from(m);
      highlight = ahora.month - 1;
    }

    // Reinicia series
    serieVentasMonto = List<double>.filled(buckets, 0.0);
    serieAbonosMonto = List<double>.filled(buckets, 0.0);
    serieCambiosMonto = List<double>.filled(buckets, 0.0);
    serieApartadosMonto = List<double>.filled(buckets, 0.0);
    serieVentasCount = List<int>.filled(buckets, 0);
    serieAbonosCount = List<int>.filled(buckets, 0);
    serieCambiosCount = List<int>.filled(buckets, 0);
    serieApartadosCount = List<int>.filled(buckets, 0);

    for (final rcd in ventasRecords) {
      if (rcd.fecha.isBefore(ini) || !rcd.fecha.isBefore(fin)) continue;
      int idx;
      if (r == RangoResumen.semana)
        idx = bucketIndexSemana(rcd.fecha, ini);
      else if (r == RangoResumen.mes)
        idx = bucketIndexMes(rcd.fecha, _weekStart(ini));
      else
        idx = bucketIndexAnio(rcd.fecha);
      if (idx < 0 || idx >= buckets) continue;
      switch (rcd.tipo) {
        case VentaTipo.venta:
          serieVentasMonto[idx] += rcd.total;
          serieVentasCount[idx] += 1;
          break;
        case VentaTipo.abono:
          serieAbonosMonto[idx] += rcd.total;
          serieAbonosCount[idx] += 1;
          break;
        case VentaTipo.cambio:
          serieCambiosMonto[idx] += rcd.total;
          serieCambiosCount[idx] += 1;
          break;
      }
    }

    for (final a in apartadosRecords) {
      if (a.fecha.isBefore(ini) || !a.fecha.isBefore(fin)) continue;
      int idx;
      if (r == RangoResumen.semana)
        idx = bucketIndexSemana(a.fecha, ini);
      else if (r == RangoResumen.mes)
        idx = bucketIndexMes(a.fecha, _weekStart(ini));
      else
        idx = bucketIndexAnio(a.fecha);
      if (idx < 0 || idx >= buckets) continue;
      serieApartadosMonto[idx] += a.valorTotal;
      serieApartadosCount[idx] += 1;
    }

    labels = lbls;
    highlightIndex = (highlight < 0 || highlight >= labels.length)
        ? 0
        : highlight;
  }

  String _diaCortoES(DateTime d) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return dias[d.weekday - 1];
  }

  // API pública para la vista
  List<double> get valuesForChart {
    switch (cat) {
      case CategoriaChart.todos:
        return List.generate(
          labels.length,
          (i) =>
              serieVentasMonto[i] +
              serieAbonosMonto[i] +
              serieCambiosMonto[i] +
              serieApartadosMonto[i],
        );
      case CategoriaChart.ventas:
        return serieVentasMonto;
      case CategoriaChart.abonos:
        return serieAbonosMonto;
      case CategoriaChart.cambios:
        return serieCambiosMonto;
      case CategoriaChart.apartados:
        return serieApartadosMonto;
    }
  }

  ({double total, double ganancia, int prendas}) resumenBucket(int idx) {
    final range = bucketRange(idx);
    double total = 0, gan = 0;
    int prendas = 0;
    for (final v in ventasRecords) {
      if (_isInRange(v.fecha, range.ini, range.fin)) {
        total += v.total;
        gan += v.ganancia;
        prendas += v.prendas;
      }
    }
    return (total: total, ganancia: gan, prendas: prendas);
  }

  Map<String, dynamic> detalleBucket(int i) {
    return {
      'ventasC': serieVentasCount[i],
      'ventasM': serieVentasMonto[i],
      'abonosC': serieAbonosCount[i],
      'abonosM': serieAbonosMonto[i],
      'cambiosC': serieCambiosCount[i],
      'cambiosM': serieCambiosMonto[i],
      'apartadosC': serieApartadosCount[i],
      'apartadosM': serieApartadosMonto[i],
    };
  }

  ({DateTime ini, DateTime fin}) bucketRange(int index) {
    final ahora = DateTime.now().toLocal();
    if (rango == RangoResumen.semana) {
      final base = _startOfWeek(ahora);
      final ini = base.add(Duration(days: index));
      final fin = ini.add(const Duration(days: 1));
      return (ini: ini, fin: fin);
    } else if (rango == RangoResumen.mes) {
      final mesIni = _startOfMonth(ahora);
      final clampFin = DateTime(ahora.year, ahora.month + 1, 1);
      final base = _startOfWeek(mesIni);
      final ini = base.add(Duration(days: 7 * index));
      final fin = base.add(Duration(days: 7 * (index + 1)));
      final iniC = ini.isBefore(mesIni) ? mesIni : ini;
      final finC = fin.isAfter(clampFin) ? clampFin : fin;
      return (ini: iniC, fin: finC);
    } else {
      final year = ahora.year;
      final ini = DateTime(year, index + 1, 1);
      final fin = DateTime(year, index + 2, 1);
      return (ini: ini, fin: fin);
    }
  }

  bool _isInRange(DateTime x, DateTime a, DateTime b) {
    return !x.isBefore(a) && x.isBefore(b);
  }

  String nombrePeriodo() {
    switch (rango) {
      case RangoResumen.semana:
        return 'día';
      case RangoResumen.mes:
        return 'semana';
      case RangoResumen.anio:
        return 'mes';
    }
  }

  // Mutadores que notifican
  void setRango(RangoResumen r) {
    rango = r;
    _aplicarRango(rango);
    notifyListeners();
  }

  void setCat(CategoriaChart c) {
    cat = c;
    notifyListeners();
  }

  void setModo(bool m) {
    modoTorta = m;
    notifyListeners();
  }

  void setHighlight(int i) {
    highlightIndex = i;
    notifyListeners();
  }
}
