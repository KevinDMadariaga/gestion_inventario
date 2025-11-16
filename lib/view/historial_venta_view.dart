import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gestion_inventario/ViewModel/historial_venta_viewmodel.dart';
import 'package:gestion_inventario/models/historial_venta_model.dart';
import 'package:gestion_inventario/view/ventas_resumen_view.dart';

class HistorialVentasView extends StatefulWidget {
  const HistorialVentasView({super.key});

  @override
  State<HistorialVentasView> createState() => _HistorialVentasViewState();
}

class _HistorialVentasViewState extends State<HistorialVentasView> {
  late final HistorialVentaViewModel vm;
  bool _dialogAbierto = false;

  @override
  void initState() {
    super.initState();
    vm = HistorialVentaViewModel();
  }

  // ---------- Helpers de imagen (mantengo en la vista) ----------
  Widget _buildProductImageFromVentaItem(
    Map<String, dynamic> item, {
    double w = 44,
    double h = 44,
    BoxFit fit = BoxFit.cover,
  }) {
    final String b64 = (item['fotoBase64'] ?? '') as String;
    final String f = (item['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b64), width: w, height: h, fit: fit);
      } catch (_) {}
    }
    if (f.startsWith('http://') || f.startsWith('https://')) {
      return Image.network(
        f,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (_, __, ___) => _imgPlaceholder(w, h, broken: true),
      );
    }
    if (f.isNotEmpty && f.startsWith('/')) {
      final file = File(f);
      if (file.existsSync())
        return Image.file(file, width: w, height: h, fit: fit);
    }
    if (f.isNotEmpty && !f.startsWith('http') && !f.startsWith('/')) {
      try {
        return Image.memory(base64Decode(f), width: w, height: h, fit: fit);
      } catch (_) {}
    }
    return _imgPlaceholder(w, h);
  }

  Widget _imgPlaceholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  Future<void> _abrirDialogoProducto(
    Map<String, dynamic> p,
    DateTime fechaVenta,
  ) async {
    if (_dialogAbierto) {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 60));
    }
    _dialogAbierto = true;

    final nombreP = '${p['nombre'] ?? ''}'.toUpperCase();
    final precioP = vm.precioItem(p);

    Widget img = _imgPlaceholder(320, 320);
    final String b64 = (p['fotoBase64'] ?? '') as String;
    final String f = (p['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        img = Image.memory(base64Decode(b64), fit: BoxFit.contain);
      } catch (_) {}
    } else if (f.startsWith('http')) {
      img = Image.network(f, fit: BoxFit.contain);
    } else if (f.isNotEmpty && f.startsWith('/')) {
      final file = File(f);
      img = file.existsSync() ? Image.file(file, fit: BoxFit.contain) : img;
    } else if (f.isNotEmpty) {
      try {
        img = Image.memory(base64Decode(f), fit: BoxFit.contain);
      } catch (_) {}
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: LayoutBuilder(
          builder: (context, c) {
            final maxH = MediaQuery.of(context).size.height * 0.80;
            final maxW = MediaQuery.of(context).size.width * 0.95;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH, maxWidth: maxW),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: InteractiveViewer(
                          child: FittedBox(fit: BoxFit.contain, child: img),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nombreP,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vm.fmtMon.format(precioP),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vm.fmtFecha.format(fechaVenta),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    _dialogAbierto = false;
  }

  String _tituloVenta(List productos) {
    if (productos.isEmpty) return 'VENTA';
    final p0 = (productos.first as Map).cast<String, dynamic>();
    final nombre0 = '${p0['nombre'] ?? 'Producto'}'.toUpperCase();
    if (productos.length == 1) return nombre0;
    return '$nombre0 +${productos.length - 1} MÁS';
  }

  Widget _chipStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _chipTipo(String text, Color color) {
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: color,
    );
  }

  Widget _rowKV(
    String k,
    String v, {
    bool strongRight = false,
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: strongRight ? FontWeight.bold : FontWeight.normal,
              color: emphasize ? Colors.green[800] : null,
              fontSize: emphasize ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(width: 3),
            Text(
              'Historial de ventas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromRGBO(244, 143, 177, 1),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () async {
                final correctPassword = '0210';
                final controller = TextEditingController();
                final isValid = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Ingresa la contraseña'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          hintText: 'Ingrese 4 dígitos',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            final password = controller.text.trim();
                            if (password == correctPassword) {
                              Navigator.of(context).pop(true);
                            } else {
                              Navigator.of(context).pop(false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contraseña incorrecta'),
                                ),
                              );
                            }
                          },
                          child: const Text('Aceptar'),
                        ),
                      ],
                    );
                  },
                );

                if (isValid ?? false) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResumenVentasView(),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.analytics, size: 30),
              label: const Text(''),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => vm.refresh(),
        child: FutureBuilder<List<VentaHistorialModel>>(
          future: vm.future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snap.hasError)
              return Center(child: Text('Error: ${snap.error}'));
            final ventas = snap.data ?? [];
            if (ventas.isEmpty)
              return const Center(child: Text('No hay ventas registradas hoy'));

            final double totalGeneral = ventas.fold<double>(
              0.0,
              (acc, v) => acc + (v.total),
            );
            DateTime? ultima;
            for (final v in ventas) {
              final f = vm.parseLocal(v.fechaVentaRaw);
              ultima = (ultima == null || f.isAfter(ultima)) ? f : ultima;
            }

            final List<Widget> children = [];

            children.add(
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.insights, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              runSpacing: 6,
                              spacing: 12,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                _chipStat('Ventas', '${ventas.length}'),
                                _chipStat(
                                  'Ingresos',
                                  vm.fmtMon.format(totalGeneral),
                                ),
                                _chipStat(
                                  'Última',
                                  ultima == null
                                      ? '—'
                                      : vm.fmtFecha.format(ultima),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mostrando únicamente las ventas del día actual. Para consultar otros días usa el botón “Resumen”.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            for (final v in ventas) {
              final String tipoVenta = v.tipoVenta;
              final Map origenMap = v.origen;
              final String evento = '${origenMap['evento'] ?? ''}';

              final bool esCambio = tipoVenta == 'cambio';
              final bool esAbono = tipoVenta == 'abono_apartado';
              final bool esAbonoFinal = esAbono && (evento == 'abono_final');

              final cliente = v.cliente;
              final nombreCliente = '${cliente['nombre'] ?? 'Sin nombre'}';
              final tel = '${cliente['telefono'] ?? ''}';
              final subtotal = v.subtotal;
              final descuento = v.descuento;
              final total = v.total;

              final fecha = vm.parseLocal(v.fechaVentaRaw);
              final productos = v.productos;

              children.add(
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 0.7,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            76,
                            78,
                            175,
                          ).withOpacity(.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          color: Color.fromRGBO(244, 143, 177, 1),
                        ),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _tituloVenta(productos),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: .4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (esAbono || esAbonoFinal) ...[
                                const SizedBox(width: 8),
                                _chipTipo('ABONO', Colors.indigo),
                              ],
                              if (esCambio) ...[
                                const SizedBox(width: 8),
                                _chipTipo('CAMBIO', Colors.deepPurple),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vm.fmtMon.format(vm.asDouble(total)),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vm.fmtFecha.format(fecha),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                        const SizedBox(height: 8),
                        _rowKV('Cliente', nombreCliente, strongRight: true),
                        const SizedBox(height: 6),
                        _rowKV('Teléfono', tel.isEmpty ? '—' : tel),
                        const SizedBox(height: 14),
                        if (productos.isNotEmpty) ...[
                          const Center(
                            child: Text(
                              'Productos vendidos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 240,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: productos.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final p = (productos[i] as Map)
                                    .cast<String, dynamic>();
                                final nombreP = '${p['nombre'] ?? ''}'
                                    .toUpperCase();
                                return GestureDetector(
                                  onTap: () => _abrirDialogoProducto(p, fecha),
                                  child: Container(
                                    width: 170,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child:
                                                _buildProductImageFromVentaItem(
                                                  p,
                                                  w: double.infinity,
                                                  h: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          nombreP,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          vm.fmtMon.format(vm.precioItem(p)),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _rowKV(
                          'Subtotal',
                          vm.fmtMon.format(vm.asDouble(subtotal)),
                        ),
                        const SizedBox(height: 4),
                        _rowKV(
                          'Descuento',
                          vm.fmtMon.format(vm.asDouble(descuento)),
                        ),
                        const SizedBox(height: 6),
                        _rowKV(
                          'Total',
                          vm.fmtMon.format(vm.asDouble(total)),
                          strongRight: true,
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView(children: children);
          },
        ),
      ),
    );
  }
}
