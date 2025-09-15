import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gestion_inventario/screens/ventas/ventas_resumen.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';

class HistorialVentasPage extends StatefulWidget {
  const HistorialVentasPage({super.key});

  @override
  State<HistorialVentasPage> createState() => _HistorialVentasPageState();
}

class _HistorialVentasPageState extends State<HistorialVentasPage> {
  final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
  final _fmtMon = NumberFormat.currency(locale: 'es_CO', symbol: r'$');
  Future<List<Map<String, dynamic>>>? _future;

  bool _dialogAbierto = false;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  // --- Helpers de fecha para filtrar "HOY" (hora local) ---
  DateTime _parseLocal(dynamic v) {
    try {
      final d = DateTime.parse('$v');
      return d.isUtc ? d.toLocal() : d;
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  bool _inToday(DateTime d) {
    final now = DateTime.now();
    final ini = DateTime(now.year, now.month, now.day);
    final fin = ini.add(const Duration(days: 1));
    return !d.isBefore(ini) && d.isBefore(fin);
  }

  Future<List<Map<String, dynamic>>> _cargar() async {
    final ventas = await MongoService().getVentas(); // trae todo

    // Filtra SOLO ventas de HOY (hora local)
    final hoy = ventas.where((v) {
      final f = _parseLocal(v['fechaVenta']);
      return _inToday(f);
    }).toList();

    // ⛔️ Ocultar siempre los cierres de apartado (solo sirven para la ganancia)
    // y cualquier registro marcado explícitamente para no mostrar.
    hoy.removeWhere((v) {
      final tipo = ('${v['tipoVenta'] ?? ''}').toLowerCase().trim();
      final ocultar = v['ocultarEnHistorial'] == true;
      return ocultar || (tipo == 'apartado_pagado');
    });

    // Ordena desc por fecha de hoy
    hoy.sort((a, b) {
      final da = _parseLocal(a['fechaVenta']);
      final db = _parseLocal(b['fechaVenta']);
      return db.compareTo(da);
    });

    return hoy;
  }

  Future<void> _refresh() async {
    final nuevo = await _cargar();
    if (!mounted) return;
    setState(() => _future = Future.value(nuevo));
  }

  // ---------- Helpers de imagen ----------
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

  // ---------- Diálogo fotográfico ----------
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
    final precioP = _precioItem(p);

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
                          _fmtMon.format(precioP),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fmtFecha.format(fechaVenta),
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
  }

  // ---------- Utils ----------
  String _tituloVenta(List productos) {
    if (productos.isEmpty) return 'VENTA';
    final p0 = (productos.first as Map).cast<String, dynamic>();
    final nombre0 = '${p0['nombre'] ?? 'Producto'}'.toUpperCase();
    if (productos.length == 1) return nombre0;
    return '$nombre0 +${productos.length - 1} MÁS';
  }

  double _precioItem(dynamic raw) {
    final v = (raw is Map)
        ? (raw['precioVendido'] ?? raw['precioVenta'] ?? 0)
        : 0;
    return (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    const brandA = Color(0xFF16A34A); // green
    const brandB = Color(0xFF0EA5E9); // cyan

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
                // Mostrar el cuadro de diálogo para ingresar la contraseña
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
                        obscureText: true, // ocultar texto al escribir
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            final password = controller.text.trim();
                            if (password == correctPassword) {
                              Navigator.of(
                                context,
                              ).pop(true); // Contraseña correcta
                            } else {
                              Navigator.of(
                                context,
                              ).pop(false); // Contraseña incorrecta
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

                // Si la contraseña es correcta, navegar a la página de resumen
                if (isValid ?? false) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResumenVentasPage(),
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
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final ventas = snap.data ?? [];
            if (ventas.isEmpty) {
              return const Center(child: Text('No hay ventas registradas hoy'));
            }

            // Resumen superior (solo hoy)
            final double totalGeneral = ventas.fold<double>(
              0.0,
              (acc, v) =>
                  acc +
                  ((v['total'] is num)
                      ? (v['total'] as num).toDouble()
                      : double.tryParse('${v['total']}') ?? 0.0),
            );
            DateTime? ultima;
            for (final v in ventas) {
              final f = _parseLocal(v['fechaVenta']);
              ultima = (ultima == null || f.isAfter(ultima!)) ? f : ultima;
            }

            // Construye la lista: resumen + items
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
                                  _fmtMon.format(totalGeneral),
                                ),
                                _chipStat(
                                  'Última',
                                  ultima == null
                                      ? '—'
                                      : _fmtFecha.format(ultima!),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mostrando únicamente las ventas del día actual. '
                              'Para consultar otros días usa el botón “Resumen”.',
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

            // Tarjetas de cada venta (de hoy)
            for (final v in ventas) {
              final String tipoVenta = (v['tipoVenta'] as String?) ?? '';
              final Map origenMap = (v['origen'] as Map?) ?? const {};
              final String evento = '${origenMap['evento'] ?? ''}';

              final bool esCambio = tipoVenta == 'cambio';
              final bool esAbono = tipoVenta == 'abono_apartado';
              // tratamos el abono final igual que un abono normal
              final bool esAbonoFinal = esAbono && (evento == 'abono_final');

              final cliente = (v['cliente'] ?? {}) as Map;
              final nombreCliente = '${cliente['nombre'] ?? 'Sin nombre'}';
              final tel = '${cliente['telefono'] ?? ''}';
              final subtotal = (v['subtotal'] ?? 0);
              final descuento = (v['descuento'] ?? 0);
              final total = (v['total'] ?? 0);

              final fecha = _parseLocal(v['fechaVenta']);
              final productos = (v['productos'] ?? []) as List;

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
                          color: const Color.fromRGBO(244, 143, 177, 1),
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
                                _chipTipo(
                                  'ABONO',
                                  Colors.indigo,
                                ), // ← único chip
                              ],
                              if (esCambio) ...[
                                const SizedBox(width: 8),
                                _chipTipo('CAMBIO', Colors.deepPurple),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fmtMon.format(_asDouble(total)),
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
                                _fmtFecha.format(fecha),
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
                                          _fmtMon.format(_precioItem(p)),
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
                        _rowKV('Subtotal', _fmtMon.format(_asDouble(subtotal))),
                        const SizedBox(height: 4),
                        _rowKV(
                          'Descuento',
                          _fmtMon.format(_asDouble(descuento)),
                        ),
                        const SizedBox(height: 6),
                        _rowKV(
                          'Total',
                          _fmtMon.format(_asDouble(total)),
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

  // ---------- Pequeños builders de UI ----------
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
}
