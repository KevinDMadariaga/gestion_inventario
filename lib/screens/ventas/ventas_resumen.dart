import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

enum RangoResumen { semana, mes, anio }

enum CategoriaChart { todos, ventas, abonos, cambios, apartados }

enum _VentaTipo { venta, abono, cambio }

class ResumenVentasPage extends StatefulWidget {
  const ResumenVentasPage({super.key});

  @override
  State<ResumenVentasPage> createState() => _ResumenVentasPageState();
}

class _ResumenVentasPageState extends State<ResumenVentasPage> {
  final _fmtMon = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

  bool _cargando = true;

  // Datos normalizados
  List<_VentaRecord> _ventasRecords = [];
  List<_ApartadoRecord> _apartadosRecords = [];
  List<String> _labels = [];
  Map<String, Map<String, dynamic>> _prodById = {};

  // Estado UI
  RangoResumen _rango = RangoResumen.semana;
  CategoriaChart _cat = CategoriaChart.todos;
  bool _modoTorta = false; // false=barras, true=torta

  int _highlightIndex = -1; // bucket seleccionado

  List<double> _serieVentasMonto = [];
  List<double> _serieAbonosMonto = [];
  List<double> _serieCambiosMonto = [];
  List<double> _serieApartadosMonto = [];

  List<int> _serieVentasCount = [];
  List<int> _serieAbonosCount = [];
  List<int> _serieCambiosCount = [];
  List<int> _serieApartadosCount = [];

  @override
  void initState() {
    super.initState();
    _ventasRecords = [];
    _apartadosRecords = [];
    _aplicarRango(_rango); // construye labels/series vacías seguras
    _cargar();
  }

  // ---------- Helpers de fechas ----------
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final wd = d.weekday; // 1..7 (Lun..Dom)
    return _startOfDay(d).subtract(Duration(days: wd - 1));
  }

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _startOfYear(DateTime d) => DateTime(d.year, 1, 1);

  bool _isInRange(DateTime x, DateTime a, DateTime b) {
    // [a, b)
    return !x.isBefore(a) && x.isBefore(b);
  }

  String _mesActualText(DateTime d) => DateFormat('MM/yyyy').format(d);
  String _diaCortoES(DateTime d) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return dias[d.weekday - 1];
  }

  String _hexFromAnyId(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final mHex = RegExp(r'^[0-9a-fA-F]{24}$').firstMatch(s);
    if (mHex != null) return mHex.group(0)!;
    final mObj = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    if (mObj != null) return mObj.group(1)!;
    final mAny = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
    return mAny?.group(1) ?? '';
  }

  // ---------- Carga ----------
  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final ventas = await MongoService().getVentas();
      final apartados = await MongoService().getApartados();
      final productos = await MongoService().getData();
      _prodById = {};
      for (final p in productos) {
        final id = _hexFromAnyId(p['_id']);
        if (id.isNotEmpty) _prodById[id] = p;
      }

      _ventasRecords = [];
      for (final v in ventas) {
        final fStr = '${v['fechaVenta'] ?? ''}';
        DateTime fv;
        try {
          fv = DateTime.parse(fStr).toLocal();
        } catch (_) {
          continue;
        }
        final tipo = '${v['tipoVenta'] ?? ''}'
            .toLowerCase()
            .trim(); // 'abono_apartado', 'cambio', etc.
        final origen = (v['origen'] ?? {}) as Map? ?? {};
        final origenTipo = '${origen['tipo'] ?? ''}'.toLowerCase().trim();

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

          // 1) precio vendido preferentemente NETO
          final pvAny =
              p['precioVendidoNeto'] ??
              p['precioVendido'] ??
              p['precioVenta'] ??
              0;
          final double pv = (pvAny is num)
              ? pvAny.toDouble()
              : double.tryParse('$pvAny') ?? 0.0;

          // 2) precio de compra (de la línea o del catálogo)
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
            final prod = (idProd.isNotEmpty) ? _prodById[idProd] : null;
            if (prod != null) {
              final cRaw = prod['precioCompra'];
              pc = (cRaw is num)
                  ? cRaw.toDouble()
                  : double.tryParse('$cRaw') ?? 0.0;
            }
          }

          final ganItem = pv - pc;

          // 3) En ABONOS NO sumamos ganancia (se reconoce al cierre)
          if (!esAbono) g += ganItem;
        }

        // Clasifica la venta
        _VentaTipo vtipo;
        if (esAbono) {
          vtipo = _VentaTipo.abono;
        } else if (tipo == 'cambio') {
          vtipo = _VentaTipo.cambio;
        } else {
          // ventas normales o (si más adelante generas "venta final de apartado")
          vtipo = _VentaTipo.venta;
        }

        final id = _hexFromAnyId(v['_id']);
        final cliente =
            ((v['cliente'] ?? {}) as Map)['nombre']?.toString() ?? '—';

        _ventasRecords.add(
          _VentaRecord(
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

      _apartadosRecords = [];
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

        _apartadosRecords.add(
          _ApartadoRecord(
            id: id,
            cliente: cliente,
            fecha: fa,
            valorTotal: valor,
          ),
        );
      }

      _aplicarRango(_rango);

      if (!mounted) return;
      setState(() => _cargando = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando resumen: $e')));
    }
  }

  // ---------- Agregación por rango/buckets ----------
  void _aplicarRango(RangoResumen rango) {
    final ahora = DateTime.now().toLocal(); // 👈 local siempre
    late DateTime ini, fin;
    late int buckets;
    List<String> labels = [];
    int highlight = -1;

    DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _weekStart(DateTime d) =>
        _d0(d).subtract(Duration(days: d.weekday - 1));

    int bucketIndexSemana(DateTime d, DateTime start) =>
        _d0(d.toLocal()).difference(start).inDays;
    int bucketIndexMes(DateTime d, DateTime start) =>
        _d0(d.toLocal()).difference(start).inDays ~/ 7;
    int bucketIndexAnio(DateTime d) => d.toLocal().month - 1;

    if (rango == RangoResumen.semana) {
      ini = _weekStart(ahora); // lunes local
      fin = ini.add(const Duration(days: 7)); // [ini, fin)
      buckets = 7;
      for (int i = 0; i < 7; i++) {
        final d = ini.add(Duration(days: i));
        labels.add('${_diaCortoES(d)} ${d.day}');
      }
      final hoy0 = _d0(ahora);
      for (int i = 0; i < 7; i++) {
        if (_d0(ini.add(Duration(days: i))) == hoy0) {
          highlight = i;
          break;
        }
      }
    } else if (rango == RangoResumen.mes) {
      ini = DateTime(ahora.year, ahora.month, 1);
      fin = DateTime(ahora.year, ahora.month + 1, 1);
      buckets = 6; // 6 "semanas" aprox
      labels = List.generate(buckets, (i) => 'Sem${i + 1}');
      final base = _weekStart(ini);
      highlight = ((ahora.difference(base).inDays) ~/ 7).clamp(0, buckets - 1);
    } else {
      ini = DateTime(ahora.year, 1, 1);
      fin = DateTime(ahora.year + 1, 1, 1);
      buckets = 12;
      const m = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      labels = List<String>.from(m);
      highlight = ahora.month - 1;
    }

    // Reinicia series
    _serieVentasMonto = List<double>.filled(buckets, 0.0);
    _serieAbonosMonto = List<double>.filled(buckets, 0.0);
    _serieCambiosMonto = List<double>.filled(buckets, 0.0);
    _serieApartadosMonto = List<double>.filled(buckets, 0.0);
    _serieVentasCount = List<int>.filled(buckets, 0);
    _serieAbonosCount = List<int>.filled(buckets, 0);
    _serieCambiosCount = List<int>.filled(buckets, 0);
    _serieApartadosCount = List<int>.filled(buckets, 0);

    // Ventas / Abonos / Cambios
    for (final r in _ventasRecords) {
      if (r.fecha.isBefore(ini) || !r.fecha.isBefore(fin)) continue;

      int idx;
      if (rango == RangoResumen.semana) {
        idx = bucketIndexSemana(r.fecha, ini);
      } else if (rango == RangoResumen.mes) {
        idx = bucketIndexMes(r.fecha, _weekStart(ini));
      } else {
        idx = bucketIndexAnio(r.fecha);
      }
      if (idx < 0 || idx >= buckets) continue;

      switch (r.tipo) {
        case _VentaTipo.venta:
          _serieVentasMonto[idx] += r.total;
          _serieVentasCount[idx] += 1;
          break;
        case _VentaTipo.abono:
          _serieAbonosMonto[idx] += r.total;
          _serieAbonosCount[idx] += 1;
          break;
        case _VentaTipo.cambio:
          _serieCambiosMonto[idx] += r.total;
          _serieCambiosCount[idx] += 1;
          break;
      }
    }

    // Apartados
    for (final a in _apartadosRecords) {
      if (a.fecha.isBefore(ini) || !a.fecha.isBefore(fin)) continue;

      int idx;
      if (rango == RangoResumen.semana) {
        idx = bucketIndexSemana(a.fecha, ini);
      } else if (rango == RangoResumen.mes) {
        idx = bucketIndexMes(a.fecha, _weekStart(ini));
      } else {
        idx = bucketIndexAnio(a.fecha);
      }
      if (idx < 0 || idx >= buckets) continue;

      _serieApartadosMonto[idx] += a.valorTotal;
      _serieApartadosCount[idx] += 1;
    }

    _labels = labels;
    _highlightIndex = (highlight < 0 || highlight >= _labels.length)
        ? 0
        : highlight;
  }

  // ---------- Rango real (ini..fin) para un índice ----------
  ({DateTime ini, DateTime fin}) _bucketRange(int index) {
    final ahora = DateTime.now().toLocal();
    if (_rango == RangoResumen.semana) {
      final base = _startOfWeek(ahora);
      final ini = base.add(Duration(days: index));
      final fin = ini.add(const Duration(days: 1));
      return (ini: ini, fin: fin);
    } else if (_rango == RangoResumen.mes) {
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

  // ---------- Valores a graficar según categoría ----------
  List<double> get _valuesForChart {
    switch (_cat) {
      case CategoriaChart.todos:
        return List.generate(
          _labels.length,
          (i) =>
              _serieVentasMonto[i] +
              _serieAbonosMonto[i] +
              _serieCambiosMonto[i] +
              _serieApartadosMonto[i],
        );
      case CategoriaChart.ventas:
        return _serieVentasMonto;
      case CategoriaChart.abonos:
        return _serieAbonosMonto;
      case CategoriaChart.cambios:
        return _serieCambiosMonto;
      case CategoriaChart.apartados:
        return _serieApartadosMonto;
    }
  }

  // Totales del bucket seleccionado
  ({double total, double ganancia, int prendas}) _resumenBucket(int idx) {
    final r = _bucketRange(idx);
    double total = 0, gan = 0;
    int prendas = 0;

    for (final v in _ventasRecords) {
      if (_isInRange(v.fecha, r.ini, r.fin)) {
        // total = ventas+abonos+cambios
        total += v.total;
        gan += v.ganancia;
        prendas += v.prendas;
      }
    }
    return (total: total, ganancia: gan, prendas: prendas);
  }

  // Conteos/montos del bucket seleccionado por tipo (para texto resumen corto)
  Map<String, dynamic> _detalleBucket(int i) {
    return {
      'ventasC': _serieVentasCount[i],
      'ventasM': _serieVentasMonto[i],
      'abonosC': _serieAbonosCount[i],
      'abonosM': _serieAbonosMonto[i],
      'cambiosC': _serieCambiosCount[i],
      'cambiosM': _serieCambiosMonto[i],
      'apartadosC': _serieApartadosCount[i],
      'apartadosM': _serieApartadosMonto[i],
    };
  }

  String _nombrePeriodo() {
    switch (_rango) {
      case RangoResumen.semana:
        return 'día';
      case RangoResumen.mes:
        return 'semana';
      case RangoResumen.anio:
        return 'mes';
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final idx = (_highlightIndex >= 0 && _highlightIndex < _labels.length)
        ? _highlightIndex
        : 0;
    final resumen = _resumenBucket(idx);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de ventas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // === 4) DETALLE: CARD CENTRADO DE ANCHO COMPLETO CON NÚMERO GRANDE ===
                _detalleCardCentrado(idx),
                // === 1) GRÁFICO ARRIBA ===
                _ChartCard(
                  labels: _labels,
                  values: _valuesForChart,
                  highlightIndex: _highlightIndex,
                  modoTorta: _modoTorta,
                  onBarTap: (i) => setState(() => _highlightIndex = i),
                ),

                const SizedBox(height: 8),

                // === 2) FILTROS PEQUEÑOS (debajo del gráfico) ===
                _FiltrosChips(
                  rango: _rango,
                  cat: _cat,
                  modoTorta: _modoTorta,
                  onRango: (r) => setState(() {
                    _rango = r;
                    _aplicarRango(_rango);
                  }),
                  onCat: (c) => setState(() => _cat = c),
                  onModo: (torta) => setState(() => _modoTorta = torta),
                ),
              ],
            ),
    );
  }

  Widget _detalleCardCentrado(int idx) {
    final d = _detalleBucket(idx);
    final totalPeriodo =
        (d['ventasM'] as double) +
        (d['abonosM'] as double) +
        (d['cambiosM'] as double);

    // 👇 Ganancia del bucket (día/semana/mes) seleccionado
    final resumenSel = _resumenBucket(idx);
    final gananciaSel = resumenSel.ganancia;

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Detalle del ${_nombrePeriodo()} • ${_labels[idx]}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _fmtMon.format(totalPeriodo),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 14),

            // Resumen corto por tipo (sin listados)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _pill(
                  icon: Icons.shopping_bag,
                  color: const Color(0xFF2563EB),
                  text:
                      'Ventas: ${d['ventasC']} • ${_fmtMon.format(d['ventasM'])}',
                ),
                _pill(
                  icon: Icons.savings,
                  color: const Color(0xFF059669),
                  text:
                      'Abonos: ${d['abonosC']} • ${_fmtMon.format(d['abonosM'])}',
                ),
                _pill(
                  icon: Icons.swap_horiz,
                  color: const Color(0xFF7C3AED),
                  text:
                      'Cambios: ${d['cambiosC']} • ${_fmtMon.format(d['cambiosM'])}',
                ),
                _pill(
                  icon: Icons.bookmark_add,
                  color: const Color(0xFFF59E0B),
                  text:
                      'Apartados: ${d['apartadosC']}',
                ),

                // 👇 Nueva pastilla de Ganancias (según día/semana/mes seleccionado)
                _pill(
                  icon: Icons.trending_up,
                  color: const Color(0xFF16A34A),
                  text: 'Ganancias: ${_fmtMon.format(gananciaSel)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required Color color,
    required String text,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 8,
    ),
    double fontSize = 12,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Widgets auxiliares visuales ======
class _CuadrosPeriodo extends StatelessWidget {
  final String totalVendido;
  final String ganancias;
  final String prendas;
  final String fechaTxt;

  const _CuadrosPeriodo({
    required this.totalVendido,
    required this.ganancias,
    required this.prendas,
    required this.fechaTxt,
  });

  @override
  Widget build(BuildContext context) {
    final sCap = const TextStyle(fontSize: 12, color: Colors.black54);
    final sVal = const TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

    Widget card(IconData ic, Color c, String cap, String val) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: c.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: c.withOpacity(.15),
              child: Icon(ic, color: c, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cap,
                    style: sCap,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(val, style: sVal),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cols = (w >= 720) ? 3 : (w >= 420 ? 2 : 1);
        final spacing = 8.0;
        final itemW = (w - spacing * (cols - 1)) / cols;

        final items = [
          SizedBox(
            width: itemW,
            child: card(
              Icons.payments,
              const Color(0xFF1D4ED8),
              'Vendido (selección)',
              totalVendido,
            ),
          ),
          SizedBox(
            width: itemW,
            child: card(
              Icons.attach_money,
              const Color(0xFF059669),
              'Ganancias',
              ganancias,
            ),
          ),
          SizedBox(
            width: itemW,
            child: card(
              Icons.shopping_bag,
              const Color(0xFF7C3AED),
              'Prendas',
              prendas,
            ),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fechaTxt, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(spacing: spacing, runSpacing: spacing, children: items),
          ],
        );
      },
    );
  }
}

class _FiltrosChips extends StatelessWidget {
  final RangoResumen rango;
  final CategoriaChart cat;
  final bool modoTorta;
  final ValueChanged<RangoResumen> onRango;
  final ValueChanged<CategoriaChart> onCat;
  final ValueChanged<bool> onModo;

  const _FiltrosChips({
    required this.rango,
    required this.cat,
    required this.modoTorta,
    required this.onRango,
    required this.onCat,
    required this.onModo,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String t, bool sel, VoidCallback onTap) => ChoiceChip(
      label: Text(t, style: const TextStyle(fontSize: 12, height: 1)),
      selected: sel,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );

    return Column(
      children: [
        // Fila 1: Día / Semana / Mes (centrado)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            chip(
              'Día',
              rango == RangoResumen.semana,
              () => onRango(RangoResumen.semana),
            ),
            chip(
              'Semana',
              rango == RangoResumen.mes,
              () => onRango(RangoResumen.mes),
            ),
            chip(
              'Mes',
              rango == RangoResumen.anio,
              () => onRango(RangoResumen.anio),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Fila 2: Todos / Ventas / Abonos / Cambios (centrado)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            chip(
              'Todos',
              cat == CategoriaChart.todos,
              () => onCat(CategoriaChart.todos),
            ),
            chip(
              'Ventas',
              cat == CategoriaChart.ventas,
              () => onCat(CategoriaChart.ventas),
            ),
            chip(
              'Abonos',
              cat == CategoriaChart.abonos,
              () => onCat(CategoriaChart.abonos),
            ),
            chip(
              'Cambios',
              cat == CategoriaChart.cambios,
              () => onCat(CategoriaChart.cambios),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== Gráfico =====
class _ChartCard extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final int highlightIndex;
  final bool modoTorta;
  final ValueChanged<int> onBarTap;

  const _ChartCard({
    required this.labels,
    required this.values,
    required this.highlightIndex,
    required this.modoTorta,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    const double barW = 24;
    const double gap = 12;
    const double minPad = 16;
    const double chartH = 220;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: values.isEmpty
            ? const SizedBox(
                height: chartH,
                child: Center(child: Text('Sin datos')),
              )
            : (modoTorta
                  ? _PieChart(
                      values: values,
                      labels: labels,
                      highlightIndex: highlightIndex,
                      onTapSlice: onBarTap,
                    )
                  : LayoutBuilder(
                      builder: (context, cts) {
                        final double avail =
                            cts.maxWidth; // ancho visible de la card
                        final double barsW = values.length * (barW + gap) - gap;
                        final bool needScroll = (barsW + minPad * 2) > avail;

                        final double padLeft = needScroll
                            ? minPad
                            : ((avail - barsW) / 2).clamp(
                                minPad,
                                double.infinity,
                              );
                        final double padRight = padLeft;
                        final double canvasW = needScroll
                            ? barsW + padLeft + padRight
                            : avail;

                        final chart = SizedBox(
                          width: canvasW,
                          height: chartH,
                          child: _BarsInteractive(
                            values: values,
                            barWidth: barW,
                            gap: gap,
                            paddingLeft: padLeft,
                            paddingRight: padRight,
                            highlightIndex: highlightIndex,
                            onTapIndex: onBarTap,
                          ),
                        );

                        final labelsRow = SizedBox(
                          width: canvasW,
                          child: Row(
                            children: [
                              SizedBox(width: padLeft),
                              for (int i = 0; i < values.length; i++) ...[
                                SizedBox(
                                  width: barW, // mismo ancho que la barra
                                  child: Builder(
                                    builder: (_) {
                                      final parts = labels[i].split(
                                        ' ',
                                      ); // "Lun 25"
                                      final top = parts.isNotEmpty
                                          ? parts[0]
                                          : labels[i]; // Lun
                                      final bottom = parts.length > 1
                                          ? parts[1]
                                          : ''; // 25
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            top,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            bottom,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.black.withOpacity(
                                                .65,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (i != values.length - 1)
                                  SizedBox(
                                    width: gap,
                                  ), // espacio entre etiquetas
                              ],
                              SizedBox(width: padRight),
                            ],
                          ),
                        );

                        if (needScroll) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.hardEdge,
                            child: Column(
                              children: [
                                chart,
                                const SizedBox(height: 8),
                                labelsRow,
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        } else {
                          return Column(
                            children: [
                              chart,
                              const SizedBox(height: 8),
                              labelsRow,
                              const SizedBox(height: 8),
                            ],
                          );
                        }
                      },
                    )),
      ),
    );
  }
}

class _BarsInteractive extends StatelessWidget {
  final List<double> values;
  final double barWidth;
  final double gap;
  final double paddingLeft;
  final double paddingRight;
  final int highlightIndex;
  final ValueChanged<int> onTapIndex;

  const _BarsInteractive({
    required this.values,
    required this.barWidth,
    required this.gap,
    required this.paddingLeft,
    required this.paddingRight,
    required this.highlightIndex,
    required this.onTapIndex,
  });

  int _indexFromDx(double dx) {
    final x = dx - paddingLeft;
    if (x < 0) return -1;
    final bwg = barWidth + gap;
    final idx = (x / bwg).floor();
    if (idx < 0 || idx >= values.length) return -1;
    final r = x - idx * bwg;
    return (r <= barWidth) ? idx : -1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        final idx = _indexFromDx(d.localPosition.dx);
        if (idx >= 0) onTapIndex(idx);
      },
      child: CustomPaint(
        painter: _BarsPainter(
          values: values,
          barWidth: barWidth,
          gap: gap,
          paddingLeft: paddingLeft,
          paddingRight: paddingRight,
          highlightIndex: highlightIndex,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double barWidth;
  final double gap;
  final double paddingLeft;
  final double paddingRight;
  final int highlightIndex;

  _BarsPainter({
    required this.values,
    this.barWidth = 24,
    this.gap = 12,
    this.paddingLeft = 16,
    this.paddingRight = 16,
    this.highlightIndex = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintBar = Paint()..color = const Color(0xFF4CAF50);
    final paintBarHi = Paint()..color = const Color(0xFF1976D2);
    final paintGhost = Paint()
      ..color = const Color(0xFF9E9E9E).withOpacity(0.25);
    final paintAxis = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;

    final double maxVal = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b);
    const double topPad = 12;
    const double bottomPad = 24;

    final double usableH = size.height - topPad - bottomPad;
    final double scale = (maxVal <= 0) ? 0 : usableH / (maxVal * 1.15);

    final baseY = size.height - bottomPad;

    // Eje X a lo ancho visible
    canvas.drawLine(
      Offset(paddingLeft, baseY),
      Offset(size.width - paddingRight, baseY),
      paintAxis,
    );

    double x = paddingLeft;
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) {
        const double ghostH = 8.0;
        final rectGhost = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - ghostH, barWidth, ghostH),
          const Radius.circular(6),
        );
        canvas.drawRRect(rectGhost, paintGhost);
      } else {
        const double minH = 2.0;
        final double h = (v * scale).clamp(minH, double.infinity);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - h, barWidth, h),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, (i == highlightIndex) ? paintBarHi : paintBar);
      }
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) {
    return old.values != values ||
        old.barWidth != barWidth ||
        old.gap != gap ||
        old.paddingLeft != paddingLeft ||
        old.paddingRight != paddingRight ||
        old.highlightIndex != highlightIndex;
  }
}

// -------- Pie / Donut simple con taps ----------
class _PieChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final int highlightIndex;
  final ValueChanged<int> onTapSlice;

  const _PieChart({
    required this.values,
    required this.labels,
    required this.highlightIndex,
    required this.onTapSlice,
  });

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0.0, (a, b) => a + b);
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: Center(
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final size = box.size;
                final center = Offset(size.width / 2, 110);
                final p = details.localPosition - center;
                if (p.distance == 0 || total == 0) return;
                double angle = (p.direction);
                if (angle < 0) angle += 2 * 3.141592653589793;

                double acc = 0;
                for (int i = 0; i < values.length; i++) {
                  final frac = (values[i] <= 0) ? 0.0 : values[i] / total;
                  final sweep = frac * 2 * 3.141592653589793;
                  if (angle >= acc && angle < acc + sweep) {
                    onTapSlice(i);
                    break;
                  }
                  acc += sweep;
                }
              },
              child: CustomPaint(
                size: const Size(280, 220),
                painter: _PiePainter(
                  values: values,
                  highlightIndex: highlightIndex,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(values.length, (i) {
            final color = _PiePainter.colors[i % _PiePainter.colors.length];
            final v = values[i];
            final pct = total == 0 ? 0 : (v / total) * 100;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${labels[i]} • ${pct.toStringAsFixed(1)}%'),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<double> values;
  final int highlightIndex;

  _PiePainter({required this.values, required this.highlightIndex});

  static const colors = <Color>[
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFFEF5350),
    Color(0xFF26A69A),
    Color(0xFF9CCC65),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF5C6BC0),
    Color(0xFFEC407A),
    Color(0xFF7E57C2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0.0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.55;
    final paintHi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.65;

    double start = -3.141592653589793 / 2;
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final frac = total == 0 ? 0.0 : (v / total);
      final sweep = frac * 2 * 3.141592653589793;

      final p = (i == highlightIndex) ? paintHi : paint;
      p.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        p,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.highlightIndex != highlightIndex;
  }
}

// ===== Modelos =====
class _VentaRecord {
  final String id;
  final String cliente;
  final DateTime fecha;
  final double total;
  final double ganancia;
  final int prendas;
  final _VentaTipo tipo;

  _VentaRecord({
    required this.id,
    required this.cliente,
    required this.fecha,
    required this.total,
    required this.ganancia,
    required this.prendas,
    required this.tipo,
  });
}

class _ApartadoRecord {
  final String id;
  final String cliente;
  final DateTime fecha;
  final double valorTotal;

  _ApartadoRecord({
    required this.id,
    required this.cliente,
    required this.fecha,
    required this.valorTotal,
  });
}
