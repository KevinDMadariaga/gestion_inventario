import 'package:flutter/material.dart';
import 'package:gestion_inventario/ViewModel/ventas_resumen_viewmodel.dart';
import 'package:gestion_inventario/models/ventas_resumen_model.dart';

class ResumenVentasView extends StatefulWidget {
  const ResumenVentasView({super.key});

  @override
  State<ResumenVentasView> createState() => _ResumenVentasViewState();
}

class _ResumenVentasViewState extends State<ResumenVentasView> {
  late final VentasResumenViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = VentasResumenViewModel();
    vm.addListener(_onVm);
  }

  void _onVm() => setState(() {});

  @override
  void dispose() {
    vm.removeListener(_onVm);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = (vm.highlightIndex >= 0 && vm.highlightIndex < vm.labels.length)
        ? vm.highlightIndex
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de ventas')),
      body: vm.cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(10),
              children: [
                _detalleCardCentrado(idx),
                _ChartCard(
                  labels: vm.labels,
                  values: vm.valuesForChart,
                  highlightIndex: vm.highlightIndex,
                  modoTorta: vm.modoTorta,
                  onBarTap: (i) => vm.setHighlight(i),
                ),
                const SizedBox(height: 8),
                _FiltrosChips(
                  rango: vm.rango,
                  cat: vm.cat,
                  modoTorta: vm.modoTorta,
                  onRango: (r) => vm.setRango(r),
                  onCat: (c) => vm.setCat(c),
                  onModo: (t) => vm.setModo(t),
                ),
              ],
            ),
    );
  }

  Widget _detalleCardCentrado(int idx) {
    final d = vm.detalleBucket(idx);
    final totalPeriodo =
        (d['ventasM'] as double) +
        (d['abonosM'] as double) +
        (d['cambiosM'] as double);
    final resumenSel = vm.resumenBucket(idx);
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
              'Detalle del ${vm.nombrePeriodo()} • ${vm.labels[idx]}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              vm.fmtMon.format(totalPeriodo),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _pill(
                  icon: Icons.shopping_bag,
                  color: const Color(0xFF2563EB),
                  text:
                      'Ventas: ${d['ventasC']} • ${vm.fmtMon.format(d['ventasM'])}',
                ),
                _pill(
                  icon: Icons.savings,
                  color: const Color(0xFF059669),
                  text:
                      'Abonos: ${d['abonosC']} • ${vm.fmtMon.format(d['abonosM'])}',
                ),
                _pill(
                  icon: Icons.swap_horiz,
                  color: const Color(0xFF7C3AED),
                  text:
                      'Cambios: ${d['cambiosC']} • ${vm.fmtMon.format(d['cambiosM'])}',
                ),
                _pill(
                  icon: Icons.bookmark_add,
                  color: const Color(0xFFF59E0B),
                  text: 'Apartados: ${d['apartadosC']}',
                ),
                _pill(
                  icon: Icons.trending_up,
                  color: const Color(0xFF16A34A),
                  text: 'Ganancias: ${vm.fmtMon.format(gananciaSel)}',
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

// Re-using auxiliary widgets from the original screen (minimal port)
// For brevity, only include the filter chips and chart/card widgets used above.

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
            : LayoutBuilder(
                builder: (context, cts) {
                  final double avail = cts.maxWidth;
                  final double barsW = values.length * (barW + gap) - gap;
                  final bool needScroll = (barsW + minPad * 2) > avail;
                  final double padLeft = needScroll
                      ? minPad
                      : ((avail - barsW) / 2).clamp(minPad, double.infinity);
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
                            width: barW,
                            child: Builder(
                              builder: (_) {
                                final parts = labels[i].split(' ');
                                final top = parts.isNotEmpty
                                    ? parts[0]
                                    : labels[i];
                                final bottom = parts.length > 1 ? parts[1] : '';
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
                                        color: Colors.black.withOpacity(.65),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (i != values.length - 1) SizedBox(width: gap),
                        ],
                        SizedBox(width: padRight),
                      ],
                    ),
                  );

                  if (needScroll)
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
                  else
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: 8),
                        labelsRow,
                        const SizedBox(height: 8),
                      ],
                    );
                },
              ),
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
